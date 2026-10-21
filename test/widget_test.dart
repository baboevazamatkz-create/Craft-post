import 'package:craft_post/services/ai/ai_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parseAiJson разбирает ответ в обёртке ```json', () {
    final r = parseAiJson('```json\n{"caption":"c","title":"t","subtitle":"s",'
        '"items":[{"label":"Площадь","value":"120 м²"}]}\n```');
    expect(r.caption, 'c');
    expect(r.infographic.items.single.value, '120 м²');
  });

  test('parseAiJson падает без JSON', () {
    expect(() => parseAiJson('нет'), throwsFormatException);
  });
}
