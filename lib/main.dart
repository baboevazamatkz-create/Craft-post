import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'screens/photo_select_screen.dart';
import 'theme.dart';

void main() => runApp(
      ChangeNotifierProvider(
          create: (_) => AppState(), child: const CraftApp()),
    );

class CraftApp extends StatelessWidget {
  const CraftApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CRAFT Посты',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      // В браузере на компьютере — колонка шириной с телефон по центру.
      builder: (context, child) => ColoredBox(
        color: const Color(0xFFDCE9F2),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: child,
          ),
        ),
      ),
      home: const PhotoSelectScreen(),
    );
  }
}
