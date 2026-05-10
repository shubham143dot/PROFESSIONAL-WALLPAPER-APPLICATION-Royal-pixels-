import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/services/mood_engine.dart';
import '../providers/mood_provider.dart';
import '../providers/haptic_provider.dart';
import '../../core/scroll/elite_scroll_physics.dart';
import '../../../core/services/adaptive_performance.dart';

/// Horizontal mood selector strip — sits above the wallpaper grid on Home.
class MoodSelectorStrip extends ConsumerWidget {
  const MoodSelectorStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Only watch for length changes or static data here, 
    // not the selected mood itself to avoid full rebuilds.
    final moods = UserMood.values;

    return SizedBox(
      height: 92,
      child: CustomScrollView(
        scrollDirection: Axis.horizontal,
        physics: const EliteScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final mood = moods[i];
                  
                  return Consumer(
                    builder: (context, ref, child) {
                      final selectedMood = ref.watch(moodProvider).mood;
                      final isSelected = selectedMood == mood;
                      final accent = MoodEngine.accentForMood(mood);

                      return RepaintBoundary(
                        child: GestureDetector(
                          onTap: () {
                            ref.read(hapticProvider.notifier).selectionClick();
                            ref.read(moodProvider.notifier).selectMood(mood);
                          },
                          child: _buildMoodItem(mood, isSelected, accent),
                        ),
                      );
                    },
                  ).animate(target: AdaptivePerformance.enableAnimations ? null : 1.0)
                   .fadeIn(delay: (i * 40).ms)
                   .slideX(begin: 0.2, end: 0);
                },
                childCount: moods.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoodItem(UserMood mood, bool isSelected, Color accent) {
    final decoration = BoxDecoration(
      color: isSelected
          ? accent.withValues(alpha: 0.15)
          : const Color(0xFF161C2D).withValues(alpha: 0.8),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: isSelected
            ? accent.withValues(alpha: 0.7)
            : Colors.white.withValues(alpha: 0.08),
        width: isSelected ? 1.5 : 0.8,
      ),
      boxShadow: isSelected && !AdaptivePerformance.isLow
          ? [
              BoxShadow(
                color: accent.withValues(alpha: 0.3),
                blurRadius: 16,
                spreadRadius: 1,
                offset: const Offset(0, 4),
              )
            ]
          : [],
    );

    final emoji = Transform.scale(
      scale: isSelected ? 1.2 : 1.0,
      child: Text(
        MoodEngine.emojiForMood(mood),
        style: const TextStyle(fontSize: 22),
      ),
    );

    final label = Text(
      MoodEngine.labelForMood(mood),
      style: TextStyle(
        color: isSelected ? accent : const Color(0xFF94A3B8),
        fontSize: 11,
        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
        letterSpacing: 0.2,
      ),
    );

    if (AdaptivePerformance.isLow) {
      return Container(
        margin: const EdgeInsets.only(right: 10, bottom: 8, top: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: decoration,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            emoji,
            const SizedBox(height: 6),
            label,
          ],
        ),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.only(right: 10, bottom: 8, top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: decoration,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedScale(
            scale: isSelected ? 1.2 : 1.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutBack,
            child: emoji,
          ),
          const SizedBox(height: 6),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: label.style!,
            child: Text(MoodEngine.labelForMood(mood)),
          ),
        ],
      ),
    );
  }
}
