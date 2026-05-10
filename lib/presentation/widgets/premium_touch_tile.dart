import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/haptic_provider.dart';

/// A high-performance, ultra-responsive touch wrapper.
/// 
/// Optimized for the "Royal Pixels" feel:
/// - Scroll-aware touch handling (prevents glitching during scrolls)
/// - Hardware-accelerated transforms
/// - Repaint boundary isolation
class PremiumTouchTile extends ConsumerStatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  
  /// The scale to shrink to when pressed. Default is 0.97.
  final double pressScale;
  
  /// The opacity when pressed. Default is 0.9.
  final double pressOpacity;

  /// Whether to use haptic feedback. Default is true.
  final bool useHaptic;

  const PremiumTouchTile({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressScale = 0.97,
    this.pressOpacity = 0.9,
    this.useHaptic = true,
  });

  @override
  ConsumerState<PremiumTouchTile> createState() => _PremiumTouchTileState();
}

class _PremiumTouchTileState extends ConsumerState<PremiumTouchTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  
  bool _isPressed = false;
  Timer? _pressTimer;

  @override
  void initState() {
    super.initState();
    // Core animation controller for touch response (Optimized for snappy feel)
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      reverseDuration: const Duration(milliseconds: 300),
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.pressScale,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Cubic(0.4, 0.0, 0.2, 1.0), // Fast in
      reverseCurve: const Cubic(0.175, 0.885, 0.32, 1.275), // iOS-style overshoot
    ));

    _opacityAnimation = Tween<double>(
      begin: 1.0,
      end: widget.pressOpacity,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _pressTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    // We delay the press state slightly to check if this is a scroll gesture.
    // 40ms is short enough to feel instant but long enough to filter out fast scrolls.
    _pressTimer?.cancel();
    _pressTimer = Timer(const Duration(milliseconds: 40), () {
      if (mounted) {
        setState(() => _isPressed = true);
        _controller.forward();
        if (widget.useHaptic) {
          ref.read(hapticProvider.notifier).selectionClick();
        }
      }
    });
  }

  void _handleTapUp(TapUpDetails details) {
    _pressTimer?.cancel();
    if (_isPressed) {
      setState(() => _isPressed = false);
      _controller.reverse();
    }
    if (widget.onTap != null) {
      widget.onTap!();
    }
  }

  void _handleTapCancel() {
    _pressTimer?.cancel();
    if (_isPressed) {
      setState(() => _isPressed = false);
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onLongPress: widget.onLongPress != null ? () {
          _pressTimer?.cancel();
          if (widget.useHaptic) {
            ref.read(hapticProvider.notifier).mediumImpact();
          }
          widget.onLongPress!();
        } : null,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Stack(
                children: [
                  Opacity(
                    opacity: _opacityAnimation.value,
                    child: child,
                  ),
                  // Subtle premium dimming overlay during press
                  if (_isPressed)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha((15 * _controller.value).toInt()),
                            borderRadius: BorderRadius.circular(12),
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
