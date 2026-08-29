import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/safe_tap.dart';
import '../../../core/utils/royal_snack_bar.dart';
import '../../providers/auth_provider.dart';
import '../../../core/services/adaptive_performance.dart';
import '../../../core/widgets/login_required_sheet.dart';
import '../../../core/services/iap_service.dart';
import '../../../core/constants/iap_constants.dart';

// ── Lifetime plan ────────────────────────────────────────────────────────────
const _kPrice = 99;
const _kOriginalPrice = 999;

// ── PRO Benefits ─────────────────────────────────────────────────────────────
const _kBenefits = [
  (Icons.all_inclusive_rounded, 'Unlimited PRO Wallpapers', 'Access every premium 4K wallpaper — forever'),
  (Icons.high_quality_rounded, 'Ultra-HD 4K Downloads', 'Download lossless quality on every wallpaper'),
  (Icons.block_rounded, 'Completely Ad-Free', 'No ads, ever — a seamless experience'),
  (Icons.diamond_rounded, 'Diamond Streak Bonuses', 'Earn boosted diamonds on daily streaks'),
  (Icons.bolt_rounded, 'Priority New Releases', 'First access to every new drop'),
  (Icons.workspace_premium_rounded, 'Royal PRO Badge', 'Exclusive badge on your profile'),
];

class SubscriptionPage extends ConsumerStatefulWidget {
  const SubscriptionPage({super.key});

