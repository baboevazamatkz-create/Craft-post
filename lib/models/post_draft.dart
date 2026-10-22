import 'dart:typed_data';

/// Описание одного поля формы. Набор полей меняется только здесь.
class FieldSpec {
  final String key;
  final String label;
  final String hint;
  final bool multiline;
  const FieldSpec(this.key, this.label,
      {this.hint = '', this.multiline = false});
}

/// Текстовые поля формы (значки преимуществ — отдельно, см. [kFeatureCount]).
const kInfographicFields = <FieldSpec>[
  FieldSpec('object', 'Название объекта', hint: 'АЗС Magnum'),
  FieldSpec('work', 'Тип работ', hint: 'Подключение стелы'),
  FieldSpec('location', 'Локация', hint: 'Новая Джегута | КЧР'),
  FieldSpec('stat', 'Крупная цифра (необязательно)', hint: '320'),
  FieldSpec('unit', 'Единица (для цифры)', hint: 'м²'),
  FieldSpec('task', 'Задача (необязательно)', multiline: true),
  FieldSpec('done', 'Что сделано (по строке, необязательно)', multiline: true),
];

/// Сколько преимуществ (значок + подпись) в нижней части инфографики.
const kFeatureCount = 3;

class Feature {
  String icon; // ключ из kIcons
  String text;
  List<String>
      svg; // значок, нарисованный AI (пути 24×24); пусто — берётся icon
  Feature(this.icon, this.text, [List<String>? svg]) : svg = svg ?? [];

  Map<String, dynamic> toJson() => {'icon': icon, 'text': text, 'svg': svg};
  factory Feature.fromJson(Map<String, dynamic> j) => Feature(
      '${j['icon'] ?? 'bolt'}',
      '${j['text'] ?? ''}',
      [for (final s in (j['svg'] as List? ?? [])) '$s']);
}

/// Текст, который рисуется на главном фото. Редактируется на экране превью.
class InfographicText {
  String title;
  String subtitle;
  String location;
  String stat; // крупная цифра, например «320»
  String unit; // единица под цифрой, например «м²»
  List<Feature> features;
  InfographicText({
    this.title = '',
    this.subtitle = '',
    this.location = '',
    this.stat = '',
    this.unit = '',
    List<Feature>? features,
  }) : features = features ?? [];

  Map<String, dynamic> toJson() => {
        'title': title,
        'subtitle': subtitle,
        'location': location,
        'stat': stat,
        'unit': unit,
        'features': [for (final f in features) f.toJson()],
      };
  factory InfographicText.fromJson(Map<String, dynamic> j) => InfographicText(
        title: '${j['title'] ?? ''}',
        subtitle: '${j['subtitle'] ?? ''}',
        location: '${j['location'] ?? ''}',
        stat: '${j['stat'] ?? ''}',
        unit: '${j['unit'] ?? ''}',
        features: [
          for (final f in (j['features'] as List? ?? []))
            Feature.fromJson(f as Map<String, dynamic>)
        ],
      );
}

class AiResult {
  final String caption;
  final InfographicText infographic;
  AiResult(this.caption, this.infographic);
}

/// Плашка на не главном фото: подпись и точка, к которой она относится
/// (доли ширины и высоты кадра, от левого верхнего угла).
class PhotoBadge {
  String text;
  double x, y;
  PhotoBadge(this.text, this.x, this.y);

  PhotoBadge copy() => PhotoBadge(text, x, y);

  Map<String, dynamic> toJson() => {'text': text, 'x': x, 'y': y};
  factory PhotoBadge.fromJson(Map<String, dynamic> j) => PhotoBadge(
        '${j['text'] ?? ''}',
        ((j['x'] as num?) ?? 0.5).toDouble().clamp(0.0, 1.0),
        ((j['y'] as num?) ?? 0.5).toDouble().clamp(0.0, 1.0),
      );
}

/// Пост целиком. Картинки нумеруются так: 0 — главное фото, 1..n — остальные.
class PostDraft {
  PostDraft();

  String? id; // задаётся при первом сохранении в историю
  DateTime createdAt = DateTime.now();
  String? mainPath;
  List<String> otherPaths = [];
  final Map<String, String> fields = {};
  final List<Feature> features = [
    for (var i = 0; i < kFeatureCount; i++) Feature('bolt', ''),
  ];

  String caption = '';
  InfographicText infographic = InfographicText();

  /// Какие картинки уже сохранены в галерею (по индексу).
  List<bool> saved = [];

  /// Плашки на не главных фото: ссылка на фото → плашки.
  Map<String, List<PhotoBadge>> badges = {};

  List<PhotoBadge> badgesOf(String path) => badges[path] ?? const [];

  /// Фото переехали (копии в истории): переносим плашки на новые ссылки.
  void remapPhotos(Map<String, String> moved) {
    if (moved.isEmpty) return;
    badges = {
      for (final e in badges.entries) (moved[e.key] ?? e.key): e.value,
    };
  }

  // Превью в пониженном разрешении (JPEG-байты).
  Uint8List? mainPreview;
  List<Uint8List> otherPreviews = [];

  int get imageCount => mainPath == null ? 0 : 1 + otherPaths.length;

  List<Uint8List> get previews =>
      [if (mainPreview != null) mainPreview!, ...otherPreviews];

  bool isSaved(int i) => i < saved.length && saved[i];

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'mainPath': mainPath,
        'otherPaths': otherPaths,
        'fields': fields,
        'features': [for (final f in features) f.toJson()],
        'caption': caption,
        'infographic': infographic.toJson(),
        'saved': saved,
        'badges': {
          for (final e in badges.entries)
            e.key: [for (final b in e.value) b.toJson()],
        },
      };

  factory PostDraft.fromJson(Map<String, dynamic> j) {
    final d = PostDraft()
      ..id = j['id'] as String?
      ..createdAt = DateTime.tryParse('${j['createdAt']}') ?? DateTime.now()
      ..mainPath = j['mainPath'] as String?
      ..otherPaths = [for (final p in (j['otherPaths'] as List? ?? [])) '$p']
      ..caption = '${j['caption'] ?? ''}'
      ..infographic = InfographicText.fromJson(
          (j['infographic'] as Map?)?.cast<String, dynamic>() ?? {})
      ..saved = [for (final b in (j['saved'] as List? ?? [])) b == true]
      ..badges = {
        for (final e in ((j['badges'] as Map?) ?? {}).entries)
          '${e.key}': [
            for (final b in (e.value as List? ?? []))
              PhotoBadge.fromJson((b as Map).cast<String, dynamic>())
          ],
      };
    d.fields.addAll(
        ((j['fields'] as Map?) ?? {}).map((k, v) => MapEntry('$k', '$v')));
    final f = (j['features'] as List? ?? []);
    for (var i = 0; i < d.features.length && i < f.length; i++) {
      d.features[i] = Feature.fromJson(f[i] as Map<String, dynamic>);
    }
    return d;
  }
}
