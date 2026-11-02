import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Brand: pandan green (same as the website and emails), Familjen Grotesk.
abstract final class AppTheme {
  static const pandan = Color(0xFF2F6B3B);

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: pandan,
      brightness: brightness,
    );
    final base = ThemeData(colorScheme: scheme, useMaterial3: true);
    return base.copyWith(
      textTheme: GoogleFonts.familjenGroteskTextTheme(base.textTheme),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
