import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../../models/post_draft.dart';
import 'fit_text.dart';

/// Где оказалась подпись после раскладки (для отрисовки и для перетаскивания).
class BadgeBox {
  final Offset point; // метка на детали
  final Rect plaque; // область подписи
  final TextPainter text;

  /// Где выноска встречает полку: ближний к метке конец полки.
  final Offset joint;
  BadgeBox(this.point, this.plaque, this.text, this.joint);
}

class _Option {
  final Rect rect;
  final Offset joint;
  final TextPainter text;
  final double cost;
  _Option(this.rect, this.joint, this.text, this.cost);
}

/// Выноски на не главных фото в стиле «линия»: точка на детали, тонкая
/// диагональная линия к полке, подпись на полке, под подписью — мягкая
/// тень без краёв. Все размеры — доли ширины кадра, поэтому превью
/// и полное разрешение выглядят одинаково.
class BadgePainter {
  static const _white = Color(0xFFFFFFFF);

  /// Подъём выноски и её вынос вбок (доли ширины кадра). Вынос всегда в
  /// сторону полки, поэтому угол между выноской и полкой тупой (≈120–160°).
  static const _reach = [
    (0.040, 0.060),
    (0.075, 0.055),
    (0.110, 0.075),
    (0.155, 0.100),
    (0.210, 0.130),
    (0.040, 0.120),
    (0.080, 0.150),
    (0.120, 0.190),
  ];

  /// Зона логотипа (слева сверху) — подписи туда не ставим.
  static Rect logoZone(Size s) =>
      Rect.fromLTWH(0, 0, s.width * 0.30, s.width * 0.165);

  /// Перебирает места для каждой подписи (справа/слева, выше/ниже, ближе/
  /// дальше, в одну или две строки) и выбирает такие, чтобы подписи, линии
  /// и метки не мешали друг другу.
  List<BadgeBox> layout(Size size, List<PhotoBadge> badges) {
    final w = size.width;
    final points = [for (final b in badges) Offset(b.x * w, b.y * size.height)];
    final options = [
      for (var i = 0; i < badges.length; i++)
        _options(size, points[i], badges[i].text),
    ];
    final pick = <_Option?>[for (final _ in badges) null];

    double score(int i, _Option o) {
      var c = o.cost;
      for (var j = 0; j < badges.length; j++) {
        if (j != i) c += _conflict(w, o, points[i], pick[j], points[j]);
      }
      return c;
    }

    // Сначала по очереди, затем несколько уточняющих проходов: каждая
    // подпись пересаживается на лучшее место с учётом всех остальных.
    for (var pass = 0; pass < 4; pass++) {
      var changed = false;
      for (var i = 0; i < badges.length; i++) {
        var best = pick[i];
        var bestScore = best == null ? double.infinity : score(i, best);
        for (final o in options[i]) {
          final s = score(i, o);
          if (s < bestScore - 1e-6) {
            best = o;
            bestScore = s;
          }
        }
        if (!identical(best, pick[i])) changed = true;
        pick[i] = best;
      }
      if (!changed) break;
    }
    return [
      for (var i = 0; i < badges.length; i++)
        BadgeBox(points[i], pick[i]!.rect, pick[i]!.text, pick[i]!.joint),
    ];
  }

  static const _font = 0.028; // размер шрифта подписи, доля ширины кадра
  static const _padH = 0.011, _padV = 0.0055;

  /// Подписи, уже подогнанные под ширину: (по левому краю, по правому).
  /// Раскладка вызывается на каждом кадре редактора — без кэша дорого.
  final _texts = <String, (TextPainter, TextPainter)>{};

