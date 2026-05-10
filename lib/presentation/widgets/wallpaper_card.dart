import 'package:flutter/material.dart';
import '../../domain/entities/wallpaper_entity.dart';
import '../../core/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/adaptive_performance.dart';
import '../../core/animations/liquid_rect_tween.dart';
import '../../core/widgets/three_stage_image.dart';
import '../../core/scroll/velocity_aware_controller.dart';
import 'premium_glow_system.dart';

class WallpaperCard extends ConsumerWidget {
  final WallpaperEntity wallpaper;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VelocityAwareScrollController? scrollController;

  const WallpaperCard({
    super.key,
    required this.wallpaper,
    required this.onTap,
    this.onLongPress,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPremium = wallpaper.isPremium;
    final isUltraHD = wallpaper.isUltraHD;
    final isEditorsChoice = wallpaper.isEditorsChoice;

    final content = wallpaper.imageUrl.isEmpty
        ? const _BrokenImagePlaceholder()
        : _buildProgressiveImage();

    // Use PremiumGlowSystem for the advanced glow and touch response
    return PremiumGlowSystem(
      imageUrl: wallpaper.optimizedUrl,
      scrollController: scrollController,
      onTap: onTap,
      onLongPress: onLongPress,
      builder: (context, dominantColor) {
        return Stack(
          fit: StackFit.expand,
          children: [
            // Phase 7: Hero transitions are extremely expensive on budget GPUs during page push.
            // We disable them on LOW tier to ensure the detail page opens instantly.
            AdaptivePerformance.enableHeroTransitions
                ? Hero(
                    tag: 'wallpaper_${wallpaper.id}',
                    createRectTween: (begin, end) =>
                        LiquidSpringRectTween(begin: begin, end: end),
                    child: content,
                  )
                : content,
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: RepaintBoundary(
                child: _BottomInfo(wallpaper: wallpaper, dominantColor: dominantColor),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: RepaintBoundary(
                child: _TopRightBadges(
                  wallpaper: wallpaper,
                  isPremium: isPremium,
                  isUltraHD: isUltraHD,
                  isEditorsChoice: isEditorsChoice,
                ),
              ),
            ),
            // Lock overlay for premium wallpapers
            if (isPremium)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(160),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.goldMid.withAlpha(100), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_rounded, color: AppColors.goldLight, size: 11),
                      const SizedBox(width: 4),
                      Text(
                        '${wallpaper.diamondCost}',
                        style: TextStyle(
                          color: AppColors.goldLight,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Text('💎', style: TextStyle(fontSize: 9)),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildProgressiveImage() {
    final gridResUrl = wallpaper.mediumUrl.isNotEmpty
        ? wallpaper.mediumUrl
        : wallpaper.optimizedUrl;
    final thumbUrl = wallpaper.thumbnailUrl;

    return ThreeStageImage(
      imageUrl: gridResUrl,
      thumbnailUrl: thumbUrl.isNotEmpty ? thumbUrl : null,
      fit: BoxFit.cover,
      memCacheWidth: 240, // Optimized for 2-column grid (2x density on 1080p is ~240-270px)
      memCacheHeight: 480,
      fadeInDuration: const Duration(milliseconds: 150), // Snappier feel
      cacheKey: gridResUrl,
      // Pass controller to pause high-res loading during active scroll
      scrollController: scrollController,
    );
  }
}

// ── Broken image placeholder ─────────────────────────────────────────────────

class _BrokenImagePlaceholder extends StatelessWidget {
  const _BrokenImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.bg2,
      child: Icon(Icons.broken_image_outlined, color: Colors.white24, size: 24),
    );
  }
}

// ── Bottom info overlay ───────────────────────────────────────────────────────

class _BottomInfo extends StatelessWidget {
  final WallpaperEntity wallpaper;
  final Color? dominantColor;

  const _BottomInfo({required this.wallpaper, this.dominantColor});

  @override
  Widget build(BuildContext context) {
    final bool isSmall = MediaQuery.sizeOf(context).width < 380;
    final accentColor = dominantColor ?? AppColors.goldMid;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? 8 : 12,
        vertical: isSmall ? 10 : 14,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(22),
          bottomRight: Radius.circular(22),
        ),
        border: Border(
          top: BorderSide(
            color: accentColor.withValues(alpha: 0.4),
            width: 1.0,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            (wallpaper.title.isNotEmpty ? wallpaper.title : wallpaper.category)
                .toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: isSmall ? 10 : 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              height: 1.2,
              shadows: [
                Shadow(
                  color: accentColor.withValues(alpha: 0.5),
                  blurRadius: 8,
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (!isSmall && wallpaper.category.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              wallpaper.category,
              style: TextStyle(
                color: AppColors.textSecondary.withValues(alpha: 0.7),
                fontSize: 8,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// Removed _Stat and _CategoryChip to align with the cleaner, more premium "Gods" category style.

// ── Top-right badges (PRO / 4K / PICK / NEW) ─────────────────────────────────

class _TopRightBadges extends StatelessWidget {
  final WallpaperEntity wallpaper;
  final bool isPremium;
  final bool isUltraHD;
  final bool isEditorsChoice;

  const _TopRightBadges({
    required this.wallpaper,
    required this.isPremium,
    required this.isUltraHD,
    required this.isEditorsChoice,
  });

  bool get _isNew {
    final created = wallpaper.createdAt;
    if (created == null) return false;
    // Cache the "now" value for this build pass
    return DateTime.now().difference(created).inHours < 24;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_isNew) _buildNewBadge(),
        if (isPremium)
          _WallpaperBadge(
            gradient: AppColors.goldGradient,
            glowColor: AppColors.goldLight,
            icon: Icons.diamond,
            iconColor: Colors.black,
            label: 'ELITE',
            labelColor: Colors.black,
          ),
        if (isUltraHD) ...[
          if (isPremium) const SizedBox(height: 4),
          const _WallpaperBadge(
            gradient: LinearGradient(
              colors: [Color(0xFF22D3EE), Color(0xFF0E7490)],
            ),
            glowColor: Color(0xFF22D3EE),
            icon: Icons.hd_rounded,
            iconColor: Colors.white,
            label: '4K',
            labelColor: Colors.white,
          ),
        ],
        if (isEditorsChoice) ...[
          if (isPremium || isUltraHD) const SizedBox(height: 4),
          const _WallpaperBadge(
            gradient: LinearGradient(
              colors: [Color(0xFFFBBF24), Color(0xFFD97706)],
            ),
            glowColor: Color(0xFFFBBF24),
            icon: Icons.star_rounded,
            iconColor: Colors.black,
            label: 'PICK',
            labelColor: Colors.black,
          ),
        ],
      ],
    );
  }

  Widget _buildNewBadge() {
    return const _WallpaperBadge(
      gradient: LinearGradient(
        colors: [Color(0xFF10B981), Color(0xFF059669)],
      ),
      glowColor: Color(0xFF10B981),
      icon: Icons.new_releases_rounded,
      iconColor: Colors.white,
      label: 'NEW',
      labelColor: Colors.white,
    );
  }
}

// ─── Reusable badge widget ─────────────────────────────────────────────────────

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
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: glowColor.withValues(alpha: 0.6), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
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
