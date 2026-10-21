import 'package:flutter/material.dart';

import '../models/icon_library.dart';

/// Выбор значка. `ai` — значок, нарисованный AI (если он есть).
class IconDropdown extends StatelessWidget {
  final String value;
  final bool hasAi;
  final ValueChanged<String> onChanged;
  const IconDropdown({super.key, required this.value, required this.hasAi, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value == 'ai' && hasAi ? 'ai' : iconByKey(value).key,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Значок'),
      items: [
        if (hasAi) const DropdownMenuItem(value: 'ai', child: Text('Нарисован AI')),
        for (final i in kIcons) DropdownMenuItem(value: i.key, child: Text(i.label)),
      ],
      onChanged: (v) => onChanged(v ?? value),
    );
  }
}
