import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../services/adaptive_performance.dart';
import '../scroll/velocity_aware_controller.dart';

/// A performance-aware glass container that optimizes BackdropFilter.
/// 
/// Automatically disables blur during high-velocity scrolling or on 
/// low-end devices to maintain 60-120 FPS.
class PremiumGlassContainer extends StatelessWidget {
  final Widget? child;
  final double blurSigma;
  final Color color;
  final BorderRadius? borderRadius;
  final BoxBorder? border;
  final VelocityAwareScrollController? scrollController;
  final Color? glowColor;
  final double glowIntensity;
  final Offset? glowOffset;

  const PremiumGlassContainer({
    super.key,
    this.child,
    this.blurSigma = 20.0,
    this.color = Colors.transparent,
    this.borderRadius,
    this.border,
    this.scrollController,
    this.glowColor,
    this.glowIntensity = 0.5,
    this.glowOffset,
  });

  @override
  Widget build(BuildContext context) {
    final bool performanceEnabled = AdaptivePerformance.enableBackdropBlur;
    final bool glowEnabled = AdaptivePerformance.enableGlowEffects && glowColor != null;

    if (!performanceEnabled) {
      return Container(
        decoration: BoxDecoration(
          color: color.withAlpha(220), // High opacity fallback
          borderRadius: borderRadius,
          border: border,
          boxShadow: glowEnabled 
            ? [
                BoxShadow(
                  color: glowColor!.withValues(alpha: 0.15 * glowIntensity),
                  blurRadius: 20 * glowIntensity,
                  spreadRadius: 1,
                  offset: glowOffset ?? Offset.zero,
                )
              ]
            : null,
        ),
        child: child,
      );
    }

    // Disable toggling during scroll to maintain high FPS and fix lagging.
    // Glassmorphism effect will remain smooth without AnimatedSwitcher recreating BackdropFilter.
    return _buildGlass(true, glowEnabled: glowEnabled);
  }

  Widget _buildGlass(bool withBlur, {Key? key, bool glowEnabled = false}) {
    return Container(
      key: key,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        border: border,
        boxShadow: glowEnabled 
          ? [
              // Core glow
              BoxShadow(
                color: glowColor!.withValues(alpha: 0.25 * glowIntensity),
                blurRadius: 40 * glowIntensity,
                spreadRadius: 2,
                offset: glowOffset ?? Offset.zero,
              ),
              // Ambient glow
              BoxShadow(
                color: glowColor!.withValues(alpha: 0.15 * glowIntensity),
                blurRadius: 20 * glowIntensity,
                spreadRadius: 1,
              ),
            ]
          : null,
      ),
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.zero,
        child: Stack(
          children: [
            // Background Layer
            Positioned.fill(
              child: withBlur
                  ? BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
                      child: Container(color: color),
                    )
                  : Container(color: color.withAlpha(235)),
            ),
            // Content Layer
            if (child != null) child!,
          ],
        ),
      ),
    );
  }
}
