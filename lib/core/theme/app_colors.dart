import 'package:flutter/material.dart';

/// Design token system for Royal Pixels.
/// All colors should be referenced from here — never hardcode hex values inline.
class AppColors {
  AppColors._(); // non-instantiable

  // ── Backgrounds (layered depth) ───────────────────────────────────────────
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

  // ── Text ──────────────────────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFFF1F5F9);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted     = Color(0xFF475569);

  // ── UI helpers ────────────────────────────────────────────────────────────
  /// Subtle white for glass borders
  static const Color glassBorder   = Color(0x28FFFFFF); // white @ ~16%
  /// Subtle white for glass fill
  static const Color glassFill     = Color(0x12FFFFFF); // white @ ~7%
  /// dividers / separators
  static const Color divider       = Color(0x1FFFFFFF); // white @ ~12%

  // ── Special / Exclusive tier ──────────────────────────────────────────────
  /// Violet-to-pink gradient for "Special" wallpaper badges
  static const Color accentPurple      = Color(0xFF7C3AED);
  static const Color accentPink        = Color(0xFFDB2777);
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
}
