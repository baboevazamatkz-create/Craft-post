import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:idb_shim/idb_browser.dart';
import 'package:web/web.dart' as web;

import '../models/post_draft.dart';
import '../services/image_saver.dart';
import '../services/post_store.dart';

PostStore createPostStore() => _IdbPostStore();
ImageSaver createImageSaver() => _DownloadSaver();

/// JPEG средствами браузера (canvas.toBlob) — в разы быстрее, чем на Dart.
Future<Uint8List> encodeJpeg(Uint8List rgba, int w, int h, int quality) async {
  final canvas = web.HTMLCanvasElement()
    ..width = w
    ..height = h;
  final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D;
  final data = web.ImageData(
      Uint8ClampedList.view(rgba.buffer, rgba.offsetInBytes, rgba.length).toJS,
      w,
      h.toJS);
  ctx.putImageData(data, 0, 0);
  final done = Completer<web.Blob?>();
  canvas.toBlob(((web.Blob? b) => done.complete(b)).toJS, 'image/jpeg',
      (quality / 100).toJS);
  final blob = await done.future;
  if (blob == null) throw Exception('Браузер не смог закодировать JPEG');
  final buf = await blob.arrayBuffer().toDart;
  return buf.toDart.asUint8List();
}

/// В браузере «сохранить» = скачать файл в «Загрузки».
class _DownloadSaver implements ImageSaver {
  @override
  String get target => 'в загрузки';

  @override
  Future<bool> ensureAccess() async => true;

  @override
  Future<void> save(Uint8List jpeg, String name) async {
    final blob =
        web.Blob([jpeg.toJS].toJS, web.BlobPropertyBag(type: 'image/jpeg'));
    final url = web.URL.createObjectURL(blob);
    final a = web.HTMLAnchorElement()
      ..href = url
      ..download = '$name.jpg';
    web.document.body!.append(a);
    a.click();
    a.remove();
    // Небольшая пауза: браузеры не любят пачку скачиваний в один момент.
    await Future<void>.delayed(const Duration(milliseconds: 600));
    Future<void>.delayed(
        const Duration(minutes: 1), () => web.URL.revokeObjectURL(url));
  }
}

/// История в IndexedDB браузера: «posts» — JSON поста, «files» — байты
/// исходных фото и превью с ключами «<id>/<имя>». Фото поста в черновике
/// хранятся как ссылки «idb:<id>/<имя>».
class _IdbPostStore implements PostStore {
  static const _posts = 'posts', _files = 'files', _prefix = 'idb:';
  Database? _db;

  Future<Database> _open() async => _db ??= await idbFactoryBrowser.open(
        'craft_posts',
        version: 1,
        onUpgradeNeeded: (e) {
          e.database.createObjectStore(_posts);
          e.database.createObjectStore(_files);
        },
      );

  static Uint8List _bytes(Object? v) => v is Uint8List
      ? v
      : v is ByteBuffer
          ? v.asUint8List()
          : Uint8List.fromList((v as List).cast<int>());

  Future<Uint8List?> _getFile(String key) async {
    final db = await _open();
    final txn = db.transaction(_files, idbModeReadOnly);
    final v = await txn.objectStore(_files).getObject(key);
    await txn.completed;
    return v == null ? null : _bytes(v);
  }

  Future<List<String>> _fileKeys(Transaction txn, String id) async {
    final keys = await txn
        .objectStore(_files)
        .getAllKeys(KeyRange.bound('$id/', '$id/￿'));
    return [for (final k in keys) '$k'];
  }

  @override
  Future<Uint8List> readPhoto(String ref) async {
    if (ref.startsWith(_prefix)) {
      final b = await _getFile(ref.substring(_prefix.length));
      if (b == null) throw Exception('Фото не найдено в истории');
      return b;
    }
    return XFile(ref).readAsBytes(); // blob-URL из выбора фото
  }

  @override
  Future<void> save(PostDraft d, {bool previews = true}) async {
    d.id ??= DateTime.now().millisecondsSinceEpoch.toString();
    final id = d.id!;

    // Читаем новые фото заранее: внутри транзакции IndexedDB ждать нельзя.
    final incoming = <String, Uint8List>{};
    Future<String> keep(String ref, String prefix) async {
      if (ref.startsWith(_prefix)) return ref;
      final key = '$id/${prefix}_${DateTime.now().microsecondsSinceEpoch}';
      incoming[key] = await XFile(ref).readAsBytes();
      return '$_prefix$key';
    }

    final moved = <String, String>{};
    Future<String> track(String p, String prefix) async =>
        moved[p] = await keep(p, prefix);
    if (d.mainPath != null) d.mainPath = await track(d.mainPath!, 'main');
    d.otherPaths = [for (final p in d.otherPaths) await track(p, 'photo')];
    d.remapPhotos(moved);
    final used = {d.mainPath, ...d.otherPaths}
        .whereType<String>()
        .map((r) => r.substring(_prefix.length))
        .toSet();

    final db = await _open();
    final txn = db.transaction([_posts, _files], idbModeReadWrite);
    final files = txn.objectStore(_files);
    for (final e in incoming.entries) {
      await files.put(e.value, e.key);
    }
    for (final k in await _fileKeys(txn, id)) {
      final name = k.substring(id.length + 1);
      final photo = name.startsWith('main_') || name.startsWith('photo_');
      if ((photo && !used.contains(k)) ||
          (previews && name.startsWith('preview_'))) {
        await files.delete(k);
      }
    }
    if (previews) {
      final p = d.previews;
      for (var i = 0; i < p.length; i++) {
        await files.put(p[i], '$id/preview_$i');
      }
    }
    await txn.objectStore(_posts).put(jsonEncode(d.toJson()), id);
    await txn.completed;
  }

  @override
  Future<List<PostSummary>> list() async {
    final db = await _open();
    final txn = db.transaction([_posts, _files], idbModeReadOnly);
    final out = <PostSummary>[];
    final keys = await txn.objectStore(_posts).getAllKeys();
    for (final k in keys) {
      try {
        final json = await txn.objectStore(_posts).getObject(k);
        final d =
            PostDraft.fromJson(jsonDecode('$json') as Map<String, dynamic>)
              ..id ??= '$k';
        final prev = await txn.objectStore(_files).getObject('$k/preview_0');
        out.add(PostSummary.of(d, prev == null ? null : _bytes(prev)));
      } catch (_) {
        // Повреждённую запись пропускаем.
      }
    }
    await txn.completed;
    out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return out;
  }

  @override
  Future<PostDraft> load(String id) async {
    final db = await _open();
    final txn = db.transaction([_posts, _files], idbModeReadOnly);
    final json = await txn.objectStore(_posts).getObject(id);
    final d = PostDraft.fromJson(jsonDecode('$json') as Map<String, dynamic>);
    final previews = <Uint8List>[];
    for (var i = 0; i < d.imageCount; i++) {
      final v = await txn.objectStore(_files).getObject('$id/preview_$i');
      if (v == null) break;
      previews.add(_bytes(v));
    }
    await txn.completed;
    if (previews.length == d.imageCount && previews.isNotEmpty) {
      d.mainPreview = previews.first;
      d.otherPreviews = previews.sublist(1);
    }
    return d;
  }

  @override
  Future<void> delete(String id) async {
    final db = await _open();
    final txn = db.transaction([_posts, _files], idbModeReadWrite);
    for (final k in await _fileKeys(txn, id)) {
      await txn.objectStore(_files).delete(k);
    }
    await txn.objectStore(_posts).delete(id);
    await txn.completed;
  }
}
