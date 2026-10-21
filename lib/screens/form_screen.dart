import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models/post_draft.dart';
import '../widgets/busy.dart';
import 'preview_screen.dart';

class FormScreen extends StatefulWidget {
  const FormScreen({super.key});

  @override
  State<FormScreen> createState() => _FormScreenState();
}

class _FormScreenState extends State<FormScreen> {
  late final Map<String, TextEditingController> _c;

  @override
  void initState() {
    super.initState();
    final saved = context.read<AppState>().draft.fields;
    _c = {
      for (final f in kInfographicFields) f.key: TextEditingController(text: saved[f.key] ?? ''),
    };
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _create() async {
    final s = context.read<AppState>();
    s.draft.fields
      ..clear()
      ..addAll({for (final e in _c.entries) e.key: e.value.text.trim()});
    final ok = await runBusy(context, 'Готовлю пост…', s.generate);
    if (ok && mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const PreviewScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('2. Данные для инфографики')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final f in kInfographicFields) ...[
            TextField(
              controller: _c[f.key],
              keyboardType: f.numeric ? TextInputType.number : TextInputType.text,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(fontSize: 18),
              decoration: InputDecoration(labelText: f.label, hintText: f.hint),
            ),
            const SizedBox(height: 14),
          ],
          const SizedBox(height: 8),
          FilledButton(onPressed: _create, child: const Text('Создать пост')),
        ],
      ),
    );
  }
}
