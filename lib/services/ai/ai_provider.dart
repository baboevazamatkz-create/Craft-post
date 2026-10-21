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

  /// AI-редактор главного фото: по превью с инфографикой и пожеланию
  /// предлагает несколько вариантов каждого значка (и, если просили,
  /// новые подписи).
  Future<IconIdeas> suggestIcons({
    required Uint8List mainPreviewJpeg,
    required InfographicText current,
    required String instruction,
  });
}

/// Сколько вариантов значка просить для каждого преимущества.
const kIconVariants = 3;

class FeatureIdeas {
  final String text; // предложенная подпись (может совпадать с текущей)
  final List<List<String>> variants; // варианты значка — наборы SVG-путей
  FeatureIdeas(this.text, this.variants);
}

class IconIdeas {
  final String? title;
  final String? subtitle;
  final List<FeatureIdeas> features;
  IconIdeas(this.features, {this.title, this.subtitle});
}

const kIconSystemPrompt =
    'Ты дизайнер тонких линейных пиктограмм для премиальной инфографики '
    'компании-электромонтажника. На фото — пост с инфографикой: внизу три '
    'преимущества, у каждого значок и подпись. Нарисуй для каждого '
    'преимущества $kIconVariants РАЗНЫХ по идее значка (разные метафоры, а '
    'не одна и та же картинка с мелкими отличиями). '
    'Стиль: как в архитектурных и инженерных презентациях — тонкая линия '
    'одной толщины, без заливки, скруглённые концы, достаточно деталей, '
    'чтобы рисунок был интересным и узнаваемым (например: солнце с лучами и '
    'полумесяц — «день-ночь»; пульт с кнопками — «дистанционная настройка»; '
    'монтажник на стремянке — «работа на высоте»; лампа с лучами; '
    'ступени; щит с галочкой; знак заземления; велосипед-пенни-фартинг — '
    '«ретро»). Не используй банальную молнию, если есть идея точнее. '
    'Технически: сетка 24x24, всё внутри 1..23, 3–12 SVG-путей на значок '
    '(атрибут d; команды M L H V C S Q T A Z), без текста и цифр внутри, '
    'мелкие детали не меньше 1 единицы, линии не сливаются. '
    'Учти пожелание пользователя. Подписи и заголовки меняй, только если '
    'пожелание об этом; иначе верни их как есть. '
    'Ответ строго JSON без пояснений: {"title": "...", "subtitle": "...", '
    '"features": [{"text": "...", "variants": [["d", "d"], ["d"], ["d"]]}]}';

String iconRequestText(InfographicText t, String instruction) {
  final lines = <String>[
    'Заголовок: ${t.title}',
    'Подзаголовок: ${t.subtitle}',
    for (var i = 0; i < t.features.length; i++)
      'Преимущество ${i + 1}: ${t.features[i].text}',
    'Пожелание: ${instruction.trim().isEmpty ? 'сделай значки интереснее и разнообразнее' : instruction.trim()}',
  ];
  return lines.join('\n');
}

IconIdeas parseIconJson(String raw, InfographicText current) {
  final m = _jsonObject(raw);
  final list = (m['features'] as List?) ?? [];
  final features = <FeatureIdeas>[];
  for (var i = 0; i < current.features.length; i++) {
    final e = i < list.length ? list[i] as Map<String, dynamic> : const {};
    final variants = [
      for (final v in (e['variants'] as List? ?? [])) sanitizeSvgPaths(v),
    ].where((v) => v.isNotEmpty).toList();
    final text = '${e['text'] ?? ''}'.trim();
    features.add(
        FeatureIdeas(text.isEmpty ? current.features[i].text : text, variants));
  }
  String? opt(Object? v) => v == null || '$v'.trim().isEmpty ? null : '$v';
  return IconIdeas(features,
      title: opt(m['title']), subtitle: opt(m['subtitle']));
}

Map<String, dynamic> _jsonObject(String raw) {
  final start = raw.indexOf('{');
  final end = raw.lastIndexOf('}');
  if (start < 0 || end <= start) {
    throw const FormatException('AI вернул ответ без JSON');
  }
  return jsonDecode(raw.substring(start, end + 1)) as Map<String, dynamic>;
}

