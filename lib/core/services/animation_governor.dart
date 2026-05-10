import 'package:flutter/material.dart';
import 'adaptive_performance.dart';

enum AnimationQuality { full, reduced, none }

class AnimationGovernor {
  static AnimationQuality getQuality() {
    if (AdaptivePerformance.isLow) return AnimationQuality.none;
    if (AdaptivePerformance.isStandard) return AnimationQuality.reduced;
    return AnimationQuality.full;
  }

  static Duration getDuration(Duration base, AnimationQuality quality) {
    switch (quality) {
      case AnimationQuality.full:
        return base;
      case AnimationQuality.reduced:
        return base * 0.5; // Faster animations to save GPU time
      case AnimationQuality.none:
        return Duration.zero;
    }
  }

  static Curve getCurve(Curve base, AnimationQuality quality) {
    if (quality == AnimationQuality.none) return Curves.linear;
    return base;
  }
}
