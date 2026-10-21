import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import 'models/post_draft.dart';
import 'services/ai/ai_factory.dart';
import 'services/gallery_saver.dart';
import 'services/image/image_processor.dart';
import 'services/settings_service.dart';

const kPreviewSide = 900;

class AppState extends ChangeNotifier {
  final settings = SettingsService();
  final processor = ImageProcessor();
  final _picker = ImagePicker();
  final _saver = GallerySaver();

  PostDraft draft = PostDraft();

  Future<void> pickMain() async {
    final f = await _picker.pickImage(source: ImageSource.gallery);
    if (f == null) return;
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
    notifyListeners();
  }

  /// Шаг «Создать»: AI (главное фото + поля) и превью всех фото.
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
    await refreshPreviews();
  }

  Future<void> refreshPreviews() async {
    draft.mainPreview = await processor.renderMain(
        draft.mainPath!, draft.infographic,
        maxSide: kPreviewSide, quality: 75);
    draft.otherPreviews = [
      for (final p in draft.otherPaths)
        await processor.renderOther(p, maxSide: kPreviewSide, quality: 75),
    ];
    notifyListeners();
  }

  /// Финальный экспорт в полном разрешении. Файлы обрабатываются по одному,
  /// чтобы не держать в памяти все фото сразу.
  Future<void> saveAll(void Function(int done, int total) onProgress) async {
    if (!await _saver.ensureAccess()) {
      throw Exception('Нет разрешения на сохранение в галерею');
    }
    final total = 1 + draft.otherPaths.length;
    final stamp = DateTime.now().millisecondsSinceEpoch;
    onProgress(0, total);
    Uint8List jpg =
        await processor.renderMain(draft.mainPath!, draft.infographic);
    await _saver.save(jpg, 'craft_${stamp}_1_main');
    onProgress(1, total);
    for (var i = 0; i < draft.otherPaths.length; i++) {
      jpg = await processor.renderOther(draft.otherPaths[i]);
      await _saver.save(jpg, 'craft_${stamp}_${i + 2}');
      onProgress(i + 2, total);
    }
  }
}
