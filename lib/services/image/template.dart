import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart' show IconData, Icons;
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
    final left = w * 0.06;
    final right = w * 0.94;

    _shade(canvas, w, h);

    final linePaint = Paint()
      ..color = _white.withValues(alpha: 0.75)
      ..strokeWidth = math.max(1, w * 0.0016);
    canvas.drawLine(Offset(left, h * 0.697), Offset(w * 0.337, h * 0.697), linePaint);
    canvas.drawLine(Offset(left, h * 0.944), Offset(right, h * 0.944), linePaint);

    _text(t.title, w * 0.057, 300, right - left)
        .paint(canvas, Offset(left, h * 0.708));
    _text(t.subtitle, w * 0.0245, 400, right - left)
        .paint(canvas, Offset(left, h * 0.765));

    // Три преимущества: значок и подпись по центру колонки.
    final colW = w * 0.185;
    for (var i = 0; i < math.min(kFeatureCount, t.features.length); i++) {
      final cx = w * (0.141 + 0.19 * i);
      final f = t.features[i];
      final ip = _iconPainter(iconByKey(f.icon).data, w * 0.085);
      ip.paint(canvas, Offset(cx - ip.width / 2, h * 0.835));
      final cp = _text(f.text, w * 0.0185, 400, colW, align: TextAlign.center, maxLines: 2);
      cp.paint(canvas, Offset(cx - colW / 2, h * 0.9));
    }

    // Локация справа: значок-метка и текст по правому краю.
    final lp = _text(t.location, w * 0.0205, 400, w * 0.3, align: TextAlign.right, maxLines: 1);
    final lx = right - lp.width;
    final ly = h * 0.924;
    lp.paint(canvas, Offset(lx, ly));
    final pin = _iconPainter(Icons.location_on_outlined, w * 0.03);
    pin.paint(canvas, Offset(lx - pin.width - w * 0.008, ly - w * 0.002));
  }

  /// Затемнение: слева-сверху под логотип и снизу под текст.
  void _shade(ui.Canvas canvas, double w, double h) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h * 0.7),
      Paint()
        ..shader = ui.Gradient.radial(
          Offset.zero,
          w * 0.75,
          [const Color(0xB3101820), const Color(0x00101820)],
        ),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, h * 0.62, w, h * 0.38),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, h * 0.62),
          Offset(0, h),
          [const Color(0x00000000), const Color(0xE6000000)],
          [0, 0.45],
        ),
    );
  }

  TextPainter _iconPainter(IconData icon, double size) => TextPainter(
        text: TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(
            fontFamily: icon.fontFamily,
            package: icon.fontPackage,
            fontSize: size,
            color: _white,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

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
    )..layout(minWidth: align == TextAlign.center ? maxW : 0, maxWidth: math.max(1, maxW));
  }
}

/// Позиция и размер логотипа: левый верхний угол, как в макете.
class LogoPlacement {
  final double widthFraction;
  final double marginFraction;
  const LogoPlacement({this.widthFraction = 0.2, this.marginFraction = 0.052});

  Rect rect(Size canvas, Size logo) {
    final lw = canvas.width * widthFraction;
    final lh = lw * logo.height / logo.width;
    final m = canvas.width * marginFraction;
    return Rect.fromLTWH(m, m * 0.96, lw, lh);
  }
}
