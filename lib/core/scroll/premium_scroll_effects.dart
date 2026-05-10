import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'velocity_aware_controller.dart';
import '../services/adaptive_performance.dart';

// ─── Parallax Depth Item ──────────────────────────────────────────────────────

/// Layout-based parallax depth effect for grid items.
///
/// Phase 2: NO gyroscope — uses the item's position within the viewport
/// to compute a subtle vertical offset. Items near the top of the viewport
/// translate slightly up; items at the bottom translate slightly down.
/// Maximum offset: [AdaptivePerformance.parallaxDepth]% of item height.
///
/// This creates the illusion that items exist at different Z-depths
/// without any sensor input or expensive transforms.
///
/// Performance notes:
///  - Uses a single [Transform.translate] — GPU-composited, no layout pass.
///  - [FilterQuality.none] on Transform = no texture sampling overhead.
///  - Disabled automatically on low-end devices via [AdaptivePerformance].
///  - Pauses (clamps to 0) during fast scroll for pure rendering throughput.
class ParallaxDepthItem extends StatelessWidget {
  final Widget child;
  final ScrollController? scrollController;

  /// Depth multiplier 0.0–1.0 (relative importance in Z-space).
  /// Higher = more movement. Default 1.0.
  final double depthFactor;

  const ParallaxDepthItem({
    super.key,
    required this.child,
    this.scrollController,
    this.depthFactor = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    if (!AdaptivePerformance.enableParallax || scrollController == null) {
      return child;
    }

    return _LayoutParallax(
      scrollController: scrollController!,
      depthFactor: depthFactor,
      child: child,
    );
  }
}

class _LayoutParallax extends StatefulWidget {
  final Widget child;
  final ScrollController scrollController;
  final double depthFactor;

  const _LayoutParallax({
    required this.child,
    required this.scrollController,
    required this.depthFactor,
  });

  @override
  State<_LayoutParallax> createState() => _LayoutParallaxState();
}

class _LayoutParallaxState extends State<_LayoutParallax> {
  double _parallaxOffset = 0.0;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_updateOffset);
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_updateOffset);
    super.dispose();
  }

  void _updateOffset() {
    if (!mounted) return;

    // Phase 7 Fix: Removed the early return during scroll.
    // Parallax should be active DURING scroll. Setting it to 0 during scroll 
    // and then jumping to a calculated value on stop caused a visible flicker.
    // We still skip if performance is extremely low, but otherwise we calculate.

    // Find this item's position in the viewport
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.attached) return;

    final viewportHeight = MediaQuery.sizeOf(context).height;
    final itemGlobalTop = renderBox.localToGlobal(Offset.zero).dy;
    final itemHeight = renderBox.size.height;

    // Normalized position: -1.0 (above viewport) to 1.0 (below viewport)
    final itemCenter = itemGlobalTop + itemHeight / 2;
    final viewportCenter = viewportHeight / 2;
    final normalizedPos = (itemCenter - viewportCenter) / viewportHeight;

    // Parallax offset calculation
    final maxOffset = itemHeight * AdaptivePerformance.parallaxDepth * widget.depthFactor;
    final newOffset = (normalizedPos * maxOffset).clamp(-maxOffset, maxOffset);

    // Only rebuild if the change is significant to save cycles
    if ((newOffset - _parallaxOffset).abs() > 0.5) {
      setState(() => _parallaxOffset = newOffset);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(0, _parallaxOffset),
      filterQuality: ui.FilterQuality.none,
      child: widget.child,
    );
  }
}

// ─── Focus Scale Item ─────────────────────────────────────────────────────────

/// Focus-driven scale effect for grid items.
///
/// Phase 2: Items near the viewport center scale up slightly (1.0 → max 1.03).
/// Items near the edges scale down (1.0 → 0.97).
/// Creates a shadow depth-of-field / spotlight effect that guides the eye.
///
/// Disabled automatically on low-end devices.
class FocusScaleItem extends StatefulWidget {
  final Widget child;
  final ScrollController? scrollController;

  const FocusScaleItem({
    super.key,
    required this.child,
    this.scrollController,
  });

  @override
  State<FocusScaleItem> createState() => _FocusScaleItemState();
}

class _FocusScaleItemState extends State<FocusScaleItem> {
  double _scale = 1.0;

  @override
  void initState() {
    super.initState();
    if (AdaptivePerformance.enableFocusScale) {
      widget.scrollController?.addListener(_updateScale);
    }
  }

  @override
  void dispose() {
    widget.scrollController?.removeListener(_updateScale);
    super.dispose();
  }

  void _updateScale() {
    if (!mounted) return;

    // Phase 7 Fix: Removed early return during scroll to prevent stop-flicker.
    
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.attached) return;

    final viewportHeight = MediaQuery.sizeOf(context).height;
    final itemGlobalTop = renderBox.localToGlobal(Offset.zero).dy;
    final itemHeight = renderBox.size.height;
    final itemCenter = itemGlobalTop + itemHeight / 2;

    // Distance from viewport center (0 = dead center)
    final distFromCenter =
        ((itemCenter - viewportHeight / 2) / viewportHeight).abs();

