import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models/icon_library.dart';
import '../models/post_draft.dart';
import '../services/ai/ai_provider.dart';
import '../theme.dart';
import '../widgets/busy.dart';
import '../widgets/image_viewer.dart';
import '../widgets/line_icon_view.dart';

/// AI-редактор главного фото: варианты значков (и подписей) на выбор.
class AiIconsScreen extends StatefulWidget {
  const AiIconsScreen({super.key});

  @override
  State<AiIconsScreen> createState() => _AiIconsScreenState();
}

class _AiIconsScreenState extends State<AiIconsScreen> {
  final _wish = TextEditingController();
  IconIdeas? _ideas;
  // Выбор по каждому преимуществу: -1 — оставить текущий значок.
  List<int> _pick = [];
  List<bool> _newText = [];
  bool _newTitle = false, _newSubtitle = false;

  static const _quick = [
    'Интереснее и детальнее',
    'Совсем другие идеи',
    'Проще и чище',
    'Короче подписи',
  ];

  @override
  void dispose() {
    _wish.dispose();
    super.dispose();
  }

  List<String> _currentPaths(Feature f) =>
      f.svg.isNotEmpty ? f.svg : iconByKey(f.icon).paths;

  Future<void> _suggest() async {
    final s = context.read<AppState>();
    IconIdeas? res;
    final ok = await runBusy(context, 'AI рисует значки… обычно до минуты',
        () async => res = await s.suggestIcons(_wish.text));
    if (!ok || res == null || !mounted) return;
    final cur = s.draft.infographic;
    setState(() {
      _ideas = res;
      _pick = [
        for (final f in res!.features) f.variants.isEmpty ? -1 : 0,
      ];
      _newText = [
        for (var i = 0; i < res!.features.length; i++)
          res!.features[i].text != cur.features[i].text
      ];
      _newTitle = res!.title != null && res!.title != cur.title;
      _newSubtitle = res!.subtitle != null && res!.subtitle != cur.subtitle;
    });
  }

  Future<void> _apply() async {
    final s = context.read<AppState>();
    final ideas = _ideas!;
    final t = s.draft.infographic;
    for (var i = 0; i < t.features.length && i < ideas.features.length; i++) {
      final idea = ideas.features[i];
      if (_pick[i] >= 0) t.features[i].svg = idea.variants[_pick[i]];
      if (_newText[i]) t.features[i].text = idea.text;
    }
    if (_newTitle) t.title = ideas.title!;
    if (_newSubtitle) t.subtitle = ideas.subtitle!;
    final ok = await runBusy(context, 'Обновляю превью…', s.refreshPreviews);
    if (ok && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final d = s.draft;
    final ideas = _ideas;
    return Scaffold(
      appBar: AppBar(title: const Text('AI: значки главного фото')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (d.mainPreview != null)
            Center(
              child: GestureDetector(
                onTap: () => openViewer(context, d.previews, 0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(d.mainPreview!, height: 240),
                ),
              ),
            ),
          const SizedBox(height: 16),
          TextField(
            controller: _wish,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Пожелание (необязательно)',
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
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _suggest,
            icon: const Icon(Icons.auto_awesome),
            label: Text(ideas == null ? 'Предложить варианты' : 'Ещё варианты'),
          ),
          if (ideas != null) ...[
            const SizedBox(height: 20),
            for (var i = 0; i < d.infographic.features.length; i++)
              _featureBlock(i, d.infographic.features[i], ideas),
            if (ideas.title != null && ideas.title != d.infographic.title)
              _switch('Новый заголовок: «${ideas.title}»', _newTitle,
                  (v) => setState(() => _newTitle = v)),
            if (ideas.subtitle != null &&
                ideas.subtitle != d.infographic.subtitle)
              _switch('Новый подзаголовок: «${ideas.subtitle}»', _newSubtitle,
                  (v) => setState(() => _newSubtitle = v)),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _apply,
              child: const Text('Применить и обновить превью'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _featureBlock(int i, Feature f, IconIdeas ideas) {
    final idea = i < ideas.features.length ? ideas.features[i] : null;
    final variants = idea?.variants ?? const <List<String>>[];
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${i + 1}. ${f.text}',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _tile(_currentPaths(f), 'Сейчас', _pick[i] == -1,
                () => setState(() => _pick[i] = -1)),
            for (var v = 0; v < variants.length; v++)
              _tile(variants[v], 'Вариант ${v + 1}', _pick[i] == v,
                  () => setState(() => _pick[i] = v)),
          ]),
        ),
        if (variants.isEmpty)
          const Text('AI не прислал корректных вариантов',
              style: TextStyle(color: Brand.deep)),
        if (idea != null && idea.text != f.text)
          _switch('Новая подпись: «${idea.text}»', _newText[i],
              (v) => setState(() => _newText[i] = v)),
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

  Widget _switch(String text, bool value, ValueChanged<bool> onChanged) =>
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(text, style: const TextStyle(fontSize: 15)),
        value: value,
        onChanged: onChanged,
      );
}