  /// Подпись целиком в 2 строки шириной [maxWidth]: длинная — мельче,
  /// без многоточий и переносов по буквам.
  (TextPainter, TextPainter) _text(double w, String text, double maxWidth) {
    final key = '$w|$maxWidth|$text';
    final hit = _texts[key];
    if (hit != null) return hit;
    TextPainter build(String t, double fs, int? lines,
            [TextAlign align = TextAlign.left]) =>
        TextPainter(
          text: TextSpan(
            text: t,
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
          textAlign: align,
          textDirection: TextDirection.ltr,
          textWidthBasis: TextWidthBasis.longestLine,
          maxLines: lines,
        );
    final upper = text.toUpperCase();
    final left = fitText(upper, w * _font, maxWidth, 2, build);
    final fs = (left.text as TextSpan).style!.fontSize!;
    final right = build(upper, fs, left.maxLines, TextAlign.right)
      ..layout(maxWidth: maxWidth);
    if (_texts.length > 300) _texts.clear();
    return _texts[key] = (left, right);
  }

  List<_Option> _options(Size size, Offset p, String text) {
    final w = size.width, h = size.height;
    final margin = w * 0.04, padH = w * _padH, padV = w * _padV;
    final frame = Rect.fromLTRB(margin, margin, w - margin, h - margin);
    final logo = logoZone(size).inflate(w * 0.01);
    final out = <_Option>[];
    final fallback = <_Option>[];
    for (final (k, maxW) in [(0, 0.46), (1, 0.34)]) {
      final (leftText, rightText) = _text(w, text, w * maxW);
      final lines = leftText.computeLineMetrics().length;
      if (k == 1 && lines < 2) continue; // и так в одну строку
      // Чем сильнее пришлось уменьшить шрифт, тем хуже вариант.
      final shrink =
          1 - (leftText.text as TextSpan).style!.fontSize! / (w * _font);
      for (final side in [1, -1]) {
        // Справа текст прижат к левому краю, слева — к правому: так он
        // начинается от выноски.
        final tp = side > 0 ? leftText : rightText;
        final bw = tp.width + 2 * padH, bh = tp.height + 2 * padV;
        for (final up in [true, false]) {
          for (var n = 0; n < _reach.length; n++) {
            final (rise, dx) = _reach[n];
            final jx = p.dx + side * dx * w;
            final jy = p.dy + (up ? -rise : rise) * w;
            final left = side > 0 ? jx : jx - bw;
            final top = up ? jy - bh : jy;
            final r = Rect.fromLTWH(left, top, bw, bh);
            // Стоимость в долях ширины: ближе — лучше; над меткой и в одну
            // строку — чуть лучше; к центру кадра — чуть лучше.
            var cost = rise * 100 +
                dx * 25 +
                (up ? 0 : 3) +
                (k == 1 ? 4 : 0) +
                shrink * 60 +
                (lines > 2 ? 40 : 0) +
                ((side > 0) == (p.dx < w / 2) ? 0 : 2);
            final o = _Option(r, Offset(jx, jy), tp, cost);
            final inside = frame.contains(r.topLeft) &&
                frame.contains(r.bottomRight) &&
                !r.overlaps(logo);
            if (inside) {
              out.add(o);
            } else {
              final moved = _clamp(r, frame);
              fallback.add(_Option(
                  moved,
                  Offset(side > 0 ? moved.left : moved.right,
                      up ? moved.bottom : moved.top),
                  tp,
                  cost + 1000));
            }
          }
        }
      }
    }
    return out.isNotEmpty ? out : fallback;
  }

  Rect _clamp(Rect r, Rect f) {
    final dx = r.left < f.left
        ? f.left - r.left
        : (r.right > f.right ? f.right - r.right : 0.0);
    final dy = r.top < f.top
        ? f.top - r.top
        : (r.bottom > f.bottom ? f.bottom - r.bottom : 0.0);
    return r.translate(dx, dy);
  }

  /// Штраф за то, что подпись [a] (с меткой [pa]) мешает подписи [b].
  double _conflict(double w, _Option a, Offset pa, _Option? b, Offset pb) {
    var c = 0.0;
    // Чужая метка не должна оказаться под подписью или на линии.
    if (a.rect.inflate(w * 0.02).contains(pb)) c += 600;
    if (_segDist(pb, pa, a.joint) < w * 0.012) c += 200;
    if (b == null) return c;
    final gap = w * 0.015;
    if (a.rect.inflate(gap).overlaps(b.rect)) c += 1000;
    if (_segRect(pa, a.joint, b.rect.inflate(gap / 2))) c += 400;
    if (_segRect(pb, b.joint, a.rect.inflate(gap / 2))) c += 400;
    if (_segSeg(pa, a.joint, pb, b.joint)) c += 300;
    return c;
  }

  static double _segDist(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
    if (len2 == 0) return (p - a).distance;
    final t = (((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / len2)
        .clamp(0.0, 1.0);
    return (p - (a + ab * t)).distance;
  }

  static double _cross(Offset o, Offset a, Offset b) =>
      (a.dx - o.dx) * (b.dy - o.dy) - (a.dy - o.dy) * (b.dx - o.dx);

  static bool _segSeg(Offset a, Offset b, Offset c, Offset d) {
    final d1 = _cross(c, d, a), d2 = _cross(c, d, b);
    final d3 = _cross(a, b, c), d4 = _cross(a, b, d);
    return ((d1 > 0) != (d2 > 0)) && ((d3 > 0) != (d4 > 0));
  }

  static bool _segRect(Offset a, Offset b, Rect r) {
    if (r.contains(a) || r.contains(b)) return true;
    final tl = r.topLeft,
        tr = r.topRight,
        bl = r.bottomLeft,
        br = r.bottomRight;
    return _segSeg(a, b, tl, tr) ||
        _segSeg(a, b, tr, br) ||
        _segSeg(a, b, br, bl) ||
        _segSeg(a, b, bl, tl);
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
      canvas.drawRect(b.plaque.inflate(w * 0.009), smoke);
    }
    for (final b in laid) {
      final r = b.plaque;
      stroke(b.point, b.joint);
      stroke(Offset(r.left, b.joint.dy), Offset(r.right, b.joint.dy));
      b.text.paint(canvas, Offset(r.left + w * _padH, r.top + w * _padV));
      canvas.drawCircle(
          b.point, dotR + lw, Paint()..color = const Color(0x59000000));
      canvas.drawCircle(b.point, dotR, Paint()..color = _white);
    }
  }
}
