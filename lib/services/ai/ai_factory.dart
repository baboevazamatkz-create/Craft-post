import 'ai_provider.dart';
import 'anthropic_provider.dart';
import 'openai_provider.dart';

const kProviderIds = {
  'anthropic': 'Claude (Anthropic)',
  'openai': 'OpenAI (GPT)',
};

/// Настоящий AI всегда: без ключа провайдер сам сообщит, что ключ не введён
/// (раньше молча включалась заглушка со случайными значками).
AiProvider createAiProvider(String id, String apiKey) => switch (id) {
      'openai' => OpenAiProvider(apiKey),
      _ => AnthropicProvider(apiKey),
    };
