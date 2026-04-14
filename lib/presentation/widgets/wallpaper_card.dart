import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../domain/entities/wallpaper_entity.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import 'dart:ui';

class WallpaperCard extends StatefulWidget {
  final WallpaperEntity wallpaper;
  final VoidCallback onTap;

  const WallpaperCard({
    super.key,
    required this.wallpaper,
    required this.onTap,
  });

  @override
  State<WallpaperCard> createState() => _WallpaperCardState();
}

class _WallpaperCardState extends State<WallpaperCard>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;
  late final AnimationController _glowCtrl;
  late final Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 130),
    );
    _glowAnim = CurvedAnimation(parent: _glowCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    HapticFeedback.lightImpact();
    setState(() => _isPressed = true);
    _glowCtrl.forward();
  }

  void _onTapUp(TapUpDetails _) {
    setState(() => _isPressed = false);
    _glowCtrl.reverse();
    widget.onTap();
  }

  void _onTapCancel() {
    setState(() => _isPressed = false);
    _glowCtrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final isPremium = widget.wallpaper.isPremium;
    final isSpecial = widget.wallpaper.isSpecial;

    // Determine border & glow colors
    final Color borderColor = isSpecial
        ? AppColors.accentPurple.withAlpha(130)
        : isPremium
            ? AppColors.goldMid.withAlpha(110)
            : AppColors.glassBorder;

    final Color glowColor = isSpecial
        ? AppColors.accentPurple
        : isPremium
            ? AppColors.goldMid
            : Colors.black;

    return RepaintBoundary(
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        child: AnimatedBuilder(
          animation: _glowAnim,
          builder: (context, child) {
            return AnimatedScale(
              scale: _isPressed ? 0.95 : 1.0,
              duration: const Duration(milliseconds: 150),
              curve: _isPressed ? Curves.easeOutQuart : Curves.easeOutBack,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: isSpecial || isPremium ? borderColor : AppColors.glassBorder.withAlpha(50), 
                    width: 1.3
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: glowColor.withAlpha(
                        (_isPressed ? 110 : (isSpecial ? 35 : isPremium ? 30 : 60)),
                      ),
                      blurRadius: _isPressed ? 28 : (isSpecial || isPremium ? 18 : 12),
                      spreadRadius: _isPressed ? 3 : 0,
                      offset: const Offset(0, 6),
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
              color: isSpecial
                  ? AppColors.accentPurple.withAlpha(18)
                  : isPremium
                      ? AppColors.bg2
                      : AppColors.bg1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // ── Wallpaper image ──────────────────────────────────
                  Hero(
                    tag: 'wallpaper_${widget.wallpaper.id}',
                    child: CachedNetworkImage(
                      imageUrl: widget.wallpaper.optimizedUrl,
                      fit: BoxFit.cover,
                      memCacheHeight: 600,
                      placeholder: (context, url) => Shimmer.fromColors(
                        baseColor: AppColors.bg2,
                        highlightColor: AppColors.bg3,
                        child: Container(color: Colors.white),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: AppColors.bg2,
                        child: const Icon(Icons.broken_image_outlined,
                            color: Colors.white24),
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
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.transparent, Colors.black87, Colors.black],
                          stops: [0.0, 0.7, 1.0],
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
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withAlpha(20),
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

                  // ── SPECIAL badge (purple-pink) ─────────────────────
                  if (isSpecial)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: AppColors.specialGradient,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accentPurple.withAlpha(90),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.auto_awesome,
                                color: Colors.white, size: 10),
                            SizedBox(width: 3),
                            Text(
                              'SPECIAL',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  // ── PRO badge (gold) ────────────────────────────────
                  else if (isPremium)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: AppColors.goldGradient,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.goldLight.withAlpha(120),
                              blurRadius: 12,
                              spreadRadius: 1,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock_rounded, color: Colors.black, size: 10),
                            SizedBox(width: 3),
                            Text(
                              'PRO',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
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
