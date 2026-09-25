import 'package:royal_pixels/core/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui';
import '../../../core/services/adaptive_performance.dart';
import '../../../domain/entities/wallpaper_entity.dart';
import 'package:royal_pixels/presentation/providers/wallpaper_provider.dart';
import 'package:royal_pixels/presentation/providers/trending_provider.dart';
import 'package:royal_pixels/core/theme/app_colors.dart';
import 'package:royal_pixels/core/utils/safe_tap.dart';
import 'package:royal_pixels/presentation/providers/auth_provider.dart';
import 'package:royal_pixels/core/services/image_prefetch_service.dart';
import 'package:royal_pixels/presentation/providers/haptic_provider.dart';
import 'package:royal_pixels/presentation/providers/likes_provider.dart';
import 'package:royal_pixels/presentation/providers/navigation_provider.dart';

enum FeedType { explore, live }

class SocialFeedPage extends ConsumerStatefulWidget {
  final String? initialWallpaperId;
  const SocialFeedPage({super.key, this.initialWallpaperId});

  @override
  ConsumerState<SocialFeedPage> createState() => _SocialFeedPageState();
}

class _SocialFeedPageState extends ConsumerState<SocialFeedPage> {
  PageController? _pageController;
  bool _initialIncrementDone = false;
  final Set<String> _viewedIds = {};
  FeedType _selectedFeed = FeedType.explore;

