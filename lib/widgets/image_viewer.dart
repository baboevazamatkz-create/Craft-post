import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Полноэкранный просмотр с увеличением (щипок, двойной тап) и листанием.
Future<void> openViewer(
    BuildContext context, List<Uint8List> images, int initial) {
  return Navigator.push(
    context,
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _Viewer(images: images, initial: initial),
    ),
  );
}

class _Viewer extends StatefulWidget {
  final List<Uint8List> images;
  final int initial;
  const _Viewer({required this.images, required this.initial});

  @override
  State<_Viewer> createState() => _ViewerState();
}

class _ViewerState extends State<_Viewer> {
  late final PageController _pages =
      PageController(initialPage: widget.initial);
  late int _index = widget.initial;
  final _zoom = <int, TransformationController>{};
  bool _zoomed = false;

  TransformationController _ctrl(int i) =>
      _zoom.putIfAbsent(i, TransformationController.new);

  @override
  void dispose() {
    _pages.dispose();
    for (final c in _zoom.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _toggleZoom(int i, TapDownDetails d) {
    final c = _ctrl(i);
    if (c.value.getMaxScaleOnAxis() > 1.01) {
      c.value = Matrix4.identity();
    } else {
      const k = 2.5;
      final p = d.localPosition;
      c.value = Matrix4.identity()
        ..translateByDouble(-p.dx * (k - 1), -p.dy * (k - 1), 0, 1)
        ..scaleByDouble(k, k, 1, 1);
    }
    setState(() => _zoomed = c.value.getMaxScaleOnAxis() > 1.01);
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.images.length;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        PageView.builder(
          controller: _pages,
          physics: _zoomed
              ? const NeverScrollableScrollPhysics()
              : const PageScrollPhysics(),
          itemCount: n,
          onPageChanged: (i) => setState(() {
            _index = i;
            _zoomed = false;
            for (final c in _zoom.values) {
              c.value = Matrix4.identity();
            }
          }),
          itemBuilder: (_, i) {
            TapDownDetails? tap;
            return GestureDetector(
              onDoubleTapDown: (d) => tap = d,
              onDoubleTap: () => _toggleZoom(i, tap!),
              child: InteractiveViewer(
                transformationController: _ctrl(i),
                minScale: 1,
                maxScale: 6,
                onInteractionEnd: (_) => setState(
                    () => _zoomed = _ctrl(i).value.getMaxScaleOnAxis() > 1.01),
                child: Center(
                    child: Image.memory(widget.images[i], fit: BoxFit.contain)),
              ),
            );
          },
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(children: [
              IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: Colors.black54),
                iconSize: 28,
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
              const Spacer(),
              if (n > 1)
                Text('${_index + 1} / $n',
                    style: const TextStyle(color: Colors.white, fontSize: 18)),
              const SizedBox(width: 12),
            ]),
          ),
        ),
      ]),
    );
  }
}
