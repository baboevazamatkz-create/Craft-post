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
      home: const PhotoSelectScreen(),
    );
  }
}
