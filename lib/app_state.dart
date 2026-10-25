import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import 'models/post_draft.dart';
import 'services/ai/ai_factory.dart';
import 'services/ai/ai_provider.dart';
import 'platform/platform.dart';
import 'services/icon_catalog.dart';
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

  /// Выбор фото скопом (можно сразу все). Новые добавляются к уже
  /// выбранным; если главного ещё нет — им становится первое из выбранных.
  Future<void> pickPhotos() async {
    final files = await _picker.pickMultiImage();
    if (files.isEmpty) return;
    addPhotos([for (final f in files) f.path]);
  }

  void addPhotos(List<String> paths) {
    final known = {draft.mainPath, ...draft.otherPaths};
    final fresh = [
      for (final p in paths)
        if (!known.contains(p)) p
    ];
    if (fresh.isEmpty) return;
    draft.mainPath ??= fresh.removeAt(0);
    draft.otherPaths = [...draft.otherPaths, ...fresh];
    notifyListeners();
  }

  /// Делает фото главным: оно меняется местами с текущим главным.
  void setMain(String path) {
    final i = draft.otherPaths.indexOf(path);
    if (i < 0 || draft.mainPath == null) return;
    draft.otherPaths[i] = draft.mainPath!;
    draft.mainPath = path;
    notifyListeners();
  }

  /// Убирает фото из поста. Если убрали главное — главным становится
  /// первое из остальных.
  void removePhoto(String path) {
    if (path == draft.mainPath) {
      draft.mainPath =
          draft.otherPaths.isEmpty ? null : draft.otherPaths.removeAt(0);
    } else {
      draft.otherPaths.remove(path);
    }
    notifyListeners();
  }

  void reset() {
    draft = PostDraft();
    saveStates = [];
    lastSaveError = null;
    notifyListeners();
  }

  /// Подмена AI в тестах (заглушка без сети).
  @visibleForTesting
  AiProvider? aiOverride;

  Future<AiProvider> _ai() async =>
      aiOverride ??
      createAiProvider(await settings.provider(), await settings.apiKey());

  /// Шаг «Создать»: AI (главное фото + поля) пишет подпись, тексты
  /// инфографики и варианты преимуществ. Превью — после выбора значков.
  Future<void> generate() async {
    final ai = await _ai();
    final photo = await processor.aiPhoto(draft.mainPath!);
    final result =
        await ai.generate(mainPhotoJpeg: photo, fields: draft.fields);
    draft.caption = result.caption;
    draft.infographic = result.infographic
      ..stat = draft.fields['stat'] ?? ''
      ..unit = draft.fields['unit'] ?? '';
    draft.featureIdeas = result.featureIdeas;
    draft.saved = List.filled(draft.imageCount, false);
    saveStates = List.filled(draft.imageCount, SaveState.none);
    notifyListeners();
  }

  /// Ещё варианты преимуществ; новые добавляются в конец списка.
  Future<int> moreFeatureIdeas() async {
    final ai = await _ai();
    final photo = await processor.aiPhoto(draft.mainPath!, maxSide: 768);
    final fresh = await ai.suggestFeatures(
        mainPhotoJpeg: photo,
        fields: draft.fields,
        exclude: draft.featureIdeas);
    final added = [
      for (final f in fresh)
        if (!draft.featureIdeas.contains(f)) f
    ];
    draft.featureIdeas = [...draft.featureIdeas, ...added];
    notifyListeners();
    return added.length;
  }

  IconCatalog? _catalog;

  /// Библиотека значков (загружается один раз).
  Future<IconCatalog> catalog() async => _catalog ??= await IconCatalog.load();

  /// Значки из библиотеки к преимуществам: имена → пути (в AI уходят только
  /// подписи преимуществ и список имён).
  Future<List<List<(String, List<String>)>>> pickIcons(
      List<String> features, String instruction, Set<String> exclude) async {
    final cat = await catalog();
    final names = await (await _ai()).pickIcons(
        features: features,
        catalog: cat,
        exclude: exclude,
        instruction: instruction);
    return [
      for (final list in names) [for (final n in list) (n, cat.icons[n]!)]
    ];
  }

  /// Значки, нарисованные AI (дольше; идут фоном).
  Future<List<List<List<String>>>> drawIcons(
          List<String> features, String instruction) async =>
      (await _ai()).drawIcons(features: features, instruction: instruction);

  /// Выбранные преимущества со значками — на главное фото, затем превью.
  Future<void> setFeatures(List<Feature> features) async {
    draft.infographic.features = features;
    await refreshPreviews();
  }

  /// Плашки через AI: в AI уходят ВСЕ фото поста (главное — для понимания
  /// объекта), плашки ставятся на не главные. Существующие плашки заменяются.
  Future<int> suggestBadges() async {
    if (draft.otherPaths.isEmpty) return 0;
    final ai = await _ai();
    final main = await processor.aiPhoto(draft.mainPath!, maxSide: 768);
    final others = [
      for (final p in draft.otherPaths) await processor.aiPhoto(p)
    ];
    final result = await ai.suggestBadges(
        mainJpeg: main,
        otherJpegs: others,
        context: fieldsToText(draft.fields,
            [for (final f in draft.infographic.features) f.text]));
    var count = 0;
    for (var i = 0; i < draft.otherPaths.length; i++) {
      draft.badges[draft.otherPaths[i]] = result[i];
      count += result[i].length;
    }
    await _rerenderOthers(draft.otherPaths);
    return count;
  }

  bool get hasBadges => draft.badges.values.any((l) => l.isNotEmpty);

  /// Убирает плашки со всех фото разом; возвращает прежние — для «Вернуть».
  Future<Map<String, List<PhotoBadge>>> clearBadges() async {
    final before = draft.badges;
    draft.badges = {};
    await _rerenderOthers([
      for (final e in before.entries)
        if (e.value.isNotEmpty) e.key
    ]);
    return before;
  }

  Future<void> restoreBadges(Map<String, List<PhotoBadge>> before) async {
    draft.badges = before;
    await _rerenderOthers([
      for (final e in before.entries)
        if (e.value.isNotEmpty) e.key
    ]);
  }

  /// Плашки одного фото поправлены вручную.
  Future<void> updateBadges(String path, List<PhotoBadge> badges) async {
    draft.badges[path] = badges;
    await _rerenderOthers([path]);
  }

  /// Перерисовывает превью указанных не главных фото; их отметки
  /// «сохранено» сбрасываются, раз картинка изменилась.
  Future<void> _rerenderOthers(List<String> paths) async {
    for (final p in paths) {
      final i = draft.otherPaths.indexOf(p);
      if (i < 0 || i >= draft.otherPreviews.length) continue;
      draft.otherPreviews[i] = await processor.renderOther(p,
          badges: draft.badgesOf(p), maxSide: kPreviewSide, quality: 75);
      if (i + 1 < saveStates.length &&
          (saveStates[i + 1] == SaveState.saved ||
              saveStates[i + 1] == SaveState.error)) {
        saveStates[i + 1] = SaveState.none;
        draft.saved[i + 1] = false;
      }
    }
    await store.save(draft);
    notifyListeners();
  }

  /// Перерисовывает превью и обновляет пост в истории. Главное фото после
  /// правок текста считается несохранённым.
  Future<void> refreshPreviews() async {
    draft.mainPreview = await processor.renderMain(
        draft.mainPath!, draft.infographic,
        maxSide: kPreviewSide, quality: 75);
    draft.otherPreviews = [
      for (final p in draft.otherPaths)
        await processor.renderOther(p,
            badges: draft.badgesOf(p), maxSide: kPreviewSide, quality: 75),
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
          : await processor.renderOther(post.otherPaths[i - 1],
              badges: post.badgesOf(post.otherPaths[i - 1]));
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
