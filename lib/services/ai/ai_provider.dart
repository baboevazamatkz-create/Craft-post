import 'dart:convert';
import 'dart:typed_data';

import '../../models/post_draft.dart';

/// Общий интерфейс. Чтобы добавить провайдера: реализовать класс
/// и зарегистрировать его в [createAiProvider].
abstract class AiProvider {
  String get id;
  String get title;

  /// По главному фото (уменьшенное JPEG) и полям формы: подпись к посту,
  /// тексты инфографики и [kFeatureIdeas] вариантов преимуществ на выбор.
  Future<AiResult> generate({
    required Uint8List mainPhotoJpeg,
    required Map<String, String> fields,
  });

  /// Ещё варианты преимуществ, не похожие на [exclude].
  Future<List<String>> suggestFeatures({
    required Uint8List mainPhotoJpeg,
    required Map<String, String> fields,
    required List<String> exclude,
  });

  /// Значки к выбранным преимуществам: для каждого — [kIconVariants]
  /// разных по идее варианта (наборы SVG-путей). Фото не отправляется.
  Future<List<List<List<String>>>> suggestIcons({
    required List<String> features,
    required String instruction,
  });

  /// Плашки на не главные фото: AI видит главное фото (для понимания
  /// объекта) и все остальные, на каждом отмечает 1–3 детали работы.
  /// Возвращает список плашек для каждого из [otherJpegs] по порядку.
  Future<List<List<PhotoBadge>>> suggestBadges({
    required Uint8List mainJpeg,
    required List<Uint8List> otherJpegs,
    required String context,
  });
}

/// Сколько вариантов преимуществ предлагать за раз.
const kFeatureIdeas = 8;

/// Сколько вариантов значка просить для каждого преимущества.
const kIconVariants = 3;

const _featureRules =
    'Преимущество — 1–3 слова для нижней строки инфографики под значком: '
    'конкретно про этот объект и эти работы — что получил заказчик или чем '
    'работа особенная. Варианты разные по смыслу. Без общих слов вроде '
    '«Качество», «Надёжность», «Профессионализм». Уровень примеров: '
    '«Автоматика день-ночь», «Дистанционная настройка», «Работа на высоте», '
    '«Скрытая проводка», «Запуск за 1 день», «Защита от скачков». '
    'Не выдумывай того, чего нет на фото и в данных.';

const kFeatureSystemPrompt =
    'Ты SMM-помощник компании CRAFT SYSTEM (электромонтаж). По фото объекта '
    'и данным предложи новые варианты преимуществ для инфографики, не '
    'похожие на уже предложенные. $_featureRules '
    'Ответ строго JSON без пояснений: {"features": ["...", "..."]}';

const kIconSystemPrompt =
    'Ты дизайнер тонких линейных пиктограмм для премиальной инфографики '
    'компании-электромонтажника. Внизу инфографики три преимущества, у '
    'каждого значок над подписью. Нарисуй для каждого преимущества '
    '$kIconVariants РАЗНЫХ по идее значка (разные метафоры, а не одна и та же '
    'картинка с мелкими отличиями). '
    'Стиль: как в архитектурных и инженерных презентациях — тонкая линия '
    'одной толщины, без заливки, скруглённые концы, достаточно деталей, '
    'чтобы рисунок был интересным и узнаваемым (например: солнце с лучами и '
    'полумесяц — «день-ночь»; пульт с кнопками — «дистанционная настройка»; '
    'монтажник на стремянке — «работа на высоте»; лампа с лучами; '
    'ступени; щит с галочкой; знак заземления). Не используй банальную '
    'молнию, если есть идея точнее. '
    'Технически: сетка 24x24, всё внутри 1..23, 3–12 SVG-путей на значок '
    '(атрибут d; команды M L H V C S Q T A Z), без текста и цифр внутри, '
    'мелкие детали не меньше 1 единицы, линии не сливаются. '
    'Учти пожелание пользователя. '
    'Ответ строго JSON без пояснений: {"features": [{"text": "...", '
    '"variants": [["d", "d"], ["d"], ["d"]]}]} — в том же порядке, что '
    'преимущества в запросе.';

