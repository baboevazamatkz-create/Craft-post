import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import '../models/post_draft.dart';
import '../services/image_saver.dart';
import '../services/post_store.dart';

PostStore createPostStore() => _FilePostStore();
ImageSaver createImageSaver() => _GallerySaver();

/// JPEG-кодирование в отдельном изоляте.
Future<Uint8List> encodeJpeg(Uint8List rgba, int w, int h, int quality) =>
    compute(_encodeJpg, _JpgJob(rgba, w, h, quality));

class _JpgJob {
  final Uint8List rgba;
  final int w, h, quality;
  _JpgJob(this.rgba, this.w, this.h, this.quality);
}

Uint8List _encodeJpg(_JpgJob j) {
  final im = img.Image.fromBytes(
      width: j.w, height: j.h, bytes: j.rgba.buffer, numChannels: 4);
  return Uint8List.fromList(img.encodeJpg(im, quality: j.quality));
}

class _GallerySaver implements ImageSaver {
  static const album = 'CRAFT SYSTEM';

  @override
  String get target => 'в галерею';

  @override
  Future<bool> ensureAccess() async {
    if (await Gal.hasAccess(toAlbum: true)) return true;
    return Gal.requestAccess(toAlbum: true);
  }

  @override
  Future<void> save(Uint8List jpeg, String name) =>
      Gal.putImageBytes(jpeg, album: album, name: name);
}

/// <documents>/posts/<id>/: post.json, копии исходных фото и превью.
class _FilePostStore implements PostStore {
  Future<Directory> _root() async {
    final dir =
        Directory('${(await getApplicationDocumentsDirectory()).path}/posts');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<Directory> _dir(String id) async =>
      Directory('${(await _root()).path}/$id');

  @override
  Future<Uint8List> readPhoto(String ref) => File(ref).readAsBytes();

  @override
  Future<void> save(PostDraft d, {bool previews = true}) async {
    d.id ??= DateTime.now().millisecondsSinceEpoch.toString();
    final dir = await _dir(d.id!);
    if (!await dir.exists()) await dir.create(recursive: true);

    Future<String> keep(String path, String prefix) async {
      if (path.startsWith(dir.path)) return path;
      final dot = path.lastIndexOf('.');
      final ext = dot > path.lastIndexOf('/') ? path.substring(dot) : '.jpg';
      final target =
          '${dir.path}/${prefix}_${DateTime.now().microsecondsSinceEpoch}$ext';
      await File(path).copy(target);
      return target;
    }

    final moved = <String, String>{};
    Future<String> track(String p, String prefix) async =>
        moved[p] = await keep(p, prefix);
    if (d.mainPath != null) d.mainPath = await track(d.mainPath!, 'main');
    d.otherPaths = [for (final p in d.otherPaths) await track(p, 'photo')];
    d.remapPhotos(moved);

    // Удаляем копии фото, которые больше не входят в пост.
    final used = {d.mainPath, ...d.otherPaths};
    await for (final f in dir.list()) {
      final name = f.path.split('/').last;
      if ((name.startsWith('main_') || name.startsWith('photo_')) &&
          !used.contains(f.path)) {
        await f.delete();
      }
    }

    if (previews) {
      for (final f in dir.listSync().whereType<File>()) {
        if (f.path.split('/').last.startsWith('preview_')) await f.delete();
      }
      final p = d.previews;
      for (var i = 0; i < p.length; i++) {
        await File('${dir.path}/preview_$i.jpg').writeAsBytes(p[i]);
      }
    }
    await File('${dir.path}/post.json').writeAsString(jsonEncode(d.toJson()));
  }

  @override
  Future<List<PostSummary>> list() async {
    final out = <PostSummary>[];
    await for (final e in (await _root()).list()) {
      final json = File('${e.path}/post.json');
      if (e is! Directory || !await json.exists()) continue;
      try {
        final d = PostDraft.fromJson(
            jsonDecode(await json.readAsString()) as Map<String, dynamic>);
        d.id ??= e.path.split('/').last;
        final prev = File('${e.path}/preview_0.jpg');
        out.add(PostSummary.of(
            d, await prev.exists() ? await prev.readAsBytes() : null));
      } catch (_) {
        // Повреждённую запись пропускаем.
      }
    }
    out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return out;
  }

  @override
  Future<PostDraft> load(String id) async {
    final dir = await _dir(id);
    final d = PostDraft.fromJson(
        jsonDecode(await File('${dir.path}/post.json').readAsString())
            as Map<String, dynamic>);
    final previews = <Uint8List>[];
    for (var i = 0; i < d.imageCount; i++) {
      final f = File('${dir.path}/preview_$i.jpg');
      if (!await f.exists()) break;
      previews.add(await f.readAsBytes());
    }
    if (previews.length == d.imageCount && previews.isNotEmpty) {
      d.mainPreview = previews.first;
      d.otherPreviews = previews.sublist(1);
    }
    return d;
  }

  @override
  Future<void> delete(String id) async {
    final dir = await _dir(id);
    if (await dir.exists()) await dir.delete(recursive: true);
  }
}