  @override
  Widget build(BuildContext context) {
    final wallpaperState = ref.watch(wallpaperProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      extendBody: true,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          _buildBody(wallpaperState),
          _buildTrendingHeader(),
        ],
      ),
    );
  }

  Widget _buildTrendingHeader() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(120),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withAlpha(30), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(100),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildFeedTab(
                label: AppLocalizations.of(context)!.explore,
                isSelected: _selectedFeed == FeedType.explore,
                onTap: () {
                  if (_selectedFeed != FeedType.explore) {
                    ref.read(hapticProvider.notifier).selectionClick();
                    setState(() {
                      _selectedFeed = FeedType.explore;
                      _pageController?.jumpToPage(0);
                    });
                  } else {
                    // Force refresh if already on explore to "explore each time"
                    ref.read(feedWallpapersProvider.notifier).refresh();
                    _pageController?.jumpToPage(0);
                  }
                },
              ),
              const SizedBox(width: 4),
              _buildFeedTab(
                label: AppLocalizations.of(context)!.live,
                isSelected: _selectedFeed == FeedType.live,
                isLive: true,
                onTap: () {
                  if (_selectedFeed != FeedType.live) {
                    ref.read(hapticProvider.notifier).selectionClick();
                    setState(() {
                      _selectedFeed = FeedType.live;
                      _pageController?.jumpToPage(0);
                    });
                  }
                },
              ),
            ],
          ),
        ),
      ).animate(target: AdaptivePerformance.enableAnimations ? null : 1.0).fadeIn(delay: 800.ms).slideY(begin: -0.5),
    );
  }

  Widget _buildFeedTab({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    bool isLive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: 300.ms,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: isSelected
              ? (isLive ? AppColors.specialGradient : AppColors.goldGradient)
              : null,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: (isLive ? AppColors.accentPink : AppColors.goldMid).withAlpha(80),
                    blurRadius: 12,
                    spreadRadius: -2,
                  )
                ]
              : [],
        ),
        child: Row(
          children: [
            if (isSelected) ...[
              Icon(
                isLive ? Icons.sensors_rounded : Icons.local_fire_department_rounded,
                size: 14,
                color: Colors.black,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.white.withAlpha(150),
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(WallpaperState state) {
    final trendingAsync = ref.watch(trendingProvider);
    final exploreWallpapers = ref.watch(feedWallpapersProvider);
    final liveWallpapers = ref.watch(liveWallpapersProvider);

    return trendingAsync.when(
      data: (trendingWallpapers) {
        final List<WallpaperEntity> allWallpapers = 
            _selectedFeed == FeedType.explore ? exploreWallpapers : liveWallpapers;
        
        // Listen for external navigation requests to specific wallpapers (e.g. from Long Press Preview)
        ref.listen<String?>(feedTargetWallpaperProvider, (previous, next) {
          if (next != null && _pageController != null) {
            final targetIndex = allWallpapers.indexWhere((w) => w.id == next);
            if (targetIndex != -1) {
              _pageController!.jumpToPage(targetIndex);
              // Reset the target so it doesn't jump again on subsequent builds
              Future.microtask(() {
                ref.read(feedTargetWallpaperProvider.notifier).state = null;
              });
            }
          }
        });

        if (allWallpapers.isEmpty && state.isLoading) {
          return const Center(child: CircularProgressIndicator(color: AppColors.goldMid));
        }

        // Calculate initial page based on optional ID or external navigation target
        int initialPage = 0;
        final targetId = ref.read(feedTargetWallpaperProvider);
        
        if (targetId != null) {
          final foundIndex = allWallpapers.indexWhere((w) => w.id == targetId);
          if (foundIndex != -1) initialPage = foundIndex;
          // Clear it so we don't re-use it on accidental rebuilds
          Future.microtask(() => ref.read(feedTargetWallpaperProvider.notifier).state = null);
        } else if (widget.initialWallpaperId != null) {
          final foundIndex = allWallpapers.indexWhere((w) => w.id == widget.initialWallpaperId);
          if (foundIndex != -1) initialPage = foundIndex;
        }

        // Initialize PageController
        _pageController ??= PageController(initialPage: initialPage);
          
        // Initial Prefetch
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ImagePrefetchService.prefetchReel(
              context, 
              allWallpapers, 
              initialPage, 
              lookAhead: 4,
            );
          }
        });

        // Increment view for the very first wallpaper on load
        if (!_initialIncrementDone && allWallpapers.isNotEmpty) {
          _initialIncrementDone = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final id = allWallpapers[0].id;
            if (_viewedIds.add(id)) {
              final userId = ref.read(authProvider).user?.uid;
              ref.read(wallpaperProvider.notifier).incrementViews(id, userId: userId);
              ref.read(trendingProvider.notifier).incrementViews(id, userId: userId);
            }
          });
        }

        if (allWallpapers.isEmpty) {
          if (state.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.goldMid),
            );
          }
          return Center(
            child: Text(AppLocalizations.of(context)!.noWallpapersFound1, style: TextStyle(color: Colors.white)),
          );
        }

        return PageView.builder(
          controller: _pageController!,
          scrollDirection: Axis.vertical,
          itemCount: allWallpapers.length,
          onPageChanged: (index) {
            if (index < allWallpapers.length) {
              final id = allWallpapers[index].id;
              if (_viewedIds.add(id)) {
                final userId = ref.read(authProvider).user?.uid;
                ref.read(wallpaperProvider.notifier).incrementViews(id, userId: userId);
                ref.read(trendingProvider.notifier).incrementViews(id, userId: userId);
              }
              ImagePrefetchService.prefetchReel(context, allWallpapers, index);
            }
          },
          itemBuilder: (context, index) {
            final wp = allWallpapers[index];
            return WallpaperReelCard(wallpaper: wp);
          },
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.goldMid),
      ),
      error: (err, stack) => Center(
        child: Text('Error: $err', style: const TextStyle(color: Colors.white)),
      ),
    );
  }
}

class WallpaperReelCard extends ConsumerStatefulWidget {
  final WallpaperEntity wallpaper;

  const WallpaperReelCard({super.key, required this.wallpaper});

  @override
  ConsumerState<WallpaperReelCard> createState() => _WallpaperReelCardState();
}

