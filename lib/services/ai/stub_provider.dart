import 'dart:math';
import 'dart:typed_data';

import '../../models/post_draft.dart';
import '../../models/icon_library.dart';
import 'ai_provider.dart';

/// Работает без сети и ключа: собирает текст из полей формы. Нужна только
/// для проверки приложения; настоящие преимущества и значки рисует AI.
class StubAiProvider implements AiProvider {
  @override
  String get id => 'stub';
  @override
  String get title => 'Заглушка (без AI)';

  static const _ideas = [
    'Автоматика день-ночь',
    'Дистанционная настройка',
    'Работа на высоте',
    'Скрытая проводка',
    'Защита от скачков',
    'Запуск за 1 день',
    'Маркировка линий',
    'Монтаж без пыли',
    'Запас мощности',
    'Гарантия 3 года',
  ];

  @override
  Future<AiResult> generate({
    required Uint8List mainPhotoJpeg,
    required Map<String, String> fields,
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
          title: f('object'), subtitle: f('work'), location: f('location')),
      _ideas.take(kFeatureIdeas).toList(),
    );
  }

  @override
  Future<List<String>> suggestFeatures({
    required Uint8List mainPhotoJpeg,
    required Map<String, String> fields,
    required List<String> exclude,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return [
      for (final i in _ideas)
        if (!exclude.contains(i)) i
    ];
  }

  /// Без AI: случайные встроенные значки, только чтобы пройти шаг.
  @override
  Future<List<List<List<String>>>> suggestIcons({
    required List<String> features,
    required String instruction,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final rnd = Random();
    return [
      for (final _ in features)
        [
          for (final i in ([...kIcons]..shuffle(rnd)).take(kIconVariants))
            i.paths
        ],
    ];
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
            'Кабель в одну линию по лазеру',
            'Ни одного провода на виду',
            'Запас под обслуживание'
          ]
        : done;
    return [
      for (var i = 0; i < otherJpegs.length; i++)
        [PhotoBadge(phrases[i % phrases.length], 0.5, 0.55)],
    ];
  }
}
