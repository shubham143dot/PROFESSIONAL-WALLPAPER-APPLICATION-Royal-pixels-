import 'package:flutter/material.dart';
import '../../core/theme/app_text_styles.dart';

/// Liquid iOS glassmorphic badge with frosted blur and glowing border.
class StatBadge extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color color;
  final bool isDark;

  const StatBadge({
    super.key,
    required this.label,
    this.icon,
    required this.color,
    this.isDark = true,
  });

  @override
  Widget build(BuildContext context) {
    Widget badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: color.withValues(alpha: isDark ? 0.18 : 0.14),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.45 : 0.35),
          width: 0.9,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: isDark ? 0.15 : 0.10),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
          if (!isDark)
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.7),
              blurRadius: 4,
              offset: const Offset(0, -1),
            ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );

    return badge;
  }
}
