import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../domain/entities/wallpaper_entity.dart';
import '../../core/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/haptic_provider.dart';
import '../../core/utils/safe_tap.dart';
import 'dart:async';
import 'package:sensors_plus/sensors_plus.dart';
import '../providers/parallax_provider.dart';


class WallpaperCard extends ConsumerStatefulWidget {

  final WallpaperEntity wallpaper;
  final VoidCallback onTap;
  /// Optional long-press handler. When provided, a medium haptic fires
  /// immediately on long-press start (before the callback), giving a
  /// zero-lag premium feel.
  final VoidCallback? onLongPress;

  const WallpaperCard({
    super.key,
    required this.wallpaper,
    required this.onTap,
    this.onLongPress,
  });

  @override
  ConsumerState<WallpaperCard> createState() => _WallpaperCardState();
}

class _WallpaperCardState extends ConsumerState<WallpaperCard>
    with SingleTickerProviderStateMixin {

  bool _isPressed = false;
  late final AnimationController _glowCtrl;
  late final Animation<double> _glowAnim;
  
  final ValueNotifier<Offset> _tiltOffset = ValueNotifier(Offset.zero);
  StreamSubscription? _accelSub;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 130),
    );
    _glowAnim = CurvedAnimation(parent: _glowCtrl, curve: Curves.easeOut);

    _initParallax();
  }

  Future<void> _initParallax() async {
    // 1. Check if hardware supports it
    final isSupported = await ref.read(parallaxSupportProvider.future);
    if (!isSupported) return;

    // 2. Check if user enabled it in settings
    final isEnabled = ref.read(parallaxProvider);
    if (!isEnabled) return;

    // 3. Start listening to sensors
    try {
      _accelSub = accelerometerEventStream().listen(
        (event) {
          if (!mounted) return;
          final tx = (event.x / 9.8).clamp(-1.0, 1.0);
          final ty = (event.y / 9.8).clamp(-1.0, 1.0);
          _tiltOffset.value = Offset(tx, ty);
        },
        onError: (e) {
          // Silent fail for card grid (prevents spamming logs in grid)
        },
        cancelOnError: true,
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    _accelSub?.cancel();
    _glowCtrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    ref.read(hapticProvider.notifier).lightImpact();
    setState(() => _isPressed = true);
    _glowCtrl.forward();
  }

  void _onTapUp(TapUpDetails _) {
    setState(() => _isPressed = false);
    _glowCtrl.reverse();
    SafeTap.run('wp_card_${widget.wallpaper.id}', () {
      widget.onTap();
    });
  }

  void _onTapCancel() {
    setState(() => _isPressed = false);
    _glowCtrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final isParallaxEnabled = ref.watch(parallaxProvider);
    final isPremium = widget.wallpaper.isPremium;
    final isUltraHD = widget.wallpaper.isUltraHD;
    final isEditorsChoice = widget.wallpaper.isEditorsChoice;

    // Determine border & glow colors
    final Color borderColor = isPremium
        ? AppColors.goldMid.withAlpha(110)
        : AppColors.glassBorder;

    final Color glowColor = isPremium ? AppColors.goldMid : Colors.black;

    return RepaintBoundary(
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        onLongPress: widget.onLongPress == null
            ? null
            : () {
                SafeTap.run('wp_card_long_${widget.wallpaper.id}', () {
                  // Haptic fires the moment the long-press is recognised (~300ms
                  // after finger-down) — feels instant vs waiting for a callback.
                  ref.read(hapticProvider.notifier).mediumImpact();
                  widget.onLongPress!();
                });
              },
        child: AnimatedBuilder(
          animation: _glowAnim,
          builder: (context, child) {
            return AnimatedScale(
              scale: _isPressed ? 0.97 : 1.0,
              duration: const Duration(milliseconds: 200),
              curve: _isPressed ? Curves.easeOutQuart : Curves.easeOutBack,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: isPremium ? borderColor : AppColors.glassBorder.withAlpha(50), 
                    width: 1.3
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: glowColor.withAlpha(
                        (_isPressed ? 140 : (isPremium ? 40 : 20)),
                      ),
                      blurRadius: _isPressed ? 32 : (isPremium ? 20 : 14),
                      spreadRadius: _isPressed ? 4 : 0,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: child,
              ),
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: ColoredBox(
              color: isPremium ? AppColors.bg2 : AppColors.bg1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // ── Wallpaper image ──────────────────────────────────
                  ValueListenableBuilder<Offset>(
                    valueListenable: _tiltOffset,
                    builder: (context, tilt, child) {
                      final activeTilt = isParallaxEnabled ? tilt : Offset.zero;
                      return AnimatedScale(
                        // Inner zoom up to 1.12 on press! 1.08 for parallax buffer
                        scale: _isPressed ? 1.12 : (isParallaxEnabled ? 1.08 : 1.0), 
                        duration: const Duration(milliseconds: 250),
                        curve: _isPressed ? Curves.easeOutQuart : Curves.easeOut,
                        child: AnimatedSlide(
                          // Move opposite to device tilt, deep effect
                          offset: Offset(-activeTilt.dx * 0.04, activeTilt.dy * 0.04),
                          duration: const Duration(milliseconds: 150),
                          child: child!,
                        ),
                      );
                    },
                    child: Hero(
                      tag: 'wallpaper_${widget.wallpaper.id}',
                      child: widget.wallpaper.imageUrl.isEmpty
                          ? Container(
                              color: AppColors.bg2,
                              child: const Icon(Icons.broken_image_outlined,
                                  color: Colors.white24, size: 24),
                            )
                          : CachedNetworkImage(
                        imageUrl: widget.wallpaper.thumbnailUrl,
                        // Stable cache key: all URL variants share the same cache entry.
                        // Prevents images vanishing when switching between thumbnail/optimized URLs.
                        cacheKey: widget.wallpaper.cacheKey,
                        fit: BoxFit.cover,
                        // Optimize memory cache for buttery smooth scrolling
                        memCacheHeight: 400,
                        memCacheWidth: 260,
                        maxWidthDiskCache: 600,
                        maxHeightDiskCache: 1000,
                        fadeInDuration: const Duration(milliseconds: 400),
                        fadeOutDuration: const Duration(milliseconds: 200),
                        placeholder: (context, url) => Stack(
                          fit: StackFit.expand,
                          children: [
                            // 1. Extreme low-res blurred background (Instagram style)
                            if (widget.wallpaper.blurUrl.isNotEmpty)
                              Image.network(
                                widget.wallpaper.blurUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const SizedBox(),
                              ),
                            // 2. Subtle Shimmer overlay
                            Shimmer.fromColors(
                              baseColor: Colors.white.withAlpha(5),
                              highlightColor: Colors.white.withAlpha(15),
                              period: const Duration(milliseconds: 1500),
                              child: Container(color: Colors.white),
                            ),
                          ],
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: AppColors.bg2,
                          child: const Icon(Icons.broken_image_outlined,
                              color: Colors.white24, size: 24),
                        ),
                      ),
                    ),
                  ),

                  // ── Bottom gradient + title + category chip ──────────
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(10, 36, 10, 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Colors.black.withAlpha(180),
                            Colors.black.withAlpha(240),
                          ],
                          stops: const [0.0, 0.6, 1.0],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.wallpaper.category.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  // Simplified logic: High alpha transparency instead of blur.
                                  // This is much cheaper on mobile GPUs.
                                  color: Colors.black.withAlpha(160),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: Colors.white.withAlpha(40),
                                      width: 0.8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.category_rounded,
                                      color: AppColors.goldLight.withAlpha(200),
                                      size: 8,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      widget.wallpaper.category.toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 8,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          // Title
                          Text(
                            widget.wallpaper.title.isNotEmpty
                                ? widget.wallpaper.title
                                : widget.wallpaper.category,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              letterSpacing: 0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Top-right badges stack ───────────────────────────
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // PRO badge (gold)
                        if (isPremium)
                          _WallpaperBadge(
                            gradient: AppColors.goldGradient,
                            glowColor: AppColors.goldLight,
                            icon: Icons.lock_rounded,
                            iconColor: Colors.black,
                            label: 'PRO',
                            labelColor: Colors.black,
                          ),

                        // 4K / Ultra HD badge (cyan-teal)
                        if (isUltraHD) ...[
                          if (isPremium) const SizedBox(height: 4),
                          _WallpaperBadge(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF22D3EE), Color(0xFF0E7490)],
                            ),
                            glowColor: const Color(0xFF22D3EE),
                            icon: Icons.hd_rounded,
                            iconColor: Colors.white,
                            label: '4K',
                            labelColor: Colors.white,
                          ),
                        ],

                        // Editor's Choice badge (amber-orange)
                        if (isEditorsChoice) ...[
                          if (isPremium || isUltraHD) const SizedBox(height: 4),
                          _WallpaperBadge(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFBBF24), Color(0xFFD97706)],
                            ),
                            glowColor: const Color(0xFFFBBF24),
                            icon: Icons.star_rounded,
                            iconColor: Colors.black,
                            label: 'PICK',
                            labelColor: Colors.black,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Reusable badge widget ────────────────────────────────────────────────────

class _WallpaperBadge extends StatelessWidget {
  final LinearGradient gradient;
  final Color glowColor;
  final IconData icon;
  final Color iconColor;
  final String label;
  final Color labelColor;

  const _WallpaperBadge({
    required this.gradient,
    required this.glowColor,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: glowColor.withAlpha(80),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 9),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              color: labelColor,
              fontSize: 8,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
