import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/safe_tap.dart';

/// Animated 💎 diamond counter badge for the AppBar.
/// Upgraded with glassmorphism, soft glow, and premium micro-animations.
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
      onTap: () {
        if (onTap != null) {
          SafeTap.run('diamond_counter', onTap!);
        }
      },
      child: RepaintBoundary(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                padding: const EdgeInsets.only(left: 10, right: 4, top: 4, bottom: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.goldMid.withAlpha(80),
                    width: 0.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.goldMid.withAlpha(40),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 💎 Shimmer icon
                    const Text('💎', style: TextStyle(fontSize: 14))
                        .animate(onPlay: (c) => c.repeat())
                        .shimmer(
                          duration: 2400.ms,
                          color: AppColors.goldLight.withAlpha(120),
                        )
                        .scale(
                          duration: 400.ms,
                          curve: Curves.easeOutBack,
                        ),
                    const SizedBox(width: 4),
                    // Animated count
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 500),
                      transitionBuilder: (child, animation) => SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.4),
                          end: Offset.zero,
                        ).animate(CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutCubic,
                        )),
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
                          shadows: [
                            Shadow(
                              color: Color(0x66FFD700),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

