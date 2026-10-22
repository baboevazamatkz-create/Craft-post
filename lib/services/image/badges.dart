import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../../models/post_draft.dart';

/// Где оказалась плашка после раскладки (для отрисовки и для перетаскивания).
class BadgeBox {
  final Offset point; // метка на детали
  final Rect plaque; // сама плашка
  final TextPainter text;
  BadgeBox(this.point, this.plaque, this.text);
}

/// Плашки-выноски на не главных фото. Все размеры — доли ширины кадра,
/// поэтому превью и полное разрешение выглядят одинаково.
class BadgePainter {
  static const _white = Color(0xFFFFFFFF);

  /// Зона логотипа (слева сверху) — плашки туда не ставим.
  static Rect logoZone(Size s) =>
      Rect.fromLTWH(0, 0, s.width * 0.30, s.width * 0.165);

  List<BadgeBox> layout(Size size, List<PhotoBadge> badges) {
    final w = size.width, h = size.height;
    final margin = w * 0.035, padH = w * 0.026, padV = w * 0.014;
    final boxes = <BadgeBox>[];
    for (final b in badges) {
      final p = Offset(b.x * w, b.y * h);
      final tp = TextPainter(
        text: TextSpan(
          text: b.text.toUpperCase(),
          style: TextStyle(
            fontFamily: 'Cormorant',
            fontSize: w * 0.034,
            fontWeight: FontWeight.w400,
            color: _white,
            height: 1.15,
            letterSpacing: w * 0.034 * 0.04,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        maxLines: 2,
        ellipsis: '…',
      )..layout(maxWidth: w * 0.46);
      final pw = tp.width + 2 * padH, ph = tp.height + 2 * padV;

      // По умолчанию — над меткой, сдвинута к центру кадра.
      final toRight = p.dx < w / 2;
      final ax = p.dx + (toRight ? 1 : -1) * w * 0.07;
      var r =
          Rect.fromLTWH(toRight ? ax : ax - pw, p.dy - w * 0.11 - ph, pw, ph);
      if (r.top < margin) r = r.translate(0, (p.dy + w * 0.11) - r.top);
      r = _clamp(r, size, margin);
      if (r.overlaps(logoZone(size))) {
        r = Rect.fromLTWH(r.left, logoZone(size).bottom + margin * 0.5, pw, ph);
      }
      // Не налезать на уже поставленные плашки.
      for (var guard = 0; guard < 12; guard++) {
        final hit = boxes.where((o) => o.plaque.inflate(w * 0.012).overlaps(r));
        if (hit.isEmpty) break;
        r = r.translate(0, hit.first.plaque.bottom + w * 0.012 - r.top);
        if (r.bottom > h - margin) {
          r = r.translate(0, hit.first.plaque.top - w * 0.012 - r.bottom);
        }
        r = _clamp(r, size, margin);
      }
      boxes.add(BadgeBox(p, r, tp));
    }
    return boxes;
  }

  Rect _clamp(Rect r, Size s, double m) {
    final dx = r.left < m
        ? m - r.left
        : (r.right > s.width - m ? s.width - m - r.right : 0.0);
    final dy = r.top < m
        ? m - r.top
        : (r.bottom > s.height - m ? s.height - m - r.bottom : 0.0);
    return r.translate(dx, dy);
  }

  void paint(ui.Canvas canvas, Size size, List<PhotoBadge> badges,
      {List<BadgeBox>? boxes}) {
    final w = size.width;
    final laid = boxes ?? layout(size, badges);
    final line = Paint()
      ..color = _white.withValues(alpha: 0.85)
      ..strokeWidth = math.max(1.0, w * 0.0018)
      ..style = PaintingStyle.stroke;
    final halo = Paint()
      ..color = const Color(0x59000000)
      ..strokeWidth = math.max(2.0, w * 0.005)
      ..style = PaintingStyle.stroke;
    final ringR = w * 0.013;

    for (final b in laid) {
      // Выноска: от края метки до ближайшей точки плашки.
      final target = Offset(b.point.dx.clamp(b.plaque.left, b.plaque.right),
          b.point.dy.clamp(b.plaque.top, b.plaque.bottom));
      final v = target - b.point;
      if (v.distance > ringR * 1.5) {
        final start = b.point + v / v.distance * ringR;
        canvas.drawLine(start, target, halo);
        canvas.drawLine(start, target, line);
      }
    }
    for (final b in laid) {
      final rr = RRect.fromRectAndRadius(b.plaque, Radius.circular(w * 0.012));
      canvas.drawRRect(rr, Paint()..color = const Color(0x8C000000));
      canvas.drawRRect(
          rr,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1.0, w * 0.0016)
            ..color = _white.withValues(alpha: 0.55));
      b.text.paint(
          canvas,
          Offset(b.plaque.center.dx - b.text.width / 2,
              b.plaque.center.dy - b.text.height / 2));
      // Метка: кольцо с точкой, с тёмным ореолом для читаемости.
      canvas.drawCircle(b.point, ringR, halo);
      canvas.drawCircle(
          b.point,
          ringR,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1.2, w * 0.0025)
            ..color = _white);
      canvas.drawCircle(b.point, w * 0.0045, Paint()..color = _white);
    }
  }
}
