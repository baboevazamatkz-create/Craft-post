import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../theme.dart';
import '../widgets/image_viewer.dart';

/// Согласование по одной картинке на весь экран, начиная с главной.
/// Свайп вправо — в сохранение (фоном), свайп влево — оставить.
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  late List<int> _order;
  final _kept = <int>[];
  int _pos = 0;
  int _round = 0;

  static const _green = Color(0xFF2E9E5B);

  @override
  void initState() {
    super.initState();
    final s = context.read<AppState>();
    _order = [
      for (var i = 0; i < s.draft.imageCount; i++)
        if (s.saveStates[i] != SaveState.saved) i
    ];
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _decide(bool save) {
    final i = _order[_pos];
    if (save) {
      context.read<AppState>().approve(i);
    } else {
      _kept.add(i);
    }
    HapticFeedback.selectionClick();
    setState(() => _pos++);
  }

  void _reviewKept() {
    setState(() {
      _order = List.of(_kept);
      _kept.clear();
      _pos = 0;
      _round++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final done = _pos >= _order.length;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(children: [
          _topBar(s, done),
          Expanded(child: done ? _summary(s) : _card(s)),
          if (!done) _buttons(),
        ]),
      ),
    );
  }

  Widget _topBar(AppState s, bool done) {
    final active = s.countState({SaveState.queued, SaveState.saving});
    final saved = s.countState({SaveState.saved});
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
      child: Row(children: [
        IconButton(
          iconSize: 28,
          color: Colors.white,
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
        ),
        Text(
          done ? 'Готово' : 'Фото ${_pos + 1} из ${_order.length}',
          style: const TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const Spacer(),
        if (active > 0) ...[
          const SizedBox(
              width: 16,
              height: 16,
              child:
                  CircularProgressIndicator(strokeWidth: 2, color: Brand.sky)),
          const SizedBox(width: 8),
          Text('сохраняю $active',
              style: const TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(width: 12),
        ],
        Icon(Icons.check_circle,
            color: saved > 0 ? _green : Colors.white24, size: 20),
        const SizedBox(width: 4),
        Text('$saved', style: const TextStyle(color: Colors.white70)),
      ]),
    );
  }

  Widget _card(AppState s) {
    final i = _order[_pos];
    final previews = s.draft.previews;
    return Dismissible(
      key: ValueKey('card_${_round}_$i'),
      direction: DismissDirection.horizontal,
      dismissThresholds: const {
        DismissDirection.startToEnd: 0.25,
        DismissDirection.endToStart: 0.25,
      },
      onDismissed: (dir) => _decide(dir == DismissDirection.startToEnd),
      background:
          _hint(Alignment.centerLeft, _green, Icons.download_done, 'Сохранить'),
      secondaryBackground: _hint(Alignment.centerRight, const Color(0xFF3A4752),
          Icons.pan_tool_alt_outlined, 'Оставить'),
      child: GestureDetector(
        onTap: () => openViewer(context, previews, i),
        child: Container(
          color: Colors.black,
          alignment: Alignment.center,
          child: Stack(children: [
            Image.memory(previews[i], fit: BoxFit.contain),
            if (i == 0)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: Brand.blue,
                      borderRadius: BorderRadius.circular(20)),
                  child: const Text('Главное',
                      style: TextStyle(color: Colors.white, fontSize: 13)),
                ),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _hint(Alignment a, Color c, IconData icon, String text) => Container(
        color: c,
        alignment: a,
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: Colors.white, size: 56),
          const SizedBox(height: 8),
          Text(text,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700)),
        ]),
      );

  Widget _buttons() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text('Свайп вправо — сохранить, влево — оставить',
                style: TextStyle(color: Colors.white54, fontSize: 14)),
          ),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white38),
                ),
                onPressed: () => _decide(false),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Оставить'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: _green),
                onPressed: () => _decide(true),
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Сохранить'),
              ),
            ),
          ]),
        ]),
      );

  Widget _summary(AppState s) {
    final total = s.draft.imageCount;
    final saved = s.countState({SaveState.saved});
    final active = s.countState({SaveState.queued, SaveState.saving});
    final failed = s.countState({SaveState.error});
    const white = TextStyle(color: Colors.white, fontSize: 17);
    return ListView(padding: const EdgeInsets.all(20), children: [
      Text('Сохранено в галерею: $saved из $total',
          style: white.copyWith(fontSize: 22, fontWeight: FontWeight.w700)),
      const SizedBox(height: 12),
      if (active > 0) ...[
        LinearProgressIndicator(
            minHeight: 8, value: total == 0 ? 0 : saved / total),
        const SizedBox(height: 8),
        Text('Ещё сохраняется: $active (можно не ждать)', style: white),
      ],
      if (failed > 0) ...[
        const SizedBox(height: 8),
        Text('Ошибки: $failed. ${s.lastSaveError ?? ''}',
            style: const TextStyle(color: Colors.redAccent, fontSize: 16)),
      ],
      if (_kept.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text('Оставлено: ${_kept.length}', style: white),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _reviewKept,
          child: const Text('Пройти оставленные ещё раз'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () {
            for (final i in _kept) {
              s.approve(i);
            }
            setState(_kept.clear);
          },
          child: const Text('Сохранить оставленные'),
        ),
      ],
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: () {
          Clipboard.setData(ClipboardData(text: s.draft.caption));
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Подпись скопирована')));
        },
        icon: const Icon(Icons.copy),
        label: const Text('Скопировать подпись'),
      ),
      const SizedBox(height: 12),
      OutlinedButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Вернуться к правкам'),
      ),
      const SizedBox(height: 12),
      FilledButton(
        onPressed: () {
          s.reset();
          Navigator.popUntil(context, (r) => r.isFirst);
        },
        child: const Text('Новый пост'),
      ),
      const SizedBox(height: 12),
      const Text('Пост сохранён в истории приложения.',
          style: TextStyle(color: Colors.white54, fontSize: 14)),
    ]);
  }
}
