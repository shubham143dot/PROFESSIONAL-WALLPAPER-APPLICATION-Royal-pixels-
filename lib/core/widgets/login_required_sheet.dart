import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import '../constants/app_constants.dart';
import '../../presentation/providers/auth_provider.dart';
import '../../presentation/providers/haptic_provider.dart';


/// Reason codes that customise the message shown in the sheet.
enum LoginRequiredReason {
  favorites,
  premium,
  diamonds,
  subscription,
  general,
}

/// Shows a premium bottom sheet asking the user to sign in.
/// Returns `true` if the user successfully signed in, `false` otherwise.
Future<bool> showLoginRequiredSheet(
  BuildContext context, {
  LoginRequiredReason reason = LoginRequiredReason.general,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _LoginRequiredSheet(reason: reason),
  );
  return result == true;
}

class _LoginRequiredSheet extends ConsumerWidget {
  final LoginRequiredReason reason;
  const _LoginRequiredSheet({required this.reason});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = _reasonConfig(reason);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: EdgeInsets.fromLTRB(
              24, 16, 24, MediaQuery.of(context).padding.bottom + 32),
          decoration: BoxDecoration(
            color: AppColors.bg0.withAlpha(230),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(
                color: AppColors.glassBorder.withAlpha(120), width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Drag handle ──────────────────────────────────────────
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 28),

              // ── Icon ─────────────────────────────────────────────────
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: AppColors.goldGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.goldMid.withAlpha(80),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(config.icon, color: Colors.black, size: 36),
              )
                  .animate()
                  .scale(
                      begin: const Offset(0.7, 0.7),
                      duration: 450.ms,
                      curve: Curves.elasticOut)
                  .fade(duration: 300.ms),
              const SizedBox(height: 20),

              // ── Title ─────────────────────────────────────────────────
              Text(
                config.title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.2,
                ),
                textAlign: TextAlign.center,
              ).animate().fade(delay: 80.ms, duration: 350.ms),
              const SizedBox(height: 10),

              // ── Description ──────────────────────────────────────────
              Text(
                config.description,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.55,
                ),
                textAlign: TextAlign.center,
              ).animate().fade(delay: 120.ms, duration: 350.ms),
              const SizedBox(height: 32),

              // ── Sign-in button ────────────────────────────────────────
              Consumer(
                builder: (context, ref, _) {
                  final isLoading = ref.watch(authProvider).isLoading;
                  return SizedBox(
                    width: double.infinity,
                    child: _SignInButton(
                      isLoading: isLoading,
                      onTap: () async {
                        ref.read(hapticProvider.notifier).lightImpact();
                        await ref
                            .read(authProvider.notifier)
                            .loginWithGoogle();
                        final authState = ref.read(authProvider);
                        if (authState.user != null &&
                            context.mounted) {
                          Navigator.of(context).pop(true);
                          // Ensure we're on the home route
                          context.go('/home');
                        }
                      },
                    ),
                  );
                },
              ).animate().fade(delay: 160.ms, duration: 350.ms),

              const SizedBox(height: 14),

              // ── Maybe later ───────────────────────────────────────────
              TextButton(
                onPressed: () {
                  ref.read(hapticProvider.notifier).selectionClick();
                  Navigator.of(context).pop(false);
                },
                child: const Text(
                  'Maybe Later',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ).animate().fade(delay: 200.ms, duration: 350.ms),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sign-in button (Google style) ─────────────────────────────────────────────
class _SignInButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onTap;
  const _SignInButton({required this.isLoading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
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
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: AppColors.goldLight.withAlpha(40),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: isLoading
            ? const SizedBox(
                height: 24,
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.goldMid),
                    ),
                  ),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/google_logo.png',
                    width: 22,
                    height: 22,
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
    );
  }
}

// ── Reason config ─────────────────────────────────────────────────────────────
class _ReasonConfig {
  final IconData icon;
  final String title;
  final String description;
  const _ReasonConfig(
      {required this.icon, required this.title, required this.description});
}

_ReasonConfig _reasonConfig(LoginRequiredReason reason) {
  switch (reason) {
    case LoginRequiredReason.favorites:
      return const _ReasonConfig(
        icon: Icons.favorite_rounded,
        title: 'Save Your Favorites',
        description:
            'Sign in to save your favorite wallpapers and sync them across all your devices.',
      );
    case LoginRequiredReason.premium:
      return const _ReasonConfig(
        icon: Icons.lock_rounded,
        title: 'Unlock Premium Content',
        description:
            'Sign in to unlock premium wallpapers using your Diamond wallet or a PRO subscription.',
      );
    case LoginRequiredReason.diamonds:
      return const _ReasonConfig(
        icon: Icons.diamond_rounded,
        title: 'Earn & Spend Diamonds',
        description:
            'Sign in to earn diamonds, claim daily rewards, and unlock exclusive premium wallpapers.',
      );
    case LoginRequiredReason.subscription:
      return const _ReasonConfig(
        icon: Icons.workspace_premium_rounded,
        title: 'Unlock PRO Membership',
        description:
            'Sign in to purchase a PRO subscription and get unlimited access to all premium wallpapers.',
      );
    case LoginRequiredReason.general:
      return const _ReasonConfig(
        icon: Icons.person_rounded,
        title: 'Sign In Required',
        description:
            'Create a free account with Google to unlock this feature and enjoy the full ${AppConstants.appName} experience.',
      );
  }
}
