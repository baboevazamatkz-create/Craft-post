import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../services/post_store.dart';
import '../theme.dart';
import '../widgets/busy.dart';
import 'preview_screen.dart';

/// Посты, сохранённые в приложении. Открыть — к превью и правкам.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<PostSummary>> _items = context.read<AppState>().history();

  void _reload() => setState(() => _items = context.read<AppState>().history());

  Future<void> _open(PostSummary p) async {
    final s = context.read<AppState>();
    final ok = await runBusy(context, 'Открываю пост…', () => s.openPost(p.id));
    if (ok && mounted) {
      await Navigator.push(
          context, MaterialPageRoute(builder: (_) => const PreviewScreen()));
      _reload();
    }
  }

  Future<void> _delete(PostSummary p) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Удалить пост?'),
        content: Text('«${p.title}» будет удалён из приложения. '
            'Уже сохранённые фото останутся.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Отмена')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Удалить')),
        ],
      ),
    );
    if (yes == true && mounted) {
      await context.read<AppState>().deletePost(p.id);
      _reload();
    }
  }

  String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Мои посты')),
      body: FutureBuilder<List<PostSummary>>(
        future: _items,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snap.data!;
          if (items.isEmpty) {
            return const Center(
              child: Text('Пока нет сохранённых постов',
                  style: TextStyle(fontSize: 17)),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final p = items[i];
              return Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _open(p),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: p.preview != null
                            ? Image.memory(p.preview!,
                                width: 72,
                                height: 96,
                                fit: BoxFit.cover,
                                cacheWidth: 216)
                            : Container(
                                width: 72, height: 96, color: Brand.tint),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 17, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text(_date(p.createdAt),
                                style: const TextStyle(color: Brand.deep)),
                            const SizedBox(height: 4),
                            Text('Сохранено: ${p.saved} из ${p.total}',
                                style: TextStyle(
                                    color: p.saved == p.total && p.total > 0
                                        ? const Color(0xFF2E9E5B)
                                        : Brand.deep)),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Удалить',
                        onPressed: () => _delete(p),
                        icon:
                            const Icon(Icons.delete_outline, color: Brand.deep),
                      ),
                    ]),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
