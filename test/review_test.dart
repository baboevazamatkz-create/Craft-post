import 'dart:typed_data';

import 'package:craft_post/app_state.dart';
import 'package:craft_post/models/post_draft.dart';
import 'package:craft_post/screens/features_screen.dart';
import 'package:craft_post/screens/preview_screen.dart';
import 'package:craft_post/services/ai/ai_provider.dart';
import 'package:craft_post/services/image/badges.dart';
import 'package:craft_post/services/image/fit_text.dart';
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
    ..infographic = InfographicText(features: [
      for (final t in ['Скрытая проводка', 'Работа на высоте', 'Свет'])
        Feature('bolt', t, ['M4 4h16v16H4z'])
    ])
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
    d.featureIdeas = ['Свет', 'Щит'];
    final r = PostDraft.fromJson(d.toJson());
    expect(r.id, '42');
    expect(r.otherPaths, ['/a/1.jpg']);
    expect(r.saved, [true, false]);
    expect(r.infographic.stat, '320');
    expect(r.infographic.features.single.svg, ['M1 1L2 2']);
    expect(r.fields['object'], 'АЗС');
    expect(r.featureIdeas, ['Свет', 'Щит']);
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

  test('parseIconJson: варианты значков по порядку, мусор отбрасывается', () {
    final r = parseIconJson(
        '```json\n{"features":[{"text":"Свет","variants":'
        '[["M2 2L22 22","M4 4h16"],["<script>"],["M12 3a9 9 0 1 0 0.01 0"]]},'
        '{"text":"Щит","variants":[["M4 3h16v18H4z"]]}]}\n```',
        3);
    expect(r.length, 3);
    expect(r[0].length, 2); // «<script>» отброшен
    expect(r[1].single, ['M4 3h16v18H4z']);
    expect(r[2], isEmpty);
  });

  test('parseFeatureJson: строки и объекты, без повторов и пустых', () {
    expect(
        parseFeatureJson('{"features":["Скрытая проводка",{"text":"Работа '
            'на высоте"},"","Скрытая проводка"]}'),
        ['Скрытая проводка', 'Работа на высоте']);
  });

  testWidgets('Преимущества: выбор трёх, затем AI сразу рисует значки',
      (t) async {
    FlutterSecureStorage.setMockInitialValues({});
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 2.75;
    addTearDown(t.view.reset);
    final s = stateWith3Photos();
    s.draft.infographic = InfographicText(); // новый пост: ничего не выбрано
    s.draft.featureIdeas = [
      'Автоматика день-ночь',
      'Дистанционная настройка',
      'Работа на высоте',
      'Скрытая проводка',
    ];
    await t.pumpWidget(app(s, const FeaturesScreen()));
    expect(find.text('Выбрано 0 из 3'), findsOneWidget);
    await t.tap(find.text('Скрытая проводка'));
    await t.tap(find.text('Автоматика день-ночь'));
    await t.tap(find.text('Работа на высоте'));
    await t.pump();
    expect(find.text('1'), findsOneWidget); // порядок — как нажимали
    await t.tap(find.text('Далее — значки'));
    await settle(t);
    // Экран значков сам отправляет запрос в AI (без ключа — заглушка).
    await t.runAsync(() => Future<void>.delayed(const Duration(seconds: 1)));
    await settle(t);
    expect(find.text('1. Скрытая проводка'), findsOneWidget);
    expect(find.text('Вариант 3'), findsNWidgets(3));
    final next = find.widgetWithText(FilledButton, 'Далее — превью');
    await t.scrollUntilVisible(next, 300,
        scrollable: find.byType(Scrollable).first);
    expect(t.widget<FilledButton>(next).onPressed, isNotNull);
  });

  test('Фото скопом: первое — главное, нажатие меняет главное местами', () {
    final s = AppState();
    s.addPhotos(['a', 'b', 'c', 'd']);
    expect(s.draft.mainPath, 'a');
    expect(s.draft.otherPaths, ['b', 'c', 'd']);

    s.setMain('c'); // главное меняется местами с выбранным
    expect(s.draft.mainPath, 'c');
    expect(s.draft.otherPaths, ['b', 'a', 'd']);

    s.addPhotos(['d', 'e']); // повторы не добавляются
    expect(s.draft.otherPaths, ['b', 'a', 'd', 'e']);

    s.removePhoto('c'); // убрали главное — главным стало первое из остальных
    expect(s.draft.mainPath, 'b');
    expect(s.draft.otherPaths, ['a', 'd', 'e']);

    s.removePhoto('d');
    expect(s.draft.otherPaths, ['a', 'e']);
  });

  test('parseBadgeJson: плашки по номерам фото, лишнее отбрасывается', () {
    final r = parseBadgeJson(
        '```json\n{"photos":['
        '{"photo":1,"badges":[{"text":"Ровная укладка кабеля","x":0.4,"y":0.7},'
        '{"text":"  ","x":0.1,"y":0.1},{"text":"Под лазер","x":2,"y":-1},'
        '{"text":"Плотное прилегание","x":0.5,"y":0.5},{"text":"Четвёртая","x":0.5,"y":0.5}]},'
        '{"photo":3,"badges":[{"text":"Чужое фото","x":0.5,"y":0.5}]}]}\n```',
        2);
    expect(r.length, 2);
    expect([for (final b in r[0]) b.text],
        ['Ровная укладка кабеля', 'Под лазер', 'Плотное прилегание']);
    expect(r[0][1].x, 1.0); // координаты зажаты в кадр
    expect(r[0][1].y, 0.0);
    expect(r[1], isEmpty);
  });

  test('Плашки сохраняются в JSON и переезжают вместе с фото', () {
    final d = PostDraft()
      ..mainPath = 'm'
      ..otherPaths = ['a', 'b']
      ..badges = {
        'a': [PhotoBadge('Ровная укладка кабеля', 0.3, 0.6)]
      };
    final back = PostDraft.fromJson(d.toJson());
    expect(back.badgesOf('a').single.text, 'Ровная укладка кабеля');
    expect(back.badgesOf('b'), isEmpty);
    back.remapPhotos({'a': 'idb:1/photo_0', 'b': 'idb:1/photo_1'});
    expect(back.badgesOf('idb:1/photo_0').single.y, 0.6);
  });

  test('Раскладка плашек: в кадре, без наложений и пересечений, углы тупые',
      () {
    const size = Size(1080, 1440);
    final frame = Offset.zero & size;
    double cross(Offset o, Offset a, Offset b) =>
        (a.dx - o.dx) * (b.dy - o.dy) - (a.dy - o.dy) * (b.dx - o.dx);
    bool segSeg(Offset a, Offset b, Offset c, Offset d) =>
        ((cross(c, d, a) > 0) != (cross(c, d, b) > 0)) &&
        ((cross(a, b, c) > 0) != (cross(a, b, d) > 0));
    bool segRect(Offset a, Offset b, Rect r) =>
        r.contains(a) ||
        r.contains(b) ||
        segSeg(a, b, r.topLeft, r.topRight) ||
        segSeg(a, b, r.topRight, r.bottomRight) ||
        segSeg(a, b, r.bottomRight, r.bottomLeft) ||
        segSeg(a, b, r.bottomLeft, r.topLeft);

    final cases = [
      [
        PhotoBadge('Ровная укладка кабеля', 0.1, 0.05), // под логотипом
        PhotoBadge('Укладка под лазер', 0.12, 0.08),
        PhotoBadge('Плотное прилегание', 0.9, 0.98),
      ],
      [
        PhotoBadge('Жгут без единого перехлёста', 0.39, 0.25),
        PhotoBadge('Реле напряжения от скачков', 0.22, 0.60),
        PhotoBadge('Щит утоплен в стену', 0.43, 0.63),
      ],
      [
        PhotoBadge('Три подрозетника — одна ось', 0.25, 0.63),
        PhotoBadge('Запас кабеля под подключение', 0.45, 0.62),
        PhotoBadge('Ввод сверху', 0.48, 0.45),
      ],
    ];
    for (final badges in cases) {
      final boxes = BadgePainter().layout(size, badges);
      for (final b in boxes) {
        expect(frame.contains(b.plaque.topLeft), isTrue);
        expect(frame.contains(b.plaque.bottomRight), isTrue);
        expect(b.plaque.overlaps(BadgePainter.logoZone(size)), isFalse);
        // Полка уходит от метки: угол между выноской и полкой тупой.
        final toShelf = b.plaque.center.dx - b.joint.dx;
        final toPoint = b.point.dx - b.joint.dx;
        expect(toShelf * toPoint, lessThan(0), reason: badges.first.text);
      }
      for (var i = 0; i < boxes.length; i++) {
        for (var j = 0; j < boxes.length; j++) {
          if (i == j) continue;
          final a = boxes[i], b = boxes[j];
          expect(a.plaque.overlaps(b.plaque), isFalse);
          expect(segRect(a.point, a.joint, b.plaque), isFalse,
              reason: '${badges[i].text} → ${badges[j].text}');
          expect(b.plaque.contains(a.point), isFalse);
          if (i < j) {
            expect(segSeg(a.point, a.joint, b.point, b.joint), isFalse);
          }
        }
      }
    }
  });

  testWidgets('Превью: кнопка плашек через AI и правка на каждом фото',
      (t) async {
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 2.75;
    addTearDown(t.view.reset);
    await t.pumpWidget(app(stateWith3Photos(), const PreviewScreen()));
    await t.pump();
    expect(find.text('Плашки на остальные фото через AI'), findsOneWidget);
    expect(find.byIcon(Icons.edit), findsNWidgets(2));
    await t.scrollUntilVisible(find.text('Другие преимущества и значки'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Скрытая проводка'), findsOneWidget);
  });

  test('fitText: длинный текст мельче, но целиком и без многоточий', () {
    TextPainter build(String t, double size, int? lines) => TextPainter(
        text: TextSpan(text: t, style: TextStyle(fontSize: size)),
        textDirection: TextDirection.ltr,
        maxLines: lines);
    double sizeOf(TextPainter p) => (p.text as TextSpan).style!.fontSize!;

    expect(sizeOf(fitText('ЩИТ', 20, 200, 2, build)), 20);
    final long = fitText('ДЛИННАЯ ПОДПИСЬ ПРЕИМУЩЕСТВА', 20, 200, 2, build);
    expect(sizeOf(long), lessThan(20));
    expect(sizeOf(long), greaterThanOrEqualTo(11));
    expect(long.didExceedMaxLines, isFalse);
    expect(long.computeLineMetrics().length, lessThanOrEqualTo(2));
    expect(long.width, lessThanOrEqualTo(200.5)); // слово не режется
  });
}
