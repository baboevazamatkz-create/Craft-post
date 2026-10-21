import 'package:flutter/material.dart';

/// Светлая тема в фирменных голубых тонах (цвета ромбов логотипа).
class Brand {
  static const blue = Color(0xFF008DC8); // основной
  static const sky = Color(0xFF56B9E5); // светлый ромб
  static const deep = Color(0xFF0073A0); // тёмный ромб
  static const ink = Color(0xFF0B3A53); // текст
  static const background = Color(0xFFF2F8FC);
  static const tint = Color(0xFFE3F3FB); // заливка плашек
  static const border = Color(0xFFBFE3F5);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: Brand.blue,
    brightness: Brightness.light,
  ).copyWith(
    primary: Brand.blue,
    onPrimary: Colors.white,
    secondary: Brand.sky,
    tertiary: Brand.deep,
    primaryContainer: Brand.tint,
    onPrimaryContainer: Brand.ink,
    surface: Colors.white,
    onSurface: Brand.ink,
    outline: Brand.border,
  );
  final radius = BorderRadius.circular(16);

  return ThemeData(
    useMaterial3: true,
    // Шрифт встроен в приложение: в браузере не зависит от Google Fonts.
    fontFamily: 'Roboto',
    colorScheme: scheme,
    scaffoldBackgroundColor: Brand.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: Brand.background,
      foregroundColor: Brand.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: 'Roboto',
        color: Brand.ink,
        fontSize: 21,
        fontWeight: FontWeight.w700,
      ),
      iconTheme: IconThemeData(color: Brand.blue, size: 28),
      actionsIconTheme: IconThemeData(color: Brand.blue, size: 28),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Brand.blue,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Brand.border,
        disabledForegroundColor: Colors.white,
        minimumSize: const Size.fromHeight(60),
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: const TextStyle(
            fontFamily: 'Roboto', fontSize: 18, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Brand.blue,
        backgroundColor: Colors.white,
        minimumSize: const Size.fromHeight(56),
        side: const BorderSide(color: Brand.sky, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: const TextStyle(
            fontFamily: 'Roboto', fontSize: 17, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      labelStyle: const TextStyle(color: Brand.deep),
      floatingLabelStyle: const TextStyle(color: Brand.blue),
      hintStyle: TextStyle(color: Brand.ink.withValues(alpha: 0.4)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Brand.border, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Brand.blue, width: 2),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: Brand.blue,
      linearTrackColor: Brand.tint,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: radius),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: Brand.ink,
      behavior: SnackBarBehavior.floating,
    ),
    dividerTheme: const DividerThemeData(color: Brand.border),
  );
}
