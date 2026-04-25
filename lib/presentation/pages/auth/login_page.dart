import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/haptic_provider.dart';
import '../../../core/constants/app_constants.dart';


class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    ref.listen<AuthState>(authProvider, (previous, next) {
      // Navigate to home on successful login OR guest mode
      final wasLoggedIn = previous?.user != null || (previous?.isGuest ?? false);
      final isLoggedIn = next.user != null || next.isGuest;
      
      if (isLoggedIn && !wasLoggedIn) {
        if (mounted) {
          // Special welcome for Premium users
          if (next.user?.isSubscribed == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('👑 Welcome back, Premium Member! All features unlocked.'),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          context.go('/home');
        }
      } else if (next.error != null && previous?.error != next.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${next.error}')),
        );
      }
    });

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Background wallpaper ─────────────────────────────────────
          Image.asset(
            'assets/login_bg.png',
            fit: BoxFit.cover,
          ),
          // ── Dark + blur overlay ──────────────────────────────────────
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              color: AppColors.bg0.withAlpha(180),
            ),
          ),
          // ── Centered frosted glass card ──────────────────────────────
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(28, 36, 28, 36),
                    decoration: BoxDecoration(
                      color: AppColors.glassFill,
                      borderRadius: BorderRadius.circular(28),
                      border:
                          Border.all(color: AppColors.glassBorder, width: 1.2),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ── Diamond icon with gold ring ────────────────
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppColors.goldRingGradient,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.goldMid.withAlpha(80),
                                blurRadius: 24,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(2.5),
                            child: CircleAvatar(
                              backgroundColor: AppColors.bg0,
                              child: const Icon(
                                Icons.diamond,
                                size: 36,
                                color: AppColors.goldLight,
                              ),
                            ),
                          ),
                        )
                            .animate()
                            .fade(duration: 600.ms, delay: 100.ms)
                            .scale(
                                begin: const Offset(0.7, 0.7),
                                duration: 500.ms,
                                curve: Curves.easeOutBack),
                        const SizedBox(height: 24),
                        // ── Title ──────────────────────────────────────
                        ShaderMask(
                          shaderCallback: (bounds) =>
                              AppColors.goldGradient.createShader(bounds),
                          child: const Text(
                            'Royal Pixels',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              fontSize: 30,
                              letterSpacing: 2.0,
                            ),
                          ),
                        )
                            .animate()
                            .fade(duration: 600.ms, delay: 200.ms)
                            .slideY(
                                begin: 0.3,
                                end: 0,
                                duration: 500.ms,
                                curve: Curves.easeOut),
                        const SizedBox(height: 10),
                        // ── Subtitle ───────────────────────────────────
                        const Text(
                          'Premium wallpapers for your device.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                            letterSpacing: 0.3,
                          ),
                          textAlign: TextAlign.center,
                        )
                            .animate()
                            .fade(duration: 500.ms, delay: 300.ms),
                        const SizedBox(height: 40),
                        // ── Sign-in button ─────────────────────────────
                        if (authState.isLoading)
                          const SizedBox(
                            height: 52,
                            child: Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.goldLight),
                                ),
                              ),
                            ),
                          )
                        else
                          GestureDetector(
                            onTap: () {
                              ref.read(hapticProvider.notifier).lightImpact();
                              ref.read(authProvider.notifier).loginWithGoogle();
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withAlpha(240),
                                    Colors.white,
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.goldLight.withAlpha(40),
                                    blurRadius: 20,
                                    spreadRadius: 0,
                                    offset: const Offset(0, 8),
                                  ),
                                  BoxShadow(
                                    color: Colors.black.withAlpha(20),
                                    blurRadius: 10,
                                    spreadRadius: 0,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Actual Google Logo Asset
                                  Image.asset(
                                    'assets/google_logo.png',
                                    width: 24,
                                    height: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Continue with Google',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F1420),
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                              .animate()
                              .fade(duration: 500.ms, delay: 400.ms)
                              .slideY(
                                  begin: 0.3,
                                  end: 0,
                                  duration: 450.ms,
                                  curve: Curves.easeOut),

                        const SizedBox(height: 14),
                        // ── Continue as Guest ─────────────────────────────
                        if (!authState.isLoading)
                          GestureDetector(
                            onTap: () async {
                              ref.read(hapticProvider.notifier).lightImpact();
                              await ref
                                  .read(authProvider.notifier)
                                  .continueAsGuest();
                            },
                            child: Container(
                              width: double.infinity,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(10),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withAlpha(35),
                                  width: 1.2,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.person_outline_rounded,
                                    color: AppColors.textSecondary,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 9),
                                  const Text(
                                    'Continue as Guest',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                              .animate()
                              .fade(duration: 500.ms, delay: 450.ms)
                              .slideY(
                                  begin: 0.3,
                                  end: 0,
                                  duration: 450.ms,
                                  curve: Curves.easeOut),

                        const SizedBox(height: 20),
                        // ── Trust badges ───────────────────────────────
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _TrustBadge(icon: Icons.lock_outline, label: 'Secure'),
                            _TrustDot(),
                            _TrustBadge(icon: Icons.shield_outlined, label: 'Private'),
                            _TrustDot(),
                            _TrustBadge(icon: Icons.block_outlined, label: 'No Spam'),
                          ],
                        )
                            .animate()
                            .fade(duration: 400.ms, delay: 550.ms),

                        const SizedBox(height: 20),
                        // ── Version ────────────────────────────────────
                        Text(
                          '${AppConstants.appName} • v${AppConstants.appVersion}',
                          style: TextStyle(
                            color: AppColors.textMuted.withAlpha(130),
                            fontSize: 11,
                            letterSpacing: 0.5,
                          ),
                        )
                            .animate()
                            .fade(duration: 400.ms, delay: 600.ms),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}



// ─── Trust badge ──────────────────────────────────────────────────────────────
class _TrustBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  const _TrustBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _TrustDot extends StatelessWidget {
  const _TrustDot();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: Text('·', style: TextStyle(color: AppColors.textMuted)),
      );
}
