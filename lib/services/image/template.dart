import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart' show Colors;

import 'package:flutter/painting.dart';

import '../../models/post_draft.dart';

/// Шаблон инфографики. Заглушка: все размеры заданы долями ширины фото,
/// поэтому результат одинаков в превью и в полном разрешении.
/// Реальные макеты подставляются сюда (позиции, шрифты, цвета, значки).
class InfographicTemplate {
  static const accent = Color(0xFFFFC400);
  static const dark = Color(0xFF141414);

  void paint(Canvas canvas, Size size, InfographicText t) {
    final w = size.width;
    final h = size.height;
    final pad = w * 0.05;

    // Верхняя плашка с названием объекта.
    final top = Rect.fromLTWH(0, 0, w, h * 0.22);
    canvas.drawRect(
      top,
      Paint()
        ..shader = ui.Gradient.linear(Offset.zero, Offset(0, top.height), [
          dark.withValues(alpha: 0.85),
          dark.withValues(alpha: 0),
        ]),
    );
    final titleP = _text(t.title, w * 0.065, Colors.white, FontWeight.w800, w - 2 * pad);
    titleP.paint(canvas, Offset(pad, pad));
    final subP = _text(t.subtitle, w * 0.038, accent, FontWeight.w600, w - 2 * pad);
    subP.paint(canvas, Offset(pad, pad + titleP.height + w * 0.01));

    // Нижний ряд карточек с цифрами.
    if (t.items.isNotEmpty) {
      final items = t.items.take(4).toList();
      final gap = w * 0.025;
      final cardW = (w - 2 * pad - gap * (items.length - 1)) / items.length;
      final cardH = w * 0.2;
      final y = h - pad - cardH;
      for (var i = 0; i < items.length; i++) {
        final x = pad + i * (cardW + gap);
        final r = RRect.fromRectAndRadius(
            Rect.fromLTWH(x, y, cardW, cardH), Radius.circular(w * 0.025));
        canvas.drawRRect(r, Paint()..color = dark.withValues(alpha: 0.82));
        canvas.drawRRect(
            r,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = w * 0.004
              ..color = accent);
        final v = _text(items[i].value, w * 0.05, accent, FontWeight.w800, cardW - gap * 2,
            align: TextAlign.center);
        final l = _text(items[i].label, w * 0.028, Colors.white, FontWeight.w500, cardW - gap * 2,
            align: TextAlign.center);
        final total = v.height + l.height;
        final y0 = y + (cardH - total) / 2;
        v.paint(canvas, Offset(x + gap, y0));
        l.paint(canvas, Offset(x + gap, y0 + v.height));
      }
    }
  }

  TextPainter _text(String s, double size, Color color, FontWeight weight, double maxW,
      {TextAlign align = TextAlign.left}) {
    final p = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontSize: size,
          color: color,
          fontWeight: weight,
          height: 1.1,
          shadows: const [Shadow(blurRadius: 6, color: Color(0x99000000))],
        ),
      ),
      textAlign: align,
      textDirection: TextDirection.ltr,
      maxLines: 2,
      ellipsis: '…',
    )..layout(maxWidth: math.max(1, maxW));
    return p;
  }
}

/// Позиция и размер логотипа. Заглушка: правый нижний угол, 24% ширины.
class LogoPlacement {
  final double widthFraction;
  final double marginFraction;
  const LogoPlacement({this.widthFraction = 0.24, this.marginFraction = 0.04});

  Rect rect(Size canvas, Size logo) {
    final lw = canvas.width * widthFraction;
    final lh = lw * logo.height / logo.width;
    final m = canvas.width * marginFraction;
    return Rect.fromLTWH(canvas.width - lw - m, canvas.height - lh - m, lw, lh);
  }
}
