import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../models/post_draft.dart';
import 'ai_provider.dart';

/// Подходит и для OpenAI-совместимых API (поменять [baseUrl] и [model]).
class OpenAiProvider implements AiProvider {
  final String apiKey;
  final String model;
  final String baseUrl;
  OpenAiProvider(this.apiKey,
      {this.model = 'gpt-4o-mini', this.baseUrl = 'https://api.openai.com/v1'});

  @override
  String get id => 'openai';
  @override
  String get title => 'OpenAI (GPT)';

  @override
  Future<AiResult> generate({
    required Uint8List mainPhotoJpeg,
    required Map<String, String> fields,
    required List<Feature> features,
  }) async {
    if (apiKey.isEmpty) throw Exception('Не задан API-ключ (Настройки)');
    final resp = await http
        .post(
          Uri.parse('$baseUrl/chat/completions'),
          headers: {
            'authorization': 'Bearer $apiKey',
            'content-type': 'application/json',
          },
          body: jsonEncode({
            'model': model,
            'messages': [
              {'role': 'system', 'content': kSystemPrompt},
              {
                'role': 'user',
                'content': [
                  {
                    'type': 'image_url',
                    'image_url': {
                      'url':
                          'data:image/jpeg;base64,${base64Encode(mainPhotoJpeg)}'
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
    final body =
        jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    return parseAiJson(body['choices'][0]['message']['content'] as String);
  }
}
