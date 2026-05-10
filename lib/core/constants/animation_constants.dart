import 'package:flutter/material.dart';

class AppAnimations {
  // ── Durations ──────────────────────────────────────────────────────────────
  static const Duration premiumTransition = Duration(milliseconds: 500);
  static const Duration smoothEntrance = Duration(milliseconds: 350);
  static const Duration staggeringDelay = Duration(milliseconds: 35);
  static const Duration interactionQuick = Duration(milliseconds: 200);
  static const Duration interactionSlow = Duration(milliseconds: 350);

  // ── Curves ────────────────────────────────────────────────────────────────
  // Premium curve: Starts with energy, finishes with elegant deceleration
  static const Curve premiumCurve = Curves.fastLinearToSlowEaseIn;

  // Deceleration curve for grid items and entrance
  static const Curve easeOutExpo = Cubic(0.16, 1, 0.3, 1);

  // Standard ease out for simple transitions
  static const Curve smoothCurve = Curves.easeOutQuart;

  // ── Values ────────────────────────────────────────────────────────────────
  static const double pageScaleBegin = 0.94;
  static const double cardSlideOffset = 0.06;

  // ── Grid Animation ────────────────────────────────────────────────────────
  /// Maximum number of cards that get the stagger entrance animation.
  /// Cards beyond this index appear instantly — avoids absurd delays.
  static const int maxStaggerCards = 8;
}
