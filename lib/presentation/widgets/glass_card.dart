import 'package:flutter/material.dart';
import '../../core/theme/glass_decorations.dart';
import 'liquid_pop.dart';

/// Premier iOS Liquid Glassmorphic card widget with frosted blur,
/// specular rim highlights, and tactile spring pop interaction.
class GlassCard extends StatelessWidget {
  final Widget child;
  final bool isDark;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? borderColor;
  final Gradient? gradient;
  final double blurSigma;

  const GlassCard({
    super.key,
    required this.child,
    this.isDark = true,
    this.borderRadius = GlassDecorations.defaultBorderRadius,
    this.padding = const EdgeInsets.all(20),
    this.margin,
    this.onTap,
    this.onLongPress,
    this.borderColor,
    this.gradient,
    this.blurSigma = GlassDecorations.defaultBlurSigma,
  });

  @override
  Widget build(BuildContext context) {
    final bool highContrast = MediaQuery.of(context).highContrast;

    Widget cardBody = Container(
      padding: padding,
      decoration: GlassDecorations.glassCardDecoration(
        isDark: true,
        borderRadius: borderRadius,
        customBorderColor: borderColor,
        customGradient: gradient,
        highContrast: highContrast,
      ),
      child: child,
    );

    if (onTap != null || onLongPress != null) {
      cardBody = LiquidPop(
        onTap: onTap,
        onLongPress: onLongPress,
        pressedScale: 0.97,
        child: cardBody,
      );
    }

    if (margin != null) {
      cardBody = Padding(
        padding: margin!,
        child: cardBody,
      );
    }

    return cardBody;
  }
}
