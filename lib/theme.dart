import 'package:flutter/material.dart';

abstract final class Brand {
  static const brown = Color(0xFF5A3824);
  static const brownDark = Color(0xFF3C291F);
  static const bronze = Color(0xFF8D5E3D);
  static const gold = Color(0xFFD4AF76);
  static const canvas = Color(0xFFF8F6F2);
  static const warmSurface = Color(0xFFF3EFE8);
  static const ink = Color(0xFF302A25);
  static const muted = Color(0xFF756C63);
  static const success = Color(0xFF177A4E);
  static const warning = Color(0xFF8A5900);
  static const danger = Color(0xFFB3261E);
  static const radius = 20.0;
  static const gutter = 20.0;

  static ThemeData theme({bool dark = false}) {
    final scheme = ColorScheme.fromSeed(
      seedColor: brown,
      brightness: dark ? Brightness.dark : Brightness.light,
      primary: dark ? const Color(0xFFE6BE9E) : brown,
      secondary: dark ? const Color(0xFFD6AA87) : bronze,
      surface: dark ? const Color(0xFF2C2621) : Colors.white,
      error: dark ? const Color(0xFFFFB4AB) : danger,
    ).copyWith(
      outline: dark ? const Color(0xFF9C8E80) : const Color(0xFF8C7D70),
      outlineVariant: dark ? const Color(0xFF443B32) : const Color(0xFFE8E2DA),
      onSurface: dark ? const Color(0xFFF2ECE5) : ink,
      onSurfaceVariant: dark ? const Color(0xFFC3B8AC) : muted,
    );
    final base = ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        fontFamily: 'NotoSansArabic',
        fontFamilyFallback: const ['NotoSans']);
    return base.copyWith(
      scaffoldBackgroundColor: dark ? const Color(0xFF1F1B18) : canvas,
      textTheme: base.textTheme.copyWith(
        headlineMedium: base.textTheme.headlineMedium
            ?.copyWith(fontSize: 28, fontWeight: FontWeight.w700, height: 1.6),
        headlineSmall: base.textTheme.headlineSmall
            ?.copyWith(fontSize: 22, fontWeight: FontWeight.w700, height: 1.6),
        titleLarge: base.textTheme.titleLarge
            ?.copyWith(fontSize: 18, fontWeight: FontWeight.w700, height: 1.6),
        titleMedium: base.textTheme.titleMedium
            ?.copyWith(fontSize: 15, fontWeight: FontWeight.w700, height: 1.6),
        bodyLarge:
            base.textTheme.bodyLarge?.copyWith(fontSize: 15, height: 1.7),
        bodyMedium:
            base.textTheme.bodyMedium?.copyWith(fontSize: 13, height: 1.7),
        labelLarge: base.textTheme.labelLarge
            ?.copyWith(fontSize: 13, fontWeight: FontWeight.w700),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: base.textTheme.titleMedium
            ?.copyWith(color: scheme.onSurface, fontWeight: FontWeight.w700),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? scheme.surface : const Color(0xFFFCFBF9),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: scheme.outlineVariant)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: scheme.primary, width: 2)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 52),
          side: BorderSide(color: scheme.outlineVariant),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 76,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
            fontFamily: 'NotoSansArabic',
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w400,
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant)),
      ),
      dividerTheme:
          DividerThemeData(color: scheme.outlineVariant, thickness: 1),
      snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
      listTileTheme: const ListTileThemeData(
          contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 6)),
    );
  }
}
