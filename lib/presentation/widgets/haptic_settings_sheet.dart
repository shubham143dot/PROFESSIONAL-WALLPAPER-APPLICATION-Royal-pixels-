import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/entities/haptic_level.dart';
import '../providers/haptic_provider.dart';

class HapticSettingsSheet extends ConsumerWidget {
  const HapticSettingsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLevel = ref.watch(hapticProvider);
    final notifier = ref.read(hapticProvider.notifier);
    final hapticSupport = ref.watch(hapticSupportProvider);

    return hapticSupport.when(
      data: (isHardwareSupported) => _buildContent(context, ref, currentLevel, notifier, isHardwareSupported),
      loading: () => _buildLoading(context),
      error: (_, __) => _buildContent(context, ref, currentLevel, notifier, false),
    );
  }

  Widget _buildLoading(BuildContext context) {
    return Container(
      height: 300,
      decoration: const BoxDecoration(
        color: AppColors.bg1,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(40),
          topRight: Radius.circular(40),
        ),
      ),
      child: const Center(
        child: CircularProgressIndicator(color: AppColors.goldMid),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, HapticLevel currentLevel, HapticNotifier notifier, bool isHardwareSupported) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bg1,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(40),
          topRight: Radius.circular(40),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textMuted.withAlpha(80),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
            child: Column(
              children: [
                const Text(
                  'Haptic Intensity',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ).animate().fade(duration: 400.ms).slideY(begin: 0.1),
                
                const SizedBox(height: 10),
                
                Text(
                  'Customize how the application feels in your hand with precision feedback.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary.withAlpha(180),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ).animate().fade(delay: 150.ms, duration: 400.ms),

                // Note if not supported
                if (!isHardwareSupported)
                  Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.red.withAlpha(15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.red.withAlpha(50),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.red.withAlpha(30),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.info_outline_rounded,
                              color: Colors.redAccent,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'This feature is not supported',
                                  style: TextStyle(
                                    color: Colors.redAccent,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Your device hardware does not support haptic feedback.',
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ).animate().shake(delay: 600.ms, duration: 500.ms).fadeIn(),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Options List - De-congested single column
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: HapticLevel.values.map((level) {
                final isSelected = currentLevel == level;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _HapticOptionCard(
                    level: level,
                    isSelected: isSelected,
                    isEnabled: isHardwareSupported,
                    onTap: () => notifier.setLevel(level),
                  ),
                );
              }).toList(),
            ),
          ).animate().fadeIn(delay: 300.ms, duration: 500.ms).slideY(begin: 0.05),

          const SizedBox(height: 24),

          // Test Button
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
            child: SizedBox(
              width: double.infinity,
              child: Consumer(
                builder: (context, ref, child) {
                  final isOff = currentLevel == HapticLevel.off;
                  
                  return ElevatedButton(
                    onPressed: (isHardwareSupported) ? () => notifier.trigger() : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isHardwareSupported ? AppColors.bg2 : AppColors.bg3.withAlpha(100),
                      foregroundColor: isHardwareSupported ? AppColors.goldLight : AppColors.textMuted,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                        side: BorderSide(
                          color: !isHardwareSupported 
                            ? AppColors.textMuted.withAlpha(20)
                            : isOff 
                              ? AppColors.textMuted.withAlpha(40)
                              : AppColors.goldMid.withAlpha(100), 
                          width: 1
                        ),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          !isHardwareSupported 
                            ? Icons.vibration_outlined 
                            : isOff ? Icons.volume_off_rounded : Icons.vibration_rounded, 
                          size: 20,
                          color: !isHardwareSupported ? AppColors.textMuted : null,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          !isHardwareSupported 
                            ? 'HARDWARE NOT SUPPORTED'
                            : isOff ? 'MUTED' : 'TEST VIBRATION',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                            fontSize: 13,
                            color: !isHardwareSupported ? AppColors.textMuted : null,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ).animate().fade(delay: 500.ms).slideY(begin: 0.2),
        ],
      ),
    );
  }
}

class _HapticOptionCard extends StatelessWidget {
  final HapticLevel level;
  final bool isSelected;
  final bool isEnabled;
  final VoidCallback onTap;

  const _HapticOptionCard({
    required this.level,
    required this.isSelected,
    this.isEnabled = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !isEnabled,
      child: Opacity(
        opacity: isEnabled ? 1.0 : 0.4,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutQuart,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.goldMid.withAlpha(15) : AppColors.bg2.withAlpha(100),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? AppColors.goldMid : AppColors.glassBorder,
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.goldMid.withAlpha(30),
                    blurRadius: 20,
                    spreadRadius: -5,
                  )
                ]
              : [],
        ),
        child: Row(
          children: [
            // Icon Stack
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.goldMid.withAlpha(40) : AppColors.bg3,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                _getIconForLevel(level),
                color: isSelected ? AppColors.goldLight : AppColors.textSecondary,
                size: 26,
              ),
            ).animate(target: isSelected ? 1 : 0).scale(begin: const Offset(1, 1), end: const Offset(1.05, 1.05)),
            
            const SizedBox(width: 16),
            
            // Text Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    level.label,
                    style: TextStyle(
                      color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                      fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    level.description,
                    style: TextStyle(
                      color: isSelected ? AppColors.goldLight.withAlpha(180) : AppColors.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            
            // Radio-like indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.goldMid : AppColors.textMuted.withAlpha(100),
                  width: isSelected ? 7 : 2,
                ),
              ),
            ),
          ],
        ),
      ),
        ),
      ),
    );
  }

  IconData _getIconForLevel(HapticLevel level) {
    switch (level) {
      case HapticLevel.off:
        return Icons.do_disturb_on_rounded;
      case HapticLevel.light:
        return Icons.blur_on_rounded;
      case HapticLevel.medium:
        return Icons.vibration_rounded;
      case HapticLevel.strong:
        return Icons.shutter_speed_rounded;
    }
  }
}
