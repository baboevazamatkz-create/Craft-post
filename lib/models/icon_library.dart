import 'package:flutter/material.dart';

/// Библиотека значков для инфографики. Сейчас — временные значки Material;
/// реальные линейные значки заказчика заменят их (файлы PNG/SVG в assets/icons).
class IconSpec {
  final String key;
  final String label;
  final IconData data;
  const IconSpec(this.key, this.label, this.data);
}

const kIcons = <IconSpec>[
  IconSpec('day_night', 'День-ночь', Icons.brightness_4_outlined),
  IconSpec('remote', 'Дистанционная настройка', Icons.settings_remote_outlined),
  IconSpec('height', 'Работа на высоте', Icons.engineering_outlined),
  IconSpec('cable', 'Кабельная линия', Icons.cable_outlined),
  IconSpec('panel', 'Электрощит', Icons.electrical_services_outlined),
  IconSpec('light', 'Освещение', Icons.lightbulb_outline),
  IconSpec('camera', 'Видеонаблюдение', Icons.videocam_outlined),
  IconSpec('safety', 'Безопасность', Icons.verified_user_outlined),
  IconSpec('check', 'Проверка системы', Icons.fact_check_outlined),
  IconSpec('timer', 'Сроки', Icons.timer_outlined),
  IconSpec('bolt', 'Электричество', Icons.bolt_outlined),
  IconSpec('tools', 'Монтаж', Icons.build_outlined),
];

IconSpec iconByKey(String key) =>
    kIcons.firstWhere((i) => i.key == key, orElse: () => kIcons.first);
