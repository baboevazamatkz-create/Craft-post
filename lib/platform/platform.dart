// Платформенные части: телефон (dart:io) или браузер (web).
export 'platform_io.dart' if (dart.library.js_interop) 'platform_web.dart';
