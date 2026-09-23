import 'package:flutter/material.dart';

/// University-style Material 3 theme.
/// Primary: deep navy blue  Accent: amber gold  Surface: warm white
class AppTheme {
  AppTheme._();

  // ── Brand palette ─────────────────────────────────────────────────────────
  static const Color _primary = Color(0xFF1A3A6B); // deep navy
  static const Color _secondary = Color(0xFFF5A623); // amber gold
  static const Color _error = Color(0xFFD32F2F);
  static const Color _surface = Color(0xFFFAFAFA);
  static const Color _onPrimary = Colors.white;

  // ── Light theme ───────────────────────────────────────────────────────────
  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _primary,
      brightness: Brightness.light,
      primary: _primary,
      secondary: _secondary,
      error: _error,
      surface: _surface,
      onPrimary: _onPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: 'Roboto',

      // ── AppBar ──────────────────────────────────────────────────────────
      appBarTheme: const AppBarTheme(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.15,
        ),
      ),

      // ── Elevated button — large, accessible ─────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
          elevation: 2,
        ),
      ),

      // ── Outlined button ─────────────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _primary,
          minimumSize: const Size(double.infinity, 56),
          side: const BorderSide(color: _primary, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── Text button ─────────────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _primary,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── Input fields ────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _error, width: 2),
        ),
        labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 15),
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
        errorStyle: const TextStyle(color: _error, fontSize: 12),
      ),

      // ── Card ────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: Colors.white,
        margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      ),

      // ── Typography ──────────────────────────────────────────────────────
      textTheme: const TextTheme(
        displayLarge: TextStyle(
            fontSize: 32, fontWeight: FontWeight.w700, color: _primary),
        displayMedium: TextStyle(
            fontSize: 28, fontWeight: FontWeight.w700, color: _primary),
        headlineLarge: TextStyle(
            fontSize: 24, fontWeight: FontWeight.w700, color: _primary),
        headlineMedium: TextStyle(
            fontSize: 20, fontWeight: FontWeight.w600, color: _primary),
        titleLarge: TextStyle(
            fontSize: 18, fontWeight: FontWeight.w600, color: _primary),
        titleMedium: TextStyle(
            fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFF1A1A2E)),
        bodyLarge: TextStyle(fontSize: 16, color: Color(0xFF1A1A2E)),
        bodyMedium: TextStyle(fontSize: 14, color: Color(0xFF555577)),
        labelLarge: TextStyle(
            fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
      ),

      // ── Scaffold background ─────────────────────────────────────────────
      scaffoldBackgroundColor: const Color(0xFFF0F2F8),

      // ── Snack bar ───────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ── Dark theme (optional) ─────────────────────────────────────────────────
  static ThemeData get dark {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _primary,
      brightness: Brightness.dark,
      primary: const Color(0xFF5B8DEF),
      secondary: _secondary,
      error: const Color(0xFFEF5350),
      surface: const Color(0xFF1E1E2E),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFF13131F),
    );
  }
}
