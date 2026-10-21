import 'dart:typed_data';

import '../../models/post_draft.dart';
import '../../models/icon_library.dart';
import 'ai_provider.dart';

/// Работает без сети и ключа: собирает текст из полей формы.
class StubAiProvider implements AiProvider {
  @override
  String get id => 'stub';
  @override
  String get title => 'Заглушка (без AI)';

  @override
  Future<AiResult> generate({
    required Uint8List mainPhotoJpeg,
    required Map<String, String> fields,
    required List<Feature> features,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    String f(String k) => (fields[k] ?? '').trim();
    final done = f('done')
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .map((l) => ' ▪ ${l.trim()}');
    final caption = [
      '🔷 ${[
        f('object'),
        f('stat'),
        f('unit')
      ].where((e) => e.isNotEmpty).join(' ')}',
      if (f('task').isNotEmpty) '❗ Задача — ${f('task')}',
      if (f('work').isNotEmpty && f('task').isEmpty)
        '❗ Задача — ${f('work').toLowerCase()}.',
      if (done.isNotEmpty) '✔️ Что было сделано:\n${done.join('\n')}',
    ].join('\n\n');
    return AiResult(
      caption,
      InfographicText(
        title: f('object'),
        subtitle: f('work'),
        location: f('location'),
        features: [
          for (final x in features) Feature(guessIcon(x.text), x.text)
        ],
      ),
    );
  }
}
