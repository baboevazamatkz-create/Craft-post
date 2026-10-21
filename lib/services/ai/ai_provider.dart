import 'dart:convert';
import 'dart:typed_data';

import '../../models/icon_library.dart';
import '../../models/post_draft.dart';

/// Общий интерфейс. Чтобы добавить провайдера: реализовать класс
/// и зарегистрировать его в [createAiProvider].
abstract class AiProvider {
  String get id;
  String get title;

  /// Отправляет ТОЛЬКО главное фото (уменьшенное JPEG) и текст полей.
  Future<AiResult> generate({
    required Uint8List mainPhotoJpeg,
    required Map<String, String> fields,
    required List<Feature> features,
  });
}

final kSystemPrompt =
    'Ты SMM-помощник компании CRAFT SYSTEM (электромонтажные работы для '
    'бизнеса, г. Черкесск). По фото и данным объекта составь подпись к '
    'Instagram-посту строго в таком формате:\n'
    '🔷 <Тип объекта> «<НАЗВАНИЕ>»\n\n'
    '❗ Задача — <одно предложение>.\n\n'
    '✔️ Что было сделано:\n ▪ <пункт>\n ▪ <пункт> (3–5 пунктов)\n\n'
    '⚡ Профессиональные детали:\n ▪ <пункт> (3 пункта)\n'
    'Деловой тон, без хэштегов. Не выдумывай факты и цифры: опирайся на '
    'поля формы и фото. '
    'Для инфографики верни title (название объекта), subtitle (тип работ), '
    'location, features — ровно $kFeatureCount преимущества: короткая подпись '
    '(1–3 слова) и значок icon из списка: ${kIcons.map((i) => i.key).join(", ")}. '
    'Если преимущества заданы в форме, оставь их текст. '
    'Ответ строго JSON без пояснений: {"caption": "...", "title": "...", '
    '"subtitle": "...", "location": "...", '
    '"features": [{"icon": "...", "text": "..."}]}';

String fieldsToText(Map<String, String> fields, List<Feature> features) {
  final labels = {for (final f in kInfographicFields) f.key: f.label};
  final lines = fields.entries
      .where((e) => e.value.trim().isNotEmpty)
      .map((e) => '${labels[e.key] ?? e.key}: ${e.value}')
      .toList();
  for (var i = 0; i < features.length; i++) {
    if (features[i].text.trim().isNotEmpty) {
      lines.add('Преимущество ${i + 1}: ${features[i].text} (значок ${features[i].icon})');
    }
  }
  return lines.join('\n');
}

/// Разбирает JSON из ответа модели (допускает обёртку ```json).
AiResult parseAiJson(String raw) {
  final start = raw.indexOf('{');
  final end = raw.lastIndexOf('}');
  if (start < 0 || end <= start) {
    throw const FormatException('AI вернул ответ без JSON');
  }
  final m = jsonDecode(raw.substring(start, end + 1)) as Map<String, dynamic>;
  final features = ((m['features'] as List?) ?? [])
      .map((e) => Feature('${e['icon'] ?? 'bolt'}', '${e['text'] ?? ''}'))
      .toList();
  return AiResult(
    '${m['caption'] ?? ''}',
    InfographicText(
      title: '${m['title'] ?? ''}',
      subtitle: '${m['subtitle'] ?? ''}',
      location: '${m['location'] ?? ''}',
      features: features,
    ),
  );
}
