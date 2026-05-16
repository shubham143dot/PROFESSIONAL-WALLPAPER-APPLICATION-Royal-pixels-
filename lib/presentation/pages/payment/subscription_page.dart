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

// ── Plan model ──────────────────────────────────────────────────────────────
class _Plan {
  final String id;
  final String label;
  final String duration;
  final int price;
  final int? originalPrice;
  final String? badge;
  final String? savingText;
  final bool isPopular;
  final bool isLifetime;

  const _Plan({
    required this.id,
    required this.label,
    required this.duration,
    required this.price,
    this.originalPrice,
    this.badge,
    this.savingText,
    this.isPopular = false,
    this.isLifetime = false,
  });
}

const List<_Plan> _plans = [
  _Plan(
    id: IapConstants.monthly,
    label: 'Monthly PRO Membership',
    duration: '30 days',
    price: 99,
    originalPrice: 149,
    savingText: 'Save ₹50',
  ),
  _Plan(
    id: IapConstants.semiAnnual,
    label: '6 Months PRO Membership',
    duration: '180 days',
    price: 499,
    originalPrice: 594,
    badge: '⭐ MOST POPULAR',
    savingText: 'Save ₹95 (16% off)',
    isPopular: true,
  ),
  _Plan(
    id: IapConstants.annual,
    label: 'Annual PRO Membership',
    duration: '365 days',
    price: 899,
    originalPrice: 1188,
    badge: '🔥 BEST VALUE',
    savingText: 'Save ₹289 (24% off)',
  ),
  _Plan(
    id: IapConstants.lifetime,
    label: 'Life Time Access',
    duration: 'Forever',
    price: 1199,
    originalPrice: 1999,
    badge: '👑 ULTIMATE',
    savingText: 'Save ₹800 (40% off)',
    isLifetime: true,
  ),
];

class SubscriptionPage extends ConsumerStatefulWidget {
  const SubscriptionPage({super.key});