class _WallpaperReelCardState extends ConsumerState<WallpaperReelCard>
    with TickerProviderStateMixin {
  final List<Offset> _hearts = [];

  void _handleDoubleTap() {
    // 1. Trigger Haptics
    ref.read(hapticProvider.notifier).mediumImpact();

    // 2. Perform Like Logic (ensure it's liked)
    final isLiked = ref.read(likesNotifierProvider.notifier).isFavorite(widget.wallpaper.id);
    if (!isLiked) {
      ref.read(likesNotifierProvider.notifier).toggleLike(widget.wallpaper.id);
    }

    // 3. Add Heart Animation Instance
    setState(() {
      _hearts.add(Offset.zero); // Center-based for now
    });

    // 4. Cleanup after animation finishes
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted && _hearts.isNotEmpty) {
        setState(() {
          _hearts.removeAt(0);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    
    return GestureDetector(
      onDoubleTap: _handleDoubleTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Full screen background image (Optimized for speed)
          CachedNetworkImage(
            imageUrl: widget.wallpaper.blurUrl,
            fit: BoxFit.cover,
            memCacheWidth: 100,
            memCacheHeight: 200,
            placeholder: (context, url) => Container(color: AppColors.bg0),
            errorWidget: (context, url, error) => Container(color: AppColors.bg0),
          ),

          CachedNetworkImage(
            imageUrl: widget.wallpaper.getAdaptiveReelUrl(AdaptivePerformance.tier),
            fit: BoxFit.cover,
            fadeInDuration: 300.ms,
            fadeOutDuration: 300.ms,
            memCacheWidth: (MediaQuery.of(context).size.width * MediaQuery.of(context).devicePixelRatio).round(),
            placeholder: (context, url) => const SizedBox.shrink(),
            errorWidget: (context, url, error) => const Icon(Icons.error, color: Colors.white54),
          ),

          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black45,
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black54,
                  Colors.black87,
                ],
                stops: [0.0, 0.2, 0.6, 0.8, 1.0],
              ),
            ),
          ),

        if (AdaptivePerformance.enableAnimations)
          ..._hearts.map((_) => Center(
            child: Icon(
              Icons.favorite_rounded,
              color: Colors.redAccent.withValues(alpha: 0.9),
              size: 110,
            ).animate()
             .scale(
               begin: const Offset(0.3, 0.3),
               end: const Offset(1.2, 1.2),
               duration: 400.ms,
               curve: Curves.elasticOut,
             )
             .fadeOut(delay: 400.ms, duration: 300.ms)
             .moveY(begin: 0, end: -80, delay: 400.ms, duration: 400.ms, curve: Curves.easeOut),
          )),

        Positioned(
          bottom: 120 + bottomPadding,
          left: 20,
          right: 85,
          child: RepaintBoundary(
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.wallpaper.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  height: 1.1,
                  shadows: [
                    Shadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 2)),
                  ],
                ),
              ).animate(target: AdaptivePerformance.enableAnimations ? null : 1.0)
                  .fade(duration: 400.ms)
                  .slideY(begin: 0.2, curve: Curves.easeOutExpo),
              
              const SizedBox(height: 12),
              
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (widget.wallpaper.isPremium) 
                    _buildGlassTag('PREMIUM', color: AppColors.goldMid, isGold: true)
                  else
                    _buildGlassTag('FREE', color: Colors.greenAccent, isGold: false),
                  
                  if (widget.wallpaper.isUltraHD)
                    _buildGlassTag('4K', color: const Color(0xFF22D3EE)),
                  if (widget.wallpaper.isEditorsChoice)
                    _buildGlassTag('EDITOR\'S PICK', color: const Color(0xFFFBBF24)),
                ],
              ).animate(target: AdaptivePerformance.enableAnimations ? null : 1.0)
                        .fade(delay: 100.ms, duration: 400.ms),
            ],
          ),
        ),
      ),

        Positioned(
          right: 15,
          bottom: 160 + bottomPadding,
          child: RepaintBoundary(
            child: Column(
              children: [
                _buildLikeButton(context, ref),
                const SizedBox(height: 20),
                _buildStatItem(Icons.visibility_rounded, widget.wallpaper.viewCount.toString()),
                const SizedBox(height: 20),
                _buildMainActionButton(context),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

  Widget _buildLikeButton(BuildContext context, WidgetRef ref) {
    final isLiked = ref.watch(likesNotifierProvider.notifier).isFavorite(widget.wallpaper.id);
    
    return Column(
      children: [
        GestureDetector(
          onTap: () {
            ref.read(hapticProvider.notifier).lightImpact();
            ref.read(likesNotifierProvider.notifier).toggleLike(widget.wallpaper.id);
          },
          child: Container(
            height: 54,
            width: 54,
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(80),
              shape: BoxShape.circle,
              border: Border.all(
                color: isLiked ? Colors.redAccent.withAlpha(200) : Colors.white.withAlpha(40),
                width: 1.5,
              ),
              boxShadow: isLiked ? [
                BoxShadow(
                  color: Colors.redAccent.withAlpha(60),
                  blurRadius: 15,
                  spreadRadius: 2,
                )
              ] : [],
            ),
            child: ClipOval(
              child: AdaptivePerformance.enableBackdropBlur
                ? BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Icon(
                      isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: isLiked ? Colors.redAccent : Colors.white,
                      size: 26,
                    ),
                  )
                : Icon(
                    isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: isLiked ? Colors.redAccent : Colors.white,
                    size: 26,
                  ).animate(target: (isLiked && AdaptivePerformance.enableAnimations) ? null : 1.0)
                   .scale(begin: const Offset(1, 1), end: const Offset(1.2, 1.2), duration: 200.ms, curve: Curves.elasticOut)
                   .then()
                   .scale(begin: const Offset(1.2, 1.2), end: const Offset(1, 1), duration: 200.ms),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          widget.wallpaper.likeCount.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            shadows: [Shadow(color: Colors.black, blurRadius: 4)],
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(IconData icon, String value) {
    return Column(
      children: [
        Container(
          height: 54,
          width: 54,
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(80),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withAlpha(40), width: 1.5),
          ),
          child: ClipOval(
            child: AdaptivePerformance.enableBackdropBlur
                ? BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Icon(icon, color: Colors.white, size: 26),
                  )
                : Icon(icon, color: Colors.white, size: 26),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            shadows: [Shadow(color: Colors.black, blurRadius: 4)],
          ),
        ),
      ],
    );
  }

  Widget _buildGlassTag(String text, {Color? color, bool isGold = false}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: AdaptivePerformance.enableBackdropBlur
          ? BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: _buildGlassTagContainer(text, color, isGold),
            )
          : _buildGlassTagContainer(text, color, isGold, opaque: true),
    );
  }

  Widget _buildGlassTagContainer(String text, Color? color, bool isGold, {bool opaque = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (color ?? Colors.white).withAlpha(opaque ? 200 : (isGold ? 40 : 25)),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: (color ?? Colors.white).withAlpha(isGold ? 80 : 40),
          width: 1,
        ),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: color ?? Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildMainActionButton(BuildContext context) {
    final button = GestureDetector(
      onTap: () => SafeTap.run('reel_action_${widget.wallpaper.id}', () => context.push('/detail', extra: widget.wallpaper)),
      child: Container(
        height: 62,
        width: 62,
        decoration: BoxDecoration(
          gradient: AppColors.goldGradient,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.goldMid.withAlpha(150),
              blurRadius: 20,
              spreadRadius: 2,
            )
          ],
        ),
        child: const Icon(Icons.download_rounded, color: Colors.black, size: 30),
      ),
    );

    if (AdaptivePerformance.isLow) return button;

    return button
        .animate(onPlay: (controller) => controller.repeat(), target: AdaptivePerformance.enableAnimations ? null : 1.0)
        .shimmer(duration: 2.seconds, color: Colors.white38);
  }
}
