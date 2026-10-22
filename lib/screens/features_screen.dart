import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models/post_draft.dart';
import '../theme.dart';
import '../widgets/busy.dart';
import 'icons_screen.dart';

/// Выбор преимуществ для главного фото из вариантов AI. Порядок на
/// инфографике — как нажимали. Дальше AI сразу рисует к ним значки.
class FeaturesScreen extends StatefulWidget {
  /// Открыт из превью: по готовности вернуться в превью.
  final bool editing;
  const FeaturesScreen({super.key, this.editing = false});

  @override
  State<FeaturesScreen> createState() => _FeaturesScreenState();
}

class _FeaturesScreenState extends State<FeaturesScreen> {
  late final List<String> _chosen;

  @override
  void initState() {
    super.initState();
    final d = context.read<AppState>().draft;
    _chosen = [
      for (final f in d.infographic.features)
        if (f.text.trim().isNotEmpty) f.text
    ];
    // Выбранные раньше (или старый пост без вариантов) — тоже в списке.
    for (final t in _chosen) {
      if (!d.featureIdeas.contains(t)) d.featureIdeas.add(t);
    }
  }

  void _toggle(String t) {
    setState(() {
      if (_chosen.contains(t)) {
        _chosen.remove(t);
      } else if (_chosen.length < kFeatureCount) {
        _chosen.add(t);
      } else {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(
              content: Text('Уже выбрано 3 — снимите одно, чтобы заменить')));
      }
    });
  }

  Future<void> _more() async {
    final s = context.read<AppState>();
    var n = 0;
    final ok = await runBusy(context, 'AI придумывает ещё…',
        () async => n = await s.moreFeatureIdeas());
    if (ok && mounted && n == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Новых вариантов не нашлось')));
    }
  }

  /// Свой вариант ([index] == null) или правка подписи варианта.
  Future<void> _edit([int? index]) async {
    final ideas = context.read<AppState>().draft.featureIdeas;
    final old = index == null ? '' : ideas[index];
    final ctrl = TextEditingController(text: old);
    final res = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(index == null ? 'Своё преимущество' : 'Подпись'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 40,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Защита от скачков'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('Отмена')),
          TextButton(
              onPressed: () => Navigator.pop(c, ctrl.text.trim()),
              child: const Text('Готово')),
        ],
      ),
    );
    ctrl.dispose();
    if (res == null || res.isEmpty || !mounted) return;
    setState(() {
      if (index == null) {
        if (!ideas.contains(res)) ideas.insert(0, res);
        if (!_chosen.contains(res) && _chosen.length < kFeatureCount) {
          _chosen.add(res);
        }
      } else {
        ideas[index] = res;
        final i = _chosen.indexOf(old);
        if (i >= 0) _chosen[i] = res;
      }
    });
  }

  Future<void> _next() async {
    final d = context.read<AppState>().draft;
    // Значок уже выбранного раньше преимущества предлагается как «Сейчас».
    final before = {for (final f in d.infographic.features) f.text: f.svg};
    final features = [
      for (final t in _chosen) Feature('bolt', t, [...?before[t]])
    ];
    final done = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
            builder: (_) =>
                IconsScreen(features: features, editing: widget.editing)));
    if (done == true && widget.editing && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final ideas = context.watch<AppState>().draft.featureIdeas;
    return Scaffold(
      appBar: AppBar(title: const Text('3. Преимущества')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Выберите 3 преимущества — они встанут внизу главного фото '
            'в том порядке, в каком вы нажимали.',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < ideas.length; i++) _idea(i, ideas[i]),
          const SizedBox(height: 4),
          OutlinedButton.icon(
            onPressed: _more,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Ещё варианты от AI'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _edit(),
            icon: const Icon(Icons.add),
            label: const Text('Добавить своё'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _chosen.length == kFeatureCount ? _next : null,
            child: Text(_chosen.length == kFeatureCount
                ? 'Далее — значки'
                : 'Выбрано ${_chosen.length} из $kFeatureCount'),
          ),
        ],
      ),
    );
  }

  Widget _idea(int i, String text) {
    final n = _chosen.indexOf(text);
    final on = n >= 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: on ? Brand.tint : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: on ? Brand.blue : Brand.border, width: 1.5),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _toggle(text),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
            child: Row(children: [
              CircleAvatar(
                radius: 15,
                backgroundColor: on ? Brand.blue : Brand.tint,
                child: on
                    ? Text('${n + 1}',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700))
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(text,
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: on ? FontWeight.w600 : FontWeight.w400))),
              IconButton(
                tooltip: 'Изменить подпись',
                icon: const Icon(Icons.edit_outlined, color: Brand.deep),
                onPressed: () => _edit(i),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
