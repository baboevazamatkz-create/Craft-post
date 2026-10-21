import 'dart:typed_data';

import 'package:gal/gal.dart';

class GallerySaver {
  static const album = 'CRAFT SYSTEM';

  Future<bool> ensureAccess() async {
    if (await Gal.hasAccess(toAlbum: true)) return true;
    return Gal.requestAccess(toAlbum: true);
  }

  Future<void> save(Uint8List jpeg, String name) =>
      Gal.putImageBytes(jpeg, album: album, name: name);
}
