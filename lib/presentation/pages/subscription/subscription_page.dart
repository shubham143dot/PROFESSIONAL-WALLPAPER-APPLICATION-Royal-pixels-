import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui';
import '../../../core/theme/app_colors.dart';
import '../payment/payment_bottom_sheet.dart';
import '../../providers/auth_provider.dart';
import '../../../core/di/service_locator.dart';
import '../../../domain/repositories/payment_repository.dart';

class SubscriptionPage extends ConsumerStatefulWidget {
  const SubscriptionPage({super.key});

  @override
  ConsumerState<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends ConsumerState<SubscriptionPage> {
  bool _isRefreshing = false;

  /// After payment confirmed, refresh the auth state so isSubscribed updates.
  Future<void> _refreshSubscriptionStatus() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    setState(() => _isRefreshing = true);
    final repo = sl<PaymentRepository>();
    await repo.checkSubscriptionStatus(user.uid);
    // Re-fetch user data from Firestore into the auth provider
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
      wallpaperId: 'SUB_PLAN_${months}M',
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
            content: const Text('🎉 You\'re now a PRO member! Enjoy all Premium wallpapers.'),
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

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Stack(
        children: [
          // Background glow top-right
          Positioned(
            top: -120,
            right: -120,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFFFCC00).withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Background glow bottom-left
          Positioned(
            bottom: -80,
            left: -80,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFFF8C00).withValues(alpha: 0.08),
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
                // ── AppBar ──────────────────────────────────────────────
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
                        letterSpacing: 2,
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
                        const SizedBox(height: 8),

                        // ── Hero Icon ─────────────────────────────────
                        Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            gradient: AppColors.goldGradient,
                            borderRadius: BorderRadius.circular(26),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF8C00)
                                    .withValues(alpha: 0.4),
                                blurRadius: 28,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.workspace_premium,
                              color: Colors.black, size: 46),
                        )
                            .animate()
                            .scale(
                                begin: const Offset(0.7, 0.7),
                                duration: 500.ms,
                                curve: Curves.elasticOut)
                            .fade(duration: 300.ms),
                        const SizedBox(height: 24),

