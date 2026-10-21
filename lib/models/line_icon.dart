import 'dart:ui';

import 'package:path_drawing/path_drawing.dart';

/// Рисует линейный значок из SVG-путей (сетка 24×24) в квадрат [box].
/// Если рисунок выходит за сетку (бывает у AI), он вписывается в неё.
void paintLineIcon(
    Canvas canvas, List<String> paths, Rect box, double stroke, Color color) {
  final parsed = <Path>[];
  Rect? bounds;
  for (final d in paths) {
    try {
      final p = parseSvgPathData(d);
      final b = p.getBounds();
      if (b.isEmpty && b.width == 0 && b.height == 0) continue;
      parsed.add(p);
      bounds = bounds == null ? b : bounds.expandToInclude(b);
    } catch (_) {
      // Некорректный путь пропускаем.
    }
  }
  if (parsed.isEmpty || bounds == null) return;

  // Сетка 24×24; если рисунок за её пределами — вписываем с полями 1.5.
  var grid = const Rect.fromLTWH(0, 0, 24, 24);
  final inside = bounds.left >= -0.5 &&
      bounds.top >= -0.5 &&
      bounds.right <= 24.5 &&
      bounds.bottom <= 24.5;
  if (!inside) {
    final side =
        (bounds.width > bounds.height ? bounds.width : bounds.height) * 24 / 21;
    grid = Rect.fromCenter(center: bounds.center, width: side, height: side);
  }
  final k = box.width / grid.width;
  final paint = Paint()
    ..style = PaintingStyle.stroke
    ..color = color
    ..strokeWidth = stroke / k
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true;
  canvas.save();
  canvas.translate(box.left, box.top);
  canvas.scale(k);
  canvas.translate(-grid.left, -grid.top);
  for (final p in parsed) {
    canvas.drawPath(p, paint);
  }
  canvas.restore();
}
