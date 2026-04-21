import 'package:flutter/material.dart';

class AppTheme {
  // ─────────────── Palette: Sapphire & Cyan ───────────────
  // Primary: Royal Sapphire Blue
  static const Color primary      = Color(0xFF2563EB); // Royal Blue
  static const Color primaryDark  = Color(0xFF1E3A8A); // Deep Sapphire
  static const Color primaryLight = Color(0xFFEFF6FF); // Soft ice blue

  // Accent: Vibrant Cyan/Teal (CTA, highlights)
  static const Color accent       = Color(0xFF06B6D4); // Electric Cyan
  static const Color accentLight  = Color(0xFFCFFAFE); // Light Cyan

  // Secondary: Soft Purple/Violet
  static const Color secondary    = Color(0xFF8B5CF6); // Violet
  static const Color secondaryLight = Color(0xFFEDE9FE);

  // Semantics
  static const Color success      = Color(0xFF10B981); // Emerald
  static const Color successLight = Color(0xFFD1FAE5);
  static const Color warning      = Color(0xFFF59E0B); // Amber
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color error        = Color(0xFFEF4444); // Red
  static const Color errorLight   = Color(0xFFFEE2E2);

  // Neutrals
  static const Color background   = Color(0xFFF8FAFC); // Clean slate background
  static const Color surface      = Color(0xFFFFFFFF);
  static const Color surfaceAlt   = Color(0xFFF1F5F9); // Slate-100
  static const Color border       = Color(0xFFE2E8F0); // Slate-200

  // Text
  static const Color textPrimary   = Color(0xFF0F172A); // Deep slate text
  static const Color textSecondary = Color(0xFF64748B); // Slate-500
  static const Color textMuted     = Color(0xFF94A3B8); // Slate-400

  // Header gradient — Deep Ocean Blue gradient
  static const Color headerTop    = Color(0xFF0F172A); // Midnight Slate
  static const Color headerMid    = Color(0xFF1E3A8A); // Deep Sapphire
  static const Color headerBottom = Color(0xFF2563EB); // Royal Blue

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

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent, Color(0xFF0891B2)], // Cyan-500 to Cyan-600
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
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(50), // pill shape
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(50),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(50),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(50),
          borderSide: const BorderSide(color: error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(50),
          borderSide: const BorderSide(color: error, width: 2),
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
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.3),
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
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primary;
          return Colors.transparent;
        }),
        side: const BorderSide(color: border, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      dividerTheme: const DividerThemeData(color: border, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: textPrimary,
        contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ─────────────── Reusable Decorations ───────────────
  static BoxDecoration get cardDecoration => BoxDecoration(
    color: surface,
    borderRadius: BorderRadius.circular(24),
    boxShadow: [
      BoxShadow(color: primary.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 6)),
    ],
  );

  static BoxDecoration get elevatedCardDecoration => BoxDecoration(
    color: surface,
    borderRadius: BorderRadius.circular(24),
    boxShadow: [
      BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 24, offset: const Offset(0, 8)),
    ],
  );

  static BoxDecoration get accentCardDecoration => BoxDecoration(
    gradient: accentGradient,
    borderRadius: BorderRadius.circular(24),
    boxShadow: [
      BoxShadow(color: accent.withValues(alpha: 0.35), blurRadius: 20, offset: const Offset(0, 8)),
    ],
  );
}
