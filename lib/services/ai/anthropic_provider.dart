import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'ai_provider.dart';

class AnthropicProvider extends ChatAiProvider {
  final String apiKey;
  final String model;
  AnthropicProvider(this.apiKey, {this.model = 'claude-opus-5-5'});

  @override
  String get id => 'anthropic';
  @override
  String get title => 'Claude (Anthropic)';

  @override
  Future<String> ask({
    required String system,
    required String text,
    required List<Uint8List> images,
    List<String>? labels,
    String effort = 'medium',
    bool cacheSystem = false,
  }) async {
    if (apiKey.trim().isEmpty) {
      throw Exception(
          'Не введён API-ключ. Откройте ⚙ Настройки и вставьте ключ.');
    }
    final content = [
      for (var i = 0; i < images.length; i++) ...[
        if (labels != null && i < labels.length)
          {'type': 'text', 'text': labels[i]},
        {
          'type': 'image',
          'source': {
            'type': 'base64',
            'media_type': 'image/jpeg',
            'data': base64Encode(images[i]),
          },
        },
      ],
      {'type': 'text', 'text': text},
    ];
    // Длинный постоянный системный текст (список значков) кэшируется.
    final Object sys = cacheSystem
        ? [
            {
              'type': 'text',
              'text': system,
              'cache_control': {'type': 'ephemeral'},
            }
          ]
        : system;
    var body = await _post(sys, content, effort);
    // Если рассуждения не уместились в лимит — повторяем с меньшим усилием.
    if (body['stop_reason'] == 'max_tokens' && effort != 'low') {
      body = await _post(sys, content, 'low');
    }
    if (body['stop_reason'] == 'refusal') {
      throw Exception('AI отказался обработать это фото. Попробуйте другое.');
    }
    if (body['stop_reason'] == 'max_tokens') {
      throw Exception('AI не уложился в ответ. Попробуйте ещё раз.');
    }
    return (body['content'] as List)
        .where((c) => c['type'] == 'text')
        .map((c) => c['text'] as String)
        .join();
  }

  Future<Map<String, dynamic>> _post(
      Object system, List<Map<String, Object>> content, String effort) async {
    final resp = await http
        .post(
          Uri.parse('https://api.anthropic.com/v1/messages'),
          headers: {
            'x-api-key': apiKey,
            'anthropic-version': '2023-06-01',
            // Если модель откажет по правилам безопасности, сервер сам
            // повторит запрос на рекомендованной запасной модели.
            'anthropic-beta': 'server-side-fallback-2026-07-01',
            'content-type': 'application/json',
            // В браузере Anthropic требует явного согласия на прямой доступ
            // (ключ пользователя хранится только в его браузере).
            if (kIsWeb) 'anthropic-dangerous-direct-browser-access': 'true',
          },
          body: jsonEncode({
            'model': model,
            'max_tokens': 16000,
            'output_config': {'effort': effort},
            'fallbacks': 'default',
            'system': system,
            'messages': [
              {'role': 'user', 'content': content}
            ],
          }),
        )
        .timeout(const Duration(seconds: 180));
    final body =
        jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    if (resp.statusCode != 200) {
      throw Exception(_errorText(resp.statusCode, body));
    }
    return body;
  }

  static String _errorText(int status, Map<String, dynamic> body) {
    final msg = '${(body['error'] as Map?)?['message'] ?? ''}';
    if (status == 401) return 'Неверный API-ключ. Проверьте его в Настройках.';
    if (status == 400 && msg.toLowerCase().contains('credit')) {
      return 'На счёте Anthropic закончились средства. Пополните баланс в console.anthropic.com.';
    }
    if (status == 429) {
      return 'Слишком много запросов. Подождите минуту и повторите.';
    }
    if (status >= 500) return 'Сервис AI временно недоступен. Повторите позже.';
    return 'AI: ошибка $status. $msg';
  }
}
