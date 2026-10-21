import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../models/post_draft.dart';

/// Краткая запись для списка истории.
class PostSummary {
  final String id;
  final DateTime createdAt;
  final String title;
  final int total;
  final int saved;
  final File? preview;
  PostSummary(this.id, this.createdAt, this.title, this.total, this.saved,
      this.preview);
}

/// История постов внутри приложения: <documents>/posts/<id>/
/// post.json, копии исходных фото (для повторного экспорта) и превью.
class PostStore {
  Future<Directory> _root() async {
    final dir =
        Directory('${(await getApplicationDocumentsDirectory()).path}/posts');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<Directory> _dir(String id) async =>
      Directory('${(await _root()).path}/$id');

  /// Сохраняет пост. При первом вызове назначает id. Исходные фото
  /// копируются в папку поста (временные файлы галереи могут исчезнуть).
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

    if (d.mainPath != null) d.mainPath = await keep(d.mainPath!, 'main');
    d.otherPaths = [for (final p in d.otherPaths) await keep(p, 'photo')];

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

  Future<List<PostSummary>> list() async {
    final out = <PostSummary>[];
    await for (final e in (await _root()).list()) {
      final json = File('${e.path}/post.json');
      if (e is! Directory || !await json.exists()) continue;
      try {
        final d = PostDraft.fromJson(
            jsonDecode(await json.readAsString()) as Map<String, dynamic>);
        final prev = File('${e.path}/preview_0.jpg');
        out.add(PostSummary(
          d.id ?? e.path.split('/').last,
          d.createdAt,
          d.infographic.title.isNotEmpty
              ? d.infographic.title
              : (d.fields['object'] ?? 'Без названия'),
          d.imageCount,
          d.saved.where((s) => s).length,
          await prev.exists() ? prev : null,
        ));
      } catch (_) {
        // Повреждённую запись пропускаем.
      }
    }
    out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return out;
  }

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

  Future<void> delete(String id) async {
    final dir = await _dir(id);
    if (await dir.exists()) await dir.delete(recursive: true);
  }
}
