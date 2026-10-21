import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';

class SaveScreen extends StatefulWidget {
  const SaveScreen({super.key});

  @override
  State<SaveScreen> createState() => _SaveScreenState();
}

class _SaveScreenState extends State<SaveScreen> {
  int _done = 0;
  int _total = 1;
  bool _saving = false, _finished = false;
  String? _error;

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<AppState>().saveAll((d, t) {
        if (mounted) {
          setState(() {
            _done = d;
            _total = t;
          });
        }
      });
      _finished = true;
    } catch (e) {
      _error = '$e';
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('4. Сохранение')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
                'Фото к сохранению: ${1 + s.draft.otherPaths.length}\nАльбом в галерее: CRAFT SYSTEM',
                style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 16),
            if (_saving || _finished) ...[
              LinearProgressIndicator(
                  minHeight: 10, value: _total == 0 ? 0 : _done / _total),
              const SizedBox(height: 8),
              Text('$_done из $_total', style: const TextStyle(fontSize: 16)),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_error!,
                    style:
                        const TextStyle(color: Colors.redAccent, fontSize: 16)),
              ),
            if (_finished) ...[
              const SizedBox(height: 16),
              const Text('Готово! Фото в галерее.',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () =>
                    Clipboard.setData(ClipboardData(text: s.draft.caption)),
                icon: const Icon(Icons.copy),
                label: const Text('Скопировать подпись'),
              ),
            ],
            const Spacer(),
            if (_finished)
              FilledButton(
                onPressed: () {
                  s.reset();
                  Navigator.popUntil(context, (r) => r.isFirst);
                },
                child: const Text('Новый пост'),
              )
            else
              FilledButton(
                onPressed: _saving ? null : _save,
                child: const Text('Сохранить всё'),
              ),
          ],
        ),
      ),
    );
  }
}
