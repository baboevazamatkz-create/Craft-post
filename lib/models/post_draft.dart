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

/// Текстовые поля формы. Преимущества и значки предлагает AI после формы.
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
  String icon; // ключ встроенного значка — только для старых постов
  String text;
  List<String> svg; // значок, нарисованный AI (пути 24×24)
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
  final InfographicText infographic; // без преимуществ — их выбирают отдельно
  final List<String> featureIdeas; // варианты преимуществ на выбор
  AiResult(this.caption, this.infographic, this.featureIdeas);
}

/// Плашка на не главном фото: подпись и точка, к которой она относится
/// (доли ширины и высоты кадра, от левого верхнего угла). Остальное —
/// ручная настройка в редакторе.
class PhotoBadge {
  String text;
  double x, y;

  /// Размер подписи (1 — обычный).
  double scale;

  /// Удлинение полки за текстом, доля ширины кадра.
  double shelf;

  /// Куда ведёт стрелка: конец полки относительно точки, доли ширины кадра.
  /// null — место выбирается автоматически.
  double? jx, jy;

  PhotoBadge(this.text, this.x, this.y,
      {this.scale = 1, this.shelf = 0, this.jx, this.jy});

  bool get manual => jx != null && jy != null;

  PhotoBadge copy() =>
      PhotoBadge(text, x, y, scale: scale, shelf: shelf, jx: jx, jy: jy);

  Map<String, dynamic> toJson() => {
        'text': text,
        'x': x,
        'y': y,
        if (scale != 1) 'scale': scale,
        if (shelf != 0) 'shelf': shelf,
        if (manual) ...{'jx': jx, 'jy': jy},
      };
  factory PhotoBadge.fromJson(Map<String, dynamic> j) {
    double? d(String k) => (j[k] as num?)?.toDouble();
    return PhotoBadge(
      '${j['text'] ?? ''}',
      (d('x') ?? 0.5).clamp(0.0, 1.0),
      (d('y') ?? 0.5).clamp(0.0, 1.0),
      scale: (d('scale') ?? 1).clamp(0.5, 2.0),
      shelf: (d('shelf') ?? 0).clamp(0.0, 0.5),
      jx: d('jx'),
      jy: d('jy'),
    );
  }
}

/// Пост целиком. Картинки нумеруются так: 0 — главное фото, 1..n — остальные.
class PostDraft {
  PostDraft();

  String? id; // задаётся при первом сохранении в историю
  DateTime createdAt = DateTime.now();
  String? mainPath;
  List<String> otherPaths = [];
  final Map<String, String> fields = {};

  /// Варианты преимуществ от AI; выбранные — в [InfographicText.features].
  List<String> featureIdeas = [];

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
        'featureIdeas': featureIdeas,
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
      ..featureIdeas = [
        for (final f in (j['featureIdeas'] as List? ?? [])) '$f'
      ]
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
    return d;
  }
}
