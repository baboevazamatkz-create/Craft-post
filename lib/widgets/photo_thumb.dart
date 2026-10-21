import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../theme.dart';

/// Миниатюра исходного фото по ссылке (работает и на телефоне, и в браузере).
class PhotoThumb extends StatefulWidget {
  final String ref;
  final double? width, height;
  final int cacheWidth;
  const PhotoThumb(this.ref,
      {super.key, this.width, this.height, this.cacheWidth = 400});

  @override
  State<PhotoThumb> createState() => _PhotoThumbState();
}

class _PhotoThumbState extends State<PhotoThumb> {
  late Future<Uint8List> _bytes = _load();

  Future<Uint8List> _load() =>
      context.read<AppState>().store.readPhoto(widget.ref);

  @override
  void didUpdateWidget(PhotoThumb old) {
    super.didUpdateWidget(old);
    if (old.ref != widget.ref) _bytes = _load();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
        future: _bytes,
        builder: (_, snap) => snap.hasData
            ? Image.memory(snap.data!,
                width: widget.width,
                height: widget.height,
                fit: BoxFit.cover,
                cacheWidth: widget.cacheWidth,
                gaplessPlayback: true)
            : Container(
                width: widget.width, height: widget.height, color: Brand.tint),
      );
}
