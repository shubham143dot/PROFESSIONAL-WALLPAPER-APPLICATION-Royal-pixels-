import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';

/// Animated 💎 diamond counter badge for the AppBar.
class DiamondCounterWidget extends StatelessWidget {
  final int diamonds;
  final VoidCallback? onTap;

  const DiamondCounterWidget({
    super.key,
    required this.diamonds,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1A2340), Color(0xFF0F1420)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.goldMid.withAlpha(80),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.goldMid.withAlpha(30),
              blurRadius: 8,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('💎', style: TextStyle(fontSize: 14))
                .animate(onPlay: (c) => c.repeat())
                .shimmer(
                  duration: 2400.ms,
                  color: AppColors.goldLight.withAlpha(120),
                ),
            const SizedBox(width: 4),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              transitionBuilder: (child, animation) => SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.5),
                  end: Offset.zero,
                ).animate(animation),
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: Text(
                '$diamonds',
                key: ValueKey(diamonds),
                style: const TextStyle(
                  color: AppColors.goldLight,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
