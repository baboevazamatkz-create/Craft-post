import 'package:flutter/material.dart';

import '../models/line_icon.dart';

/// Линейный значок в интерфейсе (белые линии на тёмной плашке).
class LineIconView extends StatelessWidget {
  final List<String> paths;
  final double size;
  const LineIconView(this.paths, {super.key, this.size = 76});

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size.square(size),
        painter: _Painter(paths),
      );
}

class _Painter extends CustomPainter {
  final List<String> paths;
  _Painter(this.paths);

  @override
  void paint(Canvas canvas, Size size) {
    final pad = size.width * 0.12;
    final box =
        Rect.fromLTWH(pad, pad, size.width - 2 * pad, size.width - 2 * pad);
    paintLineIcon(
        canvas, paths, box, (box.width * 0.02).clamp(1.2, 3.0), Colors.white);
  }

  @override
  bool shouldRepaint(_Painter old) => old.paths != paths;
}
