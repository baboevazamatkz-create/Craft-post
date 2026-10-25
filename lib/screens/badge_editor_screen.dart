import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models/post_draft.dart';
import '../services/image/badges.dart';
import '../theme.dart';
import '../widgets/busy.dart';

/// Ручная правка плашек на одном фото. Точку тянут на деталь, плашку —
/// куда удобно (так задаются длина и направление стрелки). Выбранную
/// плашку можно настроить: размер, длина полки, длина и направление
/// стрелки, текст; «Авто» возвращает автоматическое место.
class BadgeEditorScreen extends StatefulWidget {
  final String path;
  const BadgeEditorScreen({super.key, required this.path});

  @override
  State<BadgeEditorScreen> createState() => _BadgeEditorScreenState();
}

enum _Drag { point, plaque }

class _BadgeEditorScreenState extends State<BadgeEditorScreen> {
  final _painter = BadgePainter();
  late List<PhotoBadge> _badges;
  Uint8List? _base; // фото с логотипом, но без плашек
  Size _imgSize = const Size(3, 4);
  Size _view = Size.zero; // размер картинки на экране
  int? _sel;
  int? _drag;
  _Drag _dragMode = _Drag.point;

  /// Угол стрелки к горизонтали для кнопок направления (тупой угол с полкой).
  static const _angle = 40 * math.pi / 180;

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

  List<BadgeBox> get _boxes => _painter.layout(_view, _badges);

  /// Что под пальцем: сначала точки (их легко перекрыть), потом плашки.
  (int, _Drag)? _hit(Offset pos) {
    final boxes = _boxes;
    for (var i = boxes.length - 1; i >= 0; i--) {
      if ((boxes[i].point - pos).distance < 24) return (i, _Drag.point);
    }
    for (var i = boxes.length - 1; i >= 0; i--) {
      if (boxes[i].plaque.inflate(10).contains(pos)) return (i, _Drag.plaque);
    }
    return null;
  }

  /// Переводит плашку в ручной режим с тем местом, где она сейчас стоит.
  void _pin(int i) {
    final b = _badges[i];
    if (b.manual) return;
    final box = _boxes[i];
    b.jx = (box.joint.dx - box.point.dx) / _view.width;
    b.jy = (box.joint.dy - box.point.dy) / _view.width;
  }

  double _arrowLength(int i) {
    final b = _badges[i];
    if (_view.width == 0) return 0.1;
    if (b.manual) return math.sqrt(b.jx! * b.jx! + b.jy! * b.jy!);
    final box = _boxes[i];
    return (box.joint - box.point).distance / _view.width;
  }

  void _setLength(int i, double len) {
    _pin(i);
    final b = _badges[i];
    final cur = math.sqrt(b.jx! * b.jx! + b.jy! * b.jy!);
    if (cur < 1e-6) {
      b
        ..jx = len * math.cos(_angle)
        ..jy = -len * math.sin(_angle);
    } else {
      b
        ..jx = b.jx! / cur * len
        ..jy = b.jy! / cur * len;
    }
  }

  /// Направление стрелки: [sx] — полка вправо (1) или влево (-1),
  /// [sy] — плашка ниже (1) или выше (-1) точки.
  void _setDirection(int i, int sx, int sy) {
    final len = math.max(_arrowLength(i), 0.06);
    _badges[i]
      ..jx = sx * len * math.cos(_angle)
      ..jy = sy * len * math.sin(_angle);
  }

