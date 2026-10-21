import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:path_drawing/path_drawing.dart';
import 'package:flutter/painting.dart';

import '../../models/icon_library.dart';
import '../../models/post_draft.dart';

/// Шаблон инфографики по макету «АЗС Magnum» (фото 3:4).
/// Горизонтали заданы долями ширины, вертикали — долями высоты,
/// поэтому результат одинаков в превью и в полном разрешении.
/// Шрифт и значки пока временные (Cormorant SC, значки Material).
class InfographicTemplate {
  static const _font = 'Cormorant';
  static const _white = Color(0xFFFFFFFF);

  void paint(ui.Canvas canvas, Size size, InfographicText t) {
    final w = size.width;
    final h = size.height;
    final left = w * 0.0587;
    final right = w * 0.9418;

    _shade(canvas, w, h);

    if (t.stat.trim().isNotEmpty) {
      _text(t.stat, w * 0.2, 300, right - left, maxLines: 1)
          .paint(canvas, Offset(w * 0.0487, h * 0.4595));
      if (t.unit.trim().isNotEmpty) {
        _text(t.unit, w * 0.092, 300, right - left, maxLines: 1)
            .paint(canvas, Offset(w * 0.056, h * 0.6095));
      }
    }

    final lineW = w * 0.002;
    canvas.drawLine(
      Offset(w * 0.0613, h * 0.697),
      Offset(w * 0.337, h * 0.697),
      Paint()
        ..color = _white.withValues(alpha: 0.40)
        ..strokeWidth = lineW,
    );
    canvas.drawLine(
      Offset(w * 0.0609, h * 0.9436),
      Offset(w * 0.9418, h * 0.9436),
      Paint()
        ..color = _white.withValues(alpha: 0.58)
        ..strokeWidth = lineW,
    );

    _text(t.title, w * 0.057, 300, right - left)
        .paint(canvas, Offset(left, h * 0.710));
    _text(t.subtitle, w * 0.0245, 400, right - left)
        .paint(canvas, Offset(left, h * 0.771));

    // Три преимущества: значок и подпись по центру колонки.
    final colW = w * 0.185;
    for (var i = 0; i < math.min(kFeatureCount, t.features.length); i++) {
      final cx = w * (0.141 + 0.19 * i);
      final f = t.features[i];
      _icon(canvas, f.svg.isNotEmpty ? f.svg : iconByKey(f.icon).paths,
          Offset(cx - w * 0.043, h * 0.8303), w * 0.086, w * 0.0013);
      final cp = _text(f.text, w * 0.0185, 400, colW,
          align: TextAlign.center, maxLines: 2);
      cp.paint(canvas, Offset(cx - colW / 2, h * 0.9));
    }

    // Локация справа: значок-метка и текст по правому краю.
    final lp = _text(t.location, w * 0.0205, 400, w * 0.3,
        align: TextAlign.right, maxLines: 1);
    final lx = right - lp.width;
    final ly = h * 0.9212;
    lp.paint(canvas, Offset(lx, ly));
    _icon(canvas, kPinPaths, Offset(lx - w * 0.047, ly - w * 0.004 - h * 0.01),
        w * 0.039, w * 0.0013);
  }

  /// Затемнение (замерено по макетам): слева — чёрный градиент 74% → 0
  /// на 40% ширины, снизу — под текст.
  void _shade(ui.Canvas canvas, double w, double h) {
    // Профиль непрозрачности по x (доли ширины), снят с макета.
    const profile = <List<double>>[
      [0, 0.74],
      [0.05, 0.716],
      [0.1, 0.645],
      [0.15, 0.54],
      [0.2, 0.38],
      [0.25, 0.23],
      [0.3, 0.10],
      [0.35, 0.045],
      [0.4, 0],
    ];
    final stops = [for (final p in profile) p[0] / 0.4];
    final colors = [for (final p in profile) Color.fromRGBO(0, 0, 0, p[1])];
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader =
            ui.Gradient.linear(Offset.zero, Offset(w * 0.4, 0), colors, stops),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, h * 0.70, w, h * 0.30),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, h * 0.70),
          Offset(0, h),
          [
            for (final a in const [0.0, 0.08, 0.32, 0.58, 0.70, 0.82])
              Color.fromRGBO(0, 0, 0, a),
          ],
          const [0.0, 0.1667, 0.3333, 0.5, 0.6667, 1.0],
        ),
    );
  }

  /// Тонкий линейный значок: пути в сетке 24×24 масштабируются до [size].
  void _icon(ui.Canvas canvas, List<String> paths, Offset at, double size,
      double stroke) {
    final k = size / 24;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = _white
      ..strokeWidth = stroke / k
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.scale(k);
    for (final d in paths) {
      try {
        canvas.drawPath(parseSvgPathData(d), paint);
      } catch (_) {
        // Некорректный путь от AI пропускаем.
      }
    }
    canvas.restore();
  }

  TextPainter _text(String s, double size, int weight, double maxW,
      {TextAlign align = TextAlign.left, int maxLines = 2}) {
    return TextPainter(
      text: TextSpan(
        text: s.toUpperCase(),
        style: TextStyle(
          fontFamily: _font,
          fontSize: size,
          color: _white,
          fontWeight: weight < 400 ? FontWeight.w300 : FontWeight.w400,
          height: 1.15,
          letterSpacing: size * 0.02,
        ),
      ),
      textAlign: align,
      textDirection: TextDirection.ltr,
      maxLines: maxLines,
      ellipsis: '…',
    )..layout(
        minWidth: align == TextAlign.center ? maxW : 0,
        maxWidth: math.max(1, maxW));
  }
}

/// Позиция и размер логотипа (замерено по макету): слева сверху,
/// ширина 19,8%, отступ слева 5,16%, сверху 4,98% ширины.
class LogoPlacement {
  final double widthFraction;
  final double left;
  final double top;
  const LogoPlacement(
      {this.widthFraction = 0.1984, this.left = 0.0516, this.top = 0.0498});

  Rect rect(Size canvas, Size logo) {
    final lw = canvas.width * widthFraction;
    final lh = lw * logo.height / logo.width;
    return Rect.fromLTWH(canvas.width * left, canvas.width * top, lw, lh);
  }
}
