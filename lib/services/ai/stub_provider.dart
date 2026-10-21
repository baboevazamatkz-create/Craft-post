import 'dart:typed_data';

import '../../models/post_draft.dart';
import 'ai_provider.dart';

/// Работает без сети и ключа: собирает текст из полей формы.
class StubAiProvider implements AiProvider {
  @override
  String get id => 'stub';
  @override
  String get title => 'Заглушка (без AI)';

  @override
  Future<AiResult> generate({
    required Uint8List mainPhotoJpeg,
    required Map<String, String> fields,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    String f(String k) => (fields[k] ?? '').trim();
    final items = <InfoItem>[
      if (f('area').isNotEmpty) InfoItem('Площадь', '${f('area')} м²'),
      if (f('power').isNotEmpty) InfoItem('Мощность', '${f('power')} кВт'),
      if (f('days').isNotEmpty) InfoItem('Срок', '${f('days')} дн.'),
    ];
    final city = f('city').isEmpty ? 'Черкесск' : f('city');
    return AiResult(
      '⚡ ${f('object')}\n${f('work')}.\n\n'
      'CRAFT SYSTEM — электромонтаж для бизнеса. $city.\n\n'
      '#электромонтаж #craftsystem #черкесск',
      InfographicText(title: f('object'), subtitle: f('work'), items: items),
    );
  }
}
