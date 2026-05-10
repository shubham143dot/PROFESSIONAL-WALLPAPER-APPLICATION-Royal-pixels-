import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:royal_pixels/core/services/adaptive_performance.dart';

/// A premium, velocity-aware liquid transition for wallpaper previews.
/// Implements depth, backdrop blur, and momentum-based timing.
class LiquidTransitionPage<T> extends CustomTransitionPage<T> {
  final double scrollVelocity;

  LiquidTransitionPage({
    required super.child,
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
    this.scrollVelocity = 0.0,
  }) : super(
          transitionDuration: _calculateDuration(scrollVelocity),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          opaque: false, // Essential for seeing the previous page scale down
          barrierColor: Colors.black54,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return _LiquidTransitionBuilder(
              animation: animation,
              secondaryAnimation: secondaryAnimation,
              scrollVelocity: scrollVelocity,
              child: child,
            );
          },
        );

  static Duration _calculateDuration(double velocity) {
    // Dynamic duration based on scroll momentum
    final double v = velocity.abs();
    // Fast scroll (v > 2000) -> 240ms, Idle (v = 0) -> 450ms
    final double durationMs = (450 - (v / 2500 * 210)).clamp(240, 450);
    return Duration(milliseconds: durationMs.toInt());
  }
}

class _LiquidTransitionBuilder extends StatelessWidget {
  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final double scrollVelocity;
  final Widget child;

  const _LiquidTransitionBuilder({
    required this.animation,
    required this.secondaryAnimation,
    required this.scrollVelocity,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final bool enableBlur = AdaptivePerformance.enableBackdropBlur;

    // Premium deceleration curve for the main animation
    final Animation<double> curvedAnimation = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutQuart,
      reverseCurve: Curves.easeInQuart,
    );

    // Spring curve for liquid overshoot effect (used for scale)
    final Animation<double> springAnimation = CurvedAnimation(
      parent: animation,
      curve: const _LiquidSpringCurve(),
    );

    return ScaleTransition(
      scale: Tween<double>(begin: 1.0, end: 0.94).animate(
        CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeInOutCubic),
      ),
      child: FadeTransition(
        opacity: Tween<double>(begin: 1.0, end: 0.5).animate(
          CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeInOutCubic),
        ),
        child: Stack(
          children: [
            // Background Dimmer + Blur
            // Performance optimization: Fade a FIXED blur rather than animating the sigma.
            // Animating sigma causes expensive GPU kernel recomputations every frame.
            if (enableBlur)
              FadeTransition(
                opacity: animation,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.45),
                  ),
                ),
              )
            else
              FadeTransition(
                opacity: animation,
                child: Container(
                  color: Colors.black.withValues(alpha: 0.75),
                ),
              ),
            
            // Morphing content with Scale + Liquid feel + Parallax
            RepaintBoundary(
              child: AnimatedBuilder(
                animation: animation,
                builder: (context, _) {
                  // Scale: 0.88 -> 1.02 -> 1.0 (refined starting scale)
                  final double scale = 0.88 + (0.12 * springAnimation.value);
                  
                  // Fade in with a slightly delayed start for focus
                  final double opacity = CurvedAnimation(
                    parent: animation,
                    curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
                  ).value;

                  // Subtle parallax: slide up from 80px below
                  final double parallaxY = 80 * (1.0 - curvedAnimation.value);

                  return Opacity(
                    opacity: opacity,
                    child: Transform.translate(
                      offset: Offset(0, parallaxY),
                      child: Transform.scale(
                        scale: scale,
                        alignment: Alignment.center,
                        child: child,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom curve that implements a spring-like liquid motion with overshoot.
/// Designed to reach ~1.02 at t=0.8 and settle to 1.0 at t=1.0.
class _LiquidSpringCurve extends Curve {
  const _LiquidSpringCurve();

  @override
  double transformInternal(double t) {
    if (t == 0) return 0;
    if (t == 1) return 1;
    
    // Spring formula: f(t) = 1 - e^(-5t) * cos(8t)
    // We want a more aggressive overshoot for the "liquid" feel
    const double damping = 4.5;
    const double period = 7.0;
    
    // Normalize result so it ends exactly at 1.0
    // The raw formula oscillates around 1.
    return 1 - (math.exp(-damping * t) * math.cos(period * t));
  }
}
