import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../domain/entities/wallpaper_entity.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/scroll/scroll.dart';
import 'premium_touch_tile.dart';
import '../../../core/services/image_prefetch_service.dart';
import '../../../core/services/adaptive_performance.dart';

/// A horizontally scrolling "Trending Now" section header + card row.
/// Shows up to [maxItems] wallpapers with fire badge + view count.
class TrendingSection extends StatefulWidget {
  final List<WallpaperEntity> wallpapers;
  final void Function(WallpaperEntity) onTap;
  final int maxItems;
  final String title;

  const TrendingSection({
    super.key,
    required this.wallpapers,
    required this.onTap,
    this.maxItems = 24,
    this.title = 'TOP FEED',
  });

  @override
  State<TrendingSection> createState() => _TrendingSectionState();
}

class _TrendingSectionState extends State<TrendingSection> {
  /// Tracks whether the initial entrance animation has played.
  bool _hasAnimated = false;
  late final VelocityAwareScrollController _scrollController;
  double _lastOffset = 0;

  @override
  void initState() {
    super.initState();
    _scrollController = VelocityAwareScrollController();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _hasAnimated = true);
    });
  }

  void _onScroll() {
    if (!mounted) return;
    
    final currentOffset = _scrollController.offset;
    final delta = currentOffset - _lastOffset;
    _lastOffset = currentOffset;

    // Horizontal bidirectional prefetching
    ImagePrefetchService.preloadBidirectional(
      context,
      widget.wallpapers,
      (currentOffset / 130).floor(), // Estimate index based on card width
      scrollDelta: delta,
      isFastScrolling: _scrollController.velocity.value > 1500,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.wallpapers.isEmpty) return const SizedBox.shrink();
    final items = widget.wallpapers.take(widget.maxItems).toList();

    return PremiumScrollEffectListener(
      controller: _scrollController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Section header ─────────────────────────────────────────────
          _buildHeader(items),

          // ── Horizontal card scroll ──────────────────────────────────────
          SizedBox(
            height: 180,
            child: CustomScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              physics: const PremiumAlwaysScrollPhysics(),
              cacheExtent: AdaptivePerformance.isLow ? 400 : 1200,
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final wp = items[index];
                        return _TrendingCard(
                          wallpaper: wp,
                          index: index,
                          onTap: () => widget.onTap(wp),
                          skipAnimation: _hasAnimated,
                        );
                      },
                      childCount: items.length,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildHeader(List<WallpaperEntity> items) {
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
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
          Text(
            widget.title,
            style: const TextStyle(
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
    );

    if (_hasAnimated) return header;
    return header
        .animate(target: AdaptivePerformance.enableAnimations ? null : 1.0)
        .fade(duration: 400.ms)
        .slideX(begin: -0.1, end: 0, duration: 350.ms);
  }
}

class _TrendingCard extends StatelessWidget {
  final WallpaperEntity wallpaper;
  final int index;
  final VoidCallback onTap;
  final bool skipAnimation;

  const _TrendingCard({
    required this.wallpaper,
    required this.index,
    required this.onTap,
    this.skipAnimation = false,
  });

  @override
  Widget build(BuildContext context) {
    final card = RepaintBoundary(
      child: PremiumTouchTile(
        onTap: onTap,
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
                CachedNetworkImage(
                  imageUrl: wallpaper.thumbnailUrl,
                  fit: BoxFit.cover,
                  memCacheWidth: 260,
                  memCacheHeight: 360,
                  fadeInDuration: const Duration(milliseconds: 150),
                  fadeOutDuration: Duration.zero,
                  useOldImageOnUrlChange: true,
                  placeholder: (_, __) =>
                      const ColoredBox(color: AppColors.bg2),
                  errorWidget: (_, __, ___) => Container(
                    color: AppColors.bg2,
                    child: const Icon(Icons.broken_image_outlined,
                        color: Colors.white24),
                  ),
                ),
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
                      wallpaper.title,
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
                      '#${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (skipAnimation || !AdaptivePerformance.enableAnimations) return card;
    return card
        .animate(delay: (index * 60).ms)
        .fade(duration: 400.ms)
        .slideX(
            begin: 0.2, end: 0, duration: 380.ms, curve: Curves.easeOutCubic);
  }
}
