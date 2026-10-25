import 'dart:convert';

import 'package:flutter/services.dart';

/// Библиотека тонких контурных значков Tabler (MIT, assets/icons):
/// имя → SVG-пути в сетке 24×24. Собирается tool/icons/build_tabler.py.
class IconCatalog {
  final Map<String, List<String>> icons;
  IconCatalog(this.icons);

  static Future<IconCatalog> load() async {
    final raw =
        jsonDecode(await rootBundle.loadString('assets/icons/tabler.json'))
            as Map<String, dynamic>;
    return IconCatalog({
      for (final e in (raw['icons'] as Map<String, dynamic>).entries)
        e.key: [for (final p in e.value as List) '$p'],
    });
  }

  /// Имена по строке — для AI. Порядок постоянный, чтобы запрос кэшировался.
  late final String namesText = icons.keys.join('\n');
}
