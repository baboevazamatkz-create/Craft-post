import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../../models/icon_library.dart';
import '../../models/line_icon.dart';
import '../../models/post_draft.dart';
import 'fit_text.dart';

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

  /// Тонкий линейный значок: пути в сетке 24×24 масштабируются до [size].
  void _icon(ui.Canvas canvas, List<String> paths, Offset at, double size,
          double stroke) =>
      paintLineIcon(canvas, paths, at & Size(size, size), stroke, _white);

  /// Текст в капсе; длинный — мельче, но целиком (без многоточий).
  TextPainter _text(String s, double size, int weight, double maxW,
      {TextAlign align = TextAlign.left, int maxLines = 2}) {
    return fitText(
      s.toUpperCase(),
      size,
      math.max(1, maxW),
      maxLines,
      (text, size, lines) => TextPainter(
        text: TextSpan(
          text: text,
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
        maxLines: lines,
      ),
      minWidth: align == TextAlign.center ? maxW : 0,
    );
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
