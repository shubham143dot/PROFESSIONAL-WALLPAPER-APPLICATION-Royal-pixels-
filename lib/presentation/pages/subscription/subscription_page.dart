import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui';
import '../../../core/theme/app_colors.dart';
import '../payment/payment_bottom_sheet.dart';
import '../../providers/auth_provider.dart';
import '../../../core/di/service_locator.dart';
import '../../../domain/repositories/payment_repository.dart';

// ── Sentinel for Lifetime (admin sets expiry to this date) ──────────────────
const int _kLifetimeMonths = 9999;

class SubscriptionPage extends ConsumerStatefulWidget {
  const SubscriptionPage({super.key});

  @override
  ConsumerState<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends ConsumerState<SubscriptionPage> {
  bool _isRefreshing = false;

  /// After payment confirmed, refresh auth state so isSubscribed updates.
  Future<void> _refreshSubscriptionStatus() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    setState(() => _isRefreshing = true);
    final repo = sl<PaymentRepository>();
    await repo.checkSubscriptionStatus(user.uid);
    if (mounted) {
      await ref.read(authProvider.notifier).refreshUser();
    }
    if (mounted) setState(() => _isRefreshing = false);
  }

  Future<void> _onPlanTapped({
    required BuildContext context,
    required int months,
    required double price,
    required String title,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final paid = await showPaymentBottomSheet(
      context,
      wallpaperId: 'SUB_PLAN_${months == _kLifetimeMonths ? 'LIFETIME' : '${months}M'}',
      wallpaperTitle: 'PRO – $title',
      amount: price,
      isSubscription: true,
      subscriptionMonths: months,
    );

    if (paid && mounted) {
      await _refreshSubscriptionStatus();
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              months == _kLifetimeMonths
                  ? '🎉 Lifetime PRO unlocked! Enjoy all Premium wallpapers — forever!'
                  : '🎉 You\'re now a PRO member! Enjoy all Premium wallpapers.',
            ),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final isSubscribed = user?.isSubscribed ?? false;
    final expiry = user?.subscriptionExpiry;
    final isLifetime = expiry != null &&
        expiry.year >= DateTime.now().year + 50; // lifetime sentinel date

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Stack(
        children: [
          // Background glow — top right (gold)
          Positioned(
            top: -140,
            right: -140,
            child: Container(
              width: 380,
              height: 380,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFFFCC00).withValues(alpha: 0.14),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Background glow — bottom left (orange)
          Positioned(
            bottom: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFFF8C00).withValues(alpha: 0.09),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // ── AppBar ────────────────────────────────────────────────
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  floating: true,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new,
                        color: Colors.white, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  centerTitle: true,
                  title: ShaderMask(
                    shaderCallback: (b) =>
                        AppColors.goldGradient.createShader(b),
                    child: const Text(
                      'PRO MEMBERSHIP',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.5,
                      ),
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 6),

                        // ── Hero Icon ──────────────────────────────────────
                        _buildHeroIcon(),
                        const SizedBox(height: 22),

                        // ── Main Title ────────────────────────────────────
                        const Text(
                          'Unlock Every\nPremium Wallpaper',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            height: 1.2,
                            letterSpacing: 0.3,
                          ),
                        )
                            .animate()
                            .fade(delay: 100.ms, duration: 400.ms)
                            .slideY(begin: 0.1, end: 0),
                        const SizedBox(height: 12),

                        // ── Subtitle ──────────────────────────────────────
                        Text(
                          'Unlimited access to all premium wallpapers,\nno ads, and full HD downloads.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 14,
                            height: 1.65,
                          ),
                        )
                            .animate()
                            .fade(delay: 150.ms, duration: 400.ms),

                        const SizedBox(height: 30),

                        // ── Subscription Status Banner ─────────────────────
                        if (isSubscribed && expiry != null) ...[
                          _buildActiveBanner(expiry, isLifetime)
                              .animate()
                              .fade(duration: 400.ms)
                              .slideY(begin: -0.05, end: 0),
                          const SizedBox(height: 24),
                        ] else if (_isRefreshing) ...[
                          const _RefreshingBanner(),
                          const SizedBox(height: 24),
                        ],

                        // ── Feature List ───────────────────────────────────
                        _buildFeatureList()
                            .animate()
                            .fade(delay: 200.ms, duration: 400.ms),

                        const SizedBox(height: 36),

                        // ── Plans / Manage ─────────────────────────────────
                        if (!isSubscribed) ...[
                          // Section header
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Choose Your Plan',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // ── Monthly Plan ───────────────────────────────
                          _PlanCard(
                            label: 'MONTHLY',
                            title: 'Monthly Plan',
                            price: '₹99',
                            priceSize: 26,
                            billingNote: '/ month',
                            subtitle: 'Perfect to get started',
                            perMonthChip: null,
                            isPopular: false,
                            isBestValue: false,
                            onTap: () => _onPlanTapped(
                              context: context,
                              months: 1,
                              price: 99,
                              title: '1 Month Plan',
                            ),
                          ).animate().fade(delay: 250.ms, duration: 400.ms).slideY(begin: 0.05, end: 0),
                          const SizedBox(height: 14),

                          // ── Yearly Plan (MOST POPULAR) ─────────────────
                          _PlanCard(
                            label: 'YEARLY',
                            title: 'Yearly Plan',
                            price: '₹499',
                            priceSize: 30, // bigger to draw the eye
                            billingNote: '/ year',
                            subtitle: 'Save 58% compared to monthly',
                            perMonthChip: 'Just ₹41/month',
                            isPopular: true,
                            isBestValue: false,
                            onTap: () => _onPlanTapped(
                              context: context,
                              months: 12,
                              price: 499,
                              title: 'Yearly Plan',
                            ),
                          ).animate().fade(delay: 300.ms, duration: 400.ms).slideY(begin: 0.05, end: 0),
                          const SizedBox(height: 14),

                          // ── Lifetime Plan (BEST VALUE) ─────────────────
                          _PlanCard(
                            label: 'LIFETIME',
                            title: 'Lifetime Plan',
                            price: '₹999',
                            priceSize: 26,
                            billingNote: 'one-time',
                            subtitle: 'Pay once, unlock forever',
                            perMonthChip: null,
                            isPopular: false,
                            isBestValue: true,
                            onTap: () => _onPlanTapped(
                              context: context,
                              months: _kLifetimeMonths,
                              price: 999,
                              title: 'Lifetime Plan',
                            ),
                          ).animate().fade(delay: 350.ms, duration: 400.ms).slideY(begin: 0.05, end: 0),

                          const SizedBox(height: 28),

                          // ── CTA Button ─────────────────────────────────
                          _buildCtaButton(context),

                          const SizedBox(height: 16),

                          // ── Trust Line ─────────────────────────────────
                          Text(
                            '✨ Join 2,000+ users enjoying premium wallpapers',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.45),
                              fontSize: 13,
                            ),
                          ).animate().fade(delay: 400.ms, duration: 400.ms),

                        ] else ...[
                          // Already subscribed — manage section
                          _buildManageSection()
                              .animate()
                              .fade(delay: 250.ms, duration: 400.ms),
                        ],

                        const SizedBox(height: 28),

                        // ── Fine print ─────────────────────────────────────
                        Text(
                          'Payment via UPI. Subscription is activated\nmanually within a few hours of payment.\nContact support if not activated within 24h.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.28),
                            fontSize: 11,
                            height: 1.65,
                          ),
                        ),

