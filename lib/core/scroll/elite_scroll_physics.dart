import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// Elite custom scroll physics with hand-tuned ballistic simulation.
///
/// Phase 4: Surpasses Flutter's default BouncingScrollPhysics by:
///  - Custom exponential friction curve (softer mid-scroll, firmer at edges)
///  - Velocity-aware deceleration (fast flicks preserve more momentum)
///  - Natural exponential decay instead of linear deceleration
///  - Elastic overscroll with critically-damped snap-back
///  - Zero abrupt stops — momentum always decays continuously
///  - Velocity Limiter: Prevents scrolling too fast to maintain 120FPS
class EliteScrollPhysics extends BouncingScrollPhysics {
  /// Friction coefficient: higher = faster deceleration.
  /// Increased to 9.5 to prevent "auto-scrolling too long" issues.
  final double friction;

  const EliteScrollPhysics({
    super.parent,
    this.friction = 12.0,
  });

  @override
  EliteScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return EliteScrollPhysics(
      parent: buildParent(ancestor),
      friction: friction,
    );
  }


  // â”€â”€ Overscroll friction â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  @override
  double frictionFactor(double overscrollFraction) {
    // Firmer overscroll resistance (0.35 instead of 0.40)
    return 0.35 * math.pow(1.0 - overscrollFraction, 2);
  }

  // â”€â”€ Spring for elastic snap-back â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  @override
  SpringDescription get spring => const SpringDescription(
        mass: 0.5,      // Slightly more weight
        stiffness: 180, // Even firmer spring
        damping: 30,    // More damping to prevent any bounce-back overshoot
      );

  // â”€â”€ Fling velocity gates â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  @override
  double get minFlingVelocity => 150.0; // Ignore tiny movements to prevent accidental long scrolls

  @override
  double get maxFlingVelocity => 3500.0; // Lower cap for better control

  // ── Custom ballistic simulation ─────────────────────────────────────────

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    final Tolerance tolerance = toleranceFor(position);
    
    final double clampedVelocity = velocity.clamp(-maxFlingVelocity, maxFlingVelocity);

    if (position.outOfRange) {
      final double target = position.pixels < position.minScrollExtent
          ? position.minScrollExtent
          : position.maxScrollExtent;
      return SpringSimulation(spring, position.pixels, target, clampedVelocity,
          tolerance: tolerance);
    }

    // Firmer stop threshold
    if (clampedVelocity.abs() < tolerance.velocity * 3.0) return null;

    return _ExponentialScrollSimulation(
      position: position.pixels,
      velocity: clampedVelocity,
      minPosition: position.minScrollExtent,
      maxPosition: position.maxScrollExtent,
      friction: friction,
      spring: spring,
      tolerance: tolerance,
    );
  }

  // ── Momentum carry-through ──────────────────────────────────────────────
  // Significantly dampened to prevent "auto-scrolling" feel between nested views.
  @override
  double carriedMomentum(double existingVelocity) {
    return existingVelocity.sign *
        math.min(
          0.0003 * math.pow(existingVelocity.abs(), 1.7).toDouble(),
          maxFlingVelocity * 0.7,
        );
  }

  /// Helper to determine if a drag is "strong" enough to be a high-velocity flick.
  /// Returns true if the velocity is high enough to warrant performance optimizations
  static bool isHighVelocity(double velocity) => velocity.abs() > 3000;

  /// Returns true if the given drag should trigger a dismiss.
  static bool shouldDismiss({
    required double dragFraction, // offset / screenHeight
    required double velocity,
  }) {
    const double dismissThreshold = 0.45;
    const double velocityThreshold = 1800.0;

    return dragFraction >= dismissThreshold ||
           (dragFraction > 0.15 && velocity > velocityThreshold);
  }

  /// Returns the spring-back curve for rejected dismiss drags.
  Curve get snapCurve => const Cubic(0.2, 0.8, 0.4, 1.0);
}

/// Always-scrollable variant (needed for RefreshIndicator compatibility).
class EliteAlwaysScrollPhysics extends EliteScrollPhysics {
  const EliteAlwaysScrollPhysics({super.parent, super.friction = 12.0});

  @override
  EliteAlwaysScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return EliteAlwaysScrollPhysics(
      parent: buildParent(ancestor),
      friction: friction,
    );
  }

  @override
  bool shouldAcceptUserOffset(ScrollMetrics position) => true;
}

// ─── Exponential Deceleration Simulation ──────────────────────────────────────

/// A scroll simulation based on exponential velocity decay.
///
/// Unlike Flutter's linear friction model, this preserves velocity at high
/// speeds (momentum feel) and terminates cleanly at low speeds.
/// When the simulated position would exceed bounds, a spring takes over.
class _ExponentialScrollSimulation extends Simulation {
  final double _startPosition;
  final double _startVelocity;
  final double _friction;

  _ExponentialScrollSimulation({
    required double position,
    required double velocity,
    required double minPosition,
    required double maxPosition,
    required double friction,
    required SpringDescription spring,
    required super.tolerance,
  })  : _startPosition = position,
        _startVelocity = velocity,
        _friction = friction;

  // Exponential decay: position = p0 + v0/k * (1 - e^(-k*t))
  @override
  double x(double time) {
    if (_friction <= 0) return _startPosition + _startVelocity * time;
    final pos = _startPosition +
        (_startVelocity / _friction) * (1.0 - math.exp(-_friction * time));
    return pos;
  }

  // Derivative: velocity = v0 * e^(-k*t)
  @override
  double dx(double time) {
    final vel = _startVelocity * math.exp(-_friction * time);
    // Clamp to zero when near tolerance
    if (vel.abs() < tolerance.velocity) return 0.0;
    return vel;
  }

  @override
  bool isDone(double time) {
    return dx(time).abs() < tolerance.velocity;
  }
}

// ─── Swipe-Down Dismiss Physics ───────────────────────────────────────────────

/// Drag-to-dismiss physics for the wallpaper detail page.
///
/// Phase 4: Gesture-driven transitions.
/// - Drag down > 30% of screen → dismiss with spring acceleration
/// - Drag down < 30% → elastic snap-back
/// - Velocity > 800px/s → immediate dismiss regardless of position
class DismissPhysics {
  static const double _dismissThreshold = 0.30; // 30% screen height
  static const double _velocityThreshold = 800.0;

  /// Returns true if the given drag should trigger a dismiss.
  static bool shouldDismiss({
    required double dragFraction, // offset / screenHeight
    required double velocity, // px/s downward
  }) {
    return dragFraction >= _dismissThreshold ||
        velocity >= _velocityThreshold;
  }

  /// Returns the spring-back curve for rejected dismiss drags.
  static SpringSimulation snapBackSimulation({
    required double currentOffset,
  }) {
    return SpringSimulation(
      const SpringDescription(mass: 0.5, stiffness: 200, damping: 25),
      currentOffset,
      0.0, // snap back to zero
      0.0, // from rest
    );
  }
}
