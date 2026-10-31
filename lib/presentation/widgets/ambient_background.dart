import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class AmbientBackground extends StatelessWidget {
  final Widget child;
  final bool isDark;
  final bool isAmoled;

  const AmbientBackground({
    super.key,
    required this.child,
    this.isDark = true,
    this.isAmoled = false,
  });

  @override
  Widget build(BuildContext context) {
    // Keep widget tree structure 100% invariant across theme/AMOLED state changes:
    // AnimatedContainer -> Stack -> [Orb 1, Orb 2, KeyedSubtree(child)]
    // This prevents Flutter element reconciliation from ever mismatched swapping
    // child elements or resetting PageView / Settings navigation.
    final bgColor = isAmoled
        ? AppColors.darkBackground
        : (isDark ? AppColors.bg0 : Colors.white);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      color: bgColor,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Ambient Orb 1 - Top Left (Royal Gold) with smooth animated fade
          Positioned(
            top: -100,
            left: -80,
            child: IgnorePointer(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                opacity: isAmoled ? 0.0 : 1.0,
                child: Container(
                  width: 340,
                  height: 340,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.goldMid.withValues(alpha: 0.12),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Ambient Orb 2 - Top Right (Royal Indigo) with smooth animated fade
          Positioned(
            top: 50,
            right: -100,
            child: IgnorePointer(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                opacity: isAmoled ? 0.0 : 1.0,
                child: Container(
                  width: 320,
                  height: 320,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.royalIndigo.withValues(alpha: 0.10),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Content root with explicit Key to guarantee preservation of identity and state
          KeyedSubtree(
            key: const ValueKey('ambient_content_root'),
            child: child,
          ),
        ],
      ),
    );
  }
}
