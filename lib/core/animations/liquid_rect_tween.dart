import 'package:flutter/material.dart';

/// A custom RectTween that uses spring physics for a liquid feel.
class LiquidSpringRectTween extends RectTween {
  LiquidSpringRectTween({super.begin, super.end});

  @override
  Rect? lerp(double t) {
    if (t == 0) return begin;
    if (t == 1) return end;

    // Use a custom spring-like curve for the lerp
    // cubicBezier(0.2, 0.8, 0.2, 1) is requested for easing
    final double curvedT = const Cubic(0.2, 0.8, 0.2, 1.0).transform(t);
    
    return Rect.lerp(begin, end, curvedT);
  }
}
