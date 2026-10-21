import 'dart:typed_data';

/// Описание одного поля формы. Набор полей меняется только здесь.
class FieldSpec {
  final String key;
  final String label;
  final String hint;
  final bool numeric;
  const FieldSpec(this.key, this.label, {this.hint = '', this.numeric = false});
}

/// Заглушка: набор полей будет уточнён по примерам пользователя.
const kInfographicFields = <FieldSpec>[
  FieldSpec('object', 'Название объекта', hint: 'Например: Магазин «Продукты»'),
  FieldSpec('work', 'Тип работ', hint: 'Электромонтаж, щиты, освещение'),
  FieldSpec('area', 'Площадь, м²', numeric: true),
  FieldSpec('power', 'Мощность, кВт', numeric: true),
  FieldSpec('days', 'Срок, дней', numeric: true),
  FieldSpec('city', 'Город', hint: 'Черкесск'),
];

class InfoItem {
  String label;
  String value;
  InfoItem(this.label, this.value);
}

/// Текст, который рисуется на главном фото. Редактируется на экране превью.
class InfographicText {
  String title;
  String subtitle;
  List<InfoItem> items;
  InfographicText({this.title = '', this.subtitle = '', List<InfoItem>? items})
      : items = items ?? [];
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

  String caption = '';
  InfographicText infographic = InfographicText();

  // Превью в пониженном разрешении (JPEG-байты).
  Uint8List? mainPreview;
  List<Uint8List> otherPreviews = [];

  bool get hasPhotos => mainPath != null;
}
