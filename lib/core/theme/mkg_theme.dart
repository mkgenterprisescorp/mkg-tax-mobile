import 'package:flutter/material.dart';

/// Legacy MKG Tax Consultants brand tokens (Android parity).
abstract final class MkgColors {
  static const Color primary = Color(0xFF006FCD);
  static const Color dark = Color(0xFF0B1824);
  static const Color textGrey = Color(0xFF666666);
  static const Color grey = Color(0xFFB8B8B8);
  static const Color lightPrimary = Color(0x1A006FCD);
  static const Color bottomInactive = Color(0xFF707070);
  static const Color surfaceGrey = Color(0xFFF1F5F8);
  static const Color green = Color(0xFF0BAA12);
  static const Color red = Color(0xFFFF0000);
  static const Color orange = Color(0xFFFFAE50);
}

ThemeData buildMkgTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: MkgColors.primary,
    primary: MkgColors.primary,
    surface: Colors.white,
    onSurface: MkgColors.dark,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: const AppBarTheme(
      backgroundColor: MkgColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: MkgColors.surfaceGrey,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: MkgColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: MkgColors.lightPrimary,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? MkgColors.primary : MkgColors.bottomInactive,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? MkgColors.primary : MkgColors.bottomInactive,
        );
      }),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE6EEF5)),
      ),
    ),
  );
}
