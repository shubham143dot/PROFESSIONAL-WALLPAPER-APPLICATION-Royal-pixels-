import 'package:flutter/material.dart';
import '../../core/utils/haptic_helper.dart';

/// Interactive liquid iOS pop/bounce wrapper.
///
/// Compresses smoothly on press down (Curves.easeOutCubic) and springs back
/// with an elastic pop overshoot (Curves.easeOutBack) on release, matching
/// the tactile feel of iOS liquid glass controls.
class LiquidPop extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double pressedScale;
  final Duration pressDuration;
  final Duration releaseDuration;
  final Curve pressCurve;
  final Curve releaseCurve;
  final bool enableHaptic;
  final HitTestBehavior behavior;

  const LiquidPop({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressedScale = 0.95,
    this.pressDuration = const Duration(milliseconds: 110),
    this.releaseDuration = const Duration(milliseconds: 240),
    this.pressCurve = Curves.easeOutCubic,
    this.releaseCurve = Curves.easeOutBack,
    this.enableHaptic = true,
    this.behavior = HitTestBehavior.opaque,
  });

  @override
  State<LiquidPop> createState() => _LiquidPopState();
}

class _LiquidPopState extends State<LiquidPop> {
  bool _isPressed = false;

  void _handleTapDown(TapDownDetails _) {
    if (widget.onTap == null && widget.onLongPress == null) return;
    setState(() => _isPressed = true);
  }

  void _handleTapUp(TapUpDetails _) {
    if (_isPressed) {
      setState(() => _isPressed = false);
    }
  }

  void _handleTapCancel() {
    if (_isPressed) {
      setState(() => _isPressed = false);
    }
  }

  void _handleTap() {
    if (widget.onTap == null) return;
    if (widget.enableHaptic) {
      HapticHelper.lightImpact();
    }
    widget.onTap!();
  }

  @override
  Widget build(BuildContext context) {
    final bool reduceMotion = MediaQuery.of(context).disableAnimations;
    final bool isInteractive = widget.onTap != null || widget.onLongPress != null;

    if (!isInteractive) {
      return widget.child;
    }

    final double targetScale = _isPressed ? widget.pressedScale : 1.0;
    final Duration duration = reduceMotion
        ? Duration.zero
        : (_isPressed ? widget.pressDuration : widget.releaseDuration);
    final Curve curve = _isPressed ? widget.pressCurve : widget.releaseCurve;

    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: _handleTap,
      onLongPress: widget.onLongPress != null
          ? () {
              if (widget.enableHaptic) HapticHelper.mediumImpact();
              widget.onLongPress!();
            }
          : null,
      child: AnimatedScale(
        scale: targetScale,
        duration: duration,
        curve: curve,
        child: widget.child,
      ),
    );
  }
}
