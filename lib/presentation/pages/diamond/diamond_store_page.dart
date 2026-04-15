import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/ads/ad_helper.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/diamond_provider.dart';
import '../../../core/utils/royal_snack_bar.dart';

class DiamondStorePage extends ConsumerStatefulWidget {
  const DiamondStorePage({super.key});

  @override
  ConsumerState<DiamondStorePage> createState() => _DiamondStorePageState();
}

class _DiamondStorePageState extends ConsumerState<DiamondStorePage> {
  bool _isWatchingAd = false;

  static const List<int> _streakRewards = [10, 15, 20, 25, 30, 40, 50];
  static const List<String> _dayLabels = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
  ];

  Future<void> _watchAd() async {
    final userId = ref.read(authProvider).user?.uid ?? '';
    if (userId.isEmpty) {
      RoyalSnackBar.show(context, 'Please login first', type: SnackBarType.info);
      return;
    }

    final diamondState = ref.read(diamondProvider);
    if (!diamondState.canWatchAd) {
      RoyalSnackBar.show(
        context,
        'Daily ad limit reached! Come back tomorrow.',
        type: SnackBarType.info,
      );
      return;
    }

    setState(() => _isWatchingAd = true);

    AdHelper.showRewardedAd(onCompleted: () async {
      if (!mounted) return;
      final success =
          await ref.read(diamondProvider.notifier).addAdReward(userId);
      setState(() => _isWatchingAd = false);

      if (mounted) {
        if (success) {
          HapticFeedback.heavyImpact();
          RoyalSnackBar.show(context, '💎 +10 Diamonds earned!');
        } else {
          RoyalSnackBar.show(
            context,
            'Ad limit reached for today (5/day)',
            type: SnackBarType.info,
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final diamondState = ref.watch(diamondProvider);

    return Scaffold(
      backgroundColor: AppColors.bg0,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Sliver AppBar ─────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 0,
            pinned: true,
            floating: false,
            snap: false,
            backgroundColor: AppColors.bg1,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              '💎 Diamond Store',
              style: TextStyle(
                  color: AppColors.goldLight,
                  fontWeight: FontWeight.w800,
                  fontSize: 16),
            ),
            centerTitle: true,
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Diamond Balance Badge ────────────────────────────────────
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.goldDeep.withAlpha(60),
                          AppColors.goldMid.withAlpha(40),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                          color: AppColors.goldMid.withAlpha(100)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('💎',
                                style: TextStyle(fontSize: 32))
                            .animate(onPlay: (c) => c.repeat())
                            .shimmer(
                                duration: 2000.ms,
                                color: AppColors.goldLight),
                        const SizedBox(width: 12),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 500),
                          child: Text(
                            '${diamondState.diamonds}',
                            key: ValueKey(diamondState.diamonds),
                            style: const TextStyle(
                              color: AppColors.goldLight,
                              fontSize: 42,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fade().scale(begin: const Offset(0.9, 0.9)),
                ),
                const SizedBox(height: 6),
                const Center(
                  child: Text(
                    'Your Diamond Balance',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── Streak Section ───────────────────────────────────────────
                _SectionHeader(title: '🔥 Daily Streak'),
                const SizedBox(height: 12),
                _buildStreakCard(diamondState.streak),
                const SizedBox(height: 20),

                // ── Watch Ad Section ─────────────────────────────────────────
                _SectionHeader(title: '📺 Watch & Earn'),
                const SizedBox(height: 12),
                _buildAdCard(diamondState),
                const SizedBox(height: 20),

                // ── How to Earn ───────────────────────────────────────────────
                _SectionHeader(title: '💰 How to Earn'),
                const SizedBox(height: 12),
                _buildEarnCard(),
                const SizedBox(height: 20),

                // ── How to Spend ──────────────────────────────────────────────
                _SectionHeader(title: '🔓 How to Spend'),
                const SizedBox(height: 12),
                _buildSpendCard(),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakCard(int currentStreak) {
    final currentDay = currentStreak.clamp(0, 7);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bg1,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🔥', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                currentDay == 0
                    ? 'Start your streak today!'
                    : 'Day $currentDay of 7',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: List.generate(7, (i) {
              final dayNum = i + 1;
              final isPast = dayNum < currentDay;
              final isCurrent = dayNum == currentDay;

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
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(10),
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
                          fontSize: 12,
                          color: isPast ? Colors.greenAccent : AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _dayLabels[i],
                        style: TextStyle(
                          color: isCurrent
                              ? AppColors.goldLight
                              : AppColors.textMuted,
                          fontSize: 8,
                          fontWeight: isCurrent
                              ? FontWeight.w800
                              : FontWeight.w500,
                        ),
                      ),
                      Text(
                        '+${_streakRewards[i]}',
                        style: TextStyle(
                          color: isCurrent
                              ? AppColors.goldMid
                              : AppColors.textMuted,
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.bg2,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline,
                    color: AppColors.textMuted, size: 14),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Miss a day and your streak resets to Day 1. Day 7 gives a special bonus!',
                    style:
                        TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fade().slideY(begin: 0.05);
  }

  Widget _buildAdCard(DiamondState diamondState) {
    final canWatch = diamondState.canWatchAd;
    final remaining = diamondState.remainingAdsToday;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bg1,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: canWatch
              ? AppColors.goldMid.withAlpha(60)
              : AppColors.glassBorder,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: canWatch
                      ? AppColors.goldMid.withAlpha(30)
                      : AppColors.bg2,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.play_circle_fill_rounded,
                  color: canWatch ? AppColors.goldMid : AppColors.textMuted,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Watch Ad → 💎 +10',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      canWatch
                          ? '$remaining ads remaining today'
                          : 'Limit reached — come back tomorrow!',
                      style: TextStyle(
                        color: canWatch
                            ? AppColors.textSecondary
                            : Colors.redAccent.withAlpha(180),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              // Progress dots
              Row(
                children: List.generate(5, (i) {
                  final watched = 5 - remaining;
                  return Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < watched
                          ? AppColors.goldMid
                          : AppColors.bg3,
                    ),
                  );
                }),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: canWatch ? _watchAd : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  gradient: canWatch ? AppColors.goldGradient : null,
                  color: canWatch ? null : AppColors.bg2,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: canWatch
                      ? [
                          BoxShadow(
                            color: AppColors.goldMid.withAlpha(60),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          )
                        ]
                      : [],
                ),
                child: _isWatchingAd
                    ? const SizedBox(
                        height: 20,
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
                          Icon(
                            Icons.play_arrow_rounded,
                            color: canWatch
                                ? Colors.black
                                : AppColors.textMuted,
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            canWatch
                                ? 'Watch Ad → +10 Diamonds'
                                : 'Limit Reached (5/day)',
                            style: TextStyle(
                              color: canWatch
                                  ? Colors.black
                                  : AppColors.textMuted,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fade(delay: 100.ms).slideY(begin: 0.05);
  }

  Widget _buildEarnCard() {
    final items = [
      ('🔥', 'Daily Login Streak', 'Day 1–7: +10 to +50 💎 per day'),
      ('📺', 'Watch & Earn (Ads)', '+10 💎 per ad · max 5 ads/day = 50 💎'),
      ('📥', 'Download Wallpaper', '+5 💎 · free & premium · 80 💎/day cap'),
      ('🖼️', 'Set as Wallpaper', '+5 💎 · free & premium · 80 💎/day cap'),
      ('🏆', 'Daily Maximum', 'Up to 130 💎/day  (80 actions + 50 ads)'),
    ];
    return _InfoCard(items: items);
  }

  Widget _buildSpendCard() {
    final items = [
      ('💎', 'Premium Wallpaper', 'Unlock for 60 💎'),
      ('💎', 'Special Wallpaper', 'Unlock for 70 💎'),
      ('📺', 'Free Unlock (Ad)', 'Watch an ad once to unlock for free'),
    ];
    return _InfoCard(items: items, accentColor: AppColors.accentPurple);
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<(String, String, String)> items;
  final Color accentColor;

  const _InfoCard({
    required this.items,
    this.accentColor = AppColors.goldMid,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg1,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: accentColor.withAlpha(25),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(item.$1,
                            style: const TextStyle(fontSize: 16)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.$2,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            item.$3,
                            style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (i < items.length - 1)
                Divider(
                    height: 1,
                    color: AppColors.divider,
                    indent: 16,
                    endIndent: 16),
            ],
          );
        }).toList(),
      ),
    ).animate().fade(delay: 150.ms).slideY(begin: 0.05);
  }
}
