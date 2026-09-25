import 'package:royal_pixels/core/l10n/app_localizations.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/reward_ad_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/royal_snack_bar.dart';
import '../../../core/widgets/login_required_sheet.dart';
import '../../providers/auth_provider.dart';
import '../../providers/diamond_provider.dart';

/// Premium "Watch & Earn" section embedded inside Diamond Store.
class WatchEarnSection extends ConsumerStatefulWidget {
  const WatchEarnSection({super.key});

  @override
  ConsumerState<WatchEarnSection> createState() => _WatchEarnSectionState();
}

class _WatchEarnSectionState extends ConsumerState<WatchEarnSection>
    with TickerProviderStateMixin {
  final RewardAdService _adService = RewardAdService.instance;

  late AnimationController _glowController;
  late AnimationController _pulseController;
  late AnimationController _celebController;

  bool _showCelebration = false;
  int _lastEarned = 0;
  bool _isWatching = false;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _celebController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _adService.addListener(_onAdStateChanged);
    _adService.initialize();
  }

  void _onAdStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _adService.removeListener(_onAdStateChanged);
    _glowController.dispose();
    _pulseController.dispose();
    _celebController.dispose();
    super.dispose();
  }

  Future<void> _watchAd() async {
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated) {
      showLoginRequiredSheet(context, reason: LoginRequiredReason.diamonds);
      return;
    }
    if (_isWatching) return;

    HapticFeedback.mediumImpact();
    setState(() => _isWatching = true);

    _adService.showRewardedAd(
      onRewarded: (diamonds) async {
        // Add diamonds to wallet
        final userId = auth.user!.uid;
        await ref.read(diamondProvider.notifier).addDiamonds(userId, diamonds);

        if (mounted) {
          setState(() {
            _lastEarned = diamonds;
            _showCelebration = true;
            _isWatching = false;
          });
          HapticFeedback.heavyImpact();
          _celebController.forward(from: 0).then((_) {
            if (mounted) setState(() => _showCelebration = false);
          });
        }
      },
      onFailed: () {
        if (mounted) {
          setState(() => _isWatching = false);
          RoyalSnackBar.show(
            context,
            '⚠️ Ad not ready, please try again shortly',
            type: SnackBarType.info,
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    if (user?.isSubscribed ?? false) {
      return const SizedBox.shrink();
    }

    final watched = _adService.adsWatchedToday;
    final earned = _adService.diamondsEarnedToday;
    final cooldown = _adService.isCooldownActive;
    final secs = _adService.cooldownSecondsRemaining;
    final capReached = _adService.isDailyCapReached;
    final adReady = _adService.isAdReady;
    final canWatch = _adService.canWatchAd && !_isWatching;

    return Stack(
      children: [
        AnimatedBuilder(
          animation: _glowController,
          builder: (_, child) {
            final g = _glowController.value;
            return Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0E0A20), Color(0xFF08101E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Color.lerp(
                    const Color(0x40A060FF),
                    const Color(0x90C090FF),
                    g,
                  )!,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color.lerp(
                      const Color(0x10A060FF),
                      const Color(0x30A060FF),
                      g,
                    )!,
                    blurRadius: 30,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: child,
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(earned, capReached),
                const SizedBox(height: 20),
                _buildProgressSlots(watched),
                const SizedBox(height: 20),
                _buildProgressBar(earned),
                const SizedBox(height: 20),
                _buildWatchButton(canWatch, cooldown, secs, capReached, adReady),
                if (!capReached) ...[
                  const SizedBox(height: 14),
                  _buildInfoRow(),
                ],
              ],
            ),
          ),
        ),

        // Celebration overlay
        if (_showCelebration)
          Positioned.fill(
            child: _DiamondCelebration(
              diamonds: _lastEarned,
              onComplete: () => setState(() => _showCelebration = false),
            ),
          ),
      ],
    );
  }

  Widget _buildHeader(int earned, bool capReached) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7C3AED).withAlpha(80),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Center(
            child: Text('📺', style: TextStyle(fontSize: 22)),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppLocalizations.of(context)!.watchEarn,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              Text(
                capReached
                    ? '🎉 Daily limit reached! Resets at midnight'
                    : 'Watch ads • Earn 20 💎 each • 5 ads/day',
                style: TextStyle(
                  color: Colors.white.withAlpha(120),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        // Earned badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF1A0E3A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF7C3AED).withAlpha(120),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ShaderMask(
                shaderCallback: (b) => AppColors.goldGradient.createShader(b),
                child: const Icon(Icons.diamond_rounded,
                    color: Colors.white, size: 12),
              ),
              const SizedBox(width: 4),
              ShaderMask(
                shaderCallback: (b) => AppColors.goldGradient.createShader(b),
                child: Text(
                  '$earned',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProgressSlots(int watched) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(RewardAdService.maxAdsPerDay, (i) {
        final isDone = i < watched;
        final isNext = i == watched;

        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < 4 ? 8 : 0),
            child: Column(
              children: [
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (_, __) {
                    return Container(
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: isDone
                            ? const LinearGradient(
                                colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
                              )
                            : isNext
                                ? LinearGradient(
                                    colors: [
                                      Color.lerp(
                                        const Color(0xFF2A1060),
                                        const Color(0xFF3D1A80),
                                        _pulseController.value,
                                      )!,
                                      const Color(0xFF1A0840),
                                    ],
                                  )
                                : const LinearGradient(
                                    colors: [
                                      Color(0xFF0F0D1A),
                                      Color(0xFF0A0B14)
                                    ],
                                  ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDone
                              ? const Color(0xFF7C3AED).withAlpha(200)
                              : isNext
                                  ? Color.lerp(
                                      const Color(0x607C3AED),
                                      const Color(0xBB9C5AFF),
                                      _pulseController.value,
                                    )!
                                  : const Color(0xFF1E2030),
                          width: isNext ? 2 : 1.2,
                        ),
                        boxShadow: isDone || isNext
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF7C3AED).withAlpha(
                                    isDone ? 80 : 40,
                                  ),
                                  blurRadius: 12,
                                  spreadRadius: 0,
                                )
                              ]
                            : [],
                      ),
                      child: Center(
                        child: isDone
                            ? ShaderMask(
                                shaderCallback: (b) =>
                                    AppColors.goldGradient.createShader(b),
                                child: const Icon(Icons.diamond_rounded,
                                    color: Colors.white, size: 22),
                              ).animate().scale(
                                  begin: const Offset(0.5, 0.5),
                                  curve: Curves.elasticOut,
                                )
                            : isNext
                                ? const Icon(Icons.play_circle_rounded,
                                    color: Color(0xFF9C6AFF), size: 22)
                                : Text(
                                    '${i + 1}',
                                    style: const TextStyle(
                                      color: Color(0xFF3A3550),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 6),
                Text(AppLocalizations.of(context)!.n20,
                  style: TextStyle(
                    color: isDone
                        ? AppColors.goldMid
                        : isNext
                            ? const Color(0xFF9C6AFF)
                            : const Color(0xFF2A2840),
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildProgressBar(int earned) {
    final progress = earned / RewardAdService.maxDiamondsPerDay;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(AppLocalizations.of(context)!.sessionProgress,
              style: TextStyle(
                color: Colors.white.withAlpha(120),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '$earned / ${RewardAdService.maxDiamondsPerDay} 💎 today',
              style: const TextStyle(
                color: AppColors.goldLight,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Stack(
            children: [
              Container(
                height: 8,
                color: const Color(0xFF0F0D1A),
              ),
              AnimatedFractionallySizedBox(
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                widthFactor: progress.clamp(0.0, 1.0),
                child: Container(
                  height: 8,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF7C3AED), Color(0xFFD4A017)],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWatchButton(
    bool canWatch,
    bool cooldown,
    int secs,
    bool capReached,
    bool adReady,
  ) {
    final Color btnTop;
    final Color btnBottom;
    final Widget btnChild;

    if (capReached) {
      btnTop = const Color(0xFF1A1A2A);
      btnBottom = const Color(0xFF12121E);
      btnChild = Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🏆', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Text(AppLocalizations.of(context)!.dailyLimitReachedBackTomorrow,
            style: TextStyle(
              color: Colors.white.withAlpha(120),
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ],
      );
    } else if (cooldown) {
      btnTop = const Color(0xFF1A1040);
      btnBottom = const Color(0xFF100830);
      btnChild = Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.timer_rounded, color: Color(0xFF9C6AFF), size: 20),
          const SizedBox(width: 8),
          Text(
            'Next ad in $secs seconds...',
            style: const TextStyle(
              color: Color(0xFF9C6AFF),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      );
    } else if (!adReady || _isWatching) {
      btnTop = const Color(0xFF1A1040);
      btnBottom = const Color(0xFF100830);
      btnChild = Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white.withAlpha(150),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _isWatching ? 'Loading Ad...' : 'Loading Ad...',
            style: TextStyle(
              color: Colors.white.withAlpha(150),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
    } else {
      btnTop = const Color(0xFF7C3AED);
      btnBottom = const Color(0xFF4F46E5);
      btnChild = Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('▶️', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Text(AppLocalizations.of(context)!.watchAdEarn20,
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: (canWatch && !_isWatching) ? _watchAd : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [btnTop, btnBottom],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: canWatch && !_isWatching
              ? [
                  BoxShadow(
                    color: const Color(0xFF7C3AED).withAlpha(80),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
          border: Border.all(
            color: canWatch && !_isWatching
                ? const Color(0xFF9C6AFF).withAlpha(100)
                : Colors.white.withAlpha(10),
            width: 1,
          ),
        ),
        child: Center(child: btnChild),
      ),
    )
        .animate(
          target: canWatch && !_isWatching ? 1 : 0,
          onPlay: (c) => c.repeat(reverse: true),
        )
        .shimmer(
          duration: 2000.ms,
          color: Colors.white.withAlpha(20),
        );
  }

  Widget _buildInfoRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF080A14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1A1830), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              color: Color(0xFF5544AA), size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(AppLocalizations.of(context)!.n5AdsdayResetsAtMidnight15sCooldown20PerAd,
              style: TextStyle(
                color: Colors.white.withAlpha(80),
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Diamond Celebration Overlay ─────────────────────────────────────────────
class _DiamondCelebration extends StatefulWidget {
  final int diamonds;
  final VoidCallback onComplete;

  const _DiamondCelebration({
    required this.diamonds,
    required this.onComplete,
  });

  @override
  State<_DiamondCelebration> createState() => _DiamondCelebrationState();
}

class _DiamondCelebrationState extends State<_DiamondCelebration>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_Particle> _particles = [];
  final Random _rng = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    // Spawn particles
    for (int i = 0; i < 20; i++) {
      _particles.add(_Particle(
        x: _rng.nextDouble(),
        y: _rng.nextDouble() * 0.6 + 0.2,
        speedX: (_rng.nextDouble() - 0.5) * 0.8,
        speedY: -(_rng.nextDouble() * 0.6 + 0.4),
        size: _rng.nextDouble() * 12 + 8,
        delay: _rng.nextDouble() * 0.3,
      ));
    }

    _controller.forward().then((_) => widget.onComplete());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final alpha = t < 0.1
            ? (t / 0.1)
            : t > 0.7
                ? ((1.0 - t) / 0.3).clamp(0.0, 1.0)
                : 1.0;

        return Opacity(
          opacity: alpha,
          child: Stack(
            children: [
              // Blur background
              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(120),
                  borderRadius: BorderRadius.circular(24),
                ),
              ),

              // Flying particles
              ..._particles.map((p) {
                final pt = ((t - p.delay) / (1.0 - p.delay)).clamp(0.0, 1.0);
                final px = p.x + p.speedX * pt;
                final py = p.y + p.speedY * pt + 0.5 * pt * pt;
                final pa = (1.0 - pt).clamp(0.0, 1.0);

                return Positioned(
                  left: px * 300,
                  top: py * 200,
                  child: Opacity(
                    opacity: pa,
                    child: Transform.rotate(
                      angle: pt * 3.14,
                      child: ShaderMask(
                        shaderCallback: (b) =>
                            AppColors.goldGradient.createShader(b),
                        child: Icon(
                          Icons.diamond_rounded,
                          color: Colors.white,
                          size: p.size,
                        ),
                      ),
                    ),
                  ),
                );
              }),

              // Center reward text
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ShaderMask(
                      shaderCallback: (b) =>
                          AppColors.goldGradient.createShader(b),
                      child: const Icon(
                        Icons.diamond_rounded,
                        color: Colors.white,
                        size: 56,
                      ),
                    )
                        .animate()
                        .scale(
                          begin: const Offset(0.3, 0.3),
                          end: const Offset(1.2, 1.2),
                          curve: Curves.elasticOut,
                          duration: 700.ms,
                        )
                        .then()
                        .scale(
                          end: const Offset(1.0, 1.0),
                          duration: 200.ms,
                        ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF7C3AED).withAlpha(120),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: ShaderMask(
                        shaderCallback: (b) =>
                            AppColors.goldGradient.createShader(b),
                        child: Text(
                          '+${widget.diamonds} DIAMONDS!',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    )
                        .animate()
                        .fade(duration: 300.ms)
                        .slideY(begin: 0.3, curve: Curves.easeOutBack),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Particle {
  final double x, y, speedX, speedY, size, delay;
  const _Particle({
    required this.x,
    required this.y,
    required this.speedX,
    required this.speedY,
    required this.size,
    required this.delay,
  });
}
