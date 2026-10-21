import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import 'models/post_draft.dart';
import 'services/ai/ai_factory.dart';
import 'services/ai/ai_provider.dart';
import 'platform/platform.dart';
import 'services/image/image_processor.dart';
import 'services/image_saver.dart';
import 'services/post_store.dart';
import 'services/settings_service.dart';

const kPreviewSide = 900;

enum SaveState { none, queued, saving, saved, error }

class AppState extends ChangeNotifier {
  final settings = SettingsService();
  final PostStore store = createPostStore();
  late final processor = ImageProcessor(read: store.readPhoto);
  final _picker = ImagePicker();
  final ImageSaver saver = createImageSaver();

  PostDraft draft = PostDraft();

  /// Состояние фонового сохранения каждой картинки (индекс как в [PostDraft]).
  List<SaveState> saveStates = [];
  String? lastSaveError;
  Future<void> _queue = Future.value();

  Future<void> pickMain() async {
    final f = await _picker.pickImage(source: ImageSource.gallery);
    if (f == null) return;
    // Новое главное фото у поста из истории — это уже новый пост.
    if (draft.id != null) reset();
    draft.mainPath = f.path;
    draft.otherPaths.remove(f.path);
    notifyListeners();
  }

  Future<void> pickOthers() async {
    final files = await _picker.pickMultiImage();
    if (files.isEmpty) return;
    draft.otherPaths =
        files.map((f) => f.path).where((p) => p != draft.mainPath).toList();
    notifyListeners();
  }

  void removeOther(String path) {
    draft.otherPaths.remove(path);
    notifyListeners();
  }

  void reset() {
    draft = PostDraft();
    saveStates = [];
    lastSaveError = null;
    notifyListeners();
  }

  /// Шаг «Создать»: AI (главное фото + поля), превью всех фото
  /// и запись поста в историю приложения.
  Future<void> generate() async {
    final providerId = await settings.provider();
    final ai = createAiProvider(providerId, await settings.apiKey());
    final photo = await processor.aiPhoto(draft.mainPath!);
    final result = await ai.generate(
        mainPhotoJpeg: photo, fields: draft.fields, features: draft.features);
    draft.caption = result.caption;
    draft.infographic = result.infographic
      ..stat = draft.fields['stat'] ?? ''
      ..unit = draft.fields['unit'] ?? '';
    draft.saved = List.filled(draft.imageCount, false);
    saveStates = List.filled(draft.imageCount, SaveState.none);
    await refreshPreviews();
  }

  /// AI-редактор главного фото: варианты значков по текущему превью.
  /// В AI уходит только главное фото (превью с инфографикой) и тексты.
  Future<IconIdeas> suggestIcons(String instruction) async {
    final ai =
        createAiProvider(await settings.provider(), await settings.apiKey());
    final jpeg = draft.mainPreview ?? await processor.aiPhoto(draft.mainPath!);
    return ai.suggestIcons(
        mainPreviewJpeg: jpeg,
        current: draft.infographic,
        instruction: instruction);
  }

  /// Перерисовывает превью и обновляет пост в истории. Главное фото после
  /// правок текста считается несохранённым.
  Future<void> refreshPreviews() async {
    draft.mainPreview = await processor.renderMain(
        draft.mainPath!, draft.infographic,
        maxSide: kPreviewSide, quality: 75);
    draft.otherPreviews = [
      for (final p in draft.otherPaths)
        await processor.renderOther(p, maxSide: kPreviewSide, quality: 75),
    ];
    _syncStates();
    if (saveStates[0] == SaveState.saved || saveStates[0] == SaveState.error) {
      saveStates[0] = SaveState.none;
      draft.saved[0] = false;
    }
    await store.save(draft);
    notifyListeners();
  }

  void _syncStates() {
    final n = draft.imageCount;
    draft.saved = [for (var i = 0; i < n; i++) draft.isSaved(i)];
    saveStates = [
      for (var i = 0; i < n; i++)
        i < saveStates.length && saveStates[i] != SaveState.saved
            ? saveStates[i]
            : (draft.saved[i] ? SaveState.saved : SaveState.none),
    ];
  }

  /// Ставит картинку в очередь на сохранение в галерею (полное разрешение).
  /// Очередь обрабатывает по одной картинке, пока пользователь листает дальше.
  void approve(int i) {
    final s = saveStates[i];
    if (s == SaveState.queued ||
        s == SaveState.saving ||
        s == SaveState.saved) {
      return;
    }
    saveStates[i] = SaveState.queued;
    notifyListeners();
    final post = draft;
    _queue = _queue.then((_) => _saveOne(post, i));
  }

  Future<void> _saveOne(PostDraft post, int i) async {
    final current = identical(post, draft);
    void set(SaveState s) {
      if (identical(post, draft)) {
        saveStates[i] = s;
        notifyListeners();
      }
    }

    try {
      if (!await saver.ensureAccess()) {
        throw Exception('Нет разрешения на сохранение ${saver.target}');
      }
      set(SaveState.saving);
      final jpg = i == 0
          ? await processor.renderMain(post.mainPath!, post.infographic)
          : await processor.renderOther(post.otherPaths[i - 1]);
      await saver.save(jpg, 'craft_${post.id ?? 'post'}_${i + 1}');
      if (i < post.saved.length) post.saved[i] = true;
      await store.save(post, previews: false);
      set(SaveState.saved);
    } catch (e) {
      lastSaveError = '$e';
      set(SaveState.error);
    }
    if (!current) notifyListeners();
  }

  int countState(Set<SaveState> states) =>
      saveStates.where(states.contains).length;

  Future<List<PostSummary>> history() => store.list();

  Future<void> openPost(String id) async {
    draft = await store.load(id);
    saveStates = [
      for (var i = 0; i < draft.imageCount; i++)
        draft.isSaved(i) ? SaveState.saved : SaveState.none
    ];
    if (draft.previews.length != draft.imageCount) {
      await refreshPreviews();
    }
    notifyListeners();
  }

  Future<void> deletePost(String id) async {
    await store.delete(id);
    if (draft.id == id) reset();
    notifyListeners();
  }
}