  @override
  ConsumerState<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends ConsumerState<SubscriptionPage>
    with TickerProviderStateMixin {
  int _selectedIndex = 2; // default to annual
  late AnimationController _glowController;
  late AnimationController _pulseController;
  late AnimationController _particleController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _glowController.dispose();
    _pulseController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  Future<void> _subscribe() async {
    final selected = _plans[_selectedIndex];
    
    SafeTap.run('subscribe_pro_${selected.id}', () async {
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

      HapticFeedback.heavyImpact();
      
      try {
        final iapService = ref.read(iapServiceProvider);
        
        // This will trigger the Google Play billing flow
        await iapService.buyProduct(selected.id);
        
        // Note: The UI will reflect the PRO status once the purchase 
        // is verified and delivered by IapService, which refreshes the user.
        
      } catch (e) {
        if (!mounted) return;
        RoyalSnackBar.show(
          context,
          '❌ Could not initiate purchase: $e',
          type: SnackBarType.error,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final selected = _plans[_selectedIndex];

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
                      width: 320,
                      height: 320,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Color.lerp(const Color(0x30D4A017), const Color(0x60D4A017), g)!,
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 180,
                    right: -100,
                    child: Container(
                      width: 260,
                      height: 260,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Color.lerp(const Color(0x207C3AED), const Color(0x407C3AED), 1 - g)!,
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 200,
                    left: -50,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Color.lerp(const Color(0x18FDDB6A), const Color(0x35FDDB6A), g)!,
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
                      // ── Hero crown icon ─────────────────────────────────
                      _buildHeroBadge(),
                      const SizedBox(height: 24),

                      // ── Headline ────────────────────────────────────────
                      ShaderMask(
                        shaderCallback: (b) => AppColors.goldGradient.createShader(b),
                        child: const Text(
                          'Unlock Everything',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ).animate().fade(delay: 200.ms),

                      const SizedBox(height: 10),

                      Text(
                        'Join PRO and get unlimited access to exclusive premium wallpapers — no diamonds needed.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                          height: 1.6,
                        ),
                      ).animate().fade(delay: 300.ms),

                      const SizedBox(height: 32),

                      // ── Feature pills ───────────────────────────────────
                      _buildFeaturePills(),

                      const SizedBox(height: 36),

                      // ── Plans label ─────────────────────────────────────
                      Row(
                        children: [
                          Container(
                            width: 3, height: 20,
                            decoration: BoxDecoration(
                              gradient: AppColors.goldGradient,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'CHOOSE YOUR PLAN',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ).animate().fade(delay: 400.ms),

                      const SizedBox(height: 16),

                      // ── Plan cards ──────────────────────────────────────
                      ...List.generate(_plans.length, (i) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildPlanCard(i),
                        ).animate().fade(delay: Duration(milliseconds: 450 + i * 80)).slideY(begin: 0.15, end: 0);
                      }),

                      const SizedBox(height: 28),

                      // ── Subscribe button ────────────────────────────────
                      _buildSubscribeButton(selected),

                      const SizedBox(height: 20),

                      // ── Trust row ───────────────────────────────────────
                      _buildTrustRow(),

                      const SizedBox(height: 16),

                      // ── Fine print ──────────────────────────────────────
                      Text(
                        'Cancel anytime • Secure payment • Instant activation',
                        style: TextStyle(
                          color: AppColors.textMuted.withAlpha(150),
                          fontSize: 11,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 24),
                      _buildRestoreButton(),
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
            // Outer pulse ring
            Container(
              width: 130 + p * 12,
              height: 130 + p * 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.goldMid.withAlpha((30 + 20 * (1 - p)).round()),
                  width: 1,
                ),
              ),
            ),
            // Middle ring
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.goldMid.withAlpha((50 + 30 * p).round()),
                  width: 1.5,
                ),
              ),
            ),
            // Core badge
            Container(
              width: 90, height: 90,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFD4A017), Color(0xFF9B7000)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.goldMid.withAlpha((80 + (40 * p)).round()),
                    blurRadius: 30 + p * 15,
                    spreadRadius: 3,
                  ),
                ],
              ),
              child: const Center(
                child: Text('👑', style: TextStyle(fontSize: 40)),
              ),
            ),
          ],
        );
      },
    ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack);
  }

  // ── Feature pills ──────────────────────────────────────────────────────────
  Widget _buildFeaturePills() {
    final features = [
      (Icons.lock_open_rounded, 'Unlimited Access'),
      (Icons.high_quality_rounded, '4K Quality'),
      (Icons.block_rounded, 'Ad-Free'),
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: features.asMap().entries.map((e) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.goldMid.withAlpha(15),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: AppColors.goldMid.withAlpha(50), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(e.value.$1, color: AppColors.goldLight, size: 14),
              const SizedBox(width: 6),
              Text(
                e.value.$2,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ).animate().fade(delay: Duration(milliseconds: 350 + e.key * 60));
      }).toList(),
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

  // ── Plan card ──────────────────────────────────────────────────────────────
  Widget _buildPlanCard(int index) {
    final plan = _plans[index];
    final isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() => _selectedIndex = index);
        HapticFeedback.selectionClick();
      },
      child: AnimatedBuilder(
        animation: _glowController,
        builder: (_, __) {
          final g = _glowController.value;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? LinearGradient(
                      colors: [
                        const Color(0xFF1A1200).withAlpha(240),
                        const Color(0xFF0D0E1A),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: isSelected ? null : const Color(0xFF0C0D18),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? Color.lerp(const Color(0xFFD4A017), const Color(0xFFFFD700), g)!
                    : const Color(0xFF1C1E2E),
                width: isSelected ? 1.8 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: Color.lerp(
                          const Color(0x35D4A017),
                          const Color(0x60D4A017),
                          g,
                        )!,
                        blurRadius: 24,
                        spreadRadius: 1,
                      ),
                    ]
                  : [],
            ),
            child: Row(
              children: [
                // Radio indicator
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: isSelected ? AppColors.goldGradient : null,
                    color: isSelected ? null : Colors.transparent,
                    border: Border.all(
                      color: isSelected ? Colors.transparent : const Color(0xFF3A3C50),
                      width: 2,
                    ),
                    boxShadow: isSelected
                        ? [BoxShadow(color: AppColors.goldMid.withAlpha(80), blurRadius: 8)]
                        : [],
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.black, size: 14)
                      : null,
                ),

                const SizedBox(width: 14),

                // Plan info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            plan.label,
                            style: TextStyle(
                              color: isSelected ? AppColors.goldLight : AppColors.textPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              letterSpacing: -0.2,
                            ),
                          ),
                          if (plan.badge != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                gradient: plan.isLifetime
                                    ? AppColors.specialGradient
                                    : plan.isPopular
                                        ? AppColors.goldGradient
                                        : AppColors.trendingGradient,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                plan.badge!,
                                style: TextStyle(
                                  color: plan.isPopular ? Colors.black : Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            plan.duration,
                            style: TextStyle(
                              color: AppColors.textSecondary.withAlpha(180),
                              fontSize: 12,
                            ),
                          ),
                          if (plan.savingText != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              plan.savingText!,
                              style: const TextStyle(
                                color: Color(0xFF4CAF50),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Price
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (plan.originalPrice != null)
                      Text(
                        '₹${plan.originalPrice}',
                        style: TextStyle(
                          color: AppColors.textMuted.withAlpha(150),
                          fontSize: 12,
                          decoration: TextDecoration.lineThrough,
                          decorationColor: AppColors.textMuted,
                        ),
                      ),
                    ShaderMask(
                      shaderCallback: (b) => (isSelected ? AppColors.goldGradient : const LinearGradient(colors: [AppColors.textPrimary, AppColors.textSecondary])).createShader(b),
                      child: Text(
                        '₹${plan.price}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Subscribe button ───────────────────────────────────────────────────────
  Widget _buildSubscribeButton(_Plan selected) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (_, __) {
        final p = _pulseController.value;
        return GestureDetector(
          onTap: _subscribe,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFD4A017), Color(0xFFB8860B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.goldMid.withAlpha((80 + (40 * p).round())),
                  blurRadius: 20 + p * 12,
                  offset: const Offset(0, 8),
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('👑', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'GET PRO — ₹${selected.price}',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      selected.duration == 'Forever' ? 'One-time payment' : '${selected.label} access',
                      style: TextStyle(
                        color: Colors.black.withAlpha(160),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 10),
                const Icon(Icons.arrow_forward_rounded, color: Colors.black, size: 20),
              ],
            ),
          ),
        );
      },
    ).animate().slideY(begin: 0.4, end: 0, duration: 500.ms, curve: Curves.easeOutCubic);
  }

  // ── Trust row ──────────────────────────────────────────────────────────────
  Widget _buildTrustRow() {
    final items = [
      (Icons.verified_rounded, 'Verified'),
      (Icons.lock_rounded, 'Secure'),
      (Icons.support_agent_rounded, 'Support'),
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: items.map((e) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
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
}

// ── Particle painter ──────────────────────────────────────────────────────────
class _ParticlePainter extends CustomPainter {
  final double progress;
  _ParticlePainter(this.progress);

  static final List<_Particle> _particles = List.generate(18, (i) => _Particle(i));

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in _particles) {
      final t = (progress + p.offset) % 1.0;
      final x = p.startX * size.width + sin(t * pi * 2 + p.phaseX) * 30;
      final y = size.height - t * (size.height + 40) + p.startY;
      final alpha = (sin(t * pi) * 180).round().clamp(0, 255);
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
      : startX = (seed * 0.067 + 0.03),
        startY = (seed * 37.0) % 60 - 30,
        offset = (seed * 0.058) % 1.0,
        phaseX = seed * 0.8,
        radius = 1.0 + (seed % 3) * 0.8;
}
