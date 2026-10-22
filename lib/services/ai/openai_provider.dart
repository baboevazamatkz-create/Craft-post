import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'ai_provider.dart';

/// Подходит и для OpenAI-совместимых API (поменять [baseUrl] и [model]).
class OpenAiProvider extends ChatAiProvider {
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
  Future<String> ask({
    required String system,
    required String text,
    required List<Uint8List> images,
    List<String>? labels,
    String effort = 'medium',
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
              {'role': 'system', 'content': system},
              {
                'role': 'user',
                'content': [
                  for (var i = 0; i < images.length; i++) ...[
                    if (labels != null && i < labels.length)
                      {'type': 'text', 'text': labels[i]},
                    {
                      'type': 'image_url',
                      'image_url': {
                        'url':
                            'data:image/jpeg;base64,${base64Encode(images[i])}'
                      },
                    },
                  ],
                  {'type': 'text', 'text': text},
                ],
              }
            ],
          }),
        )
        .timeout(const Duration(seconds: 180));
    if (resp.statusCode != 200) {
      throw Exception('AI: ошибка ${resp.statusCode}');
    }
    final body =
        jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    return body['choices'][0]['message']['content'] as String;
  }
}
