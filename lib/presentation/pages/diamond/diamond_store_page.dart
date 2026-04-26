import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/ads/ad_helper.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/diamond_provider.dart';
import '../../../core/utils/royal_snack_bar.dart';
import 'package:flutter/services.dart';
import '../../../core/utils/safe_tap.dart';

import '../../../core/widgets/login_required_sheet.dart';

class DiamondStorePage extends ConsumerStatefulWidget {
  const DiamondStorePage({super.key});

  @override
  ConsumerState<DiamondStorePage> createState() => _DiamondStorePageState();
}

class _DiamondStorePageState extends ConsumerState<DiamondStorePage>
    with SingleTickerProviderStateMixin {
  bool _isWatchingAd = false;
  late AnimationController _glowController;

  static const List<int> _streakRewards = [10, 15, 20, 25, 30, 40, 50];
  static const List<String> _dayLabels = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
  ];

  // ── Diamond Packs ──────────────────────────────────────────────────────────
  static const List<_DiamondPack> _packs = [
    _DiamondPack(
      id: 'pack_300',
      diamonds: 300,
      price: 49,
      tier: _PackTier.small,
    ),
    _DiamondPack(
      id: 'pack_800',
      diamonds: 800,
      price: 99,
      tier: _PackTier.medium,
      badge: '⭐ MOST POPULAR',
      isPopular: true,
    ),
    _DiamondPack(
      id: 'pack_2000',
      diamonds: 2000,
      price: 199,
      tier: _PackTier.medium,
      badge: '+20% EXTRA',
    ),
    _DiamondPack(
      id: 'pack_3500',
      diamonds: 3500,
      price: 299,
      tier: _PackTier.large,
      badge: 'LIMITED OFFER',
    ),
    _DiamondPack(
      id: 'pack_7000',
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

  Future<void> _watchAd() async {
    SafeTap.run('watch_ad_bonus', () async {
      final authState = ref.read(authProvider);
      if (!authState.isAuthenticated) {
        showLoginRequiredSheet(context, reason: LoginRequiredReason.diamonds);
        return;
      }

      setState(() => _isWatchingAd = true);
      try {
        AdHelper.showRewardedAd(
          onCompleted: (earned) {
            if (earned && authState.user != null) {
              ref.read(diamondProvider.notifier).addAdReward(authState.user!.uid);
              RoyalSnackBar.show(context, '💎 +10 Diamonds added to your wallet!');
              HapticFeedback.mediumImpact();
            }
            if (mounted) setState(() => _isWatchingAd = false);
          },
        );
      } catch (e) {
        if (mounted) setState(() => _isWatchingAd = false);
      }
    });
  }

  Future<void> _buyDiamondPack(_DiamondPack pack) async {
    SafeTap.run('buy_diamond_pack_${pack.id}', () async {
      final authState = ref.read(authProvider);
      if (!authState.isAuthenticated) {
        showLoginRequiredSheet(context, reason: LoginRequiredReason.diamonds);
        return;
      }
      
      HapticFeedback.selectionClick();
      RoyalSnackBar.show(
        context,
        '🛠️ Payment system is under maintenance. Please check back later!',
        type: SnackBarType.info,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final diamondState = ref.watch(diamondProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF06080F),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Premium AppBar ─────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 0,
            pinned: true,
            floating: false,
            backgroundColor: Colors.transparent,
            elevation: 0,
            flexibleSpace: ClipRect(
              child: BackdropFilter(
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
                  child: const Text(
                    '💎',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
                const SizedBox(width: 8),
                ShaderMask(
                  shaderCallback: (b) =>
                      AppColors.goldGradient.createShader(b),
                  child: const Text(
                    'DIAMOND STORE',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      letterSpacing: 2.5,
                    ),
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

                // ── Daily Streak ───────────────────────────────────────────
                _buildSectionLabel('🔥 Daily Streak', subtitle: 'Login every day to grow your stash'),
                const SizedBox(height: 12),
                _buildStreakCard(diamondState),
                const SizedBox(height: 28),

                // ── Watch & Earn ─────────────────────────────────────────
                _buildSectionLabel('📺 Watch & Earn', subtitle: 'Up to 5 ads per day · +10 💎 each'),
                const SizedBox(height: 12),
                _buildAdCard(diamondState),
                const SizedBox(height: 28),

                // ── How to Earn ──────────────────────────────────────────
                _buildSectionLabel('💰 How to Earn', subtitle: 'Max 130 💎 diamonds per day'),
                const SizedBox(height: 12),
                _buildEarnCard(),
                const SizedBox(height: 36),

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
                colors: [Color(0xFF1E1040), Color(0xFF0C1730), Color(0xFF06080F)],
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
            child: const Center(
              child: Text('💎', style: TextStyle(fontSize: 42)),
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
                      child: const Text(
                        '💎 Diamonds',
                        style: TextStyle(
                          color: Color(0xFF8899CC),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
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
    final currentStreak = diamondState.streak;
    final canClaim = diamondState.canClaimToday;
    final currentDay = currentStreak.clamp(0, 7);
    
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1220),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: canClaim ? AppColors.goldMid.withAlpha(80) : const Color(0xFF1E2840), 
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: canClaim ? AppColors.goldMid.withAlpha(20) : const Color(0x20FF6B00),
            blurRadius: 20,
            spreadRadius: -4,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFFFF6B00), Color(0xFFFF3300)]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Text('🔥', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 4),
                    Text(
                      currentDay == 0
                          ? 'Start Streak'
                          : 'Day $currentDay / 7',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                'Complete all 7 days → 🎁 Bonus!',
                style: TextStyle(
                    color: Colors.white.withAlpha(80), fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: List.generate(7, (i) {
              final dayNum = i + 1;
              final isPast = dayNum < currentDay;
              final isCurrent = dayNum == currentDay;

              Color bg;
              Color border;
              LinearGradient? grad;

              if (isCurrent) {
                bg = Colors.transparent;
                border = AppColors.goldMid;
                grad = const LinearGradient(
                  colors: [Color(0xFF3D2A00), Color(0xFF1E1500)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                );
              } else if (isPast) {
                bg = const Color(0xFF0A2010);
                border = const Color(0xFF2A7040);
                grad = null;
              } else {
                bg = const Color(0xFF0D1220);
                border = const Color(0xFF1A2240);
                grad = null;
              }

              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: bg,
                    gradient: grad != null
                        ? LinearGradient(
                            colors: grad.colors,
                            begin: grad.begin,
                            end: grad.end,
                          )
                        : null,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: border, width: 1.2),
                    boxShadow: isCurrent
                        ? [
                            BoxShadow(
                              color: AppColors.goldMid.withAlpha(60),
                              blurRadius: 12,
                              spreadRadius: 1,
                            )
                          ]
                        : [],
                  ),
                  child: Column(
                    children: [
                      Text(
                        isCurrent
                            ? '💎'
                            : isPast
                                ? '✓'
                                : '·',
                        style: TextStyle(
                          fontSize: isCurrent ? 12 : 11,
                          color: isPast ? Colors.greenAccent : const Color(0xFF556688),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _dayLabels[i],
                        style: TextStyle(
                          color: isCurrent
                              ? AppColors.goldLight
                              : isPast
                                  ? Colors.greenAccent.withAlpha(180)
                                  : const Color(0xFF445566),
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
                              : isPast
                                  ? const Color(0xFF447744)
                                  : const Color(0xFF334455),
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF080C18),
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: const Color(0xFF1A2240), width: 1),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    color: Color(0xFF446688), size: 13),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'Miss a day and your streak resets. Day 7 gives a special bonus!',
                    style: TextStyle(
                        color: Colors.white.withAlpha(70), fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fade().slideY(begin: 0.05);
  }

  // ── Ad Card ────────────────────────────────────────────────────────────────
  Widget _buildAdCard(DiamondState diamondState) {
    final isPro = ref.watch(authProvider).user?.isSubscribed ?? false;
    final canWatch = diamondState.canWatchAd;
    final remaining = diamondState.remainingAdsToday;
    final watched = 5 - remaining;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1220),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: canWatch
              ? AppColors.goldMid.withAlpha(50)
              : const Color(0xFF1E2840),
          width: 1.2,
        ),
        boxShadow: canWatch
            ? [
                BoxShadow(
                  color: AppColors.goldMid.withAlpha(20),
                  blurRadius: 24,
                  spreadRadius: -4,
                )
              ]
            : [],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Play icon container
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: canWatch
                      ? const LinearGradient(
                          colors: [Color(0xFF2A2000), Color(0xFF1A1500)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: canWatch ? null : const Color(0xFF0D1220),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: canWatch
                        ? AppColors.goldMid.withAlpha(60)
                        : const Color(0xFF1A2240),
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.play_circle_fill_rounded,
                  color: canWatch ? AppColors.goldMid : const Color(0xFF334466),
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          isPro ? 'Pro Bonus' : 'Watch Ad',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFD76A), Color(0xFFFFAA00)],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            '+10 💎',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      canWatch
                          ? (isPro 
                              ? '$remaining claims remaining' 
                              : '$remaining ads remaining today')
                          : '⛔ Limit reached — come back tomorrow!',
                      style: TextStyle(
                        color: canWatch
                            ? const Color(0xFF6688AA)
                            : Colors.redAccent.withAlpha(180),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Progress bar
          Row(
            children: [
              Text(
                isPro ? '$watched/5 claimed' : '$watched/5 watched',
                style: TextStyle(
                    color: Colors.white.withAlpha(70), fontSize: 11),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: watched / 5,
                    backgroundColor: const Color(0xFF1A2240),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      canWatch ? AppColors.goldMid : const Color(0xFF334466),
                    ),
                    minHeight: 6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Watch button
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: canWatch ? _watchAd : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: canWatch
                      ? const LinearGradient(
                          colors: [Color(0xFFFFD76A), Color(0xFFFFAA00)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: canWatch ? null : const Color(0xFF0D1220),
                  borderRadius: BorderRadius.circular(14),
                  border: canWatch
                      ? null
                      : Border.all(
                          color: const Color(0xFF1E2840), width: 1),
                  boxShadow: canWatch
                      ? [
                          BoxShadow(
                            color: AppColors.goldMid.withAlpha(80),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
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
                            strokeWidth: 2.5,
                          ),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isPro
                                ? Icons.auto_awesome
                                : (canWatch ? Icons.play_arrow_rounded : Icons.lock_rounded),
                            color: canWatch
                                ? Colors.black
                                : const Color(0xFF334466),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isPro
                                ? 'Claim Bonus · Get +10 💎'
                                : (canWatch
                                    ? 'Watch Ad · Earn +10 💎'
                                    : 'Daily Limit Reached (5/day)'),
                            style: TextStyle(
                              color: canWatch
                                  ? Colors.black
                                  : const Color(0xFF334466),
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              letterSpacing: 0.3,
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

  // ── Earn Card ──────────────────────────────────────────────────────────────
  Widget _buildEarnCard() {
    final items = [
      ('🔥', 'Daily Login Streak', 'Day 1–7: +10 to +50 💎 per day'),
      ('📺', 'Watch & Earn (Ads)', '+10 💎 per ad · max 5 ads/day = 50 💎'),
      ('📥', 'Download Wallpaper', '+5 💎 · free & premium · 80 💎/day cap'),
      ('🖼️', 'Set as Wallpaper', '+5 💎 · free & premium · 80 💎/day cap'),
      ('🏆', 'Daily Maximum', 'Up to 130 💎/day  (80 actions + 50 ads)'),
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
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 13),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFF141830),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: const Color(0xFF1E2840), width: 1),
                      ),
                      child: Center(
                        child: Text(item.$1,
                            style: const TextStyle(fontSize: 17)),
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
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            item.$3,
                            style: const TextStyle(
                                color: Color(0xFF5577AA),
                                fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    // Gold chevron for the last "max" item
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
                    height: 1, color: Color(0xFF141C2C), indent: 16, endIndent: 16),
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
                      '💎 BUY DIAMONDS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Instant Delivery • Secure Digital Payments',
                    style:
                        TextStyle(color: Colors.white.withAlpha(70), fontSize: 11),
                  ),
                ],
              ),
            ),
            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.red.withAlpha(40),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.red.withAlpha(80)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.pause_circle_filled_rounded, color: Colors.white, size: 12),
                  SizedBox(width: 4),
                  Text(
                    'CLOSED',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
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
            childAspectRatio: 0.72,
          ),
          itemCount: _packs.length,
          itemBuilder: (context, i) {
            return _DiamondPackCard(
              pack: _packs[i],
              onTap: () => _buyDiamondPack(_packs[i]),
            )
                .animate()
                .fade(delay: Duration(milliseconds: 60 * i))
                .scale(
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
              Icon(Icons.lock_rounded,
                  color: Colors.white.withAlpha(50), size: 12),
              const SizedBox(width: 5),
              Text(
                'Payments are temporarily closed for maintenance  •  Coming back soon',
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
        ? 38.0
        : p.tier == _PackTier.large
            ? 32.0
            : 24.0;

    if (p.tier == _PackTier.small) {
      return Text('💎', style: TextStyle(fontSize: size));
    } else if (p.tier == _PackTier.medium) {
      return SizedBox(
        width: 52,
        height: 46,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
                top: 0,
                child: Text('💎', style: TextStyle(fontSize: size - 2))),
            Positioned(
                bottom: 0,
                left: 4,
                child: Text('💎', style: TextStyle(fontSize: size - 5))),
            Positioned(
                bottom: 0,
                right: 4,
                child: Text('💎', style: TextStyle(fontSize: size - 5))),
          ],
        ),
      );
    } else if (p.tier == _PackTier.large) {
      return SizedBox(
        width: 58,
        height: 54,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
                top: 0,
                child: Text('💎', style: TextStyle(fontSize: size))),
            Positioned(
                bottom: 2,
                left: 0,
                child: Text('💎', style: TextStyle(fontSize: size - 6))),
            Positioned(
                bottom: 2,
                right: 0,
                child: Text('💎', style: TextStyle(fontSize: size - 6))),
            Positioned(
                bottom: 0,
                child: Text('💎', style: TextStyle(fontSize: size - 9))),
          ],
        ),
      );
    } else {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🎁', style: TextStyle(fontSize: size)),
          const SizedBox(height: 2),
          const Text('💎💎💎', style: TextStyle(fontSize: 13, letterSpacing: -2)),
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
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.border.withAlpha(140), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: c.glow,
                blurRadius: 16,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            children: [
              // ── Top: diamond count strip ──────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      c.border.withAlpha(60),
                      c.border.withAlpha(20),
                    ],
                  ),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(14)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('💎', style: TextStyle(fontSize: 10)),
                    const SizedBox(width: 3),
                    Text(
                      _formatDiamonds(p.diamonds),
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

              // ── Badge ──────────────────────────────────────────────────
              if (p.badge != null) ...[
                const SizedBox(height: 5),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: c.badgeBg,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: c.badgeBg.withAlpha(100),
                        blurRadius: 8,
                        spreadRadius: -2,
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
              ] else
                const SizedBox(height: 5),

              // ── Diamond Art ─────────────────────────────────────────────
              Expanded(
                child: Center(child: _buildDiamondArt()),
              ),

              // ── Buy button ─────────────────────────────────────────────
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(7, 0, 7, 7),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [c.btnTop, c.btnBottom],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: c.btnBottom.withAlpha(120),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  '₹${p.price}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    shadows: [
                      Shadow(
                        color: Colors.black38,
                        offset: Offset(0, 1),
                        blurRadius: 3,
                      )
                    ],
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
