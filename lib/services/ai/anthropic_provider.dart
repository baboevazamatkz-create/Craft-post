import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../models/post_draft.dart';
import 'ai_provider.dart';

class AnthropicProvider implements AiProvider {
  final String apiKey;
  final String model;
  AnthropicProvider(this.apiKey, {this.model = 'claude-sonnet-4-5'});

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
            'content-type': 'application/json',
          },
          body: jsonEncode({
            'model': model,
            'max_tokens': 1024,
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
        .timeout(const Duration(seconds: 60));
    if (resp.statusCode != 200) {
      throw Exception('AI: ошибка ${resp.statusCode}');
    }
    final body = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    final text = (body['content'] as List).map((c) => c['text'] ?? '').join();
    return parseAiJson(text);
  }
}
