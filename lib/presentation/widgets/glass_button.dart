import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/haptic_helper.dart';
import 'liquid_pop.dart';

enum GlassButtonVariant {
  primary,
  secondary,
  danger,
}

/// Premier iOS Liquid Glass button with specular border highlight,
/// frosted BackdropFilter blur, and spring-pop bounce physics.
class GlassButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isDark;
  final GlassButtonVariant variant;
  final bool isLoading;
  final double height;
  final double? width;
  final double borderRadius;

  const GlassButton({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.isDark = true,
    this.variant = GlassButtonVariant.primary,
    this.isLoading = false,
    this.height = 54,
    this.width,
    this.borderRadius = 28,
  });

  @override
  Widget build(BuildContext context) {
    final bool highContrast = MediaQuery.of(context).highContrast;
    final isDisabled = onPressed == null || isLoading;

    BoxDecoration decoration;
    Color textColor;

    switch (variant) {
      case GlassButtonVariant.primary:
        decoration = BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          gradient: isDark ? AppColors.goldGradient : AppColors.royalGradient,
          border: Border.all(
            color: Colors.white.withValues(alpha: highContrast ? 0.9 : 0.45),
            width: highContrast ? 1.6 : 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: (isDark ? AppColors.goldMid : AppColors.royalIndigo).withValues(alpha: isDark ? 0.40 : 0.35),
              blurRadius: 18,
              spreadRadius: 1,
              offset: const Offset(0, 6),
            ),
            if (!isDark)
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.6),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
          ],
        );
        textColor = isDark ? Colors.black : Colors.white;
        break;

      case GlassButtonVariant.secondary:
        decoration = BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          color: highContrast
              ? (isDark ? AppColors.bg2 : const Color(0xFFFFFFFF))
              : (isDark ? AppColors.bg2 : Colors.white.withValues(alpha: 0.65)),
          border: Border.all(
            color: highContrast
                ? (isDark ? Colors.white : const Color(0xFF64748B))
                : (isDark ? AppColors.darkGlassHighlight : Colors.white.withValues(alpha: 0.90)),
            width: highContrast ? 1.5 : 0.6,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.35)
                  : const Color(0xFF64748B).withValues(alpha: 0.09),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
            if (!isDark && !highContrast)
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.8),
                blurRadius: 6,
                offset: const Offset(0, -1),
              ),
          ],
        );
        textColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
        break;

      case GlassButtonVariant.danger:
        decoration = BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          gradient: AppColors.expenseGradient,
          border: Border.all(
            color: Colors.white.withValues(alpha: highContrast ? 0.9 : 0.40),
            width: highContrast ? 1.5 : 1.1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.roseExpense.withValues(alpha: isDark ? 0.40 : 0.30),
              blurRadius: 16,
              offset: const Offset(0, 5),
            ),
            if (!isDark)
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.5),
                blurRadius: 6,
                offset: const Offset(0, -1),
              ),
          ],
        );
        textColor = Colors.white;
        break;
    }

    Widget buttonContent = Container(
      width: width,
      height: height,
      decoration: decoration,
      child: Center(
        child: isLoading
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor: AlwaysStoppedAnimation<Color>(textColor),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20, color: textColor),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
      ),
    );

    return LiquidPop(
      onTap: isDisabled
          ? null
          : () {
              HapticHelper.mediumImpact();
              onPressed!();
            },
      pressedScale: 0.94,
      child: Opacity(
        opacity: isDisabled ? 0.6 : 1.0,
        child: buttonContent,
      ),
    );
  }
}