String iconRequestText(List<String> features, String instruction) => [
      for (var i = 0; i < features.length; i++)
        'Преимущество ${i + 1}: ${features[i]}',
      'Пожелание: ${instruction.trim().isEmpty ? 'интересные, разнообразные значки' : instruction.trim()}',
    ].join('\n');

/// Варианты значков по порядку преимуществ; мусор отбрасывается.
List<List<List<String>>> parseIconJson(String raw, int count) {
  final list = (_jsonObject(raw)['features'] as List?) ?? [];
  return [
    for (var i = 0; i < count; i++)
      [
        if (i < list.length && list[i] is Map)
          for (final v in ((list[i] as Map)['variants'] as List? ?? []))
            sanitizeSvgPaths(v),
      ].where((v) => v.isNotEmpty).toList(),
  ];
}

/// Список преимуществ из JSON: строки или объекты с полем text.
List<String> parseFeatureJson(String raw) => _features(_jsonObject(raw));

List<String> _features(Map<String, dynamic> m) {
  final out = <String>[];
  for (final e in (m['features'] as List? ?? [])) {
    final t = (e is Map ? '${e['text'] ?? ''}' : '$e').trim();
    if (t.isNotEmpty && t.length <= 40 && !out.contains(t)) out.add(t);
  }
  return out;
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
  /// Один запрос: системная инструкция, изображения JPEG (каждое — со своей
  /// подписью в [labels], если задана) и текст после них.
  Future<String> ask({
    required String system,
    required String text,
    required List<Uint8List> images,
    List<String>? labels,
    String effort = 'medium',
  });

  @override
  Future<AiResult> generate({
    required Uint8List mainPhotoJpeg,
    required Map<String, String> fields,
  }) async =>
      parseAiJson(await ask(
          system: kSystemPrompt,
          text: fieldsToText(fields),
          images: [mainPhotoJpeg]));

  @override
  Future<List<String>> suggestFeatures({
    required Uint8List mainPhotoJpeg,
    required Map<String, String> fields,
    required List<String> exclude,
  }) async =>
      parseFeatureJson(await ask(
          system: kFeatureSystemPrompt,
          text: '${fieldsToText(fields)}\n\nУже предложены: '
              '${exclude.join('; ')}\n\nПредложи ещё $kFeatureIdeas.',
          images: [mainPhotoJpeg]));

  @override
  Future<List<List<List<String>>>> suggestIcons({
    required List<String> features,
    required String instruction,
  }) async =>
      parseIconJson(
          await ask(
              system: kIconSystemPrompt,
              text: iconRequestText(features, instruction),
              images: const [],
              effort: 'high'),
          features.length);

  @override
  Future<List<List<PhotoBadge>>> suggestBadges({
    required Uint8List mainJpeg,
    required List<Uint8List> otherJpegs,
    required String context,
  }) async =>
      parseBadgeJson(
          await ask(
            system: kBadgeSystemPrompt,
            text: '$context\n\nНайди интересные моменты на фото '
                '1–${otherJpegs.length}.',
            images: [mainJpeg, ...otherJpegs],
            labels: [
              'Главное фото — только для понимания объекта, его не размечай',
              for (var i = 0; i < otherJpegs.length; i++) 'Фото ${i + 1}',
            ],
            effort: 'high',
          ),
          otherJpegs.length);
}

const kSystemPrompt =
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
    'location и features — $kFeatureIdeas вариантов преимуществ на выбор, '
    'самые сильные первыми. $_featureRules '
    'Ответ строго JSON без пояснений: {"caption": "...", "title": "...", '
    '"subtitle": "...", "location": "...", "features": ["...", "..."]}';

