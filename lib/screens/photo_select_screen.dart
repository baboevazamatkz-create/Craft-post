import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../theme.dart';
import '../widgets/photo_thumb.dart';
import 'form_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

class PhotoSelectScreen extends StatelessWidget {
  const PhotoSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final d = s.draft;
    return Scaffold(
      appBar: AppBar(
        title: const Text('1. Выбор фото'),
        actions: [
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
          const Text('Главное фото (с инфографикой)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          if (d.mainPath != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: PhotoThumb(d.mainPath!,
                  height: 220, width: double.infinity, cacheWidth: 800),
            )
          else
            _EmptyPhoto(
              icon: Icons.add_photo_alternate_outlined,
              text: 'Нажмите, чтобы выбрать фото',
              height: 180,
              onTap: s.pickMain,
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: s.pickMain,
            icon: const Icon(Icons.photo),
            label: Text(d.mainPath == null
                ? 'Выбрать главное фото'
                : 'Заменить главное фото'),
          ),
          const SizedBox(height: 24),
          const Text('Остальные фото (с логотипом)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          if (d.otherPaths.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in d.otherPaths)
                  Stack(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: PhotoThumb(p,
                          width: 100, height: 100, cacheWidth: 300),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: InkWell(
                        onTap: () => s.removeOther(p),
                        child: const CircleAvatar(
                            radius: 14,
                            backgroundColor: Colors.white,
                            child:
                                Icon(Icons.close, size: 16, color: Brand.blue)),
                      ),
                    ),
                  ]),
              ],
            )
          else
            _EmptyPhoto(
              icon: Icons.photo_library_outlined,
              text: 'Можно выбрать сразу несколько',
              height: 110,
              onTap: s.pickOthers,
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: s.pickOthers,
            icon: const Icon(Icons.photo_library),
            label: Text(d.otherPaths.isEmpty
                ? 'Выбрать остальные фото'
                : 'Изменить выбор'),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: d.mainPath == null
                ? null
                : () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const FormScreen())),
            child: const Text('Далее'),
          ),
        ],
      ),
    );
  }
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
              Icon(icon, size: 44, color: Brand.sky),
              const SizedBox(height: 8),
              Text(text,
                  style: const TextStyle(color: Brand.deep, fontSize: 15)),
            ],
          ),
        ),
      ),
    );
  }
}