  Future<void> _edit(int? i) async {
    final ctrl = TextEditingController(text: i == null ? '' : _badges[i].text);
    final res = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(i == null ? 'Новая плашка' : 'Текст плашки'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 40,
          textCapitalization: TextCapitalization.sentences,
          decoration:
              const InputDecoration(hintText: 'Кабель в одну линию по лазеру'),
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
      if (i == null) {
        _badges.add(PhotoBadge(res, 0.5, 0.55));
        _sel = _badges.length - 1;
      } else {
        _badges[i].text = res;
      }
    });
  }

  void _delete(int i) => setState(() {
        _badges.removeAt(i);
        _sel = null;
      });

  Future<void> _save() async {
    final s = context.read<AppState>();
    final ok = await runBusy(
        context, 'Обновляю фото…', () => s.updateBadges(widget.path, _badges));
    if (ok && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final sel = _sel != null && _sel! < _badges.length ? _sel : null;
    return Scaffold(
      appBar: AppBar(title: const Text('Плашки на фото')),
      body: Column(children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Center(
              child: _base == null
                  ? const CircularProgressIndicator()
                  : AspectRatio(
                      aspectRatio: _imgSize.width / _imgSize.height,
                      child: LayoutBuilder(builder: (context, c) {
                        _view = Size(c.maxWidth, c.maxHeight);
                        return _canvas(sel);
                      }),
                    ),
            ),
          ),
        ),
        if (sel == null)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Text(
              'Нажмите на плашку, чтобы настроить её. Точку тяните на '
              'деталь, плашку — куда удобно.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Brand.deep),
            ),
          )
        else
          _panel(sel),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
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

  Widget _canvas(int? sel) => GestureDetector(
        onTapUp: (d) => setState(() => _sel = _hit(d.localPosition)?.$1),
        onPanStart: (d) {
          final hit = _hit(d.localPosition);
          _drag = hit?.$1;
          _dragMode = hit?.$2 ?? _Drag.point;
          if (hit != null) {
            setState(() {
              _sel = hit.$1;
              if (_dragMode == _Drag.plaque) _pin(hit.$1);
            });
          }
        },
        onPanUpdate: (d) {
          final i = _drag;
          if (i == null) return;
          setState(() {
            final b = _badges[i];
            if (_dragMode == _Drag.point) {
              b.x = (b.x + d.delta.dx / _view.width).clamp(0.0, 1.0);
              b.y = (b.y + d.delta.dy / _view.height).clamp(0.0, 1.0);
            } else {
              b.jx = (b.jx! + d.delta.dx / _view.width).clamp(-1.0, 1.0);
              b.jy = (b.jy! + d.delta.dy / _view.width).clamp(-1.5, 1.5);
            }
          });
        },
        onPanEnd: (_) => _drag = null,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(fit: StackFit.expand, children: [
            Image.memory(_base!, fit: BoxFit.fill),
            CustomPaint(painter: _BadgesPainter(_painter, _badges, sel)),
          ]),
        ),
      );

  Widget _panel(int i) {
    final b = _badges[i];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Expanded(
            child: Text('«${b.text}»',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ),
          IconButton(
              tooltip: 'Изменить текст',
              icon: const Icon(Icons.edit_outlined, color: Brand.deep),
              onPressed: () => _edit(i)),
          IconButton(
              tooltip: 'Удалить плашку',
              icon: const Icon(Icons.delete_outline, color: Brand.deep),
              onPressed: () => _delete(i)),
        ]),
        _slider(
            'Размер', b.scale, 0.6, 1.6, (v) => setState(() => b.scale = v)),
        _slider('Полка', b.shelf, 0, 0.3, (v) => setState(() => b.shelf = v)),
        _slider('Стрелка', _arrowLength(i).clamp(0.02, 0.4), 0.02, 0.4,
            (v) => setState(() => _setLength(i, v))),
        Row(children: [
          const SizedBox(
              width: 72,
              child: Text('Куда', style: TextStyle(color: Brand.deep))),
          for (final (sx, sy, icon) in [
            (-1, -1, Icons.north_west),
            (1, -1, Icons.north_east),
            (-1, 1, Icons.south_west),
            (1, 1, Icons.south_east),
          ])
            IconButton(
              tooltip: 'Плашка ${sy < 0 ? 'выше' : 'ниже'}, '
                  '${sx > 0 ? 'справа' : 'слева'}',
              icon: Icon(icon, color: Brand.blue),
              onPressed: () => setState(() => _setDirection(i, sx, sy)),
            ),
          const Spacer(),
          TextButton(
            onPressed: b.manual
                ? () => setState(() => b
                  ..jx = null
                  ..jy = null)
                : null,
            child: const Text('Авто'),
          ),
        ]),
      ]),
    );
  }

  Widget _slider(String label, double value, double min, double max,
          ValueChanged<double> onChanged) =>
      SizedBox(
        height: 40,
        child: Row(children: [
          SizedBox(
              width: 72,
              child: Text(label, style: const TextStyle(color: Brand.deep))),
          Expanded(
            child: Slider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                onChanged: onChanged),
          ),
        ]),
      );
}

class _BadgesPainter extends CustomPainter {
  final BadgePainter painter;
  final List<PhotoBadge> badges;
  final int? selected;
  _BadgesPainter(this.painter, this.badges, this.selected);

  @override
  void paint(Canvas canvas, Size size) {
    final boxes = painter.layout(size, badges);
    painter.paint(canvas, size, badges, boxes: boxes, minStroke: 0.7);
    final i = selected;
    if (i == null || i >= boxes.length) return;
    // Выбранная плашка — в голубой рамке, её точка — в кольце.
    final mark = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = Brand.sky;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            boxes[i].plaque.inflate(4), const Radius.circular(4)),
        mark);
    canvas.drawCircle(boxes[i].point, 9, mark);
  }

  @override
  bool shouldRepaint(_BadgesPainter old) => true;
}
