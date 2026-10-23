import 'package:flutter/material.dart';

abstract final class Brand {
  // Sampled from the Assiut National University screens supplied by the user.
  static const brown = Color(0xFF5A3824);
  static const brownDark = Color(0xFF4E2E1A);
  static const bronze = Color(0xFF8D5E3D);
  static const canvas = Color(0xFFF9F9FB);
  static const warmSurface = Color(0xFFF3EFEA);
  static const ink = Color(0xFF2A211C);
  static const muted = Color(0xFF6B5B50);
  static const success = Color(0xFF177A4E);
  static const warning = Color(0xFF8A5900);
  static const danger = Color(0xFFB3261E);
  static const radius = 16.0;
  static const gutter = 16.0;

  static ThemeData theme({bool dark = false}) {
    final scheme = ColorScheme.fromSeed(
      seedColor: brown,
      brightness: dark ? Brightness.dark : Brightness.light,
      primary: dark ? const Color(0xFFE6BE9E) : brown,
      secondary: dark ? const Color(0xFFD6AA87) : bronze,
      surface: dark ? const Color(0xFF36271F) : Colors.white,
      error: dark ? const Color(0xFFFFB4AB) : danger,
    );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    return base.copyWith(
      scaffoldBackgroundColor: dark ? const Color(0xFF241A15) : canvas,
      textTheme: base.textTheme.apply(
        fontFamily: 'Inter',
        bodyColor: dark ? Colors.white : ink,
        displayColor: dark ? Colors.white : ink,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: dark ? const Color(0xFF241A15) : canvas,
        centerTitle: false,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? scheme.surface : warmSurface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        backgroundColor: scheme.surface,
      ),
    );
  }
}
