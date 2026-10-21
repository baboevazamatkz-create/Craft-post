import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models/post_draft.dart';
import '../widgets/busy.dart';
import 'save_screen.dart';

class PreviewScreen extends StatefulWidget {
  const PreviewScreen({super.key});

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  late final TextEditingController _caption, _title, _subtitle;
  late final List<TextEditingController> _labels, _values;

  @override
  void initState() {
    super.initState();
    final d = context.read<AppState>().draft;
    _caption = TextEditingController(text: d.caption);
    _title = TextEditingController(text: d.infographic.title);
    _subtitle = TextEditingController(text: d.infographic.subtitle);
    _labels = [for (final i in d.infographic.items) TextEditingController(text: i.label)];
    _values = [for (final i in d.infographic.items) TextEditingController(text: i.value)];
  }

  @override
  void dispose() {
    for (final c in [_caption, _title, _subtitle, ..._labels, ..._values]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Переносит правки из полей в черновик.
  void _apply() {
    final d = context.read<AppState>().draft;
    d.caption = _caption.text;
    d.infographic
      ..title = _title.text
      ..subtitle = _subtitle.text
      ..items = [
        for (var i = 0; i < _labels.length; i++) InfoItem(_labels[i].text, _values[i].text),
      ];
  }

  Future<void> _refresh() async {
    _apply();
    await runBusy(context, 'Обновляю превью…', context.read<AppState>().refreshPreviews);
  }

  Future<void> _approve() async {
    _apply();
    final ok = await runBusy(
        context, 'Обновляю превью…', context.read<AppState>().refreshPreviews);
    if (ok && mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const SaveScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = context.watch<AppState>().draft;
    return Scaffold(
      appBar: AppBar(title: const Text('3. Превью и правки')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (d.mainPreview != null) _preview(d.mainPreview!),
          const SizedBox(height: 8),
          SizedBox(
            height: 140,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [for (final b in d.otherPreviews) Padding(padding: const EdgeInsets.only(right: 8), child: _preview(b))],
            ),
          ),
          const SizedBox(height: 16),
          const Text('Инфографика', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _field(_title, 'Заголовок'),
          _field(_subtitle, 'Подзаголовок'),
          for (var i = 0; i < _labels.length; i++)
            Row(children: [
              Expanded(child: _field(_labels[i], 'Подпись ${i + 1}')),
              const SizedBox(width: 8),
              Expanded(child: _field(_values[i], 'Значение ${i + 1}')),
            ]),
          OutlinedButton.icon(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Обновить превью'),
          ),
          const SizedBox(height: 16),
          const Text('Подпись к посту', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _caption,
            minLines: 5,
            maxLines: 14,
            style: const TextStyle(fontSize: 16),
            decoration: const InputDecoration(),
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: _approve, child: const Text('Согласовать')),
        ],
      ),
    );
  }

  Widget _preview(dynamic bytes) => ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.memory(bytes, fit: BoxFit.cover),
      );

  Widget _field(TextEditingController c, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(controller: c, decoration: InputDecoration(labelText: label)),
      );
}
