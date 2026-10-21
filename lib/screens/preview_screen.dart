import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models/post_draft.dart';
import '../widgets/busy.dart';
import '../widgets/icon_dropdown.dart';
import 'save_screen.dart';

class PreviewScreen extends StatefulWidget {
  const PreviewScreen({super.key});

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  late final TextEditingController _caption, _title, _subtitle, _location, _stat, _unit;
  late final List<TextEditingController> _feat;
  late final List<String> _icons;
  late final List<List<String>> _svgs;

  @override
  void initState() {
    super.initState();
    final d = context.read<AppState>().draft;
    _caption = TextEditingController(text: d.caption);
    _title = TextEditingController(text: d.infographic.title);
    _subtitle = TextEditingController(text: d.infographic.subtitle);
    _location = TextEditingController(text: d.infographic.location);
    _stat = TextEditingController(text: d.infographic.stat);
    _unit = TextEditingController(text: d.infographic.unit);
    _feat = [for (final f in d.infographic.features) TextEditingController(text: f.text)];
    _icons = [for (final f in d.infographic.features) f.svg.isNotEmpty ? 'ai' : f.icon];
    _svgs = [for (final f in d.infographic.features) f.svg];
  }

  @override
  void dispose() {
    for (final c in [_caption, _title, _subtitle, _location, _stat, _unit, ..._feat]) {
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
      ..location = _location.text
      ..stat = _stat.text
      ..unit = _unit.text
      ..features = [
        for (var i = 0; i < _feat.length; i++) _icons[i] == 'ai'
            ? Feature('bolt', _feat[i].text, _svgs[i])
            : Feature(_icons[i], _feat[i].text),
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
          _field(_location, 'Локация'),
          Row(children: [
            Expanded(child: _field(_stat, 'Крупная цифра')),
            const SizedBox(width: 8),
            Expanded(child: _field(_unit, 'Единица')),
          ]),
          for (var i = 0; i < _feat.length; i++) ...[
            _field(_feat[i], 'Преимущество ${i + 1}'),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: IconDropdown(value: _icons[i], hasAi: _svgs[i].isNotEmpty, onChanged: (v) => _icons[i] = v),
            ),
          ],
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
