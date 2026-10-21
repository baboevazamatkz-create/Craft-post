import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import 'form_screen.dart';
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
            tooltip: 'Настройки',
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
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
              borderRadius: BorderRadius.circular(12),
              child: Image.file(File(d.mainPath!),
                  height: 220, width: double.infinity, fit: BoxFit.cover, cacheWidth: 800),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: s.pickMain,
            icon: const Icon(Icons.photo),
            label: Text(d.mainPath == null ? 'Выбрать главное фото' : 'Заменить главное фото'),
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
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(File(p), width: 100, height: 100, fit: BoxFit.cover, cacheWidth: 300),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: InkWell(
                        onTap: () => s.removeOther(p),
                        child: const CircleAvatar(
                            radius: 14, backgroundColor: Colors.black87, child: Icon(Icons.close, size: 16)),
                      ),
                    ),
                  ]),
              ],
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: s.pickOthers,
            icon: const Icon(Icons.photo_library),
            label: Text(d.otherPaths.isEmpty ? 'Выбрать остальные фото' : 'Изменить выбор'),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: d.mainPath == null
                ? null
                : () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => const FormScreen())),
            child: const Text('Далее'),
          ),
        ],
      ),
    );
  }
}
