import 'package:flutter/material.dart';

class AppAnimations {
  // ── Durations ──────────────────────────────────────────────────────────────
  static const Duration premiumTransition = Duration(milliseconds: 650);
  static const Duration smoothEntrance = Duration(milliseconds: 800);
  static const Duration staggeringDelay = Duration(milliseconds: 45);
  static const Duration interactionQuick = Duration(milliseconds: 300);
  static const Duration interactionSlow = Duration(milliseconds: 450);

  // ── Curves ────────────────────────────────────────────────────────────────
  // Premium curve: Starts with energy, finishes with elegant deceleration
  static const Curve premiumCurve = Curves.fastLinearToSlowEaseIn;
  
  // Deceleration curve for grid items and entrance
  static const Curve easeOutExpo = Cubic(0.16, 1, 0.3, 1);
  
  // Standard ease out for simple transitions
  static const Curve smoothCurve = Curves.easeOutQuart;

  // ── Values ────────────────────────────────────────────────────────────────
  static const double pageScaleBegin = 0.92;
  static const double cardSlideOffset = 0.12;
}
