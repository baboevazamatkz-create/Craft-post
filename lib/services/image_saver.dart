import 'dart:typed_data';

/// Куда уходят готовые фото: галерея телефона или «Загрузки» браузера.
abstract class ImageSaver {
  /// Подпись для интерфейса: «в галерею» / «в загрузки».
  String get target;
  Future<bool> ensureAccess();
  Future<void> save(Uint8List jpeg, String name);
}
