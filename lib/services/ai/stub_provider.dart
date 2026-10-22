import 'dart:math';
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

  /// Без AI: для каждого преимущества три разных встроенных значка,
  /// первый — подобранный по смыслу подписи.
  @override
  Future<IconIdeas> suggestIcons({
    required Uint8List mainPreviewJpeg,
    required InfographicText current,
    required String instruction,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final rnd = Random();
    return IconIdeas([
      for (final f in current.features)
        FeatureIdeas(f.text, () {
          final keys = <String>[guessIcon(f.text)];
          final rest = [for (final i in kIcons) i.key]..shuffle(rnd);
          for (final k in rest) {
            if (keys.length >= kIconVariants) break;
            if (!keys.contains(k) && k != f.icon) keys.add(k);
          }
          return [for (final k in keys) iconByKey(k).paths];
        }()),
    ]);
  }

  /// Без AI: по одной плашке на фото из пунктов «Что сделано» (или общие
  /// фразы), в центре кадра — дальше их можно передвинуть руками.
  @override
  Future<List<List<PhotoBadge>>> suggestBadges({
    required Uint8List mainJpeg,
    required List<Uint8List> otherJpegs,
    required String context,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final done = RegExp(r'Что сделано[^:]*:\s*([\s\S]*?)(?:\n[А-ЯЁ][^:\n]*:|$)')
        .firstMatch(context)
        ?.group(1)
        ?.split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    final phrases = (done == null || done.isEmpty)
        ? const [
            'Аккуратный монтаж',
            'Ровная укладка кабеля',
            'Надёжное крепление'
          ]
        : done;
    return [
      for (var i = 0; i < otherJpegs.length; i++)
        [PhotoBadge(phrases[i % phrases.length], 0.5, 0.55)],
    ];
  }
}
