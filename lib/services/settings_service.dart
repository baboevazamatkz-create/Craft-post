import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Хранит ключ AI и выбранного провайдера на устройстве.
class SettingsService {
  static const _storage = FlutterSecureStorage();
  static const _kKey = 'ai_api_key';
  static const _kProvider = 'ai_provider';

  Future<String> apiKey() async => await _storage.read(key: _kKey) ?? '';
  Future<void> setApiKey(String v) =>
      _storage.write(key: _kKey, value: v.trim());

  Future<String> provider() async =>
      await _storage.read(key: _kProvider) ?? 'anthropic';
  Future<void> setProvider(String v) =>
      _storage.write(key: _kProvider, value: v);
}
