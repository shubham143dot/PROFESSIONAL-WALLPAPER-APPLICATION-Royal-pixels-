import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  // ── Headings ──────────────────────────────────────────────────────────────
  static TextStyle displayLarge = GoogleFonts.outfit(
    fontSize: 34,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.8,
    height: 1.2,
  );

  static TextStyle displayMedium = GoogleFonts.outfit(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
    height: 1.25,
  );

  static TextStyle titleLarge = GoogleFonts.outfit(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.4,
    height: 1.3,
  );

  static TextStyle titleMedium = GoogleFonts.outfit(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    height: 1.35,
  );

  // ── Body Text ─────────────────────────────────────────────────────────────
  static TextStyle bodyLarge = GoogleFonts.outfit(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.2,
    height: 1.45,
  );

  static TextStyle bodyMedium = GoogleFonts.outfit(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.1,
    height: 1.4,
  );

  static TextStyle bodySmall = GoogleFonts.outfit(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.35,
  );

  // ── Labels & Badges ───────────────────────────────────────────────────────
  static TextStyle labelUppercase = GoogleFonts.outfit(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.1,
    height: 1.2,
  );

  static TextStyle currencyNumber = GoogleFonts.outfit(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.0,
    height: 1.1,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  static TextStyle currencySmall = GoogleFonts.outfit(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  // Helper getters for themed colors
  static TextStyle getThemed(TextStyle base, {required bool isDark, Color? colorOverride}) {
    return base.copyWith(
      color: colorOverride ?? (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
    );
  }
}
