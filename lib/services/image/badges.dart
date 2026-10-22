import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../../models/post_draft.dart';

/// Где оказалась подпись после раскладки (для отрисовки и для перетаскивания).
class BadgeBox {
  final Offset point; // метка на детали
  final Rect plaque; // область подписи
  final TextPainter text;
  BadgeBox(this.point, this.plaque, this.text);

  /// Подпись под меткой: линия у её верхнего края, иначе — у нижнего.
  bool get below => plaque.top >= point.dy;
}

/// Выноски на не главных фото в стиле «линия»: точка на детали, тонкая
/// диагональная линия к полке, подпись на полке, под подписью — мягкая
/// тень без краёв. Все размеры — доли ширины кадра, поэтому превью
/// и полное разрешение выглядят одинаково.
class BadgePainter {
  static const _white = Color(0xFFFFFFFF);

  /// Зона логотипа (слева сверху) — подписи туда не ставим.
  static Rect logoZone(Size s) =>
      Rect.fromLTWH(0, 0, s.width * 0.30, s.width * 0.165);

  List<BadgeBox> layout(Size size, List<PhotoBadge> badges) {
    final w = size.width, h = size.height;
    final margin = w * 0.04, padH = w * 0.012, padV = w * 0.006;
    final fs = w * 0.032;
    final boxes = <BadgeBox>[];
    for (final b in badges) {
      final p = Offset(b.x * w, b.y * h);
      final tp = TextPainter(
        text: TextSpan(
          text: b.text.toUpperCase(),
          style: TextStyle(
            fontFamily: 'Cormorant',
            fontSize: fs,
            fontWeight: FontWeight.w400,
            color: _white,
            height: 1.2,
            letterSpacing: fs * 0.07,
            shadows: [
              Shadow(color: const Color(0xCC000000), blurRadius: w * 0.008)
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 2,
        ellipsis: '…',
      )..layout(maxWidth: w * 0.55);
      final bw = tp.width + 2 * padH, bh = tp.height + 2 * padV;

      // Полка отходит от метки по диагонали — в ту сторону, где хватает места.
      final dx = w * 0.05;
      final fitsRight = p.dx + dx + bw <= w - margin;
      final fitsLeft = p.dx - dx - bw >= margin;
      final toRight = fitsRight && (p.dx < w * 0.55 || !fitsLeft);
      final left = !fitsRight && !fitsLeft
          ? p.dx - bw / 2
          : (toRight ? p.dx + dx : p.dx - dx - bw);
      final rise = w * 0.08;
      var top = p.dy - rise - bh;
      if (top < w * 0.2) top = p.dy + rise;
      var r = _clamp(Rect.fromLTWH(left, top, bw, bh), size, margin);
      if (r.overlaps(logoZone(size))) {
        r = Rect.fromLTWH(r.left, logoZone(size).bottom + margin * 0.5, bw, bh);
      }
      // Не налезать на уже поставленные подписи.
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

  /// [minStroke] — нижний предел толщины линии для мелкой картинки на
  /// экране (редактор), чтобы линия не пропадала; в экспорте не нужен.
  void paint(ui.Canvas canvas, Size size, List<PhotoBadge> badges,
      {List<BadgeBox>? boxes, double minStroke = 0}) {
    final w = size.width;
    final laid = boxes ?? layout(size, badges);
    final lw = math.max(minStroke, w * 0.0008);
    final line = Paint()
      ..color = _white
      ..strokeWidth = lw
      ..style = PaintingStyle.stroke;
    final halo = Paint()
      ..color = const Color(0x40000000)
      ..strokeWidth = lw * 2.2
      ..style = PaintingStyle.stroke;
    final smoke = Paint()
      ..color = const Color(0x73000000)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.018);
    final dotR = math.max(minStroke * 2, w * 0.0036);

    void stroke(Offset a, Offset b) {
      canvas.drawLine(a, b, halo);
      canvas.drawLine(a, b, line);
    }

    for (final b in laid) {
      canvas.drawRect(b.plaque.inflate(w * 0.01), smoke);
    }
    for (final b in laid) {
      final r = b.plaque;
      final y = b.below ? r.top : r.bottom;
      // Диагональ — к ближнему концу полки.
      final end = (b.point.dx - r.left).abs() <= (b.point.dx - r.right).abs()
          ? r.left
          : r.right;
      stroke(b.point, Offset(end, y));
      stroke(Offset(r.left, y), Offset(r.right, y));
      b.text.paint(canvas, Offset(r.left + w * 0.012, r.top + w * 0.006));
      canvas.drawCircle(
          b.point, dotR + lw, Paint()..color = const Color(0x59000000));
      canvas.drawCircle(b.point, dotR, Paint()..color = _white);
    }
  }
}
