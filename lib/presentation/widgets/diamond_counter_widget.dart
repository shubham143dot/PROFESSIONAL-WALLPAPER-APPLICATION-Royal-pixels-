import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/safe_tap.dart';
import '../../core/services/adaptive_performance.dart';
import 'premium_touch_tile.dart';

/// Animated 💎 diamond counter badge for the AppBar.
/// Includes a glowing "+" button that redirects to the Diamond Store.
class DiamondCounterWidget extends StatelessWidget {
  final int diamonds;
  final bool isPremium;
  final VoidCallback? onTap;
  final VoidCallback? onPlusTap;

  const DiamondCounterWidget({
    super.key,
    required this.diamonds,
    this.isPremium = false,
    this.onTap,
    this.onPlusTap,
  });

  @override
  Widget build(BuildContext context) {
    if (isPremium) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Diamond count pill ─────────────────────────────────────────────
        PremiumTouchTile(
          onTap: onTap != null ? () => SafeTap.run('diamond_counter', onTap!) : null,
          child: RepaintBoundary(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Builder(
                  builder: (context) {
                    final content = Container(
                      padding: const EdgeInsets.only(left: 10, right: 10, top: 4, bottom: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(
                          AdaptivePerformance.enableBackdropBlur ? 15 : 30,
                        ),
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
                              .animate(
                                onPlay: (c) => c.repeat(),
                                target: AdaptivePerformance.enableAnimations ? null : 1.0,
                              )
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
                    );
                    return AdaptivePerformance.enableBackdropBlur
                        ? BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                            child: content,
                          )
                        : content;
                  },
                ),
              ),
            ),
          ),
        ),

        // ── "+" button → Diamond Store ─────────────────────────────────────
        GestureDetector(
          onTap: onPlusTap != null
              ? () => SafeTap.run('diamond_plus_btn', onPlusTap!)
              : null,
          child: Container(
            margin: const EdgeInsets.only(left: 4, right: 6, top: 8, bottom: 8),
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFD4A017)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.goldMid.withAlpha(100),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: const Icon(
              Icons.add,
              color: Colors.black,
              size: 14,
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true), target: AdaptivePerformance.enableAnimations ? null : 1.0)
              .shimmer(duration: 2000.ms, color: Colors.white.withAlpha(80)),
        ),
      ],
    );
  }
}
