import 'dart:typed_data';

/// Описание одного поля формы. Набор полей меняется только здесь.
class FieldSpec {
  final String key;
  final String label;
  final String hint;
  final bool multiline;
  const FieldSpec(this.key, this.label, {this.hint = '', this.multiline = false});
}

/// Текстовые поля формы (значки преимуществ — отдельно, см. [kFeatureCount]).
const kInfographicFields = <FieldSpec>[
  FieldSpec('object', 'Название объекта', hint: 'АЗС Magnum'),
  FieldSpec('work', 'Тип работ', hint: 'Подключение стелы'),
  FieldSpec('location', 'Локация', hint: 'Новая Джегута | КЧР'),
  FieldSpec('task', 'Задача (необязательно)', multiline: true),
  FieldSpec('done', 'Что сделано (по строке, необязательно)', multiline: true),
];

/// Сколько преимуществ (значок + подпись) в нижней части инфографики.
const kFeatureCount = 3;

class Feature {
  String icon; // ключ из kIcons
  String text;
  Feature(this.icon, this.text);
}

/// Текст, который рисуется на главном фото. Редактируется на экране превью.
class InfographicText {
  String title;
  String subtitle;
  String location;
  List<Feature> features;
  InfographicText({
    this.title = '',
    this.subtitle = '',
    this.location = '',
    List<Feature>? features,
  }) : features = features ?? [];
}

class AiResult {
  final String caption;
  final InfographicText infographic;
  AiResult(this.caption, this.infographic);
}

class PostDraft {
  String? mainPath;
  List<String> otherPaths = [];
  final Map<String, String> fields = {};
  final List<Feature> features = [
    for (var i = 0; i < kFeatureCount; i++) Feature('bolt', ''),
  ];

  String caption = '';
  InfographicText infographic = InfographicText();

  // Превью в пониженном разрешении (JPEG-байты).
  Uint8List? mainPreview;
  List<Uint8List> otherPreviews = [];
}
