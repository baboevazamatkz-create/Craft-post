import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

import '../../models/post_draft.dart';
import 'template.dart';

/// Вся обработка фото на устройстве. `maxSide == null` — полное разрешение.
class ImageProcessor {
  final InfographicTemplate template;
  final LogoPlacement logoPlacement;
  ui.Image? _logo;

  ImageProcessor({
    InfographicTemplate? template,
    this.logoPlacement = const LogoPlacement(),
  }) : template = template ?? InfographicTemplate();

  Future<ui.Image> _decode(String path) async {
    final bytes = await File(path).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  Future<ui.Image> _loadLogo() async {
    if (_logo != null) return _logo!;
    final data = await rootBundle.load('assets/logo.png');
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    _logo = (await codec.getNextFrame()).image;
    return _logo!;
  }

  Size _target(ui.Image src, int? maxSide) {
    final w = src.width.toDouble();
    final h = src.height.toDouble();
    if (maxSide == null) return Size(w, h);
    final k = math.min(1.0, maxSide / math.max(w, h));
    return Size((w * k).roundToDouble(), (h * k).roundToDouble());
  }

  Future<ui.Image> _draw(
    String path,
    int? maxSide,
    Future<void> Function(ui.Canvas canvas, Size size) overlay,
  ) async {
    final src = await _decode(path);
    final size = _target(src, maxSide);
    final rec = ui.PictureRecorder();
    final canvas = ui.Canvas(rec);
    canvas.drawImageRect(
      src,
      ui.Rect.fromLTWH(0, 0, src.width.toDouble(), src.height.toDouble()),
      ui.Rect.fromLTWH(0, 0, size.width, size.height),
      ui.Paint()..filterQuality = ui.FilterQuality.high,
    );
    await overlay(canvas, size);
    final out = await rec
        .endRecording()
        .toImage(size.width.toInt(), size.height.toInt());
    src.dispose();
    return out;
  }

  Future<Uint8List> _toJpeg(ui.Image image, int quality) async {
    final bd = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final w = image.width, h = image.height;
    image.dispose();
    return compute(
        _encodeJpg, _JpgJob(bd!.buffer.asUint8List(), w, h, quality));
  }

  /// Главное фото с инфографикой.
  Future<Uint8List> renderMain(String path, InfographicText t,
      {int? maxSide, int quality = 92}) async {
    final logo = await _loadLogo();
    final image = await _draw(path, maxSide, (c, s) async {
      template.paint(c, s, t);
      _drawLogo(c, s, logo);
    });
    return _toJpeg(image, quality);
  }

  /// Остальные фото с логотипом.
  Future<Uint8List> renderOther(String path,
      {int? maxSide, int quality = 92}) async {
    final logo = await _loadLogo();
    final image = await _draw(path, maxSide, (c, s) async {
      paintCornerShade(c, s);
      _drawLogo(c, s, logo);
    });
    return _toJpeg(image, quality);
  }

  /// Логотип как в макете: непрозрачность 60% и тёмное размытое свечение вокруг
  /// (под самим логотипом свечения нет). Параметры подобраны по замеру готового поста.
  void _drawLogo(ui.Canvas c, Size s, ui.Image logo) {
    final lw = logo.width.toDouble(), lh = logo.height.toDouble();
    final src = ui.Rect.fromLTWH(0, 0, lw, lh);
    final dst = logoPlacement.rect(s, Size(lw, lh));
    final sigma = dst.width * 0.0356;
    final bounds = dst.inflate(sigma * 4);
    final hq = ui.Paint()..filterQuality = ui.FilterQuality.high;

    // Тень: силуэт → размытие → усиление до 150% (чёрным) → вырез по логотипу.
    c.saveLayer(bounds, ui.Paint());
    c.saveLayer(
      bounds,
      ui.Paint()
        ..colorFilter = const ui.ColorFilter.matrix(<double>[
          0, 0, 0, 0, 0, //
          0, 0, 0, 0, 0,
          0, 0, 0, 0, 0,
          0, 0, 0, 1.5, 0,
        ]),
    );
    c.saveLayer(
        bounds,
        ui.Paint()
          ..imageFilter = ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma));
    c.drawImageRect(logo, src, dst, hq);
    c.restore();
    c.restore();
    c.drawImageRect(
      logo,
      src,
      dst,
      ui.Paint()
        ..filterQuality = ui.FilterQuality.high
        ..blendMode = ui.BlendMode.dstOut,
    );
    c.restore();

    c.drawImageRect(
      logo,
      src,
      dst,
      ui.Paint()
        ..filterQuality = ui.FilterQuality.high
        ..color = const ui.Color.fromRGBO(255, 255, 255, 0.6),
    );
  }

  /// Маленький JPEG без наложений — для отправки в AI.
  Future<Uint8List> aiPhoto(String path) async {
    final image = await _draw(path, 1024, (c, s) async {});
    return _toJpeg(image, 80);
  }
}

class _JpgJob {
  final Uint8List rgba;
  final int w, h, quality;
  _JpgJob(this.rgba, this.w, this.h, this.quality);
}

Uint8List _encodeJpg(_JpgJob j) {
  final im = img.Image.fromBytes(
    width: j.w,
    height: j.h,
    bytes: j.rgba.buffer,
    numChannels: 4,
  );
  return Uint8List.fromList(img.encodeJpg(im, quality: j.quality));
}
