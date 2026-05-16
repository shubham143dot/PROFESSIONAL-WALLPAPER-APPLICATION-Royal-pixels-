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
import '../../../core/utils/safe_tap.dart';

import '../../../core/widgets/login_required_sheet.dart';
import '../../../core/scroll/elite_scroll_physics.dart';
import '../../widgets/premium_touch_tile.dart';
import '../../../core/services/iap_service.dart';
import '../../../core/constants/iap_constants.dart';
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

  // ── Diamond Packs ──────────────────────────────────────────────────────────
  static const List<_DiamondPack> _packs = [
    _DiamondPack(
      id: IapConstants.pack300,
      diamonds: 300,
      price: 49,
      tier: _PackTier.small,
    ),
    _DiamondPack(
      id: IapConstants.pack800,
      diamonds: 800,
      price: 99,
      tier: _PackTier.medium,
      badge: '⭐ MOST POPULAR',
      isPopular: true,
    ),
    _DiamondPack(
      id: IapConstants.pack2000,
      diamonds: 2000,
      price: 199,
      tier: _PackTier.medium,
      badge: '+20% EXTRA',
    ),
    _DiamondPack(
      id: IapConstants.pack3500,
      diamonds: 3500,
      price: 299,
      tier: _PackTier.large,
      badge: 'LIMITED OFFER',
    ),
    _DiamondPack(
      id: IapConstants.pack7000,
      diamonds: 7000,
      price: 499,
      tier: _PackTier.mega,
      badge: 'BEST VALUE 🔥',
      isBestValue: true,
    ),
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



  Future<void> _buyDiamondPack(_DiamondPack pack) async {
    SafeTap.run('buy_diamond_pack_${pack.id}', () async {
      final authState = ref.read(authProvider);
      if (!authState.isAuthenticated) {
        showLoginRequiredSheet(context, reason: LoginRequiredReason.diamonds);
        return;
      }

      HapticFeedback.mediumImpact();
      
      try {
        final iapService = ref.read(iapServiceProvider);
        await iapService.buyProduct(pack.id);
        
        // Note: The UI will update automatically because IapService
        // updates the diamondProvider which we are watching.
      } catch (e) {
        HapticFeedback.heavyImpact();
        if (mounted) {
          RoyalSnackBar.show(
            context,
            '❌ An error occurred initiating purchase.',
            type: SnackBarType.error,
          );
        }
      }
    });
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
                const Text(
                  'DIAMOND STORE',
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
                      subtitle: 'Login every day to grow your stash'),
                  const SizedBox(height: 12),
                  _buildStreakCard(diamondState),
                  const SizedBox(height: 28),

                  // ── Watch & Earn ───────────────────────────────────────────
                  _buildSectionLabel('📺 Watch & Earn',
                      subtitle: 'Watch ads · earn diamonds · max 100/day · resets midnight'),
                  const SizedBox(height: 12),
                  const WatchEarnSection(),
                  const SizedBox(height: 28),

                  // ── How to Earn ──────────────────────────────────────────
                  _buildSectionLabel('💰 How to Earn',
                      subtitle: 'All the ways to earn Royal Diamonds'),
                  const SizedBox(height: 12),
                  _buildEarnCard(),
                  const SizedBox(height: 36),
                ] else ...[
                  // Premium Status Card
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
                        const Text(
                          'PRO MEMBERSHIP ACTIVE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'You have unlimited access to all premium wallpapers. Diamonds and daily streaks are disabled as you no longer need them!',
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

                // ── TOP-UP Section ───────────────────────────────────────
                _buildTopUpSection(),
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
                const Text(
                  'YOUR BALANCE',
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
                          const Text(
                            'Diamonds',
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
                Text(
                  'Come back tomorrow!',
                  style: TextStyle(
                    color: Colors.white.withAlpha(100),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                )
              else
                const Text(
                  '🎁 Day 7 Bonus!',
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
                child: const Center(
                  child: Text(
                    'CLAIM DAILY REWARD',
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

  // ── TOP-UP Section ─────────────────────────────────────────────────────────
  Widget _buildTopUpSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Section header ────────────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShaderMask(
                    shaderCallback: (b) =>
                        AppColors.goldGradient.createShader(b),
                    child: const Text(
                      'AVAILABLE PACKS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Instant Delivery • Secure Digital Payments',
                    style: TextStyle(
                        color: Colors.white.withAlpha(70), fontSize: 11),
                  ),
                ],
              ),
            ),
            // Secure badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withAlpha(40), width: 1),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_user_rounded, color: Colors.green, size: 14),
                  const SizedBox(width: 6),
                  const Text(
                    'SECURE',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // ── Pack grid ─────────────────────────────────────────────────────
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.64,
          ),
          itemCount: _packs.length,
          itemBuilder: (context, i) {
            return _DiamondPackCard(
              pack: _packs[i],
              onTap: () => _buyDiamondPack(_packs[i]),
            ).animate().fade(delay: Duration(milliseconds: 60 * i)).scale(
                  begin: const Offset(0.85, 0.85),
                  duration: 350.ms,
                  curve: Curves.easeOutBack,
                );
          },
        ),

        const SizedBox(height: 16),

        // ── Secure footer ─────────────────────────────────────────────────
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shield_rounded,
                  color: Colors.white.withAlpha(50), size: 12),
              const SizedBox(width: 5),
              Text(
                'End-to-end encrypted transactions  •  Powered by Royal Payments',
                style: TextStyle(
                  color: Colors.white.withAlpha(50),
                  fontSize: 10,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ─── Diamond Pack data model ────────────────────────────────────────────────
enum _PackTier { small, medium, large, mega }

class _DiamondPack {
  final String id;
  final int diamonds;
  final int price;
  final _PackTier tier;
  final String? badge;
  final bool isPopular;
  final bool isBestValue;

  const _DiamondPack({
    required this.id,
    required this.diamonds,
    required this.price,
    required this.tier,
    this.badge,
    this.isPopular = false,
    this.isBestValue = false,
  });
}

// ─── Diamond Pack Card (Ultra-premium) ───────────────────────────────────────
class _DiamondPackCard extends StatefulWidget {
  final _DiamondPack pack;
  final VoidCallback onTap;

  const _DiamondPackCard({required this.pack, required this.onTap});

  @override
  State<_DiamondPackCard> createState() => _DiamondPackCardState();
}

class _DiamondPackCardState extends State<_DiamondPackCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 120));
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.94).animate(
        CurvedAnimation(parent: _pressController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  // ── Color scheme per tier ──────────────────────────────────────────────
  _PackColors get _colors {
    final p = widget.pack;
    if (p.isBestValue) {
      return const _PackColors(
        border: Color(0xFFFF6600),
        bgTop: Color(0xFF2A1200),
        bgBottom: Color(0xFF100800),
        btnTop: Color(0xFFFF8000),
        btnBottom: Color(0xFFCC3300),
        glow: Color(0x50FF5500),
        badgeBg: Color(0xFFFF6600),
        badgeText: Colors.white,
      );
    } else if (p.isPopular) {
      return const _PackColors(
        border: Color(0xFFFFD76A),
        bgTop: Color(0xFF2A1E00),
        bgBottom: Color(0xFF100C00),
        btnTop: Color(0xFFFFD76A),
        btnBottom: Color(0xFFFFAA00),
        glow: Color(0x40FFC000),
        badgeBg: Color(0xFFFFC000),
        badgeText: Colors.black,
      );
    } else if (p.tier == _PackTier.mega) {
      return const _PackColors(
        border: Color(0xFFAA44FF),
        bgTop: Color(0xFF240050),
        bgBottom: Color(0xFF0E0030),
        btnTop: Color(0xFF9933FF),
        btnBottom: Color(0xFF5500AA),
        glow: Color(0x40880088),
        badgeBg: Color(0xFFAA44FF),
        badgeText: Colors.white,
      );
    } else {
      return const _PackColors(
        border: Color(0xFF3A5AAA),
        bgTop: Color(0xFF0E1A3A),
        bgBottom: Color(0xFF060E20),
        btnTop: Color(0xFF4477FF),
        btnBottom: Color(0xFF1133CC),
        glow: Color(0x30224499),
        badgeBg: Color(0xFF3A5AAA),
        badgeText: Colors.white,
      );
    }
  }

  Widget _buildDiamondArt() {
    final p = widget.pack;
    final size = p.tier == _PackTier.mega
        ? 52.0
        : p.tier == _PackTier.large
            ? 44.0
            : 36.0;

    // Custom Gold Diamond Art using Icons and Gradients
    Widget goldDiamond(double s) => ShaderMask(
          shaderCallback: (b) => AppColors.goldGradient.createShader(b),
          child: Icon(Icons.diamond_rounded, color: Colors.white, size: s),
        );

    if (p.tier == _PackTier.small) {
      return goldDiamond(size);
    } else if (p.tier == _PackTier.medium) {
      return SizedBox(
        width: 60,
        height: 50,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(top: 0, child: goldDiamond(size * 0.8)),
            Positioned(bottom: 0, left: 4, child: goldDiamond(size * 0.6)),
            Positioned(bottom: 0, right: 4, child: goldDiamond(size * 0.6)),
          ],
        ),
      );
    } else if (p.tier == _PackTier.large) {
      return SizedBox(
        width: 70,
        height: 60,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(top: 0, child: goldDiamond(size * 0.8)),
            Positioned(bottom: 5, left: 0, child: goldDiamond(size * 0.6)),
            Positioned(bottom: 5, right: 0, child: goldDiamond(size * 0.6)),
            Positioned(bottom: 0, child: goldDiamond(size * 0.5)),
          ],
        ),
      );
    } else {
      // Mega Pack - Treasure Chest style
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ShaderMask(
            shaderCallback: (b) => AppColors.goldGradient.createShader(b),
            child: Icon(Icons.inventory_2_rounded, color: Colors.white, size: size),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              goldDiamond(14),
              goldDiamond(14),
              goldDiamond(14),
            ],
          ),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _colors;
    final p = widget.pack;

    return GestureDetector(
      onTapDown: (_) => _pressController.forward(),
      onTapUp: (_) {
        _pressController.reverse();
        SafeTap.run('pack_card_${widget.pack.id}', () {
          widget.onTap();
        });
      },
      onTapCancel: () => _pressController.reverse(),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [c.bgTop, c.bgBottom],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: p.isBestValue || p.isPopular 
                  ? c.border.withAlpha(180) 
                  : AppColors.glassBorder, 
              width: p.isBestValue ? 2 : 1.2
            ),
            boxShadow: [
              if (p.isBestValue || p.isPopular)
                BoxShadow(
                  color: c.glow.withAlpha(40),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // Subtle background pattern
              Positioned(
                right: -20,
                top: -20,
                child: Opacity(
                  opacity: 0.05,
                  child: Icon(Icons.diamond_outlined, size: 100, color: c.border),
                ),
              ),

              Column(
                children: [
                  // ── Top: diamond count strip ──────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: c.border.withAlpha(20),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _formatDiamonds(p.diamonds),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          'DIAMOND PACK',
                          style: TextStyle(
                            color: Colors.white.withAlpha(120),
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Diamond Art ─────────────────────────────────────────────
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: _buildDiamondArt(),
                        ),
                      ),
                    ),
                  ),

                  // ── Buy button ─────────────────────────────────────────────
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [c.btnTop, c.btnBottom],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: c.btnBottom.withAlpha(100),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        '₹${p.price}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // ── Badge ──────────────────────────────────────────────────
              if (p.badge != null)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Transform.translate(
                      offset: const Offset(0, -6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [c.badgeBg, c.badgeBg.withAlpha(200)]),
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            )
                          ],
                        ),
                        child: Text(
                          p.badge!,
                          style: TextStyle(
                            color: c.badgeText,
                            fontSize: 7,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDiamonds(int d) {
    if (d >= 1000) {
      final k = d / 1000;
      return '${k % 1 == 0 ? k.toInt() : k.toStringAsFixed(1)}K';
    }
    return '$d';
  }
}

// ─── Pack color data class ───────────────────────────────────────────────────
class _PackColors {
  final Color border;
  final Color bgTop;
  final Color bgBottom;
  final Color btnTop;
  final Color btnBottom;
  final Color glow;
  final Color badgeBg;
  final Color badgeText;

  const _PackColors({
    required this.border,
    required this.bgTop,
    required this.bgBottom,
    required this.btnTop,
    required this.btnBottom,
    required this.glow,
    required this.badgeBg,
    required this.badgeText,
  });
}
