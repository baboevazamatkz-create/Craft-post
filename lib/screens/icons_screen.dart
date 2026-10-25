import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models/post_draft.dart';
import '../theme.dart';
import '../widgets/line_icon_view.dart';
import 'preview_screen.dart';

/// Вариант значка: из библиотеки (с именем), нарисованный AI или текущий.
class _Variant {
  final List<String> paths;
  final String label;
  final String? name;
  _Variant(this.paths, this.label, [this.name]);
}

/// Значки к выбранным преимуществам. При открытии сразу идут два запроса:
/// подбор из библиотеки (секунды) и рисунок AI (дольше, появляется фоном).
/// Выбрать можно, не дожидаясь рисунка.
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
  late final List<List<_Variant>> _variants;
  late final List<int> _pick; // -1 — ещё не выбран
  final _shown = <String>{}; // имена из библиотеки, уже показанные
  bool _picking = false, _drawing = false, _saving = false;

  static const _quick = [
    'Интереснее и детальнее',
    'Совсем другие идеи',
    'Проще и чище',
  ];

  @override
  void initState() {
    super.initState();
    _variants = [
      for (final f in widget.features)
        [if (f.svg.isNotEmpty) _Variant(f.svg, 'Сейчас')]
    ];
    _pick = [for (final f in widget.features) f.svg.isNotEmpty ? 0 : -1];
    WidgetsBinding.instance.addPostFrameCallback((_) => _suggest());
  }

  @override
  void dispose() {
    _wish.dispose();
    super.dispose();
  }

  List<String> get _texts => [for (final f in widget.features) f.text];

  void _error(Object e) {
    if (!mounted) return;
    final text = '$e'.replaceFirst(RegExp(r'^Exception: '), '');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Ошибка: $text'), duration: const Duration(seconds: 6)));
  }

  /// Добавляет варианты; невыбранное преимущество получает первый новый.
  void _add(int i, List<_Variant> fresh) {
    if (fresh.isEmpty) return;
    final first = _variants[i].length;
    _variants[i].addAll(fresh);
    if (_pick[i] < 0) _pick[i] = first;
  }

  Future<void> _suggest() async {
    if (_picking || _drawing) return;
    final s = context.read<AppState>();
    final texts = _texts, wish = _wish.text;
    setState(() => _picking = _drawing = true);

    // Рисунок AI — фоном, не задерживает выбор.
    unawaited(s.drawIcons(texts, wish).then((res) {
      if (!mounted) return;
      setState(() {
        for (var i = 0; i < _variants.length && i < res.length; i++) {
          _add(i, [for (final p in res[i]) _Variant(p, 'Рисунок AI')]);
        }
      });
    }, onError: _error).whenComplete(() {
      if (mounted) setState(() => _drawing = false);
    }));

    try {
      final res = await s.pickIcons(texts, wish, {..._shown});
      if (!mounted) return;
      setState(() {
        for (var i = 0; i < _variants.length && i < res.length; i++) {
          _add(i, [
            for (final (name, paths) in res[i])
              _Variant(paths, 'Вариант', name),
          ]);
          _shown.addAll([for (final (name, _) in res[i]) name]);
        }
      });
    } catch (e) {
      _error(e);
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _done() async {
    final s = context.read<AppState>();
    final features = [
      for (var i = 0; i < widget.features.length; i++)
        Feature('bolt', widget.features[i].text, _variants[i][_pick[i]].paths),
    ];
    setState(() => _saving = true);
    try {
      await s.setFeatures(features);
    } catch (e) {
      _error(e);
      return;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (!mounted) return;
    if (widget.editing) {
      Navigator.pop(context, true);
    } else {
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => const PreviewScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = !_pick.contains(-1) && !_saving;
    final busy = _picking || _drawing;
    return Scaffold(
      appBar: AppBar(title: const Text('4. Значки')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (busy) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 6),
            Text(
                _picking
                    ? 'AI подбирает значки…'
                    : 'AI рисует свой вариант — можно не ждать',
                style: const TextStyle(color: Brand.deep)),
            const SizedBox(height: 12),
          ],
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
            onPressed: busy ? null : _suggest,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Ещё варианты'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: ready ? _done : null,
            child: Text(_saving
                ? 'Готовлю превью…'
                : (widget.editing ? 'Применить' : 'Далее — превью')),
          ),
        ],
      ),
    );
  }

  Widget _feature(int i) {
    final variants = _variants[i];
    var n = 0; // номер варианта из библиотеки
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${i + 1}. ${widget.features[i].text}',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        if (variants.isEmpty)
          Text(
              _picking ? 'Подбираю…' : 'Вариантов нет — нажмите «Ещё варианты»',
              style: const TextStyle(color: Brand.deep))
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (var v = 0; v < variants.length; v++)
                _tile(
                    variants[v].paths,
                    variants[v].name != null
                        ? 'Вариант ${++n}'
                        : variants[v].label,
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
