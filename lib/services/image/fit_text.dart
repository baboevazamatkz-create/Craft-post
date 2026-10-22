import 'package:flutter/painting.dart';

/// Подбирает размер шрифта, чтобы [text] уместился целиком: не больше
/// [maxLines] строк шириной [maxWidth] и без переносов слов по буквам.
/// Сначала пробует [size], затем уменьшает (не меньше [minScale] от него).
/// [build] собирает painter для заданного размера (без layout).
TextPainter fitText(
  String text,
  double size,
  double maxWidth,
  int maxLines,
  TextPainter Function(String text, double size, int? maxLines) build, {
  double minWidth = 0,
  double minScale = 0.55,
}) {
  final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  var s = size;
  while (true) {
    final last = s <= size * minScale;
    // На последнем шаге строк не ограничиваем: лучше лишняя строка,
    // чем обрезанный текст.
    final tp = build(text, s, last ? null : maxLines)
      ..layout(minWidth: minWidth, maxWidth: maxWidth);
    final fits = !tp.didExceedMaxLines &&
        words.every((w) => (build(w, s, 1)..layout()).width <= maxWidth + 0.5);
    if (fits || last) return tp;
    s = (s * 0.93).clamp(size * minScale, size);
  }
}
