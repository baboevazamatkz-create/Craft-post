import 'ai_provider.dart';
import 'anthropic_provider.dart';
import 'openai_provider.dart';
import 'stub_provider.dart';

const kProviderIds = {
  'stub': 'Заглушка (без AI)',
  'anthropic': 'Claude (Anthropic)',
  'openai': 'OpenAI (GPT)',
};

AiProvider createAiProvider(String id, String apiKey) {
  switch (id) {
    case 'anthropic':
      return AnthropicProvider(apiKey);
    case 'openai':
      return OpenAiProvider(apiKey);
    default:
      return StubAiProvider();
  }
}
