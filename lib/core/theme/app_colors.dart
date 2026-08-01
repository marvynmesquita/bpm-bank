import 'package:flutter/material.dart';

class AppColors {
  final Color bg;
  final Color surface;
  final Color cardBg;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color accent;
  final Color accentLight;
  final Color border;
  final Brightness brightness;

  const AppColors({
    required this.bg,
    required this.surface,
    required this.cardBg,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accent,
    required this.accentLight,
    required this.border,
    required this.brightness,
  });

  static const dark = AppColors(
    bg: Color(0xFF0D0D0D),
    surface: Color(0xFF1A1A2E),
    cardBg: Color(0xFF1A1A2E),
    textPrimary: Colors.white,
    textSecondary: Color(0xFF9E9E9E),
    textMuted: Color(0xFF616161),
    accent: Color(0xFFFF6B35),
    accentLight: Color(0xFFFF8F65),
    border: Color(0x10FFFFFF),
    brightness: Brightness.dark,
  );

  static const light = AppColors(
    bg: Color(0xFFF7F7FA),
    surface: Colors.white,
    cardBg: Colors.white,
    textPrimary: Color(0xFF1A1A2E),
    textSecondary: Color(0xFF666680),
    textMuted: Color(0xFFAAAAAA),
    accent: Color(0xFFFF6B35),
    accentLight: Color(0xFFFF8F65),
    border: Color(0x12000000),
    brightness: Brightness.light,
  );
}
