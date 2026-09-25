import 'package:royal_pixels/core/l10n/app_localizations.dart';
import 'dart:ui';
import '../../../core/services/adaptive_performance.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/diamond_provider.dart';
import '../../../core/utils/royal_snack_bar.dart';
import 'package:flutter/services.dart';

import '../../../core/widgets/login_required_sheet.dart';
import '../../../core/scroll/elite_scroll_physics.dart';
import '../../widgets/premium_touch_tile.dart';
import 'watch_earn_section.dart';

class DiamondStorePage extends ConsumerStatefulWidget {
  const DiamondStorePage({super.key});

  @override
  ConsumerState<DiamondStorePage> createState() => _DiamondStorePageState();
}

class _DiamondStorePageState extends ConsumerState<DiamondStorePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;

  static const List<int> _streakRewards = [10, 15, 20, 25, 30, 40, 50];
  static const List<String> _dayLabels = [
    'Day 1',
    'Day 2',
    'Day 3',
    'Day 4',
    'Day 5',
    'Day 6',
    'Day 7'
  ];

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final diamondState = ref.watch(diamondProvider);
    final isSubscribed = ref.watch(authProvider).user?.isSubscribed ?? false;

    return Scaffold(
      backgroundColor: const Color(0xFF06080F),
      body: CustomScrollView(
        physics: const EliteScrollPhysics(),
        slivers: [
          // ── Premium AppBar ─────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 0,
            pinned: true,
            floating: false,
            backgroundColor: Colors.transparent,
            elevation: 0,
            flexibleSpace: ClipRect(
              child: AdaptivePerformance.enableBackdropBlur
                  ? BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xCC0A0D1A), Color(0xAA06080F)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    )
                  : Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFF06080F),
                      ),
                    ),
            ),
            leading: IconButton(
              icon: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withAlpha(20)),
                ),
                child: const Icon(Icons.arrow_back_ios_new,
                    color: Colors.white, size: 16),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ShaderMask(
                  shaderCallback: (b) => AppColors.goldGradient.createShader(b),
                  child: const Icon(
                    Icons.diamond_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Text(AppLocalizations.of(context)!.earnDiamonds,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
            centerTitle: true,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(
                height: 1,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Color(0x80FDDB6A),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Diamond Balance ────────────────────────────────────────
                _buildBalanceCard(diamondState.diamonds),
                const SizedBox(height: 28),

                if (!isSubscribed) ...[
                  // ── Daily Streak ───────────────────────────────────────────
                  _buildSectionLabel('🔥 Daily Streak',
                      subtitle: AppLocalizations.of(context)!.loginEveryDayToGrowYourStash),
                  const SizedBox(height: 12),
                  _buildStreakCard(diamondState),
                  const SizedBox(height: 28),

                  // ── Watch & Earn ───────────────────────────────────────────
                  _buildSectionLabel('📺 Watch & Earn',
                      subtitle: AppLocalizations.of(context)!.watchAdsEarnDiamondsMax100dayResetsMidnight),
                  const SizedBox(height: 12),
                  const WatchEarnSection(),
                  const SizedBox(height: 28),

                  // ── How to Earn ──────────────────────────────────────────
                  _buildSectionLabel('💰 How to Earn',
                      subtitle: AppLocalizations.of(context)!.allTheWaysToEarnRoyalDiamonds),
                  const SizedBox(height: 12),
                  _buildEarnCard(),
                  const SizedBox(height: 36),
                ] else ...[
                  // ── PRO Member Status ──────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.goldMid.withAlpha(40),
                          AppColors.goldMid.withAlpha(10),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.goldMid.withAlpha(100), width: 1.5),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.workspace_premium_rounded, color: AppColors.goldMid, size: 48)
                            .animate(onPlay: (c) => c.repeat())
                            .shimmer(duration: 2.seconds),
                        const SizedBox(height: 16),
                        Text(AppLocalizations.of(context)!.proMembershipActive,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(AppLocalizations.of(context)!.youHaveUnlimitedAccessToAllPremiumWallpapersEnjoyYourLifetimeProMembership,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withAlpha(150),
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn().scale(),
                  const SizedBox(height: 36),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── Section Label ──────────────────────────────────────────────────────────
  Widget _buildSectionLabel(String title, {String? subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withAlpha(100),
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ],
    );
  }

  // ── Balance Card ───────────────────────────────────────────────────────────
  Widget _buildBalanceCard(int diamonds) {
    return AnimatedBuilder(
      animation: _glowController,
      builder: (_, child) {
        final g = _glowController.value;
        return RepaintBoundary(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF1E1040),
                  Color(0xFF0C1730),
                  Color(0xFF06080F)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: [0.0, 0.5, 1.0],
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Color.lerp(
                  const Color(0x50FDDB6A),
                  const Color(0xAAFDDB6A),
                  g,
                )!,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Color.lerp(
                    const Color(0x18FDDB6A),
                    const Color(0x45FDDB6A),
                    g,
                  )!,
                  blurRadius: 40,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: Color.lerp(
                    const Color(0x10A040FF),
                    const Color(0x30A040FF),
                    g,
                  )!,
                  blurRadius: 60,
                  spreadRadius: -5,
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: Row(
        children: [
          // Glow diamond Orb
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: const RadialGradient(
                colors: [Color(0x40FDDB6A), Color(0x00000000)],
              ),
              borderRadius: BorderRadius.circular(36),
            ),
            child: Center(
              child: ShaderMask(
                shaderCallback: (b) => AppColors.goldGradient.createShader(b),
                child: const Icon(Icons.diamond_rounded, color: Colors.white, size: 42),
              ),
            ),
          )
              .animate(onPlay: (c) => c.repeat())
              .shimmer(duration: 2200.ms, color: AppColors.goldLight),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppLocalizations.of(context)!.yourBalance,
                  style: TextStyle(
                    color: Color(0xFF8899BB),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 4),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 600),
                  transitionBuilder: (child, anim) => SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.4),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                        parent: anim, curve: Curves.easeOutBack)),
                    child: FadeTransition(opacity: anim, child: child),
                  ),
                  child: ShaderMask(
                    key: ValueKey(diamonds),
                    shaderCallback: (b) =>
                        AppColors.goldGradient.createShader(b),
                    child: Text(
                      '$diamonds',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A2A50),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: const Color(0xFF2A4080), width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ShaderMask(
                            shaderCallback: (b) => AppColors.goldGradient.createShader(b),
                            child: const Icon(Icons.diamond_rounded, color: Colors.white, size: 10),
                          ),
                          const SizedBox(width: 4),
                          Text(AppLocalizations.of(context)!.diamonds,
                            style: TextStyle(
                              color: Color(0xFF8899CC),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fade().scale(begin: const Offset(0.95, 0.95));
  }

  // ── Streak Card ────────────────────────────────────────────────────────────
  Widget _buildStreakCard(DiamondState diamondState) {
    final streak = diamondState.streak;
    final canClaim = diamondState.canClaimToday;
    
    // Calculate how many days are shown as "completed"
    int doneDays = streak % 7;
    if (streak == 7 && !canClaim) doneDays = 7;
    
    final activeDay = canClaim ? (doneDays % 7) + 1 : -1;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1220),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: canClaim
              ? AppColors.goldMid.withAlpha(100)
              : const Color(0xFF1E2840),
          width: 1.5,
        ),
        boxShadow: [
          if (canClaim)
            BoxShadow(
              color: AppColors.goldMid.withAlpha(30),
              blurRadius: 30,
              spreadRadius: -5,
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B00), Color(0xFFFF3300)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF6B00).withAlpha(40),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Text('🔥', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    Text(
                      canClaim 
                        ? (doneDays == 0 ? 'Start Your Streak' : 'Day $activeDay Ready')
                        : 'Streak: $doneDays / 7',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (!canClaim)
                Text(AppLocalizations.of(context)!.comeBackTomorrow,
                  style: TextStyle(
                    color: Colors.white.withAlpha(100),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                )
              else
                Text(AppLocalizations.of(context)!.day7Bonus1,
                  style: TextStyle(
                    color: AppColors.goldLight,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1500.ms),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: List.generate(7, (i) {
              final dayNum = i + 1;
              final isDone = dayNum <= doneDays;
              final isNext = dayNum == activeDay;

              Color borderColor;
              Color? bgColor;
              Widget child;

              if (isDone) {
                borderColor = const Color(0xFF2A7040);
                bgColor = const Color(0xFF0A2010);
                child = const Icon(Icons.check_rounded, color: Colors.greenAccent, size: 14);
              } else if (isNext) {
                borderColor = AppColors.goldMid;
                bgColor = const Color(0xFF2D2000);
                child = ShaderMask(
                  shaderCallback: (b) => AppColors.goldGradient.createShader(b),
                  child: const Icon(Icons.diamond_rounded, color: Colors.white, size: 14),
                );
              } else {
                borderColor = const Color(0xFF1E2840);
                bgColor = const Color(0xFF0D1220);
                child = Text(
                  '$dayNum',
                  style: const TextStyle(
                    color: Color(0xFF445577),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                );
              }

              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(
                    children: [
                      Container(
                        height: 42,
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: borderColor,
                            width: isNext ? 2 : 1.2,
                          ),
                          boxShadow: isNext ? [
                            BoxShadow(
                              color: AppColors.goldMid.withAlpha(50),
                              blurRadius: 10,
                              spreadRadius: 0,
                            )
                          ] : [],
                        ),
                        child: Center(child: child),
                      ).animate(target: isNext ? 1 : 0)
                       .scale(begin: const Offset(1, 1), end: const Offset(1.05, 1.05), curve: Curves.easeInOut)
                       .then()
                       .shake(hz: 2),
                      const SizedBox(height: 6),
                      Text(
                        _dayLabels[i],
                        style: TextStyle(
                          color: isDone 
                              ? Colors.greenAccent.withAlpha(150)
                              : isNext ? AppColors.goldLight : const Color(0xFF445577),
                          fontSize: 8,
                          fontWeight: isNext ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        '+${_streakRewards[i]}',
                        style: TextStyle(
                          color: isDone 
                              ? Colors.greenAccent.withAlpha(100)
                              : isNext ? AppColors.goldMid : const Color(0xFF334455),
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
          if (canClaim) ...[
            const SizedBox(height: 24),
            PremiumTouchTile(
              onTap: () async {
                final authState = ref.read(authProvider);
                if (!authState.isAuthenticated) {
                  showLoginRequiredSheet(context, reason: LoginRequiredReason.diamonds);
                  return;
                }
                
                HapticFeedback.heavyImpact();
                final result = await ref.read(diamondProvider.notifier).claimDailyReward(authState.user!.uid);
                if (result != null && mounted) {
                  RoyalSnackBar.show(
                    context,
                    'You received ${result.diamonds} diamonds!',
                    type: SnackBarType.success,
                  );
                }
              },
              child: Container(
                width: double.infinity,
                height: 54,
                decoration: BoxDecoration(
                  gradient: AppColors.goldGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.goldMid.withAlpha(60),
                      blurRadius: 15,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(AppLocalizations.of(context)!.claimDailyReward,
                    style: TextStyle(
                      color: Color(0xFF2D1E00),
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ).animate(onPlay: (c) => c.repeat(reverse: true))
             .shimmer(duration: 2000.ms, color: Colors.white.withAlpha(40))
             .scale(begin: const Offset(1, 1), end: const Offset(1.02, 1.02), duration: 1000.ms),
          ] else ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF080C18),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF1A2240), width: 1),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFF446688), size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Come back tomorrow for Day ${((streak % 7) + 1) > 7 ? 1 : ((streak % 7) + 1)} rewards!',
                      style: TextStyle(color: Colors.white.withAlpha(80), fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    ).animate().fade().slideY(begin: 0.1);
  }

  // ── Earn Card ──────────────────────────────────────────────────────────────
  Widget _buildEarnCard() {
    final items = [
      (
        Icons.local_fire_department_rounded,
        'Daily Login Streak',
        'Up to +50 💎 per day · resets at midnight',
        const Color(0xFFFF6B00),
      ),
      (
        Icons.smart_display_rounded,
        'Watch & Earn',
        '+20 💎 per ad · 5 ads/day · 100 💎/day · resets midnight',
        const Color(0xFF7C3AED),
      ),
      (
        Icons.file_download_rounded,
        'Download Wallpaper',
        '+20 💎 total from download & set wallpaper actions',
        const Color(0xFF2266DD),
      ),
      (
        Icons.wallpaper_rounded,
        'Set as Wallpaper',
        'Included in the +20 💎 combined download/set limit',
        const Color(0xFF22AA66),
      ),
      (
        Icons.emoji_events_rounded,
        'Daily Maximum',
        'Earn up to 120 💎/day (100 from ads + 20 from actions)',
        AppColors.goldMid,
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0E1220),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF1E2840), width: 1.2),
      ),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          return Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: item.$4.withAlpha(20),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: item.$4.withAlpha(60), width: 1),
                      ),
                      child: Center(
                        child: Icon(item.$1, color: item.$4, size: 20),
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
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            item.$3,
                            style: const TextStyle(
                                color: Color(0xFF5577AA), fontSize: 10.5),
                          ),
                        ],
                      ),
                    ),
                    if (i == items.length - 1)
                      ShaderMask(
                        shaderCallback: (b) =>
                            AppColors.goldGradient.createShader(b),
                        child: const Icon(Icons.star_rounded,
                            color: Colors.white, size: 16),
                      ),
                  ],
                ),
              ),
              if (i < items.length - 1)
                const Divider(
                    height: 1,
                    color: Color(0xFF141C2C),
                    indent: 16,
                    endIndent: 16),
            ],
          );
        }).toList(),
      ),
    ).animate().fade(delay: 150.ms).slideY(begin: 0.05);
  }
}
