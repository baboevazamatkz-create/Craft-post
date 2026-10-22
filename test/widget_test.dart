import 'package:craft_post/services/ai/ai_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parseAiJson разбирает ответ в обёртке ```json', () {
    final r = parseAiJson('```json\n{"caption":"c","title":"t","subtitle":"s",'
        '"location":"Черкесск","features":["Настройка","Свет"]}\n```');
    expect(r.caption, 'c');
    expect(r.infographic.location, 'Черкесск');
    expect(r.infographic.features, isEmpty);
    expect(r.featureIdeas, ['Настройка', 'Свет']);
  });

  test('parseAiJson падает без JSON', () {
    expect(() => parseAiJson('нет'), throwsFormatException);
  });
}
