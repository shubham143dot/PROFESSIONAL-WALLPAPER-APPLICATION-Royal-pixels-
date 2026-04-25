import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/diamond_data.dart';
import '../../providers/auth_provider.dart';
import '../../providers/diamond_provider.dart';
import '../../providers/haptic_provider.dart';


/// Premium daily reward bottom sheet popup.
/// Shows automatically on first app open per day.
Future<void> showDailyRewardPopup(
  BuildContext context,
  WidgetRef ref,
  DailyRewardResult reward,
) async {
  await showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isDismissible: false,
    enableDrag: false,
    builder: (_) => _DailyRewardSheet(reward: reward, ref: ref),
  );
}

class _DailyRewardSheet extends ConsumerStatefulWidget {
  final DailyRewardResult reward;
  final WidgetRef ref;

  const _DailyRewardSheet({required this.reward, required this.ref});

  @override
  ConsumerState<_DailyRewardSheet> createState() => _DailyRewardSheetState();
}

class _DailyRewardSheetState extends ConsumerState<_DailyRewardSheet>
    with SingleTickerProviderStateMixin {
  bool _claimed = false;
  bool _showBonusChoice = false;
  bool _isLoading = false;

  static const List<int> _streakRewards = [10, 15, 20, 25, 30, 40, 50];
  static const List<String> _dayLabels = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
  ];

  Future<void> _claim() async {
    if (_claimed || _isLoading) return;
    ref.read(hapticProvider.notifier).heavyImpact();


    if (widget.reward.isBonus) {
      setState(() => _showBonusChoice = true);
      return;
    }

    setState(() => _isLoading = true);
    final userId = ref.read(authProvider).user?.uid ?? '';
    await ref.read(diamondProvider.notifier).claimDailyReward(userId);
    setState(() {
      _claimed = true;
      _isLoading = false;
    });

    await Future.delayed(const Duration(milliseconds: 1200));
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _claimBonus(bool takeDiamonds) async {
    setState(() => _isLoading = true);
    final userId = ref.read(authProvider).user?.uid ?? '';
    await ref.read(diamondProvider.notifier).claimDailyReward(userId);
    setState(() {
      _claimed = true;
      _isLoading = false;
      _showBonusChoice = false;
    });

    await Future.delayed(const Duration(milliseconds: 1200));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final day = widget.reward.day;
    final diamonds = widget.reward.diamonds;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.bg1.withAlpha(230),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: const Border(
              top: BorderSide(color: AppColors.glassBorder, width: 1),
              left: BorderSide(color: AppColors.glassBorder, width: 1),
              right: BorderSide(color: AppColors.glassBorder, width: 1),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: _showBonusChoice
                  ? _buildBonusChoice()
                  : _buildMainContent(day, diamonds),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent(int day, int diamonds) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Handle bar
        Center(
          child: Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: AppColors.glassBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),

        // Title
        if (!_claimed) ...[
          const Text(
            '🎁 Daily Reward!',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ).animate().fade(duration: 400.ms).slideY(begin: -0.2),
          const SizedBox(height: 6),
          Text(
            'Come back every day to build your streak',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ).animate().fade(duration: 400.ms, delay: 100.ms),
        ] else ...[
          const Text(
            '✅ Claimed!',
            style: TextStyle(
              color: AppColors.goldLight,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ).animate().scale(begin: const Offset(0.7, 0.7)).fade(),
        ],

        const SizedBox(height: 20),

        // 7-day streak row
        _buildStreakRow(day),

        const SizedBox(height: 24),

        // Diamond reward display
        if (!_claimed) ...[
          _buildRewardDisplay(day, diamonds),
          const SizedBox(height: 24),
          _buildClaimButton(diamonds),
        ] else ...[
          _buildClaimedDisplay(diamonds),
        ],

        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildStreakRow(int currentDay) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (i) {
        final dayNum = i + 1;
        final isPast = dayNum < currentDay;
        final isCurrent = dayNum == currentDay;
        final isFuture = dayNum > currentDay;

        Color bg;
        Color border;
        if (isCurrent) {
          bg = AppColors.goldMid.withAlpha(40);
          border = AppColors.goldMid;
        } else if (isPast) {
          bg = Colors.green.withAlpha(30);
          border = Colors.green.withAlpha(100);
        } else {
          bg = AppColors.bg2;
          border = AppColors.glassBorder;
        }

        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: border, width: 1.2),
            ),
            child: Column(
              children: [
                Text(
                  isCurrent
                      ? '💎'
                      : isPast
                          ? '✓'
                          : '◇',
                  style: TextStyle(
                    fontSize: isCurrent ? 14 : 12,
                    color: isPast ? Colors.greenAccent : AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _dayLabels[i],
                  style: TextStyle(
                    color: isCurrent
                        ? AppColors.goldLight
                        : isFuture
                            ? AppColors.textMuted
                            : Colors.greenAccent,
                    fontSize: 9,
                    fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w500,
                  ),
                ),
                Text(
                  '+${_streakRewards[i]}',
                  style: TextStyle(
                    color: isCurrent ? AppColors.goldMid : AppColors.textMuted,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ).animate(delay: (i * 50).ms).fade().slideY(begin: 0.1);
      }),
    );
  }

  Widget _buildRewardDisplay(int day, int diamonds) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.goldDeep.withAlpha(40),
            AppColors.goldMid.withAlpha(20),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.goldMid.withAlpha(60)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('💎', style: TextStyle(fontSize: 36))
              .animate(onPlay: (c) => c.repeat())
              .shimmer(duration: 2000.ms, color: AppColors.goldLight),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Day $day Reward',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12),
              ),
              ShaderMask(
                shaderCallback: (b) => AppColors.goldGradient.createShader(b),
                child: Text(
                  '+$diamonds Diamonds',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().scale(begin: const Offset(0.8, 0.8), delay: 200.ms).fade();
  }

  Widget _buildClaimedDisplay(int diamonds) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.green.withAlpha(20),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.withAlpha(80)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('💎', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 10),
          Text(
            '+$diamonds added to your wallet!',
            style: const TextStyle(
              color: Colors.greenAccent,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ).animate().scale(begin: const Offset(0.8, 0.8)).fade();
  }

  Widget _buildClaimButton(int diamonds) {
    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
        onTap: _claim,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: AppColors.goldGradient,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: AppColors.goldMid.withAlpha(80),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Colors.black,
                      strokeWidth: 2,
                    ),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('💎', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Text(
                      'Claim +$diamonds Diamonds',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
        ),
      )
          .animate(delay: 300.ms)
          .fade()
          .slideY(begin: 0.3),
    );
  }

  Widget _buildBonusChoice() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: AppColors.glassBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const Text('🎉', style: TextStyle(fontSize: 48)),
        const SizedBox(height: 8),
        const Text(
          'Day 7 Bonus!',
          style: TextStyle(
            color: AppColors.goldLight,
            fontSize: 26,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'You completed a full streak! Choose your bonus:',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 24),
        // Option 1: +30 diamonds
        GestureDetector(
          onTap: () => _claimBonus(true),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              gradient: AppColors.goldGradient,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: AppColors.goldMid.withAlpha(80),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('💎', style: TextStyle(fontSize: 22)),
                SizedBox(width: 10),
                Text(
                  '+80 Diamonds  (50 + bonus 30)',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ).animate().fade().slideX(begin: -0.2),
        const SizedBox(height: 12),
        // Option 2: Free wallpaper (dismiss to pick)
        GestureDetector(
          onTap: () => _claimBonus(false),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              color: AppColors.accentPurple.withAlpha(30),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.accentPurple.withAlpha(120)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('🔓', style: TextStyle(fontSize: 22)),
                SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Claim 50 Diamonds',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Then use them to unlock a wallpaper',
                      style: TextStyle(
                          color: AppColors.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ).animate().fade().slideX(begin: 0.2, delay: 100.ms),
        const SizedBox(height: 16),
      ],
    );
  }
}
