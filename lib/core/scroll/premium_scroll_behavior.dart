import 'package:flutter/material.dart';
import 'dart:ui';
import 'elite_scroll_physics.dart';

/// Global ScrollBehavior that enforces iOS-like scrolling everywhere.
///
/// Applied at the MaterialApp level to ensure every ScrollView, ListView,
/// GridView, and CustomScrollView uses the same premium physics.
///
/// Key behaviors:
/// - Removes Android overscroll glow (the blue/green edge effect)
/// - Applies [PremiumScrollPhysics] on all platforms
/// - Supports all pointer devices (touch, mouse, trackpad)
class PremiumScrollBehavior extends ScrollBehavior {
  const PremiumScrollBehavior();

  // ── Remove glow effect ────────────────────────────────────────────────────
  // Android's default glow is distracting and looks dated.
  // We replace it with elastic overscroll (iOS-style).
  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    // Return child directly — no glow, no stretch indicator.
    // The elastic bounce from PremiumScrollPhysics handles overscroll feedback.
    return child;
  }

  // ── Platform-adaptive physics ─────────────────────────────────────────────
  // Force iOS-style physics on ALL platforms, including Android.
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const EliteScrollPhysics();
  }

  // ── Pointer device support ────────────────────────────────────────────────
  // Enable scrolling from all input devices for accessibility
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}
