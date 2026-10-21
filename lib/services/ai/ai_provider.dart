import 'dart:convert';
import 'dart:typed_data';

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
  });
}

const kSystemPrompt =
    'Ты SMM-помощник компании CRAFT SYSTEM (электромонтажные работы для '
    'бизнеса, г. Черкесск). По фото и данным объекта составь подпись к '
    'Instagram-посту (деловой тон, 3–6 строк, эмодзи умеренно, хэштеги в конце) '
    'и короткий текст для инфографики. Не выдумывай цифры, используй только '
    'данные из полей. Ответ строго JSON без пояснений: '
    '{"caption": "...", "title": "...", "subtitle": "...", '
    '"items": [{"label": "...", "value": "..."}]}';

String fieldsToText(Map<String, String> fields) {
  final labels = {for (final f in kInfographicFields) f.key: f.label};
  return fields.entries
      .where((e) => e.value.trim().isNotEmpty)
      .map((e) => '${labels[e.key] ?? e.key}: ${e.value}')
      .join('\n');
}

/// Разбирает JSON из ответа модели (допускает обёртку ```json).
AiResult parseAiJson(String raw) {
  final start = raw.indexOf('{');
  final end = raw.lastIndexOf('}');
  if (start < 0 || end <= start) {
    throw const FormatException('AI вернул ответ без JSON');
  }
  final m = jsonDecode(raw.substring(start, end + 1)) as Map<String, dynamic>;
  final items = ((m['items'] as List?) ?? [])
      .map((e) => InfoItem('${e['label'] ?? ''}', '${e['value'] ?? ''}'))
      .toList();
  return AiResult(
    '${m['caption'] ?? ''}',
    InfographicText(
      title: '${m['title'] ?? ''}',
      subtitle: '${m['subtitle'] ?? ''}',
      items: items,
    ),
  );
}
