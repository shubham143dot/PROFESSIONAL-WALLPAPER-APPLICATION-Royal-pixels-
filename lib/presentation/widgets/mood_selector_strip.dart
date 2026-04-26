import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/services/mood_engine.dart';
import '../providers/mood_provider.dart';
import '../providers/haptic_provider.dart';

/// Horizontal mood selector strip — sits above the wallpaper grid on Home.
class MoodSelectorStrip extends ConsumerWidget {
  const MoodSelectorStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedMood = ref.watch(moodProvider).mood;

    return SizedBox(
      height: 92,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: UserMood.values.length,
        itemBuilder: (context, i) {
          final mood = UserMood.values[i];
          final isSelected = selectedMood == mood;
          final accent = MoodEngine.accentForMood(mood);

          return GestureDetector(
            onTap: () {
              ref.read(hapticProvider.notifier).selectionClick();
              ref.read(moodProvider.notifier).selectMood(mood);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.only(right: 10, bottom: 8, top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? accent.withAlpha(30)
                    : const Color(0xFF161C2D).withAlpha(180),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? accent.withAlpha(180) : Colors.white.withAlpha(18),
                  width: isSelected ? 1.5 : 0.8,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: accent.withAlpha(70),
                          blurRadius: 16,
                          spreadRadius: 1,
                          offset: const Offset(0, 4),
                        )
                      ]
                    : [],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedScale(
                    scale: isSelected ? 1.2 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutBack,
                    child: Text(
                      MoodEngine.emojiForMood(mood),
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                  const SizedBox(height: 6),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                      color: isSelected ? accent : const Color(0xFF94A3B8),
                      fontSize: 11,
                      fontWeight:
                          isSelected ? FontWeight.w800 : FontWeight.w500,
                      letterSpacing: 0.2,
                    ),
                    child: Text(MoodEngine.labelForMood(mood)),
                  ),
                ],
              ),
            )
                .animate(delay: (i * 40).ms)
                .fade(duration: 400.ms, curve: Curves.easeOut)
                .slideX(begin: 0.3, end: 0, duration: 350.ms, curve: Curves.easeOutCubic),
          );
        },
      ),
    );
  }
}