/// Общая часть провайдеров-чатов: каждый реализует только [ask].
abstract class ChatAiProvider implements AiProvider {
  /// Один запрос: системная инструкция, текст и одно изображение JPEG.
  Future<String> ask({
    required String system,
    required String text,
    required Uint8List jpeg,
    String effort = 'medium',
  });

  @override
  Future<AiResult> generate({
    required Uint8List mainPhotoJpeg,
    required Map<String, String> fields,
    required List<Feature> features,
  }) async =>
      parseAiJson(await ask(
          system: kSystemPrompt,
          text: fieldsToText(fields, features),
          jpeg: mainPhotoJpeg));

  @override
  Future<IconIdeas> suggestIcons({
    required Uint8List mainPreviewJpeg,
    required InfographicText current,
    required String instruction,
  }) async =>
      parseIconJson(
          await ask(
              system: kIconSystemPrompt,
              text: iconRequestText(current, instruction),
              jpeg: mainPreviewJpeg,
              effort: 'high'),
          current);
}

final kSystemPrompt =
    'Ты SMM-помощник компании CRAFT SYSTEM (электромонтажные работы для '
    'бизнеса и частных домов, г. Черкесск). По фото и данным объекта составь '
    'подпись к Instagram-посту строго в таком формате:\n'
    '🔷 <Объект и, если задана, крупная цифра с единицей>\n\n'
    '❗ Задача — <одно предложение>.\n\n'
    '✔️ Что было сделано:\n ▪ <пункт>\n ▪ <пункт> (3–6 пунктов)\n\n'
    '⚡ Профессиональные детали:\n ▪ <пункт> (2–3 пункта)\n'
    'Деловой тон, без хэштегов. Не выдумывай факты и цифры: опирайся на '
    'поля формы и фото. '
    'Для инфографики верни title (название объекта), subtitle (тип работ), '
    'location, features — ровно $kFeatureCount преимущества: короткая подпись '
    '(1–3 слова, КАПС не нужен) и значок. Значок нарисуй сам: icon_paths — '
    'массив SVG-путей (атрибут d) в сетке 24x24, только тонкий контур без '
    'заливки, простой и узнаваемый (как линейные иконки), команды M L H V C A Z. '
    'Если не уверен в рисунке — оставь icon_paths пустым и выбери icon из '
    'списка: ${kIcons.map((i) => i.key).join(", ")}. '
    'Если преимущества заданы в форме, оставь их текст, иначе придумай их по работам. '
    'Ответ строго JSON без пояснений: {"caption": "...", "title": "...", '
    '"subtitle": "...", "location": "...", '
    '"features": [{"text": "...", "icon": "...", "icon_paths": ["..."]}]}';

String fieldsToText(Map<String, String> fields, List<Feature> features) {
  final labels = {for (final f in kInfographicFields) f.key: f.label};
  final lines = fields.entries
      .where((e) => e.value.trim().isNotEmpty)
      .map((e) => '${labels[e.key] ?? e.key}: ${e.value}')
      .toList();
  for (var i = 0; i < features.length; i++) {
    if (features[i].text.trim().isNotEmpty) {
      lines.add('Преимущество ${i + 1}: ${features[i].text} ');
    }
  }
  return lines.join('\n');
}

/// Разбирает JSON из ответа модели (допускает обёртку ```json).
AiResult parseAiJson(String raw) {
  final m = _jsonObject(raw);
  final features = ((m['features'] as List?) ?? []).map((e) {
    final text = '${e['text'] ?? ''}';
    final icon = '${e['icon'] ?? ''}';
    return Feature(
      kIcons.any((i) => i.key == icon) ? icon : guessIcon(text),
      text,
      sanitizeSvgPaths(e['icon_paths']),
    );
  }).toList();
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

/// Оставляет только безопасные SVG-пути; мусор от модели отбрасывается.
List<String> sanitizeSvgPaths(Object? raw) {
  if (raw is! List) return [];
  final ok = RegExp(r'^[MmLlHhVvCcSsQqTtAaZz0-9eE.,\s-]+$');
  return raw
      .map((e) => '$e'.trim())
      .where((d) => d.isNotEmpty && d.length < 1500 && ok.hasMatch(d))
      .take(16)
      .toList();
}
