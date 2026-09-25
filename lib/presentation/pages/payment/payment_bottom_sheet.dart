import 'package:royal_pixels/core/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:ui';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/safe_tap.dart';
import '../../../core/services/adaptive_performance.dart';

/// Shows the payment bottom sheet (currently showing 'temporarily closed').
Future<bool> showPaymentBottomSheet(
  BuildContext context, {
  required String wallpaperId,
  required String wallpaperTitle,
  required double amount,
  bool isDiamondPack = false,
  int diamondAmount = 0,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const PaymentBottomSheet(),
  );
  return result ?? false;
}

class PaymentBottomSheet extends ConsumerStatefulWidget {
  const PaymentBottomSheet({super.key});

  @override
  ConsumerState<PaymentBottomSheet> createState() => _PaymentBottomSheetState();
}

class _PaymentBottomSheetState extends ConsumerState<PaymentBottomSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return FadeTransition(
      opacity: _fadeAnim,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: Builder(
          builder: (context) {
            final content = Container(
              height: screenHeight * 0.45, // Shorter since it's just a message
              decoration: BoxDecoration(
                color: const Color(0xFF0F0F0F).withAlpha(AdaptivePerformance.enableBackdropBlur ? 13 : 240),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Stack(
                children: [
                  // Background glow
                  Positioned(
                    top: -100,
                    right: -100,
                    child: Container(
                      width: 250,
                      height: 250,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppColors.goldMid.withAlpha(40),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                  Column(
                    children: [
                      // Handle bar
                      const SizedBox(height: 12),
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 40),

                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Icon with glow
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: AppColors.goldMid.withAlpha(20),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: AppColors.goldMid.withAlpha(40),
                                      width: 2),
                                ),
                                child: const Icon(
                                  Icons.error_outline_rounded,
                                  color: AppColors.goldMid,
                                  size: 40,
                                ),
                              )
                                  .animate()
                                  .scale(
                                      begin: const Offset(0.8, 0.8),
                                      duration: 600.ms,
                                      curve: Curves.elasticOut)
                                  .fade(duration: 300.ms),

                              const SizedBox(height: 32),

                              Text(AppLocalizations.of(context)!.paymentsClosed,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                                textAlign: TextAlign.center,
                              ).animate().fade(delay: 100.ms),

                              const SizedBox(height: 12),

                              Text(AppLocalizations.of(context)!.manualUpiPaymentsAreTemporarilyClosedForSystemMaintenancePleaseCheckBackLater,
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 15,
                                  height: 1.5,
                                ),
                                textAlign: TextAlign.center,
                              ).animate().fade(delay: 200.ms),

                              const Spacer(),

                              // Close button
                              SizedBox(
                                width: double.infinity,
                                child: GestureDetector(
                                  onTap: () {
                                    SafeTap.run('payment_dismiss', () {
                                      Navigator.pop(context, false);
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 18),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withAlpha(8),
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(color: Colors.white10),
                                    ),
                                    child: Text(AppLocalizations.of(context)!.dismiss,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              )
                                  .animate()
                                  .fade(delay: 300.ms)
                                  .slideY(begin: 0.1, end: 0),

                              const SizedBox(height: 32),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
            return AdaptivePerformance.enableBackdropBlur
                ? BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: content,
                  )
                : content;
          },
        ),
      ),
    );
  }
}