                        const SizedBox(height: 44),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Hero Icon ──────────────────────────────────────────────────────────────
  Widget _buildHeroIcon() {
    return Container(
      width: 92,
      height: 92,
      decoration: BoxDecoration(
        gradient: AppColors.goldGradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF8C00).withValues(alpha: 0.42),
            blurRadius: 32,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: const Icon(Icons.workspace_premium, color: Colors.black, size: 48),
    )
        .animate()
        .scale(
            begin: const Offset(0.7, 0.7),
            duration: 500.ms,
            curve: Curves.elasticOut)
        .fade(duration: 300.ms);
  }

  // ── Active subscription banner ─────────────────────────────────────────────
  Widget _buildActiveBanner(DateTime expiry, bool isLifetime) {
    final now = DateTime.now();
    final daysLeft = expiry.difference(now).inDays;
    final expiryStr = '${expiry.day} ${_monthName(expiry.month)} ${expiry.year}';

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.verified_rounded,
                    color: Colors.green, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'PRO • Active',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        if (isLifetime) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              gradient: AppColors.goldGradient,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'LIFETIME',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isLifetime
                          ? 'Lifetime access — enjoy forever 🎉'
                          : daysLeft > 0
                              ? 'Expires $expiryStr · $daysLeft days left'
                              : 'Expired on $expiryStr',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Feature list ───────────────────────────────────────────────────────────
  Widget _buildFeatureList() {
    final features = [
      (Icons.auto_awesome_rounded, 'All Premium Wallpapers Unlocked',
          'Browse and download every premium wallpaper'),
      (Icons.high_quality_rounded, 'Full Resolution Downloads',
          'Always get the highest quality'),
      (Icons.refresh_rounded, 'New Wallpapers Every Month',
          'Fresh exclusive content regularly'),
      (Icons.block_rounded, 'No Ads Experience',
          'Enjoy a clean and smooth app'),
    ];

    return Column(
      children: features
          .map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        gradient: AppColors.goldGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(f.$1, color: Colors.black, size: 18),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            f.$2,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            f.$3,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.45),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }

  // ── Big CTA button ─────────────────────────────────────────────────────────
  Widget _buildCtaButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
        onTap: () {
          // Scroll down is implicit — tapping any plan card is the real CTA.
          // This button taps the Yearly plan as the smart default.
          _onPlanTapped(
            context: context,
            months: 12,
            price: 499,
            title: 'Yearly Plan',
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            gradient: AppColors.goldGradient,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFCC00).withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.rocket_launch_rounded, color: Colors.black, size: 20),
              SizedBox(width: 10),
              Text(
                'Unlock Premium Now',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fade(delay: 400.ms, duration: 400.ms)
        .slideY(begin: 0.08, end: 0);
  }

  // ── Already subscribed — manage / extend ───────────────────────────────────
  Widget _buildManageSection() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Extend your membership',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15),
              ),
              const SizedBox(height: 6),
              Text(
                'Renewing adds time on top of your current expiry.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  _SmallPlanChip(
                    label: '+1M  ₹99',
                    months: 1,
                    price: 99,
                    onTap: (m, p) => _onPlanTapped(
                        context: context,
                        months: m,
                        price: p,
                        title: '1 Month Extension'),
                  ),
                  const SizedBox(width: 10),
                  _SmallPlanChip(
                    label: '+1Y  ₹499',
                    months: 12,
                    price: 499,
                    onTap: (m, p) => _onPlanTapped(
                        context: context,
                        months: m,
                        price: p,
                        title: 'Yearly Extension'),
                  ),
                  const SizedBox(width: 10),
                  _SmallPlanChip(
                    label: 'Lifetime  ₹999',
                    months: _kLifetimeMonths,
                    price: 999,
                    onTap: (m, p) => _onPlanTapped(
                        context: context,
                        months: m,
                        price: p,
                        title: 'Lifetime Plan'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _monthName(int m) => const [
        '',
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ][m];
}

// ─── Refreshing Banner ────────────────────────────────────────────────────────
class _RefreshingBanner extends StatelessWidget {
  const _RefreshingBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Color(0xFFFFCC00)),
          ),
          SizedBox(width: 12),
          Text('Refreshing subscription status…',
              style: TextStyle(color: Colors.white54, fontSize: 13)),
        ],
      ),
    );
  }
}