    // Scale calculation with smoothstep
    final t = (1.0 - (distFromCenter * 2.5).clamp(0.0, 1.0));
    final smoothT = t * t * (3.0 - 2.0 * t); 

    final maxScale = AdaptivePerformance.focusScaleMax;
    final newScale = 1.0 + (maxScale - 1.0) * smoothT;

    if ((newScale - _scale).abs() > 0.003) {
      setState(() => _scale = newScale);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!AdaptivePerformance.enableFocusScale ||
        widget.scrollController == null) {
      return widget.child;
    }

    return Transform.scale(
      scale: _scale,
      filterQuality: ui.FilterQuality.none,
      child: widget.child,
    );
  }
}

// ─── Velocity-Adaptive Scroll Item ────────────────────────────────────────────

/// Combines parallax + focus scale into a single wrapper.
/// Used by grid items for maximum premium feel with minimal widget nesting.
///
/// Phase 2: Premium perception engine.
class PremiumScrollItem extends StatelessWidget {
  final Widget child;
  final bool enableParallax;
  final bool enableFocusScale;
  final bool enableEdgeFade; // Kept for API compat — deprecated

  /// Optional velocity controller. Effects adapt to scroll speed.
  final ScrollController? velocityController;

  const PremiumScrollItem({
    super.key,
    required this.child,
    this.enableParallax = true,
    this.enableFocusScale = true,
    this.enableEdgeFade = true,
    this.velocityController,
  });

  @override
  Widget build(BuildContext context) {
    if (velocityController == null) return child;

    // Check velocity: fast scroll → return raw child for max throughput
    final speedListenable = (velocityController is VelocityTrackingBase)
        ? (velocityController as VelocityTrackingBase).normalizedSpeed
        : ValueNotifier<double>(0.0);

    return ValueListenableBuilder<double>(
      valueListenable: speedListenable,
      builder: (context, speed, child) {
        // Velocity-adaptive scale: slight contraction during scroll

        // Smoothly interpolates from 1.0 down to 0.975 based on speed.
        final double scale = (1.0 - (speed * 0.025)).clamp(0.975, 1.0);
        
        return Transform.scale(
          scale: scale,
          filterQuality: ui.FilterQuality.none,
          child: child!,
        );
      },
      child: child,
    );
  }
}

// ─── Premium Motion Blur ──────────────────────────────────────────────────────

/// Directional motion blur effect for grid items during high-velocity scrolling.
///
/// Phase 3: Premium Perception Engine.
/// This effect applies a vertical-only blur (sigmaY) proportional to the 
/// scroll velocity. This masks micro-jitter and frame-drops during rapid 
/// scrolling, creating a "buttery smooth" high-end feel.
///
/// Optimized for:
///  - directional blur (sigmaX=0) to maintain text legibility where possible.
///  - automatically disabled on non-high-end devices.
///  - zero overhead when speed is below threshold.
class PremiumMotionBlur extends StatelessWidget {
  final Widget child;
  final ScrollController? scrollController;
  final Axis scrollDirection;

  const PremiumMotionBlur({
    super.key,
    required this.child,
    this.scrollController,
    this.scrollDirection = Axis.vertical,
  });

  @override
  Widget build(BuildContext context) {
    // Only enable on high-tier devices to maintain battery and FPS stability
    if (scrollController == null || !AdaptivePerformance.enableMotionBlur) {
      return child;
    }

    final speedListenable = (scrollController is VelocityTrackingBase)
        ? (scrollController as VelocityTrackingBase).normalizedSpeed
        : ValueNotifier<double>(0.0);

    return ValueListenableBuilder<double>(
      valueListenable: speedListenable,
      builder: (context, speed, child) {
        // Threshold: don't apply blur for slow intentional scrolls
        if (speed < 0.18) return child!;


        // Velocity-to-Sigma mapping:
        // 0.18 speed -> ~0.5 sigma (barely visible)
        // 1.00 speed -> ~5.0 sigma (heavy directional blur)
        final sigma = (speed * 6.5).clamp(0.0, 5.0);

        return ImageFiltered(
          imageFilter: ui.ImageFilter.blur(
            sigmaX: scrollDirection == Axis.horizontal ? sigma : 0.0,
            sigmaY: scrollDirection == Axis.vertical ? sigma : 0.0,
            tileMode: ui.TileMode.clamp,
          ),
          child: child!,
        );
      },
      child: child,
    );
  }
}

// ─── PremiumScrollEffectListener ─────────────────────────────────────────────

/// Wraps the entire scroll view to propagate velocity to the controller.
/// Also updates the global scrolling state for parallax/expensive effects.
class PremiumScrollEffectListener extends ConsumerStatefulWidget {
  final Widget child;
  final ScrollController? controller;

  const PremiumScrollEffectListener({
    super.key,
    required this.child,
    this.controller,
  });

  @override
  ConsumerState<PremiumScrollEffectListener> createState() =>
      _PremiumScrollEffectListenerState();
}

class _PremiumScrollEffectListenerState
    extends ConsumerState<PremiumScrollEffectListener> {
  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (widget.controller is VelocityTrackingBase) {
          (widget.controller as VelocityTrackingBase).handleScrollNotification(notification, ref);
        }
        return false;
      },
      child: widget.child,
    );
  }
}
