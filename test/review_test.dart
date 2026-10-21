import 'dart:typed_data';

import 'package:craft_post/app_state.dart';
import 'package:craft_post/models/post_draft.dart';
import 'package:craft_post/screens/ai_icons_screen.dart';
import 'package:craft_post/screens/preview_screen.dart';
import 'package:craft_post/services/ai/ai_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:craft_post/screens/review_screen.dart';
import 'package:craft_post/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:provider/provider.dart';

Uint8List jpg() =>
    Uint8List.fromList(img.encodeJpg(img.Image(width: 30, height: 40)));

AppState stateWith3Photos() {
  final s = AppState();
  s.draft
    ..mainPath = '/x/main.jpg'
    ..otherPaths = ['/x/1.jpg', '/x/2.jpg']
    ..caption = 'Подпись'
    ..mainPreview = jpg()
    ..otherPreviews = [jpg(), jpg()]
    ..saved = [false, false, false];
  s.saveStates = List.filled(3, SaveState.none);
  return s;
}

Widget app(AppState s, Widget home) => ChangeNotifierProvider.value(
      value: s,
      child: MaterialApp(theme: buildTheme(), home: home),
    );

/// Экран показывает бесконечный индикатор фонового сохранения,
/// поэтому вместо pumpAndSettle прокручиваем время вручную.
Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 10; i++) {
    await t.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  test('PostDraft: сохранение в JSON и обратно', () {
    final d = PostDraft()
      ..id = '42'
      ..mainPath = '/a/main.jpg'
      ..otherPaths = ['/a/1.jpg']
      ..caption = '🔷 Объект'
      ..saved = [true, false]
      ..infographic = InfographicText(title: 'АЗС', stat: '320', features: [
        Feature('bolt', 'Свет', ['M1 1L2 2'])
      ]);
    d.fields['object'] = 'АЗС';
    d.features[0].text = 'Свет';
    final r = PostDraft.fromJson(d.toJson());
    expect(r.id, '42');
    expect(r.otherPaths, ['/a/1.jpg']);
    expect(r.saved, [true, false]);
    expect(r.infographic.stat, '320');
    expect(r.infographic.features.single.svg, ['M1 1L2 2']);
    expect(r.fields['object'], 'АЗС');
    expect(r.features[0].text, 'Свет');
    expect(r.imageCount, 2);
  });

  testWidgets('Согласование: свайп вправо — в сохранение, влево — оставить',
      (t) async {
    final s = stateWith3Photos();
    await t.pumpWidget(app(s, const ReviewScreen()));
    await t.pump();
    expect(find.text('Фото 1 из 3'), findsOneWidget);

    // Вправо: главное фото уходит в очередь сохранения.
    await t.fling(find.byType(Dismissible), const Offset(600, 0), 2000);
    await settle(t);
    expect(s.saveStates[0], isNot(SaveState.none));
    expect(find.text('Фото 2 из 3'), findsOneWidget);

    // Влево: остаётся.
    await t.fling(find.byType(Dismissible), const Offset(-600, 0), 2000);
    await settle(t);
    expect(s.saveStates[1], SaveState.none);

    // Кнопкой «Оставить» третье.
    await t.tap(find.text('Оставить'));
    await settle(t);
    expect(find.text('Оставлено: 2'), findsOneWidget);

    // Повторный проход только по оставленным.
    await t.tap(find.text('Пройти оставленные ещё раз'));
    await settle(t);
    expect(find.text('Фото 1 из 2'), findsOneWidget);
  });

  testWidgets('Превью: любое фото открывается на весь экран', (t) async {
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 2.75;
    addTearDown(t.view.reset);
    final s = stateWith3Photos();
    await t.pumpWidget(app(s, const PreviewScreen()));
    await t.pump();
    await t.tap(find.byIcon(Icons.zoom_in).at(1)); // первое из остальных
    await settle(t);
    expect(find.text('2 / 3'), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsWidgets);
  });

  test('parseIconJson: варианты значков, мусор отбрасывается', () {
    final cur = InfographicText(features: [
      Feature('bolt', 'Свет'),
      Feature('bolt', 'Щит'),
    ]);
    final r = parseIconJson(
        '```json\n{"title":"","features":[{"text":"Свет","variants":'
        '[["M2 2L22 22","M4 4h16"],["<script>"],["M12 3a9 9 0 1 0 0.01 0"]]},'
        '{"text":"Электрощит","variants":[["M4 3h16v18H4z"]]}]}\n```',
        cur);
    expect(r.features[0].variants.length, 2); // «<script>» отброшен
    expect(r.features[1].text, 'Электрощит');
    expect(r.title, isNull);
  });

  testWidgets('AI-редактор: без ключа предлагает варианты встроенных значков',
      (t) async {
    FlutterSecureStorage.setMockInitialValues({});
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 2.75;
    addTearDown(t.view.reset);
    final s = stateWith3Photos();
    s.draft.infographic = InfographicText(features: [
      Feature('bolt', 'Автоматика день-ночь'),
      Feature('bolt', 'Дистанционная настройка'),
      Feature('bolt', 'Работа на высоте'),
    ]);
    await t.pumpWidget(app(s, const AiIconsScreen()));
    await t.tap(find.text('Предложить варианты'));
    await t.runAsync(() => Future<void>.delayed(const Duration(seconds: 1)));
    await settle(t);
    expect(find.text('Вариант 3'), findsWidgets);
    await t.scrollUntilVisible(find.text('Применить и обновить превью'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Применить и обновить превью'), findsOneWidget);
  });
}
