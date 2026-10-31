import 'package:flutter/material.dart';

/// Design token system for Royal Pixels.
/// Contains both the luxury Royal Gold Dark identity and the Apple Liquid Glass
/// system tokens for both Dark and Light themes.
class AppColors {
  AppColors._(); // non-instantiable

  // ── Royal Pixels Dark Backgrounds (layered depth) ─────────────────────────
  /// Deepest background — body/scaffold
  static const Color bg0 = Color(0xFF080B12);

  /// Surface layer — cards, list tiles
  static const Color bg1 = Color(0xFF0F1420);

  /// Elevated surface — drawers, bottom sheets, dialogs
  static const Color bg2 = Color(0xFF161C2D);

  /// Highest elevated surface — popovers, overlays
  static const Color bg3 = Color(0xFF1E2740);

  // ── Gold brand palette ────────────────────────────────────────────────────
  /// Light gold — text highlights, shimmer, tab indicators
  static const Color goldLight = Color(0xFFFDDB6A);

  /// Mid gold — primary buttons, active states, progress
  static const Color goldMid = Color(0xFFD4A017);

  /// Primary color alias
  static const Color primary = goldMid;

  /// Deep gold — borders, badge outlines, icons on gold surfaces
  static const Color goldDeep = Color(0xFF9B7000);

  /// Gold gradient — from light to mid
  static const LinearGradient goldGradient = LinearGradient(
    colors: [goldLight, goldMid],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Deep gold gradient — for borders/rings
  static const LinearGradient goldRingGradient = LinearGradient(
    colors: [goldLight, goldDeep],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Brand Royal & Liquid Accents (from Royal Spend) ───────────────────────
  static const Color royalIndigo = Color(0xFF6366F1);
  static const Color royalIndigoLight = Color(0xFF818CF8);
  static const Color electricCyan = Color(0xFF38BDF8);
  static const Color vividMint = Color(0xFF10B981);
  static const Color roseExpense = Color(0xFFF43F5E);
  static const Color amberWarning = Color(0xFFF59E0B);
  static const Color violetAccent = Color(0xFF8B5CF6);

  // ── Apple iOS Dark Mode System Tokens (OLED & High FPS Reference) ─────────
  static const Color darkBackground = Color(0xFF000000); // True OLED Pure Black
  static const Color darkBackgroundSecondary = Color(0xFF1C1C1E); // Apple Secondary System Grouped
  static const Color darkCard = Color(0xFF1C1C1E); // Grouped Card Surface
  static const Color darkSurface = Color(0xFF2C2C2E); // Apple Tertiary System Fill
  static const Color darkElevated = Color(0xFF3A3A3C); // Apple Quaternary System Fill
  static const Color darkSeparator = Color(0xFF38383A); // Apple Hairline Separator
  static const Color darkGlassSurface = Color(0xFF1C1C1E);
  static const Color darkGlassHighlight = Color(0x1FFFFFFF); // Subtle Hairline Specular Rim
  static const Color darkGlassCard = Color(0xFF1C1C1E);
  static const Color darkTextPrimary = Color(0xFFFFFFFF); // Pure Crisp White
  static const Color darkTextSecondary = Color(0xFF8E8E93); // Apple System Gray (Secondary)
  static const Color darkTextMuted = Color(0xFF636366); // Apple System Gray 2 (Tertiary)

  // ── Apple System Vibrant Accents ──────────────────────────────────────────
  static const Color appleBlue = Color(0xFF0A84FF);
  static const Color appleGreen = Color(0xFF30D158);
  static const Color appleRed = Color(0xFFFF453A);
  static const Color appleOrange = Color(0xFFFF9F0A);
  static const Color appleYellow = Color(0xFFFFD60A);
  static const Color applePurple = Color(0xFFBF5AF2);
  static const Color appleIndigo = Color(0xFF5E5CE6);
  static const Color appleTeal = Color(0xFF64D2FF);
  static const Color appleGray = Color(0xFF8E8E93);

  // ── Light Frosted Palette (Royal Spend Apple Light Design) ─────────────────
  static const Color lightBackground = Color(0xFFF2F2F7); // Apple System Grouped Background Light
  static const Color lightBackgroundSecondary = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFF8FAFC);
  static const Color lightElevated = Color(0xFFFFFFFF);
  static const Color lightSeparator = Color(0xFFE5E5EA);
  static const Color lightGlassSurface = Color(0xCCFFFFFF);
  static const Color lightGlassHighlight = Color(0x80FFFFFF);
  static const Color lightGlassCard = Color(0xFFFFFFFF);
  static const Color lightTextPrimary = Color(0xFF0F172A); // Rich dark slate
  static const Color lightTextSecondary = Color(0xFF6C6C70); // Crisp medium gray
  static const Color lightTextMuted = Color(0xFF8E8E93); // Subtle muted gray

  // ── Default Dark Text ─────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFF1F5F9);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF475569);

  // ── UI helpers ────────────────────────────────────────────────────────────
  /// Subtle white for glass borders
  static const Color glassBorder = Color(0x28FFFFFF); // white @ ~16%
  /// Subtle white for glass fill
  static const Color glassFill = Color(0x12FFFFFF); // white @ ~7%
  /// dividers / separators
  static const Color divider = Color(0x1FFFFFFF); // white @ ~12%

  // ── Special / Exclusive tier ──────────────────────────────────────────────
  /// Violet-to-pink gradient for "Special" wallpaper badges
  static const Color accentPurple = Color(0xFF7C3AED);
  static const Color accentPink = Color(0xFFDB2777);
  static const LinearGradient specialGradient = LinearGradient(
    colors: [Color(0xFF7C3AED), Color(0xFFDB2777)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Trending gradient — fiery orange/red for trending items
  static const LinearGradient trendingGradient = LinearGradient(
    colors: [Color(0xFFFF8C00), Color(0xFFFF2D00)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Liquid Glass Gradients (from Royal Spend) ─────────────────────────────
  static const LinearGradient royalGradient = LinearGradient(
    colors: [royalIndigo, electricCyan],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient royalGoldGradient = LinearGradient(
    colors: [goldLight, goldMid, royalIndigo],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient expenseGradient = LinearGradient(
    colors: [Color(0xFFFB7185), roseExpense],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient incomeGradient = LinearGradient(
    colors: [Color(0xFF34D399), vividMint],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkCardGradient = LinearGradient(
    colors: [
      Color(0x33334155),
      Color(0x1A1E293B),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient lightCardGradient = LinearGradient(
    colors: [
      Color(0xE6FFFFFF),
      Color(0xB3F8FAFC),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
