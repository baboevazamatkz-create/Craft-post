import 'dart:typed_data';

import '../models/post_draft.dart';

/// Краткая запись для списка истории.
class PostSummary {
  final String id;
  final DateTime createdAt;
  final String title;
  final int total;
  final int saved;
  final Uint8List? preview;
  PostSummary(this.id, this.createdAt, this.title, this.total, this.saved,
      this.preview);

  static PostSummary of(PostDraft d, Uint8List? preview) => PostSummary(
        d.id ?? '',
        d.createdAt,
        d.infographic.title.isNotEmpty
            ? d.infographic.title
            : (d.fields['object'] ?? 'Без названия'),
        d.imageCount,
        d.saved.where((s) => s).length,
        preview,
      );
}

/// История постов внутри приложения. На телефоне — файлы в папке
/// приложения, в браузере — IndexedDB. Фото поста адресуются строками
/// («ссылками»): путь к файлу, blob-URL браузера или ключ хранилища.
abstract class PostStore {
  /// Сохраняет пост. При первом вызове назначает id и копирует исходные
  /// фото к себе (временные файлы выбора фото могут исчезнуть).
  Future<void> save(PostDraft d, {bool previews = true});
  Future<List<PostSummary>> list();
  Future<PostDraft> load(String id);
  Future<void> delete(String id);

  /// Байты фото по ссылке (любой из видов выше).
  Future<Uint8List> readPhoto(String ref);
}