String fieldsToText(Map<String, String> fields,
    [List<String> features = const []]) {
  final labels = {for (final f in kInfographicFields) f.key: f.label};
  return [
    for (final e in fields.entries)
      if (e.value.trim().isNotEmpty) '${labels[e.key] ?? e.key}: ${e.value}',
    for (var i = 0; i < features.length; i++)
      if (features[i].trim().isNotEmpty)
        'Преимущество ${i + 1}: ${features[i]}',
  ].join('\n');
}

/// Разбирает JSON из ответа модели (допускает обёртку ```json).
AiResult parseAiJson(String raw) {
  final m = _jsonObject(raw);
  return AiResult(
    '${m['caption'] ?? ''}',
    InfographicText(
      title: '${m['title'] ?? ''}',
      subtitle: '${m['subtitle'] ?? ''}',
      location: '${m['location'] ?? ''}',
    ),
    _features(m),
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

const kBadgeSystemPrompt =
    'Ты помогаешь компании CRAFT SYSTEM (электромонтаж) оформлять фото работ '
    'для Instagram. Тебе дают главное фото объекта (только для понимания) и '
    'пронумерованные фото работ. Плашки-выноски должны цеплять взгляд и '
    'показывать мастерство, а не подписывать предметы.\n\n'
    'Что отмечать: интересные моменты, которые обычный человек не заметит, '
    'а профессионал оценит, — инженерное решение, сложное место, аккуратность '
    'там, где её обычно нет, скрытую пользу для заказчика. Например: идеально '
    'параллельные трассы, обход препятствия, скрытая прокладка, выдержанный '
    'уровень, продуманный запас кабеля, маркировка, защита от влаги, '
    'симметрия, чистые примыкания, нестандартный узел крепления.\n'
    'Чего НЕ делать: не называй очевидное («Розетка», «Кабель», «Щит», '
    '«Светильник», «Монтаж проводки») и не пиши пустые слова («Качественный '
    'монтаж», «Аккуратная работа»). Не выдумывай того, чего не видно.\n\n'
    'Как подписывать: 2–5 слов, до 35 знаков, по-русски, живо и конкретно — '
    'суть решения или польза. Хорошо: «Кабель в одну линию по лазеру», '
    '«Ни одного провода на виду», «Запас под обслуживание», «Каждая линия '
    'подписана», «Обход балки без единого шва», «Ввод снизу — без влаги в '
    'щите», «Уровень до миллиметра». Плохо: «Розетка», «Ровный кабель», '
    '«Хороший монтаж».\n\n'
    'Лучше 1–2 сильные плашки, чем 3 слабые; максимум 3 на фото, подписи на '
    'разных фото не повторяй. Если на фото нет ничего интересного — верни '
    'для него пустой список. Для каждой плашки укажи точку прямо на этой '
    'детали: x и y — доли ширины и высоты от левого верхнего угла (0..1). '
    'Левый верхний угол кадра занят логотипом. '
    'Ответ строго JSON без пояснений: {"photos": [{"photo": 1, '
    '"badges": [{"text": "...", "x": 0.5, "y": 0.5}]}]}';

/// Разбирает плашки по фото; лишнее и испорченное отбрасывает.
List<List<PhotoBadge>> parseBadgeJson(String raw, int count) {
  final m = _jsonObject(raw);
  final out = List.generate(count, (_) => <PhotoBadge>[]);
  for (final e in (m['photos'] as List? ?? [])) {
    if (e is! Map) continue;
    final n = (e['photo'] as num?)?.toInt() ?? 0;
    if (n < 1 || n > count) continue;
    for (final b in (e['badges'] as List? ?? [])) {
      if (b is! Map) continue;
      final badge = PhotoBadge.fromJson(b.cast<String, dynamic>());
      badge.text = badge.text.trim();
      if (badge.text.isEmpty || out[n - 1].length >= 3) continue;
      if (badge.text.length > 40) badge.text = badge.text.substring(0, 40);
      out[n - 1].add(badge);
    }
  }
  return out;
}
