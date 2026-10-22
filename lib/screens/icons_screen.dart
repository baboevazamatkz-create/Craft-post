import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models/post_draft.dart';
import '../theme.dart';
import '../widgets/busy.dart';
import '../widgets/line_icon_view.dart';
import 'preview_screen.dart';

/// Значки к выбранным преимуществам: AI рисует варианты сразу при
/// открытии экрана, пользователь выбирает по одному на каждое.
class IconsScreen extends StatefulWidget {
  final List<Feature> features;

  /// Открыт из превью: по готовности вернуться в превью.
  final bool editing;
  const IconsScreen({super.key, required this.features, this.editing = false});

  @override
  State<IconsScreen> createState() => _IconsScreenState();
}

class _IconsScreenState extends State<IconsScreen> {
  final _wish = TextEditingController();
  late final List<List<List<String>>> _variants;
  late final List<int> _pick; // -1 — ещё не выбран
  late final List<bool> _hasCurrent;

  static const _quick = [
    'Интереснее и детальнее',
    'Совсем другие идеи',
    'Проще и чище',
  ];

  @override
  void initState() {
    super.initState();
    final f = widget.features;
    _hasCurrent = [for (final x in f) x.svg.isNotEmpty];
    _variants = [
      for (final x in f) [if (x.svg.isNotEmpty) x.svg]
    ];
    _pick = [for (final x in f) x.svg.isNotEmpty ? 0 : -1];
    WidgetsBinding.instance.addPostFrameCallback((_) => _suggest());
  }

  @override
  void dispose() {
    _wish.dispose();
    super.dispose();
  }

  Future<void> _suggest() async {
    final s = context.read<AppState>();
    List<List<List<String>>>? res;
    final ok = await runBusy(
        context,
        'AI рисует значки… обычно до минуты',
        () async => res = await s.suggestIcons(
            [for (final f in widget.features) f.text], _wish.text));
    if (!ok || res == null || !mounted) return;
    setState(() {
      for (var i = 0; i < _variants.length && i < res!.length; i++) {
        final first = _variants[i].length;
        _variants[i].addAll(res![i]);
        if (_pick[i] < 0 && res![i].isNotEmpty) _pick[i] = first;
      }
    });
  }

  Future<void> _done() async {
    final s = context.read<AppState>();
    final features = [
      for (var i = 0; i < widget.features.length; i++)
        Feature('bolt', widget.features[i].text, _variants[i][_pick[i]]),
    ];
    final ok = await runBusy(
        context, 'Готовлю превью…', () => s.setFeatures(features));
    if (!ok || !mounted) return;
    if (widget.editing) {
      Navigator.pop(context, true);
    } else {
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => const PreviewScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = !_pick.contains(-1);
    return Scaffold(
      appBar: AppBar(title: const Text('4. Значки')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (var i = 0; i < widget.features.length; i++) _feature(i),
          const SizedBox(height: 4),
          TextField(
            controller: _wish,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Пожелание к значкам (необязательно)',
              hintText: 'Например: значок с двумя выключателями',
            ),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 4, children: [
            for (final q in _quick)
              ActionChip(
                label: Text(q),
                backgroundColor: Brand.tint,
                side: const BorderSide(color: Brand.border),
                onPressed: () => setState(() => _wish.text = q),
              ),
          ]),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _suggest,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Ещё варианты'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: ready ? _done : null,
            child: Text(widget.editing ? 'Применить' : 'Далее — превью'),
          ),
        ],
      ),
    );
  }

  Widget _feature(int i) {
    final variants = _variants[i];
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${i + 1}. ${widget.features[i].text}',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        if (variants.isEmpty)
          const Text('Вариантов пока нет — нажмите «Ещё варианты»',
              style: TextStyle(color: Brand.deep))
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (var v = 0; v < variants.length; v++)
                _tile(
                    variants[v],
                    _hasCurrent[i] && v == 0
                        ? 'Сейчас'
                        : 'Вариант ${_hasCurrent[i] ? v : v + 1}',
                    _pick[i] == v,
                    () => setState(() => _pick[i] = v)),
            ]),
          ),
      ]),
    );
  }

  Widget _tile(List<String> paths, String label, bool selected,
          VoidCallback onTap) =>
      Padding(
        padding: const EdgeInsets.only(right: 10),
        child: GestureDetector(
          onTap: onTap,
          child: Column(children: [
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1B2630),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: selected ? Brand.blue : Colors.transparent,
                    width: 3),
              ),
              child: LineIconView(paths, size: 84),
            ),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    color: selected ? Brand.blue : Brand.deep,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400)),
          ]),
        ),
      );
}
