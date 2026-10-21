import 'package:flutter/material.dart';

import '../models/icon_library.dart';

class IconDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const IconDropdown({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: iconByKey(value).key,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Значок'),
      items: [
        for (final i in kIcons)
          DropdownMenuItem(
            value: i.key,
            child: Row(children: [
              Icon(i.data),
              const SizedBox(width: 10),
              Expanded(child: Text(i.label, overflow: TextOverflow.ellipsis)),
            ]),
          ),
      ],
      onChanged: (v) => onChanged(v ?? value),
    );
  }
}
