import 'package:royal_pixels/core/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/entities/haptic_level.dart';
import '../providers/haptic_provider.dart';
import '../../core/services/adaptive_performance.dart';
import 'premium_touch_tile.dart';
import 'dart:ui';

class HapticSettingsSheet extends ConsumerWidget {
  const HapticSettingsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hapticSupport = ref.watch(hapticSupportProvider);

    return hapticSupport.when(
      data: (isHardwareSupported) => _buildContent(context, ref, isHardwareSupported),
      loading: () => _buildLoading(context),
      error: (_, __) => _buildContent(context, ref, false),
    );
  }

  Widget _buildLoading(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
      child: Builder(
        builder: (context) {
          final content = Container(
            height: 300,
            decoration: BoxDecoration(
              color: AppColors.bg1.withAlpha(AdaptivePerformance.enableBackdropBlur ? 13 : 240),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
            ),
            child: const Center(
              child: CircularProgressIndicator(color: AppColors.goldMid),
            ),
          );
          return AdaptivePerformance.enableBackdropBlur
              ? BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: content,
                )
              : content;
        },
      ),
    );
  }

  Widget _buildContent(
      BuildContext context,
      WidgetRef ref,
      bool isHardwareSupported) {
    final enableBlur = AdaptivePerformance.enableBackdropBlur;
    
    return Stack(
      children: [
        // Main Content Container
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
          child: Builder(
            builder: (context) {
              final content = Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: enableBlur ? 0.75 : 0.95), // Solid for fallback
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                    width: 1.5,
                  ),
                ),
                child: _buildColumn(context, isHardwareSupported),
              );
              return enableBlur
                  ? BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                      child: content,
                    )
                  : content;
            },
          ),
        ),

        // Premium Close Button (Top Right)
        Positioned(
          top: 20,
          right: 20,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Builder(
                  builder: (context) {
                    final content = Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: enableBlur ? 0.08 : 0.2),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: AppColors.textPrimary,
                        size: 20,
                      ),
                    );
                    return enableBlur
                        ? BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                            child: content,
                          )
                        : content;
                  },
                ),
              ),
            ),
          ).animate().fade(delay: 400.ms).scale(delay: 400.ms),
        ),
      ],
    );
  }



  Widget _buildColumn(BuildContext context, bool isHardwareSupported) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Drag Handle
        const SizedBox(height: 12),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(20),
            borderRadius: BorderRadius.circular(2),
          ),
        ),

        const SizedBox(height: 32),

        // Hero Section
        Consumer(
          builder: (context, ref, _) {
            final level = ref.watch(hapticProvider);
            return Column(
              children: [
                _buildHeroIcon(level),
                const SizedBox(height: 24),
                Text(AppLocalizations.of(context)!.hapticEngine,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ).animate().fade().scale(begin: const Offset(0.9, 0.9)),
                const SizedBox(height: 8),
                Text(AppLocalizations.of(context)!.precisiontunedVibrationPhysicsForRoyalPixels,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary.withAlpha(150),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ).animate().fade(delay: 200.ms),
              ],
            );
          },
        ),

        const SizedBox(height: 40),

        // Main Selector
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: const _HapticControlCenterLarge(),
        ).animate().fade(delay: 300.ms).slideY(begin: 0.1),

        const SizedBox(height: 32),

        // Technical Note
        if (!isHardwareSupported)
          _buildHardwareWarning(context)
        else
          _buildTestingSection(),

        const SizedBox(height: 40),

        // Done Button
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
          child: SizedBox(
            width: double.infinity,
            child: PremiumTouchTile(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  gradient: AppColors.goldGradient,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.goldMid.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(AppLocalizations.of(context)!.optimizeEngine,
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ).animate().fade(delay: 500.ms).slideY(begin: 0.2),
      ],
    );
  }

  Widget _buildHeroIcon(HapticLevel level) {
    final bool isOff = level == HapticLevel.off;
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: isOff ? Colors.white.withAlpha(5) : AppColors.goldMid.withValues(alpha: 0.1),
        shape: BoxShape.circle,
        border: Border.all(
          color: isOff ? Colors.white10 : AppColors.goldMid.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: isOff ? [] : [
          BoxShadow(
            color: AppColors.goldMid.withValues(alpha: 0.1),
            blurRadius: 40,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Center(
        child: Icon(
          isOff ? Icons.vibration_outlined : Icons.sensors_rounded,
          color: isOff ? AppColors.textMuted : AppColors.goldLight,
          size: 40,
        ).animate(target: isOff ? 0 : 1)
         .shimmer(duration: 2.seconds, color: Colors.white24)
         .shake(duration: 500.ms),
      ),
    ).animate(onPlay: (c) => c.repeat(reverse: true))
     .scale(duration: 2.seconds, begin: const Offset(0.95, 0.95), end: const Offset(1.05, 1.05), curve: Curves.easeInOut);
  }

  Widget _buildHardwareWarning(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.withAlpha(10),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.red.withAlpha(30)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppLocalizations.of(context)!.hardwareLimitation,
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                Text(AppLocalizations.of(context)!.yourDeviceDoesNotSupportPrecisionHaptics,
                  style: TextStyle(
                    color: AppColors.textMuted.withAlpha(200),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestingSection() {
    return Consumer(
      builder: (context, ref, _) {
        final level = ref.watch(hapticProvider);
        if (level == HapticLevel.off) return const SizedBox.shrink();
        
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: PremiumTouchTile(
            onTap: () => ref.read(hapticProvider.notifier).trigger(),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.vibration_rounded, color: AppColors.goldLight, size: 18),
                  const SizedBox(width: 12),
                  Text(AppLocalizations.of(context)!.testImpulse,
                    style: TextStyle(
                      color: AppColors.goldLight,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Larger version of the haptic control center for the settings sheet
class _HapticControlCenterLarge extends ConsumerWidget {
  const _HapticControlCenterLarge();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLevel = ref.watch(hapticProvider);
    final notifier = ref.read(hapticProvider.notifier);
    final levels = HapticLevel.values;
    final selectedIndex = levels.indexOf(currentLevel);

    return Container(
      height: 100,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(120),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withAlpha(15), width: 1),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final segmentWidth = constraints.maxWidth / levels.length;
          
          return Stack(
            children: [
              // Selection Pill
              AnimatedPositioned(
                duration: const Duration(milliseconds: 600),
                curve: Curves.elasticOut,
                left: selectedIndex * segmentWidth,
                top: 0,
                bottom: 0,
                width: segmentWidth,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.goldMid.withValues(alpha: 0.4),
                        AppColors.goldMid.withValues(alpha: 0.1),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: AppColors.goldMid.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.goldMid.withValues(alpha: 0.2),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                ).animate(onPlay: (c) => c.repeat(reverse: true))
                 .shimmer(duration: 3.seconds, color: Colors.white.withAlpha(15)),
              ),
              
              Row(
                children: levels.map((level) {
                  final isSelected = currentLevel == level;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => notifier.setLevel(level),
                      behavior: HitTestBehavior.opaque,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _getIconForLevel(level),
                            color: isSelected ? AppColors.goldLight : AppColors.textMuted,
                            size: isSelected ? 30 : 24,
                          ).animate(target: isSelected ? 1 : 0)
                           .scale(begin: const Offset(0.8, 0.8), end: const Offset(1.15, 1.15), curve: Curves.easeOutBack),
                          const SizedBox(height: 6),
                          Text(
                            level.label.toUpperCase(),
                            style: TextStyle(
                              color: isSelected ? AppColors.textPrimary : AppColors.textMuted,
                              fontSize: 9,
                              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          );
        },
      ),
    );
  }

  IconData _getIconForLevel(HapticLevel level) {
    switch (level) {
      case HapticLevel.off: return Icons.not_interested_rounded;
      case HapticLevel.light: return Icons.blur_on_rounded;
      case HapticLevel.medium: return Icons.vibration_rounded;
      case HapticLevel.strong: return Icons.bolt_rounded;
    }
  }
}
