import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../domain/entities/wallpaper_entity.dart';
import '../../../core/theme/app_colors.dart';

/// A horizontally scrolling "Trending Now" section header + card row.
/// Shows up to [maxItems] wallpapers with fire badge + view count.
class TrendingSection extends StatelessWidget {
  final List<WallpaperEntity> wallpapers;
  final void Function(WallpaperEntity) onTap;
  final int maxItems;

  const TrendingSection({
    super.key,
    required this.wallpapers,
    required this.onTap,
    this.maxItems = 8,
  });

  @override
  Widget build(BuildContext context) {
    if (wallpapers.isEmpty) return const SizedBox.shrink();
    final items = wallpapers.take(maxItems).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Section header ─────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              // Fire icon with glow
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: AppColors.trendingGradient,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF6B00).withAlpha(80),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(Icons.local_fire_department_rounded,
                    color: Colors.white, size: 14),
              ),
              const SizedBox(width: 10),
              const Text(
                'TOP FEED',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              Text(
                '${items.length} wallpapers',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ).animate().fade(duration: 400.ms).slideX(begin: -0.1, end: 0, duration: 350.ms),

        // ── Horizontal card scroll ──────────────────────────────────────
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final wp = items[index];
              return _TrendingCard(
                wallpaper: wp,
                index: index,
                onTap: () => onTap(wp),
              );
            },
          ),
        ),

        const SizedBox(height: 4),
      ],
    );
  }
}

class _TrendingCard extends StatefulWidget {
  final WallpaperEntity wallpaper;
  final int index;
  final VoidCallback onTap;

  const _TrendingCard({
    required this.wallpaper,
    required this.index,
    required this.onTap,
  });

  @override
  State<_TrendingCard> createState() => _TrendingCardState();
}

class _TrendingCardState extends State<_TrendingCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutQuart,
        child: Container(
          width: 130,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withAlpha(18),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(80),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // ── Image ──────────────────────────────────────────────
                CachedNetworkImage(
                  imageUrl: widget.wallpaper.thumbnailUrl,
                  fit: BoxFit.cover,
                  memCacheWidth: 260,
                  memCacheHeight: 360,
                  errorWidget: (_, __, ___) => Container(
                    color: AppColors.bg2,
                    child: const Icon(Icons.broken_image_outlined,
                        color: Colors.white24),
                  ),
                ),

                // ── Bottom gradient ─────────────────────────────────────
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(8, 28, 8, 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.black.withAlpha(230),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: Text(
                      widget.wallpaper.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),

                // ── Rank badge (top-left) ────────────────────────────────
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: AppColors.trendingGradient,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '#${widget.index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),

                // ── View count (top-right) ──────────────────────────────
                if (widget.wallpaper.viewCount > 0)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(140),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.white.withAlpha(30), width: 0.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.remove_red_eye_outlined,
                              color: Colors.white54, size: 8),
                          const SizedBox(width: 3),
                          Text(
                            _formatCount(widget.wallpaper.viewCount),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        )
            .animate(delay: (widget.index * 60).ms)
            .fade(duration: 400.ms)
            .slideX(begin: 0.2, end: 0, duration: 380.ms, curve: Curves.easeOutCubic),
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }
}