  @override
  ConsumerState<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends ConsumerState<SubscriptionPage>
    with TickerProviderStateMixin {
  late AnimationController _glowController;
  late AnimationController _pulseController;
  late AnimationController _particleController;
  late AnimationController _shimmerController;

  bool _isPressed = false;
  bool _isPurchasing = false;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _glowController.dispose();
    _pulseController.dispose();
    _particleController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _subscribe() async {
    if (_isPurchasing) return;

    SafeTap.run('subscribe_pro_lifetime', () async {
      final authState = ref.read(authProvider);

      if (!authState.isAuthenticated) {
        showLoginRequiredSheet(context, reason: LoginRequiredReason.diamonds);
        return;
      }

      final user = authState.user!;

      if (user.isSubscribed) {
        RoyalSnackBar.show(
          context,
          '👑 You are already a PRO member!',
          type: SnackBarType.success,
        );
        return;
      }

      setState(() => _isPurchasing = true);
      HapticFeedback.heavyImpact();

      try {
        final iapService = ref.read(iapServiceProvider);
        await iapService.buyProduct(IapConstants.lifetime);
      } catch (e) {
        if (!mounted) return;
        RoyalSnackBar.show(
          context,
          '❌ Could not initiate purchase: $e',
          type: SnackBarType.error,
        );
      } finally {
        if (mounted) {
          setState(() => _isPurchasing = false);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSubscribed = ref.watch(authProvider).user?.isSubscribed ?? false;

    return Scaffold(
      backgroundColor: const Color(0xFF04050D),
      body: Stack(
        children: [
          // ── Animated background orbs ────────────────────────────────────
          AnimatedBuilder(
            animation: _glowController,
            builder: (_, __) {
              final g = _glowController.value;
              return Stack(
                children: [
                  Positioned(
                    top: -60,
                    left: -80,
                    child: Container(
                      width: 340,
                      height: 340,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Color.lerp(const Color(0x28D4A017), const Color(0x55D4A017), g)!,
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 220,
                    right: -110,
                    child: Container(
                      width: 280,
                      height: 280,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Color.lerp(const Color(0x187C3AED), const Color(0x387C3AED), 1 - g)!,
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 180,
                    left: -60,
                    child: Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Color.lerp(const Color(0x15FDDB6A), const Color(0x30FDDB6A), g)!,
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          // ── Floating particles ──────────────────────────────────────────
          if (AdaptivePerformance.enableAnimations)
            AnimatedBuilder(
              animation: _particleController,
              builder: (_, __) {
                return CustomPaint(
                  size: Size(size.width, size.height),
                  painter: _ParticlePainter(_particleController.value),
                );
              },
            ),

          // ── Main scroll content ─────────────────────────────────────────
          CustomScrollView(
            slivers: [
              // App bar
              SliverAppBar(
                expandedHeight: 0,
                pinned: true,
                backgroundColor: Colors.transparent,
                elevation: 0,
                flexibleSpace: ClipRect(
                  child: AdaptivePerformance.enableBackdropBlur
                      ? BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                          child: Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xCC04050D), Color(0x9904050D)],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                        )
                      : Container(color: const Color(0xFF04050D)),
                ),
                leading: IconButton(
                  icon: Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withAlpha(20)),
                    ),
                    child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 16),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                title: ShaderMask(
                  shaderCallback: (b) => AppColors.goldGradient.createShader(b),
                  child: const Text(
                    'PRO MEMBERSHIP',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      letterSpacing: 2.5,
                    ),
                  ),
                ),
                centerTitle: true,
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // ── Hero crown badge ─────────────────────────────────
                      _buildHeroBadge(),
                      const SizedBox(height: 28),

                      // ── Headline ─────────────────────────────────────────
                      ShaderMask(
                        shaderCallback: (b) => AppColors.goldGradient.createShader(b),
                        child: const Text(
                          'Unlock Everything',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ).animate().fade(delay: 200.ms),

                      const SizedBox(height: 8),

                      Text(
                        'One-time payment. Lifetime access.\nNo subscriptions, no recurring charges.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                          height: 1.6,
                        ),
                      ).animate().fade(delay: 300.ms),

                      const SizedBox(height: 32),

                      // ── Pricing card ─────────────────────────────────────
                      if (!isSubscribed) _buildPricingCard(),
                      if (!isSubscribed) const SizedBox(height: 32),

                      // ── PRO Already active ────────────────────────────────
                      if (isSubscribed) ...[
                        _buildAlreadyProCard(),
                        const SizedBox(height: 32),
                      ],

                      // ── Benefits list ─────────────────────────────────────
                      _buildBenefitsList(),

                      const SizedBox(height: 32),

                      // ── CTA button ───────────────────────────────────────
                      if (!isSubscribed) ...[
                        _buildCTAButton(),
                        const SizedBox(height: 16),

                        // Trust row
                        _buildTrustRow(),

                        const SizedBox(height: 14),

                        Text(
                          'Secure payment via Google Play · Instant activation',
                          style: TextStyle(
                            color: AppColors.textMuted.withAlpha(140),
                            fontSize: 11,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 20),
                        _buildRestoreButton(),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Hero Badge ─────────────────────────────────────────────────────────────
  Widget _buildHeroBadge() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (_, child) {
        final p = _pulseController.value;
        return Stack(
          alignment: Alignment.center,
          children: [
            // Outermost pulse ring — fades in/out
            Container(
              width: 148 + p * 18,
              height: 148 + p * 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.goldMid.withAlpha((18 + 15 * (1 - p)).round()),
                  width: 1,
                ),
              ),
            ),
            // Middle ring
            Container(
              width: 122 + p * 6,
              height: 122 + p * 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.goldMid.withAlpha((40 + 25 * p).round()),
                  width: 1.5,
                ),
              ),
            ),
            // Inner glow halo
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.goldMid.withAlpha((35 + (25 * p).round())),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            // Core badge
            Container(
              width: 92, height: 92,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFD4A017), Color(0xFF9B7000)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.goldMid.withAlpha((70 + (50 * p)).round()),
                    blurRadius: 32 + p * 18,
                    spreadRadius: 3,
                  ),
                  BoxShadow(
                    color: const Color(0xFFFFD700).withAlpha(30),
                    blurRadius: 60,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: child,
            ),
          ],
        );
      },
      child: const Center(
        child: Text('👑', style: TextStyle(fontSize: 42)),
      ),
    ).animate()
      .scale(duration: 700.ms, curve: Curves.easeOutBack)
      .fade(duration: 500.ms);
  }

  // ── Pricing card ───────────────────────────────────────────────────────────
  Widget _buildPricingCard() {
    return AnimatedBuilder(
      animation: _glowController,
      builder: (_, __) {
        final g = _glowController.value;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1A1200), Color(0xFF0D1020)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Color.lerp(const Color(0xFFD4A017), const Color(0xFFFFD700), g)!,
              width: 1.8,
            ),
            boxShadow: [
              BoxShadow(
                color: Color.lerp(
                  const Color(0x30D4A017),
                  const Color(0x55D4A017),
                  g,
                )!,
                blurRadius: 30,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            children: [
              // "LIFETIME PRO" badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  gradient: AppColors.goldGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  '👑  LIFETIME PRO  ·  ONE-TIME PAYMENT',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Price display
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Strikethrough original price
                  Text(
                    '₹$_kOriginalPrice',
                    style: TextStyle(
                      color: Colors.white.withAlpha(100),
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.lineThrough,
                      decorationColor: Colors.white38,
                    ),
                  ),
                  const SizedBox(width: 12),
                  ShaderMask(
                    shaderCallback: (b) => AppColors.goldGradient.createShader(b),
                    child: const Text(
                      '₹$_kPrice',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 56,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                        height: 1,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Savings pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A2010),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.greenAccent.withAlpha(60)),
                ),
                child: const Text(
                  '🔥 You save ₹900 — 90% OFF',
                  style: TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
              ).animate(onPlay: (c) => c.repeat(reverse: true))
               .shimmer(duration: 2500.ms, color: Colors.greenAccent.withAlpha(60)),
            ],
          ),
        );
      },
    ).animate()
      .fade(delay: 350.ms)
      .slideY(begin: 0.12, end: 0, delay: 350.ms, duration: 500.ms, curve: Curves.easeOutCubic);
  }

  // ── Already PRO card ───────────────────────────────────────────────────────
  Widget _buildAlreadyProCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.goldMid.withAlpha(40),
            AppColors.goldMid.withAlpha(10),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.goldMid.withAlpha(120), width: 1.8),
      ),
      child: Column(
        children: [
          const Icon(Icons.workspace_premium_rounded, color: AppColors.goldMid, size: 52)
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
            'You have lifetime access to all premium wallpapers. Enjoy Royal Pixels PRO!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withAlpha(160),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    ).animate().fadeIn().scale();
  }

  // ── Benefits list ──────────────────────────────────────────────────────────
  Widget _buildBenefitsList() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0C0E1A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF1C2030), width: 1.2),
      ),
      child: Column(
        children: _kBenefits.asMap().entries.map((e) {
          final i = e.key;
          final benefit = e.value;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.goldMid.withAlpha(30),
                            AppColors.goldMid.withAlpha(10),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.goldMid.withAlpha(50), width: 1),
                      ),
                      child: Center(
                        child: ShaderMask(
                          shaderCallback: (b) => AppColors.goldGradient.createShader(b),
                          child: Icon(benefit.$1, color: Colors.white, size: 22),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            benefit.$2,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            benefit.$3,
                            style: const TextStyle(
                              color: Color(0xFF5577AA),
                              fontSize: 11.5,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF4CAF50), size: 20),
                  ],
                ),
              ).animate().fade(delay: Duration(milliseconds: 400 + i * 70)).slideX(begin: 0.06, end: 0),
              if (i < _kBenefits.length - 1)
                const Divider(height: 1, color: Color(0xFF141A28), indent: 18, endIndent: 18),
            ],
          );
        }).toList(),
      ),
    );
  }

  // ── CTA Button ─────────────────────────────────────────────────────────────
  Widget _buildCTAButton() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (_, __) {
        final p = _pulseController.value;
        return GestureDetector(
          onTapDown: (_) {
            if (!_isPurchasing) {
              setState(() => _isPressed = true);
              HapticFeedback.mediumImpact();
            }
          },
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          onTap: _subscribe,
          child: AnimatedScale(
            scale: _isPressed ? 0.96 : 1.0,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFD4A017), Color(0xFFB8860B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.goldMid.withAlpha((60 + (50 * p).round())),
                    blurRadius: 24 + p * 16,
                    offset: const Offset(0, 8),
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: const Color(0xFFD4A017).withAlpha((20 + (20 * p).round())),
                    blurRadius: 50,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Shimmer sweep
                  if (!_isPurchasing)
                    AnimatedBuilder(
                      animation: _shimmerController,
                      builder: (_, __) {
                        return ShaderMask(
                          shaderCallback: (rect) {
                            final sweep = _shimmerController.value;
                            return LinearGradient(
                              begin: Alignment(-2.0 + sweep * 4, 0),
                              end: Alignment(-1.0 + sweep * 4, 0),
                              colors: [
                                Colors.transparent,
                                Colors.white.withAlpha(55),
                                Colors.transparent,
                              ],
                            ).createShader(rect);
                          },
                          blendMode: BlendMode.srcATop,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(22),
                              color: Colors.white,
                            ),
                          ),
                        );
                      },
                    ),
                  // Button content
                  if (_isPurchasing)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Connecting to Google Play…',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    )
                  else
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Text('👑', style: TextStyle(fontSize: 22)),
                            SizedBox(width: 10),
                            Text(
                              'GET LIFETIME PRO — ₹$_kPrice',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'One-time payment · Never expires',
                          style: TextStyle(
                            color: Colors.black.withAlpha(160),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      },
    ).animate()
      .slideY(begin: 0.4, end: 0, duration: 500.ms, curve: Curves.easeOutCubic)
      .fade(duration: 400.ms);
  }

  // ── Trust row ──────────────────────────────────────────────────────────────
  Widget _buildTrustRow() {
    final items = [
      (Icons.verified_rounded, 'Verified'),
      (Icons.lock_rounded, 'Secure'),
      (Icons.all_inclusive_rounded, 'Lifetime'),
      (Icons.support_agent_rounded, 'Support'),
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: items.map((e) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          children: [
            Icon(e.$1, color: AppColors.goldMid.withAlpha(200), size: 18),
            const SizedBox(height: 4),
            Text(
              e.$2,
              style: TextStyle(
                color: AppColors.textMuted.withAlpha(180),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildRestoreButton() {
    return TextButton(
      onPressed: () async {
        HapticFeedback.lightImpact();
        if (!mounted) return;
        try {
          RoyalSnackBar.show(context, 'Checking for past purchases...', type: SnackBarType.info);
          await ref.read(iapServiceProvider).restorePurchases();
          if (!mounted) return;
        } catch (e) {
          if (!mounted) return;
          RoyalSnackBar.show(context, 'Restore failed: $e', type: SnackBarType.error);
        }
      },
      style: TextButton.styleFrom(
        foregroundColor: AppColors.textMuted,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
      child: const Text(
        'Restore Purchases',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }
}

// ── Particle painter ──────────────────────────────────────────────────────────
class _ParticlePainter extends CustomPainter {
  final double progress;
  _ParticlePainter(this.progress);

  static final List<_Particle> _particles = List.generate(22, (i) => _Particle(i));

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in _particles) {
      final t = (progress + p.offset) % 1.0;
      final x = p.startX * size.width + sin(t * pi * 2 + p.phaseX) * 28;
      final y = size.height - t * (size.height + 40) + p.startY;
      final alpha = (sin(t * pi) * 170).round().clamp(0, 255);
      final paint = Paint()
        ..color = AppColors.goldLight.withAlpha(alpha)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(x, y), p.radius, paint);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter oldDelegate) => true;
}

class _Particle {
  final double startX;
  final double startY;
  final double offset;
  final double phaseX;
  final double radius;

  _Particle(int seed)
      : startX = (seed * 0.047 + 0.02),
        startY = (seed * 31.0) % 60 - 30,
        offset = (seed * 0.046) % 1.0,
        phaseX = seed * 0.7,
        radius = 0.8 + (seed % 4) * 0.7;
}
