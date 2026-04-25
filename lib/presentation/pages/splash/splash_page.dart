import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/update_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CINEMATIC SPLASH PAGE
// Sequence (total ~4.2 s):
//   0.0 – 0.6s  Background nebula gradient fades in
//   0.4 – 1.2s  Gold particles burst from centre
//   0.9 – 1.8s  Diamond logo scales in + glow pulse
//   1.5 – 2.5s  "ROYAL" letters slide in from left, staggered
//   1.8 – 2.8s  "PIXELS" letters slide in from right, staggered
//   2.6 – 3.1s  Shimmer sweep across the two words
//   3.0 – 3.6s  Tagline fades in
//   3.8 – 4.2s  Full screen fades out → navigate
// ─────────────────────────────────────────────────────────────────────────────

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage>
    with TickerProviderStateMixin {
  // Master clock (0 → 1 over 4.2 s)
  late final AnimationController _master;

  // Background nebula pulse
  late final Animation<double> _bgFade;
  late final Animation<double> _nebulaPulse;

  // Particles
  late final Animation<double> _particleAnim;

  // Diamond logo
  late final Animation<double> _logoScale;
  late final Animation<double> _logoGlow;
  late final Animation<double> _logoFade;

  // "ROYAL" letters
  late final List<Animation<double>> _royalAnims;

  // "PIXELS" letters
  late final List<Animation<double>> _pixelsAnims;

  // Shimmer
  late final Animation<double> _shimmer;

  // Tagline
  late final Animation<double> _taglineFade;
  late final Animation<Offset> _taglineSlide;

  // Exit fade
  late final Animation<double> _exitFade;

  // Particles list (generated once)
  final List<_Particle> _particles = [];
  final _rng = math.Random(42);

  static const _totalDuration = Duration(milliseconds: 2800);


  @override
  void initState() {
    super.initState();

    _master = AnimationController(vsync: this, duration: _totalDuration)
      ..addListener(() => setState(() {}));

    // ── Background ────────────────────────────────────────
    _bgFade = CurvedAnimation(
      parent: _master,
      curve: const Interval(0.0, 0.15, curve: Curves.easeIn),
    );
    _nebulaPulse = CurvedAnimation(
      parent: _master,
      curve: const Interval(0.1, 0.9, curve: Curves.easeInOut),
    );

    // ── Particles ─────────────────────────────────────────
    _particleAnim = CurvedAnimation(
      parent: _master,
      curve: const Interval(0.09, 0.40, curve: Curves.easeOut),
    );

    // ── Diamond logo ──────────────────────────────────────
    _logoScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _master,
        curve: const Interval(0.20, 0.42, curve: Curves.elasticOut),
      ),
    );
    _logoFade = CurvedAnimation(
      parent: _master,
      curve: const Interval(0.20, 0.35, curve: Curves.easeIn),
    );
    _logoGlow = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _master,
        curve: const Interval(0.35, 0.75, curve: Curves.easeInOut),
      ),
    );

    // ── "ROYAL" letters (left → centre, staggered) ───────
    const royalWord = 'ROYAL';
    const letterDur = 0.08; // interval per letter
    const royalStart = 0.36;
    _royalAnims = List.generate(royalWord.length, (i) {
      final s = royalStart + i * letterDur;
      final e = (s + 0.18 > 1.0) ? 1.0 : (s + 0.18);
      return CurvedAnimation(
        parent: _master,
        curve: Interval(s, e, curve: Curves.easeOutCubic),
      );
    });

    // ── "PIXELS" letters (right → centre, staggered) ─────
    const pixelsWord = 'PIXELS';
    const pixelsStart = 0.44;
    _pixelsAnims = List.generate(pixelsWord.length, (i) {
      final s = pixelsStart + i * letterDur;
      final e = (s + 0.18 > 1.0) ? 1.0 : (s + 0.18);
      return CurvedAnimation(
        parent: _master,
        curve: Interval(s, e, curve: Curves.easeOutCubic),
      );
    });

    // ── Shimmer sweep ─────────────────────────────────────
    _shimmer = CurvedAnimation(
      parent: _master,
      curve: const Interval(0.62, 0.80, curve: Curves.easeInOut),
    );

    // ── Tagline ───────────────────────────────────────────
    _taglineFade = CurvedAnimation(
      parent: _master,
      curve: const Interval(0.72, 0.86, curve: Curves.easeIn),
    );
    _taglineSlide = Tween<Offset>(
      begin: const Offset(0, 0.6),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _master,
      curve: const Interval(0.72, 0.86, curve: Curves.easeOutCubic),
    ));

    // ── Exit fade ─────────────────────────────────────────
    _exitFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _master,
        curve: const Interval(0.90, 1.0, curve: Curves.easeIn),
      ),
    );

    // Generate particles
    for (int i = 0; i < 60; i++) {
      _particles.add(_Particle(
        angle: _rng.nextDouble() * 2 * math.pi,
        speed: 0.12 + _rng.nextDouble() * 0.30,
        size: 2.0 + _rng.nextDouble() * 4.0,
        fadeStart: 0.50 + _rng.nextDouble() * 0.25,
        color: _rng.nextBool()
            ? const Color(0xFFD4A017)
            : const Color(0xFFFDDB6A),
      ));
    }

    // Navigate after animation
    _master.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _navigate();
      }
    });

    _checkPrivacyPolicy();
  }

  Future<void> _checkPrivacyPolicy() async {
    final prefs = await SharedPreferences.getInstance();
    final bool accepted = prefs.getBool('has_accepted_privacy_policy') ?? false;

    if (accepted) {
      if (mounted) _master.forward();
    } else {
      if (mounted) {
        _showPrivacyPolicyDialog();
      }
    }
  }

  void _showPrivacyPolicyDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _PrivacyPolicyDialog(
        onAccept: () async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('has_accepted_privacy_policy', true);
          if (context.mounted) {
            Navigator.pop(context);
          }
          if (mounted) {
            _master.forward();
          }
        },
        onDecline: () {
          SystemNavigator.pop();
        },
      ),
    );
  }

  Future<void> _navigate() async {
    if (!mounted) return;

    // ── Update check (Firestore backend) ────────────────────────────────
    final result = await UpdateService.checkForUpdate();

    if (!mounted) return;

    if (result.type == UpdateType.forced) {
      // Force update: block the app permanently, no dismiss.
      _showUpdateDialog(result, isForced: true);
      return; // Do NOT navigate to home/login
    }

    if (result.type == UpdateType.optional) {
      // Soft update: show dialog, user can skip.
      _showUpdateDialog(result, isForced: false);
      // Navigate even if user has not dismissed yet — they see the dialog on top.
    }

    // No update or optional → go to home / login as usual
    final authState = ref.read(authProvider);
    if (authState.user != null || authState.isGuest) {
      context.go('/home');
    } else {
      context.go('/login');
    }
  }

  void _showUpdateDialog(UpdateCheckResult result, {required bool isForced}) {
    showDialog(
      context: context,
      barrierDismissible: !isForced, // force = cannot close by tapping outside
      builder: (ctx) => _UpdateDialog(
        result: result,
        isForced: isForced,
        onUpdate: () async {
          final url = Uri.tryParse(result.storeUrl);
          if (url != null && url.hasScheme) {
            try {
              await launchUrl(url, mode: LaunchMode.externalApplication);
            } catch (e) {
              if (kDebugMode) debugPrint('[UpdateDialog] Could not open store: $e');
            }
          }
        },
        onSkip: isForced
            ? null // forced update: no skip button
            : () {
                Navigator.of(ctx).pop();
              },
      ),
    );
  }

  @override
  void dispose() {
    _master.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Opacity(
        opacity: _exitFade.value,
        child: Stack(
          children: [
            // ── Layer 1: Animated nebula background ────────────────
            Opacity(
              opacity: _bgFade.value,
              child: _NebulaBackground(progress: _nebulaPulse.value),
            ),

            // ── Layer 2: Particles ─────────────────────────────────
            CustomPaint(
              size: size,
              painter: _ParticlePainter(
                particles: _particles,
                progress: _particleAnim.value,
                centre: Offset(size.width / 2, size.height / 2),
              ),
            ),

            // ── Layer 3: Main content ──────────────────────────────
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Diamond logo
                  _buildLogo(),

                  const SizedBox(height: 32),

                  // "ROYAL PIXELS" title
                  _buildTitle(),

                  const SizedBox(height: 16),

                  // Tagline
                  _buildTagline(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── User logo with glow + scale ────────────────────────────────────────
  Widget _buildLogo() {
    final glow = _logoGlow.value;
    // Pulse between 0.6–1.0 after reveal
    final pulse = glow > 0 ? (0.6 + 0.4 * math.sin(glow * math.pi * 3)) : 0.0;

    return Opacity(
      opacity: _logoFade.value,
      child: Transform.scale(
        // Clamp to a tiny non-zero value — scale=0 produces a singular
        // transform matrix that triggers a Flutter debug assertion.
        scale: _logoScale.value.clamp(0.0001, double.infinity),
        child: Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
              colors: [Color(0x70D4A017), Colors.transparent],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFD4A017).withValues(alpha: pulse * 0.7),
                blurRadius: 40 + pulse * 30,
                spreadRadius: pulse * 10,
              ),
              BoxShadow(
                color: const Color(0xFF4A90FF).withValues(alpha: pulse * 0.4),
                blurRadius: 60 + pulse * 20,
                spreadRadius: pulse * 5,
              ),
            ],
          ),
          child: Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28.0),
              child: Image.asset(
                'assets/icon.png',
                width: 110,
                height: 110,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Staggered letter title ────────────────────────────────────────────────
  Widget _buildTitle() {
    const royalWord = 'ROYAL';
    const pixelsWord = 'PIXELS';

    return Column(
      children: [
        // "ROYAL" — letters fly in from the LEFT
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(royalWord.length, (i) {
            final anim = _royalAnims[i];
            return Opacity(
              opacity: anim.value,
              child: Transform.translate(
                offset: Offset(-30 * (1 - anim.value), 0),
                child: _LetterWidget(
                  letter: royalWord[i],
                  style: GoogleFonts.cinzel(
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 6,
                    foreground: Paint()
                      ..shader = const LinearGradient(
                        colors: [Color(0xFFFDDB6A), Color(0xFFD4A017)],
                      ).createShader(
                        const Rect.fromLTWH(0, 0, 60, 50),
                      ),
                  ),
                ),
              ),
            );
          }),
        ),

        const SizedBox(height: 2),

        // Shimmer line separator
        _ShimmerLine(progress: _shimmer.value),

        const SizedBox(height: 4),

        // "PIXELS" — letters fly in from the RIGHT
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(pixelsWord.length, (i) {
            final anim = _pixelsAnims[i];
            return Opacity(
              opacity: anim.value,
              child: Transform.translate(
                offset: Offset(30 * (1 - anim.value), 0),
                child: _LetterWidget(
                  letter: pixelsWord[i],
                  style: GoogleFonts.cinzel(
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 6,
                    color: const Color(0xFFF1F5F9).withValues(alpha: 0.92),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  // ── Tagline ───────────────────────────────────────────────────────────────
  Widget _buildTagline() {
    return Opacity(
      opacity: _taglineFade.value,
      child: SlideTransition(
        position: _taglineSlide,
        child: Text(
          'P R E M I U M  W A L L P A P E R S',
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.w300,
            letterSpacing: 4.0,
            color: const Color(0xFF94A3B8),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NEBULA ANIMATED BACKGROUND
// ─────────────────────────────────────────────────────────────────────────────
class _NebulaBackground extends StatelessWidget {
  final double progress;
  const _NebulaBackground({required this.progress});

  @override
  Widget build(BuildContext context) {
    // Animate the gradient stops to give a breathing / nebula feel
    final t = math.sin(progress * math.pi);
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0.1 * t, -0.2),
          radius: 1.6,
          colors: const [
            Color(0xFF0F1A3E), // deep royal blue
            Color(0xFF080B12), // near-black
            Color(0xFF000000), // black edges
          ],
          stops: const [0.0, 0.55, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // Secondary nebula orb (electric blue accent)
          Positioned(
            right: -80,
            bottom: 80 + t * 40,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF1A3A8F).withValues(alpha: 0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Gold nebula orb (top-left)
          Positioned(
            left: -60,
            top: -40 + t * 30,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFD4A017).withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PARTICLE SYSTEM
// ─────────────────────────────────────────────────────────────────────────────
class _Particle {
  final double angle;
  final double speed;
  final double size;
  final double fadeStart;
  final Color color;
  const _Particle({
    required this.angle,
    required this.speed,
    required this.size,
    required this.fadeStart,
    required this.color,
  });
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress; // 0→1 over burst interval
  final Offset centre;

  const _ParticlePainter({
    required this.particles,
    required this.progress,
    required this.centre,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    for (final p in particles) {
      // How far the particle has travelled
      final dist = p.speed * progress * (size.width * 0.55);
      final dx = math.cos(p.angle) * dist;
      final dy = math.sin(p.angle) * dist;
      final pos = centre.translate(dx, dy);

      // Fade out as progress reaches particle's fadeStart
      final alpha = progress < p.fadeStart
          ? 1.0
          : 1.0 - ((progress - p.fadeStart) / (1.0 - p.fadeStart)).clamp(0, 1);

      final paint = Paint()
        ..color = p.color.withValues(alpha: alpha.toDouble())
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.size * 0.8);

      // Draw a tiny diamond shape
      final path = _diamondPath(pos, p.size * (1 - progress * 0.4));
      canvas.drawPath(path, paint);
    }
  }

  Path _diamondPath(Offset centre, double r) {
    return Path()
      ..moveTo(centre.dx, centre.dy - r)
      ..lineTo(centre.dx + r * 0.6, centre.dy)
      ..lineTo(centre.dx, centre.dy + r)
      ..lineTo(centre.dx - r * 0.6, centre.dy)
      ..close();
  }

  @override
  bool shouldRepaint(_ParticlePainter old) =>
      old.progress != progress;
}



// ─────────────────────────────────────────────────────────────────────────────
// SHIMMER SWEEP LINE
// ─────────────────────────────────────────────────────────────────────────────
class _ShimmerLine extends StatelessWidget {
  final double progress;
  const _ShimmerLine({required this.progress});

  @override
  Widget build(BuildContext context) {
    final w = 220.0 * progress;
    // Guard: a zero-width Container with a gradient BoxDecoration causes a
    // Flutter assertion ("rect must be finite/non-empty"). Return an invisible
    // placeholder until the shimmer animation actually starts.
    if (w <= 0) return const SizedBox(width: 0, height: 1);
    return Container(
      width: w,
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            const Color(0xFFD4A017).withValues(alpha: 0.8),
            Colors.transparent,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4A017).withValues(alpha: 0.4 * progress),
            blurRadius: 6,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SINGLE LETTER WIDGET
// ─────────────────────────────────────────────────────────────────────────────
class _LetterWidget extends StatelessWidget {
  final String letter;
  final TextStyle style;
  const _LetterWidget({required this.letter, required this.style});

  @override
  Widget build(BuildContext context) {
    return Text(letter, style: style);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PRIVACY POLICY DIALOG
// ─────────────────────────────────────────────────────────────────────────────
class _PrivacyPolicyDialog extends StatelessWidget {
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _PrivacyPolicyDialog({
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        SystemNavigator.pop();
      },
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF141420),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 20,
              spreadRadius: 5,
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.privacy_tip_rounded, color: Colors.amber, size: 36),
            ),
            const SizedBox(height: 20),
            Text(
              'Privacy Policy',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Welcome to ${AppConstants.appName}! Before you proceed, please review and accept our Privacy Policy to understand how we handle your data and ensure a secure experience.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: Colors.white70,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () async {
                final url = Uri.parse('https://sites.google.com/view/royal-pixels-privacy/home');
                try {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                } catch (e) {
                  if (kDebugMode) {
                    debugPrint('Could not launch $url');
                  }
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
                child: Text(
                  'Read Full Privacy Policy here',
                  style: GoogleFonts.outfit(
                    color: Colors.amberAccent,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                    decorationColor: Colors.amberAccent,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: onDecline,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Decline',
                      style: GoogleFonts.outfit(
                        color: Colors.white54,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onAccept,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Accept',
                      style: GoogleFonts.outfit(
                        color: Colors.black,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// UPDATE DIALOG
// ─────────────────────────────────────────────────────────────────────────────
class _UpdateDialog extends StatelessWidget {
  final UpdateCheckResult result;
  final bool isForced;
  final VoidCallback onUpdate;
  final VoidCallback? onSkip;

  const _UpdateDialog({
    required this.result,
    required this.isForced,
    required this.onUpdate,
    this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Prevent back-button dismissal on forced update
      canPop: !isForced,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF141420),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isForced
                  ? const Color(0xFFD4A017).withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.08),
              width: isForced ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: isForced
                    ? const Color(0xFFD4A017).withValues(alpha: 0.18)
                    : Colors.black.withValues(alpha: 0.5),
                blurRadius: 24,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isForced
                      ? const Color(0xFFD4A017).withValues(alpha: 0.15)
                      : Colors.blueAccent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isForced ? Icons.system_update_rounded : Icons.new_releases_rounded,
                  color: isForced ? const Color(0xFFD4A017) : Colors.blueAccent,
                  size: 36,
                ),
              ),
              const SizedBox(height: 18),

              // Title
              Text(
                isForced ? 'Update Required' : 'Update Available',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              // Version tag
              if (result.latestVersionName.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4A017).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFD4A017).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    'v${result.latestVersionName}',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFFD4A017),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const SizedBox(height: 14),

              // Subtitle
              Text(
                isForced
                    ? 'This version is no longer supported. Please update to continue using ${AppConstants.appName}.'
                    : 'A new version of ${AppConstants.appName} is available with exciting improvements.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  color: Colors.white60,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),

              // Release notes
              if (result.releaseNotes.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
                  ),
                  child: Text(
                    result.releaseNotes,
                    style: GoogleFonts.outfit(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.6,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Buttons
              Row(
                children: [
                  if (onSkip != null) ...[
                    Expanded(
                      child: TextButton(
                        onPressed: onSkip,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Later',
                          style: GoogleFonts.outfit(
                            color: Colors.white38,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    flex: onSkip != null ? 2 : 1,
                    child: ElevatedButton(
                      onPressed: onUpdate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD4A017),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Update Now',
                        style: GoogleFonts.outfit(
                          color: Colors.black,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
