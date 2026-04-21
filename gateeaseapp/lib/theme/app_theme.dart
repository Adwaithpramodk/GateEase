import 'package:flutter/material.dart';

class AppTheme {
  // ─────────────── Palette (Modern Dark Blue / Navy) ───────────────
  static const Color primary      = Color(0xFF1E40AF); // Royal Blue
  static const Color primaryDark  = Color(0xFF1E3A8A); // Navy Blue
  static const Color primaryLight = Color(0xFFDBEAFE); // Soft Blue Tint

  static const Color accent       = Color(0xFF3B82F6); // Electric Blue
  static const Color accentLight  = Color(0xFFEFF6FF);

  static const Color secondary    = Color(0xFF64748B); // Slate
  static const Color secondaryLight = Color(0xFFF1F5F9);

  // Semantics
  static const Color success      = Color(0xFF10B981);
  static const Color successLight = Color(0xFFD1FAE5);
  static const Color warning      = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color error        = Color(0xFFEF4444);
  static const Color errorLight   = Color(0xFFFEE2E2);

  // Neutrals
  static const Color background   = Color(0xFFF8FAFC); // Slate 50
  static const Color surface      = Color(0xFFFFFFFF);
  static const Color surfaceAlt   = Color(0xFFF1F5F9); // Slate 100
  static const Color border       = Color(0xFFE2E8F0); // Slate 200

  // Text
  static const Color textPrimary   = Color(0xFF0F172A); // Slate 900
  static const Color textSecondary = Color(0xFF475569); // Slate 600
  static const Color textMuted     = Color(0xFF94A3B8); // Slate 400

  // Header gradient — Deep Professional Navy
  static const Color headerTop    = Color(0xFF1E3A8A);
  static const Color headerMid    = Color(0xFF1E40AF);
  static const Color headerBottom = Color(0xFF2563EB);

  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [headerTop, headerMid, headerBottom],
  );

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryDark],
  );

  // ─────────────── ThemeData ───────────────
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Poppins',
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        secondary: accent,
        surface: surface,
        error: error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimary,
      ),
      scaffoldBackgroundColor: background,
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: error, width: 1.5),
        ),
        labelStyle: const TextStyle(color: textSecondary, fontSize: 14),
        floatingLabelStyle: const TextStyle(color: primary, fontSize: 13, fontWeight: FontWeight.w600),
        prefixIconColor: textSecondary,
        suffixIconColor: textSecondary,
        hintStyle: const TextStyle(color: textMuted, fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.3),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      dividerTheme: const DividerThemeData(color: border, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: textPrimary,
        contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ─────────────── Reusable Decorations ───────────────
  static BoxDecoration get cardDecoration => BoxDecoration(
    color: surface,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4)),
    ],
  );

  static BoxDecoration get elevatedCardDecoration => BoxDecoration(
    color: surface,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: border, width: 1),
    boxShadow: [
      BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
    ],
  );

  static BoxDecoration get accentCardDecoration => BoxDecoration(
    color: accent,
    borderRadius: BorderRadius.circular(16),
  );
}