// ─── Plan Card ────────────────────────────────────────────────────────────────
class _PlanCard extends StatelessWidget {
  final String label;       // e.g. 'MONTHLY', 'YEARLY', 'LIFETIME'
  final String title;       // e.g. 'Yearly Plan'
  final String price;       // e.g. '₹499'
  final double priceSize;   // font size for the price text
  final String billingNote; // e.g. '/ year', 'one-time'
  final String subtitle;    // description below title
  final String? perMonthChip; // green chip e.g. 'Just ₹41/month'
  final bool isPopular;     // gold border + MOST POPULAR badge
  final bool isBestValue;   // BEST VALUE badge
  final VoidCallback onTap;

  const _PlanCard({
    required this.label,
    required this.title,
    required this.price,
    required this.priceSize,
    required this.billingNote,
    required this.subtitle,
    required this.onTap,
    this.perMonthChip,
    this.isPopular = false,
    this.isBestValue = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: isPopular ? const EdgeInsets.all(2) : EdgeInsets.zero,
        decoration: isPopular
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: AppColors.goldGradient,
              )
            : BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isBestValue
                      ? Colors.white.withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.1),
                ),
              ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: isPopular
                ? const Color(0xFF161000) // slightly warm dark for popular
                : const Color(0xFF131313),
            borderRadius: BorderRadius.circular(isPopular ? 18 : 20),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Badges ──────────────────────────────────────────
                    if (isPopular)
                      _Badge(
                        text: '⭐ MOST POPULAR',
                        gradient: AppColors.goldGradient,
                        textColor: Colors.black,
                      ),
                    if (isBestValue)
                      _Badge(
                        text: '🔥 BEST VALUE',
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF4500), Color(0xFFFF8C00)],
                        ),
                        textColor: Colors.white,
                      ),
                    if (isPopular || isBestValue) const SizedBox(height: 8),

                    // ── Title ────────────────────────────────────────────
                    Text(
                      title,
                      style: TextStyle(
                        color: isPopular
                            ? const Color(0xFFFFE566)
                            : Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Price Column ───────────────────────────────────────────
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ShaderMask(
                    shaderCallback: (b) =>
                        AppColors.goldGradient.createShader(b),
                    child: Text(
                      price,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: priceSize,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                      ),
                    ),
                  ),
                  Text(
                    billingNote,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 11,
                    ),
                  ),
                  if (perMonthChip != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Colors.green.withValues(alpha: 0.35),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        perMonthChip!,
                        style: const TextStyle(
                          color: Colors.green,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ] else
                    const SizedBox(height: 4),
                  const SizedBox(height: 4),
                  const Icon(Icons.arrow_forward_ios_rounded,
                      color: Colors.white30, size: 14),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Badge (MOST POPULAR / BEST VALUE) ───────────────────────────────────────
class _Badge extends StatelessWidget {
  final String text;
  final LinearGradient gradient;
  final Color textColor;

  const _Badge({
    required this.text,
    required this.gradient,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ─── Small plan chip (extend / manage) ───────────────────────────────────────
class _SmallPlanChip extends StatelessWidget {
  final String label;
  final int months;
  final double price;
  final void Function(int months, double price) onTap;

  const _SmallPlanChip({
    required this.label,
    required this.months,
    required this.price,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(months, price),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: AppColors.goldGradient,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
