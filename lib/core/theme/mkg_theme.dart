import 'package:flutter/material.dart';

/// MKG Tax brand — green / gold / white (mkgtaxconsultants.com favicon + portal).
abstract final class MkgColors {
  static const Color primary = Color(0xFF1A5632);
  static const Color primaryDark = Color(0xFF0D3B1F);
  static const Color accent = Color(0xFFC9A84C);
  static const Color dark = Color(0xFF122018);
  static const Color textGrey = Color(0xFF5C6B63);
  static const Color grey = Color(0xFFB8C0BA);
  static const Color lightPrimary = Color(0x1A1A5632);
  static const Color bottomInactive = Color(0xFF707070);
  static const Color surfaceGrey = Color(0xFFF3F7F4);
  static const Color green = Color(0xFF16A34A);
  static const Color red = Color(0xFFDC2626);
  static const Color orange = Color(0xFFC9A84C);
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
        fontSize: 17,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      labelStyle: const TextStyle(color: MkgColors.textGrey),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: MkgColors.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: MkgColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 0.4),
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
        return IconThemeData(color: selected ? MkgColors.primary : MkgColors.bottomInactive);
      }),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2EDE6)),
      ),
    ),
  );
}