                        const Text(
                          'Unlock Every\nPremium Wallpaper',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            height: 1.2,
                            letterSpacing: 0.3,
                          ),
                        )
                            .animate()
                            .fade(delay: 100.ms, duration: 400.ms)
                            .slideY(begin: 0.1, end: 0),
                        const SizedBox(height: 12),

                        Text(
                          'One subscription gives you access to all\nPremium wallpapers — forever while active.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 14,
                            height: 1.6,
                          ),
                        )
                            .animate()
                            .fade(delay: 150.ms, duration: 400.ms),

                        const SizedBox(height: 32),

                        // ── Subscription Status Banner ─────────────────
                        if (isSubscribed && expiry != null) ...[
                          _buildActiveBanner(expiry).animate()
                              .fade(duration: 400.ms)
                              .slideY(begin: -0.05, end: 0),
                          const SizedBox(height: 24),
                        ] else if (_isRefreshing) ...[
                          const _RefreshingBanner(),
                          const SizedBox(height: 24),
                        ],

                        // ── Feature List ──────────────────────────────
                        _buildFeatureList()
                            .animate()
                            .fade(delay: 200.ms, duration: 400.ms),

                        const SizedBox(height: 36),

                        // ── Plans ─────────────────────────────────────
                        if (!isSubscribed) ...[
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Choose your plan',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          // Social proof
                          Text(
                            '✨ Join 2,000+ users who love Royal Pixels PRO',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _PlanCard(
                            months: 1,
                            price: 99,
                            title: '1 Month',
                            subtitle: 'Try it out',
                            perMonthLabel: null,
                            onTap: () => _onPlanTapped(
                              context: context,
                              months: 1,
                              price: 99,
                              title: '1 Month Plan',
                            ),
                          ).animate().fade(delay: 250.ms, duration: 400.ms).slideY(begin: 0.05, end: 0),
                          const SizedBox(height: 14),
                          _PlanCard(
                            months: 3,
                            price: 249,
                            title: '3 Months',
                            subtitle: 'Most popular · Save ₹48',
                            perMonthLabel: '₹83/month',
                            isPopular: true,
                            onTap: () => _onPlanTapped(
                              context: context,
                              months: 3,
                              price: 249,
                              title: '3 Month Plan',
                            ),
                          ).animate().fade(delay: 300.ms, duration: 400.ms).slideY(begin: 0.05, end: 0),
                          const SizedBox(height: 14),
                          _PlanCard(
                            months: 12,
                            price: 799,
                            title: '1 Year',
                            subtitle: 'Best value · Save ₹389',
                            perMonthLabel: '₹67/month',
                            onTap: () => _onPlanTapped(
                              context: context,
                              months: 12,
                              price: 799,
                              title: '1 Year Plan',
                            ),
                          ).animate().fade(delay: 350.ms, duration: 400.ms).slideY(begin: 0.05, end: 0),
                        ] else ...[
                          // Already subscribed — show manage section
                          _buildManageSection().animate().fade(delay: 250.ms, duration: 400.ms),
                        ],

                        const SizedBox(height: 28),

                        // ── Fine print ────────────────────────────────
                        Text(
                          'Payment via UPI. Subscription is activated\nmanually within a few hours of payment.\nContact support if not activated within 24h.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.3),
                            fontSize: 11,
                            height: 1.6,
                          ),
                        ),

                        const SizedBox(height: 40),
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

  Widget _buildActiveBanner(DateTime expiry) {
    final now = DateTime.now();
    final daysLeft = expiry.difference(now).inDays;
    final expiryStr =
        '${expiry.day} ${_monthName(expiry.month)} ${expiry.year}';

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
                    const Text(
                      'PRO • Active',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      daysLeft > 0
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

  Widget _buildFeatureList() {
    final features = [
      (Icons.auto_awesome_rounded, 'All Premium Wallpapers Unlocked',
          'Browse and download every Premium wallpaper'),
      (Icons.high_quality_rounded, 'Full Resolution Downloads',
          'Always download the highest quality'),
      (Icons.refresh_rounded, 'New Premiums Every Month',
          'Fresh exclusives added regularly'),
      (Icons.support_agent_rounded, 'Priority Support',
          'Get help faster as a PRO member'),
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
                  _SmallPlanChip(label: '+1M  ₹99', months: 1, price: 99, onTap: (m, p) => _onPlanTapped(context: context, months: m, price: p, title: '1 Month Extension')),
                  const SizedBox(width: 10),
                  _SmallPlanChip(label: '+3M  ₹249', months: 3, price: 249, onTap: (m, p) => _onPlanTapped(context: context, months: m, price: p, title: '3 Month Extension')),
                  const SizedBox(width: 10),
                  _SmallPlanChip(label: '+1Y  ₹799', months: 12, price: 799, onTap: (m, p) => _onPlanTapped(context: context, months: m, price: p, title: '1 Year Extension')),
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

// ─── Refreshing banner ────────────────────────────────────────────────────────
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
            width: 16, height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFFCC00)),
          ),
          SizedBox(width: 12),
          Text('Refreshing subscription status…',
              style: TextStyle(color: Colors.white54, fontSize: 13)),
        ],
      ),
    );
  }
}

// ─── Plan card ────────────────────────────────────────────────────────────────
class _PlanCard extends StatelessWidget {
  final int months;
  final double price;
  final String title;
  final String subtitle;
  final String? perMonthLabel;
  final bool isPopular;
  final VoidCallback onTap;

  const _PlanCard({
    required this.months,
    required this.price,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.perMonthLabel,
    this.isPopular = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: isPopular
              ? AppColors.goldGradient
              : null,
          border: isPopular
              ? null
              : Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: const Color(0xFF131313),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isPopular) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          gradient: AppColors.goldGradient,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          '⭐ MOST POPULAR',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ShaderMask(
                    shaderCallback: (b) =>
                        AppColors.goldGradient.createShader(b),
                    child: Text(
                      '₹${price.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (perMonthLabel != null) ...[  
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: Colors.green.withValues(alpha: 0.35),
                            width: 0.8),
                      ),
                      child: Text(
                        perMonthLabel!,
                        style: const TextStyle(
                          color: Colors.green,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ] else
                    const SizedBox(height: 2),
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

// ─── Small plan chip (for re-subscribe / extend) ──────────────────────────────
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
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
