import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../models/post_draft.dart';
import 'ai_provider.dart';

class AnthropicProvider implements AiProvider {
  final String apiKey;
  final String model;
  AnthropicProvider(this.apiKey, {this.model = 'claude-opus-5-5'});

  @override
  String get id => 'anthropic';
  @override
  String get title => 'Claude (Anthropic)';

  @override
  Future<AiResult> generate({
    required Uint8List mainPhotoJpeg,
    required Map<String, String> fields,
    required List<Feature> features,
  }) async {
    if (apiKey.isEmpty) throw Exception('Не задан API-ключ (Настройки)');
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
          },
          body: jsonEncode({
            'model': model,
            'max_tokens': 16000,
            'output_config': {'effort': 'medium'},
            'fallbacks': 'default',
            'system': kSystemPrompt,
            'messages': [
              {
                'role': 'user',
                'content': [
                  {
                    'type': 'image',
                    'source': {
                      'type': 'base64',
                      'media_type': 'image/jpeg',
                      'data': base64Encode(mainPhotoJpeg),
                    },
                  },
                  {'type': 'text', 'text': fieldsToText(fields, features)},
                ],
              }
            ],
          }),
        )
        .timeout(const Duration(seconds: 120));
    final body =
        jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    if (resp.statusCode != 200) {
      throw Exception(_errorText(resp.statusCode, body));
    }
    if (body['stop_reason'] == 'refusal') {
      throw Exception('AI отказался обработать это фото. Попробуйте другое.');
    }
    final text = (body['content'] as List)
        .where((c) => c['type'] == 'text')
        .map((c) => c['text'] as String)
        .join();
    return parseAiJson(text);
  }

  static String _errorText(int status, Map<String, dynamic> body) {
    final msg = '${(body['error'] as Map?)?['message'] ?? ''}';
    if (status == 401) return 'Неверный API-ключ. Проверьте его в Настройках.';
    if (status == 400 && msg.toLowerCase().contains('credit')) {
      return 'На счёте Anthropic закончились средства. Пополните баланс в console.anthropic.com.';
    }
    if (status == 429)
      return 'Слишком много запросов. Подождите минуту и повторите.';
    if (status >= 500) return 'Сервис AI временно недоступен. Повторите позже.';
    return 'AI: ошибка $status. $msg';
  }
}
