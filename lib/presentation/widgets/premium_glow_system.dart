import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/palette_service.dart';
import '../../core/scroll/velocity_aware_controller.dart';
import '../../core/services/adaptive_performance.dart';
import '../providers/haptic_provider.dart';


/// A premium, iOS-level layered glow system for wallpaper cards.
/// 
/// Combines base ambient glow, dynamic color-extracted glow, and interactive
/// touch responses into a single high-performance component.
class PremiumGlowSystem extends ConsumerStatefulWidget {
  final String imageUrl;
  final Widget? child;
  final Widget Function(BuildContext context, Color? color)? builder;
  final VelocityAwareScrollController? scrollController;
  final double borderRadius;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const PremiumGlowSystem({
    super.key,
    required this.imageUrl,
    this.child,
    this.builder,
    this.scrollController,
    this.borderRadius = 20.0,
    this.onTap,
    this.onLongPress,
  }) : assert(child != null || builder != null);

  @override
  ConsumerState<PremiumGlowSystem> createState() => _PremiumGlowSystemState();
}

class _PremiumGlowSystemState extends ConsumerState<PremiumGlowSystem>
    with SingleTickerProviderStateMixin {
  Color? _dynamicColor;
  bool _isPressed = false;
  Timer? _pressTimer;
  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _intensityAnimation;

  @override
  void initState() {
    super.initState();
    
    // Core animation controller for touch response (120ms in, 450ms out)
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      reverseDuration: const Duration(milliseconds: 450),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(
        parent: _pressController,
        curve: const Cubic(0.4, 0.0, 0.2, 1.0), // Fast in
        reverseCurve: const Cubic(0.175, 0.885, 0.32, 1.275), // iOS-style overshoot
      ),
    );

    _intensityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOut),
    );

    _loadColor();
  }

  Future<void> _loadColor() async {
    // Phase 6: skip palette extraction on low-end devices to save CPU/RAM
    if (AdaptivePerformance.isLow) return;
    
    final color = await ref.read(paletteServiceProvider).getDominantColor(widget.imageUrl);
    if (mounted) {
      setState(() {
        _dynamicColor = color;
      });
    }
  }

  @override
  void dispose() {
    _pressTimer?.cancel();
    _pressController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    _pressTimer?.cancel();
    // 40ms delay to prevent animation triggers during fast scrolls/drags
    _pressTimer = Timer(const Duration(milliseconds: 40), () {
      if (mounted) {
        setState(() => _isPressed = true);
        _pressController.forward();
        ref.read(hapticProvider.notifier).selectionClick();
      }
    });
  }

  void _handleTapUp(TapUpDetails details) {
    _pressTimer?.cancel();
    if (_isPressed) {
      setState(() => _isPressed = false);
      _pressController.reverse();
    }
    widget.onTap?.call();
  }

  void _handleTapCancel() {
    _pressTimer?.cancel();
    if (_isPressed) {
      setState(() => _isPressed = false);
      _pressController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (AdaptivePerformance.isLow) {
      return GestureDetector(
        onTap: widget.onTap,
        onLongPress: () {
          ref.read(hapticProvider.notifier).lightImpact();
          widget.onLongPress?.call();
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            child: widget.builder != null
                ? widget.builder!(context, null)
                : widget.child!,
          ),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RepaintBoundary(
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onLongPress: () {
          _pressTimer?.cancel();
          ref.read(hapticProvider.notifier).mediumImpact();
          widget.onLongPress?.call();
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedBuilder(
          animation: _pressController,
          builder: (context, child) {
            final interactiveBoost = _intensityAnimation.value;

            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Stack(
                children: [
                  ValueListenableBuilder<bool>(
                    valueListenable: widget.scrollController?.isScrolling ?? ValueNotifier(false),
                    builder: (context, isScrolling, _) {
                      // Optimization: Avoid complex shadows during scroll or on non-high devices.
                      final bool showComplexShadows = !isScrolling && AdaptivePerformance.enableComplexShadows;
                      const bool showSimpleShadow = true; // Standard+ always gets simple shadow
                      
                      return Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(widget.borderRadius),
                          // Use a single, very light shadow for standard tier or when scrolling on high tier
                          boxShadow: (showSimpleShadow && !showComplexShadows) ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ] : null,
                        ),
                        child: Stack(
                          children: [
                            // Layer: HEAVY PREMIUM SHADOWS (Only rendered on High tier + Idle)
                            if (showComplexShadows)
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(widget.borderRadius),
                                    boxShadow: [
                                      // Layer 1: BASE AMBIENT GLOW
                                      BoxShadow(
                                        color: (isDark ? Colors.white : Colors.black)
                                            .withValues(alpha: (0.12 + interactiveBoost * 0.12)),
                                        blurRadius: 25 + (interactiveBoost * 20),
                                        spreadRadius: 0,
                                      ),
                                      
                                      // Layer 2: DYNAMIC COLOR GLOW (Gated)
                                      if (_dynamicColor != null && AdaptivePerformance.enableDynamicPalette)
                                        BoxShadow(
                                          color: _dynamicColor!
                                              .withValues(alpha: (0.35 + interactiveBoost * 0.25)),
                                          blurRadius: 30 + (interactiveBoost * 25),
                                          spreadRadius: 1 + (interactiveBoost * 2),
                                        ),
                                    ],
                                  ),
                                ),
                              ),

                            // CONTENT LAYER
                            ClipRRect(
                              borderRadius: BorderRadius.circular(widget.borderRadius),
                              child: widget.builder != null
                                  ? widget.builder!(context, _dynamicColor)
                                  : widget.child!,
                            ),
                          ],
                        ),
                      );
                    }
                  ),
                  
                  // Premium iOS-style dimming overlay
                  if (_isPressed)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: interactiveBoost * 0.15),
                            borderRadius: BorderRadius.circular(widget.borderRadius),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
          child: widget.child,
        ),
      ),
    );
  }
}
