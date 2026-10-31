import 'package:flutter/material.dart';
import 'app_colors.dart';

class GlassDecorations {
  static const double defaultBlurSigma = 22.0;
  static const double modalBlurSigma = 26.0;
  static const double pillBlurSigma = 16.0;
  static const double defaultBorderRadius = 24.0;
  static const double pillBorderRadius = 40.0;

  /// High-end liquid iOS glassmorphic card decoration with specular rim highlights.
  static BoxDecoration glassCardDecoration({
    required bool isDark,
    double borderRadius = defaultBorderRadius,
    Color? customBorderColor,
    Gradient? customGradient,
    bool highContrast = false,
  }) {
    if (isDark) {
      // Official Apple iOS Dark Mode: Secondary System Grouped Surface (#1C1C1E / #0F1420)
      // Solid rendering with 0.6px specular hairline rim for 120 FPS butter-smooth scroll
      return BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        color: customGradient == null ? AppColors.bg1 : null,
        gradient: customGradient,
        border: Border.all(
          color: customBorderColor ?? AppColors.darkGlassHighlight,
          width: 0.6,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 18,
            spreadRadius: 0,
            offset: Offset(0, 4),
          ),
        ],
      );
    }

    final Color defaultBorder = highContrast
        ? const Color(0xFF64748B)
        : const Color(0xEBFFFFFF);

    return BoxDecoration(
      borderRadius: BorderRadius.circular(borderRadius),
      color: highContrast ? const Color(0xFFFFFFFF) : null,
      gradient: highContrast
          ? null
          : (customGradient ??
              const LinearGradient(
                colors: [
                  Color(0xE0FFFFFF),
                  Color(0xB8F8FAFC),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )),
      border: Border.all(
        color: customBorderColor ?? defaultBorder,
        width: highContrast ? 1.5 : 1.0,
      ),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF64748B).withValues(alpha: highContrast ? 0.22 : 0.10),
          blurRadius: highContrast ? 16 : 24,
          spreadRadius: 0,
          offset: const Offset(0, 8),
        ),
        if (!highContrast)
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.85),
            blurRadius: 10,
            spreadRadius: -1,
            offset: const Offset(0, -2),
          ),
      ],
    );
  }

  /// Floating pill decoration for bars, segmented controls, and badges.
  static BoxDecoration floatingBarDecoration({
    required bool isDark,
    bool highContrast = false,
  }) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(pillBorderRadius),
      color: highContrast
          ? (isDark ? AppColors.darkCard : const Color(0xFFFFFFFF))
          : (isDark ? AppColors.bg1 : null),
      gradient: highContrast || isDark
          ? null
          : const LinearGradient(
              colors: [
                Color(0xE6FFFFFF),
                Color(0xCCF8FAFC),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
      border: Border.all(
        color: highContrast
            ? (isDark ? Colors.white : const Color(0xFF334155))
            : (isDark ? AppColors.darkGlassHighlight : const Color(0x66CBD5E1)),
        width: highContrast ? 1.8 : 0.6,
      ),
      boxShadow: [
        BoxShadow(
          color: isDark
              ? Colors.black.withValues(alpha: 0.5)
              : const Color(0xFF334155).withValues(alpha: 0.18),
          blurRadius: 30,
          spreadRadius: 2,
          offset: const Offset(0, 10),
        ),
      ],
    );
  }

  /// Liquid frosted glass pill decoration for chips, badges, and filter buttons.
  static BoxDecoration glassPillDecoration({
    required bool isDark,
    bool isSelected = false,
    Color? activeColor,
    double borderRadius = 20.0,
    bool highContrast = false,
  }) {
    final effectiveActive = activeColor ?? (isDark ? AppColors.goldMid : AppColors.royalIndigo);

    if (isSelected) {
      return BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        color: isDark
            ? effectiveActive.withValues(alpha: 0.28)
            : effectiveActive.withValues(alpha: 0.16),
        border: Border.all(
          color: effectiveActive.withValues(alpha: isDark ? 0.90 : 0.75),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: effectiveActive.withValues(alpha: isDark ? 0.35 : 0.20),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      );
    }

    if (isDark) {
      // Apple Dark Mode Pill: Tertiary Fill (#2C2C2E / #161C2D)
      return BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        color: AppColors.bg2,
        border: Border.all(
          color: const Color(0x1AFFFFFF),
          width: 0.6,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 6,
            offset: Offset(0, 1),
          ),
        ],
      );
    }

    return BoxDecoration(
      borderRadius: BorderRadius.circular(borderRadius),
      color: highContrast
          ? const Color(0xFFFFFFFF)
          : Colors.white.withValues(alpha: 0.60),
      border: Border.all(
        color: highContrast
            ? const Color(0xFF64748B)
            : Colors.white.withValues(alpha: 0.85),
        width: 1.0,
      ),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF64748B).withValues(alpha: 0.08),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  /// Liquid modal bottom sheet decoration with top specular glass highlight.
  static BoxDecoration glassModalDecoration({
    required bool isDark,
    double topRadius = 28.0,
    bool highContrast = false,
  }) {
    if (isDark) {
      return BoxDecoration(
        color: AppColors.bg1,
        borderRadius: BorderRadius.vertical(top: Radius.circular(topRadius)),
        border: Border.all(color: AppColors.darkGlassHighlight, width: 0.8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x99000000),
            blurRadius: 40,
            spreadRadius: 2,
            offset: Offset(0, -8),
          ),
        ],
      );
    }

    final sheetBg = highContrast
        ? const Color(0xFFFFFFFF)
        : Colors.white.withValues(alpha: 0.94);

    final borderColor = highContrast
        ? const Color(0xFF64748B)
        : Colors.white.withValues(alpha: 0.95);

    return BoxDecoration(
      color: sheetBg,
      borderRadius: BorderRadius.vertical(top: Radius.circular(topRadius)),
      border: Border.all(color: borderColor, width: 1.2),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.16),
          blurRadius: 40,
          spreadRadius: 2,
          offset: const Offset(0, -8),
        ),
      ],
    );
  }

  /// Liquid glass tile decoration for rows and settings list items.
  static BoxDecoration glassTileDecoration({
    required bool isDark,
    double borderRadius = 16.0,
    bool highContrast = false,
  }) {
    if (isDark) {
      return BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        color: AppColors.bg1,
        border: Border.all(
          color: const Color(0x1AFFFFFF),
          width: 0.6,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x44000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      );
    }

    return BoxDecoration(
      borderRadius: BorderRadius.circular(borderRadius),
      color: highContrast
          ? const Color(0xFFFFFFFF)
          : Colors.white.withValues(alpha: 0.70),
      border: Border.all(
        color: highContrast
            ? const Color(0xFF64748B)
            : Colors.white.withValues(alpha: 0.88),
        width: 1.0,
      ),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF64748B).withValues(alpha: 0.07),
          blurRadius: 14,
          offset: const Offset(0, 4),
        ),
        if (!highContrast)
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.7),
            blurRadius: 6,
            offset: const Offset(0, -1),
          ),
      ],
    );
  }

  static BoxDecoration circularPlusButtonDecoration() {
    return BoxDecoration(
      shape: BoxShape.circle,
      gradient: AppColors.goldGradient,
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.45),
        width: 1.5,
      ),
      boxShadow: [
        BoxShadow(
          color: AppColors.goldMid.withValues(alpha: 0.5),
          blurRadius: 18,
          spreadRadius: 2,
          offset: const Offset(0, 6),
        ),
        BoxShadow(
          color: AppColors.goldLight.withValues(alpha: 0.3),
          blurRadius: 12,
          spreadRadius: -1,
          offset: const Offset(0, -2),
        ),
      ],
    );
  }
}
