import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get lightTheme {
    final colors = AppColors.light;
    return _buildTheme(colors);
  }

  static ThemeData get darkTheme {
    final colors = AppColors.dark;
    return _buildTheme(colors);
  }

  static ThemeData _buildTheme(AppColors colors) {
    return ThemeData(
      fontFamily: GoogleFonts.montserrat().fontFamily,
      brightness: colors.brightness,
      scaffoldBackgroundColor: colors.bg,
      colorScheme: ColorScheme(
        brightness: colors.brightness,
        primary: colors.accent,
        primaryContainer: colors.accentLight,
        onPrimary: Colors.white,
        secondary: const Color(0xFF00E676),
        onSecondary: Colors.white,
        error: Colors.red,
        onError: Colors.white,
        surface: colors.surface,
        onSurface: colors.textPrimary,
      ),
      textTheme: GoogleFonts.montserratTextTheme().copyWith(
        bodyLarge: GoogleFonts.montserrat(color: colors.textPrimary),
        bodyMedium: GoogleFonts.montserrat(color: colors.textSecondary),
        bodySmall: GoogleFonts.montserrat(color: colors.textMuted),
        titleLarge: GoogleFonts.montserrat(color: colors.textPrimary, fontWeight: FontWeight.w800),
        titleMedium: GoogleFonts.montserrat(color: colors.textPrimary, fontWeight: FontWeight.w700),
        titleSmall: GoogleFonts.montserrat(color: colors.textPrimary, fontWeight: FontWeight.w600),
      ),
      cardColor: colors.cardBg,
      cardTheme: CardThemeData(
        color: colors.cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: colors.border),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.bg,
        elevation: 0,
        iconTheme: IconThemeData(color: colors.textPrimary),
        titleTextStyle: GoogleFonts.montserrat(
          color: colors.textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
      ),
      dividerColor: colors.border,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.accent,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: colors.accent.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          minimumSize: const Size(48, 48), // Accessibilidade: Área de toque mínima
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: GoogleFonts.montserrat(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: colors.accent, width: 2),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colors.surface,
        selectedItemColor: colors.accent,
        unselectedItemColor: colors.textMuted,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 11),
        unselectedLabelStyle: GoogleFonts.montserrat(fontWeight: FontWeight.w500, fontSize: 10),
      ),
    );
  }
}
