import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../theme.dart';
import '../widgets/photo_thumb.dart';
import 'form_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

/// Шаг 1: все фото поста выбираются скопом, главное назначается нажатием.
class PhotoSelectScreen extends StatelessWidget {
  const PhotoSelectScreen({super.key});

  Future<void> _newPost(BuildContext context, AppState s) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Начать новый пост?'),
        content: const Text('Выбранные фото уберутся с экрана. '
            'Уже созданные посты останутся в «Моих постах».'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Отмена')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Новый пост')),
        ],
      ),
    );
    if (yes == true) s.reset();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final d = s.draft;
    final hasPhotos = d.mainPath != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('1. Фото'),
        actions: [
          if (hasPhotos)
            IconButton(
              tooltip: 'Новый пост',
              icon: const Icon(Icons.note_add_outlined),
              onPressed: () => _newPost(context, s),
            ),
          IconButton(
            tooltip: 'Мои посты',
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const HistoryScreen())),
          ),
          IconButton(
            tooltip: 'Настройки',
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!hasPhotos) ...[
            _EmptyPhoto(
              icon: Icons.add_photo_alternate_outlined,
              text: 'Выберите все фото поста сразу —\n'
                  'главное назначите потом',
              height: 220,
              onTap: s.pickPhotos,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: s.pickPhotos,
              icon: const Icon(Icons.photo_library),
              label: const Text('Выбрать фото'),
            ),
          ] else ...[
            const Text('Главное фото (с инфографикой)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Stack(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: PhotoThumb(d.mainPath!,
                    height: 240, width: double.infinity, cacheWidth: 800),
              ),
              Positioned(
                left: 10,
                top: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: Brand.blue,
                      borderRadius: BorderRadius.circular(20)),
                  child: const Text('Главное',
                      style: TextStyle(color: Colors.white, fontSize: 13)),
                ),
              ),
              Positioned(
                right: 8,
                top: 8,
                child: _RemoveButton(() => s.removePhoto(d.mainPath!)),
              ),
            ]),
            const SizedBox(height: 20),
            Text(
                d.otherPaths.isEmpty
                    ? 'Остальные фото (с логотипом)'
                    : 'Остальные фото: ${d.otherPaths.length}',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            if (d.otherPaths.isNotEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Text('Нажмите на фото, чтобы сделать его главным',
                    style: TextStyle(fontSize: 14, color: Brand.deep)),
              ),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (final p in d.otherPaths)
                  GestureDetector(
                    onTap: () => s.setMain(p),
                    child: Stack(fit: StackFit.expand, children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: PhotoThumb(p, cacheWidth: 300),
                      ),
                      Positioned(
                        right: 4,
                        top: 4,
                        child: _RemoveButton(() => s.removePhoto(p)),
                      ),
                    ]),
                  ),
                _AddTile(onTap: s.pickPhotos),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const FormScreen())),
              child: const Text('Далее'),
            ),
          ],
        ],
      ),
    );
  }
}

class _RemoveButton extends StatelessWidget {
  final VoidCallback onTap;
  const _RemoveButton(this.onTap);

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: const CircleAvatar(
          radius: 14,
          backgroundColor: Colors.white,
          child: Icon(Icons.close, size: 16, color: Brand.blue),
        ),
      );
}

/// Плитка «добавить ещё фото» в конце сетки.
class _AddTile extends StatelessWidget {
  final VoidCallback onTap;
  const _AddTile({required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        color: Brand.tint,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Brand.border, width: 1.5),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_photo_alternate_outlined,
                    size: 32, color: Brand.sky),
                SizedBox(height: 4),
                Text('Добавить',
                    style: TextStyle(color: Brand.deep, fontSize: 14)),
              ],
            ),
          ),
        ),
      );
}

/// Пустая голубая плашка-подсказка на месте фото.
class _EmptyPhoto extends StatelessWidget {
  final IconData icon;
  final String text;
  final double height;
  final VoidCallback onTap;
  const _EmptyPhoto(
      {required this.icon,
      required this.text,
      required this.height,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Brand.tint,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Brand.border, width: 1.5),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 52, color: Brand.sky),
              const SizedBox(height: 10),
              Text(text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Brand.deep, fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }
}
