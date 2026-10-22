import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models/post_draft.dart';
import '../services/image/badges.dart';
import '../theme.dart';
import '../widgets/busy.dart';

/// Ручная правка плашек на одном фото: перетащить, изменить текст,
/// удалить, добавить свою.
class BadgeEditorScreen extends StatefulWidget {
  final String path;
  const BadgeEditorScreen({super.key, required this.path});

  @override
  State<BadgeEditorScreen> createState() => _BadgeEditorScreenState();
}

class _BadgeEditorScreenState extends State<BadgeEditorScreen> {
  final _painter = BadgePainter();
  late List<PhotoBadge> _badges;
  Uint8List? _base; // фото с логотипом, но без плашек
  Size _imgSize = const Size(3, 4);
  int? _drag;

  @override
  void initState() {
    super.initState();
    final s = context.read<AppState>();
    _badges = [for (final b in s.draft.badgesOf(widget.path)) b.copy()];
    _loadBase(s);
  }

  Future<void> _loadBase(AppState s) async {
    final bytes = await s.processor.renderOther(widget.path,
        maxSide: kPreviewSide, quality: 80, withBadges: false);
    final img = await decodeImageFromList(bytes);
    if (!mounted) return;
    setState(() {
      _base = bytes;
      _imgSize = Size(img.width.toDouble(), img.height.toDouble());
    });
  }

  int? _hit(Offset pos, Size size) {
    final boxes = _painter.layout(size, _badges);
    for (var i = boxes.length - 1; i >= 0; i--) {
      if (boxes[i].plaque.inflate(8).contains(pos) ||
          (boxes[i].point - pos).distance < 28) {
        return i;
      }
    }
    return null;
  }

  Future<void> _edit(int? i) async {
    final ctrl = TextEditingController(text: i == null ? '' : _badges[i].text);
    final res = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(i == null ? 'Новая плашка' : 'Плашка'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 40,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Ровная укладка кабеля'),
        ),
        actions: [
          if (i != null)
            TextButton(
                onPressed: () => Navigator.pop(c, '\u0000'),
                child: const Text('Удалить')),
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('Отмена')),
          TextButton(
              onPressed: () => Navigator.pop(c, ctrl.text.trim()),
              child: const Text('Готово')),
        ],
      ),
    );
    ctrl.dispose();
    if (res == null || !mounted) return;
    setState(() {
      if (res == '\u0000') {
        _badges.removeAt(i!);
      } else if (res.isNotEmpty) {
        if (i == null) {
          _badges.add(PhotoBadge(res, 0.5, 0.55));
        } else {
          _badges[i].text = res;
        }
      }
    });
  }

  Future<void> _save() async {
    final s = context.read<AppState>();
    final ok = await runBusy(
        context, 'Обновляю фото…', () => s.updateBadges(widget.path, _badges));
    if (ok && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Плашки на фото')),
      body: Column(children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Center(
              child: _base == null
                  ? const CircularProgressIndicator()
                  : AspectRatio(
                      aspectRatio: _imgSize.width / _imgSize.height,
                      child: LayoutBuilder(builder: (context, c) {
                        final size = Size(c.maxWidth, c.maxHeight);
                        return GestureDetector(
                          onTapUp: (d) {
                            final i = _hit(d.localPosition, size);
                            if (i != null) _edit(i);
                          },
                          onPanStart: (d) =>
                              _drag = _hit(d.localPosition, size),
                          onPanUpdate: (d) {
                            final i = _drag;
                            if (i == null) return;
                            setState(() {
                              final b = _badges[i];
                              b.x = (b.x + d.delta.dx / size.width)
                                  .clamp(0.0, 1.0);
                              b.y = (b.y + d.delta.dy / size.height)
                                  .clamp(0.0, 1.0);
                            });
                          },
                          onPanEnd: (_) => _drag = null,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Stack(fit: StackFit.expand, children: [
                              Image.memory(_base!, fit: BoxFit.fill),
                              CustomPaint(
                                  painter: _BadgesPainter(_painter, _badges)),
                            ]),
                          ),
                        );
                      }),
                    ),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Перетащите плашку на нужную деталь. '
            'Нажмите на неё, чтобы изменить текст или удалить.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Brand.deep),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _badges.length >= 6 ? null : () => _edit(null),
                icon: const Icon(Icons.add),
                label: const Text('Плашка'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                  onPressed: _base == null ? null : _save,
                  child: const Text('Готово')),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _BadgesPainter extends CustomPainter {
  final BadgePainter painter;
  final List<PhotoBadge> badges;
  _BadgesPainter(this.painter, this.badges);

  @override
  void paint(Canvas canvas, Size size) =>
      painter.paint(canvas, size, badges, minStroke: 0.7);

  @override
  bool shouldRepaint(_BadgesPainter old) => true;
}
