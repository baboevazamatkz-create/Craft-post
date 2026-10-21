import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'screens/photo_select_screen.dart';

void main() => runApp(
      ChangeNotifierProvider(
          create: (_) => AppState(), child: const CraftApp()),
    );

class CraftApp extends StatelessWidget {
  const CraftApp({super.key});

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFFFC400);
    return MaterialApp(
      title: 'CRAFT Посты',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
            seedColor: accent, brightness: Brightness.dark),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(60),
            textStyle:
                const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            textStyle: const TextStyle(fontSize: 17),
          ),
        ),
        inputDecorationTheme:
            const InputDecorationTheme(border: OutlineInputBorder()),
      ),
      home: const PhotoSelectScreen(),
    );
  }
}
