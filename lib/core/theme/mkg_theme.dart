import 'package:flutter/material.dart';

/// Brand tokens cloned from financemkgtaxpro web portal (index.css).
/// Primary green HSL(142,76%,26%) · accent gold HSL(45,93%,47%).
abstract final class MkgColors {
  static const Color primary = Color(0xFF0F7A3A);
  static const Color primaryDark = Color(0xFF0A5C2B);
  static const Color accent = Color(0xFFE8B90A);
  static const Color dark = Color(0xFF122018);
  static const Color textGrey = Color(0xFF5C6B63);
  static const Color grey = Color(0xFFB8C0BA);
  static const Color lightPrimary = Color(0x1A0F7A3A);
  static const Color bottomInactive = Color(0xFF707070);
  static const Color surfaceGrey = Color(0xFFF3F7F4);
  static const Color green = Color(0xFF16A34A);
  static const Color red = Color(0xFFDC2626);
  static const Color orange = Color(0xFFCA8A04);
}

ThemeData buildMkgTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: MkgColors.primary,
    primary: MkgColors.primary,
    secondary: MkgColors.accent,
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
        letterSpacing: 0.3,
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
        side: const BorderSide(color: Color(0xFFE2EDE6)),
      ),
    ),
  );
}
