import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui';
import 'dart:math';
import '../../../domain/entities/wallpaper_entity.dart';
import '../../providers/wallpaper_provider.dart';
import '../../providers/trending_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/safe_tap.dart';
import '../../providers/likes_provider.dart';
import '../../providers/auth_provider.dart';
import '../../../core/utils/royal_snack_bar.dart';


class SocialFeedPage extends ConsumerStatefulWidget {
  final String? initialWallpaperId;
  const SocialFeedPage({super.key, this.initialWallpaperId});

  @override
  ConsumerState<SocialFeedPage> createState() => _SocialFeedPageState();
}

class _SocialFeedPageState extends ConsumerState<SocialFeedPage> {
  PageController? _pageController;
  bool _initialIncrementDone = false;
  List<String>? _cachedOtherIds;
  final Set<String> _viewedIds = {};

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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(100),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ShaderMask(
                shaderCallback: (bounds) => AppColors.trendingGradient.createShader(bounds),
                child: const Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 8),
              Text(
                'ROYAL FEED',
                style: TextStyle(
                  color: Colors.white.withAlpha(230),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: 800.ms).slideY(begin: -0.5);
  }

  Widget _buildBody(WallpaperState state) {
    final trendingAsync = ref.watch(trendingProvider);

    return trendingAsync.when(
      data: (trendingWallpapers) {
        // ── Combine and Deduplicate ─────────────────────────────────────
        final List<WallpaperEntity> allWallpapers = [];
        final Set<String> seenIds = {};

        // 1. Add trending wallpapers first (these will have a rank)
        // Sync each trending wallpaper with the main state if it exists there
        for (final wp in trendingWallpapers) {
          WallpaperEntity syncedWp = wp;
          
          // Try to find the latest version in the main state
          final inFree = state.freeWallpapers.where((w) => w.id == wp.id);
          if (inFree.isNotEmpty) {
            syncedWp = inFree.first;
          } else {
            final inPrem = state.premiumWallpapers.where((w) => w.id == wp.id);
            if (inPrem.isNotEmpty) {
              syncedWp = inPrem.first;
            }
          }

          if (syncedWp.id.isEmpty || seenIds.add(syncedWp.id)) {
            allWallpapers.add(syncedWp);
          }
        }
        
        final int trendingCount = allWallpapers.length;

        // 2. Collect all other wallpapers
        final List<WallpaperEntity> others = [];
        for (final wp in state.freeWallpapers) {
          if (!seenIds.contains(wp.id)) {
            others.add(wp);
          }
        }
        for (final wp in state.premiumWallpapers) {
          if (!seenIds.contains(wp.id)) {
            others.add(wp);
          }
        }
        
        // Cache the shuffled order to prevent reshuffling on every rebuild (e.g. when liking)
        if (_cachedOtherIds == null) {
          final toShuffle = others.map((e) => e.id).toList();
          toShuffle.shuffle(Random());
          _cachedOtherIds = toShuffle;
        } else {
          // Stable append: Find IDs in 'others' that aren't in '_cachedOtherIds' yet
          final currentIds = _cachedOtherIds!.toSet();
          final newIds = others
              .map((w) => w.id)
              .where((id) => !currentIds.contains(id))
              .toList();
          
          if (newIds.isNotEmpty) {
            _cachedOtherIds = [..._cachedOtherIds!, ...newIds];
          }
        }

        final Map<String, WallpaperEntity> othersMap = { for (var w in others) w.id: w };
        for (final id in _cachedOtherIds!) {
          if (othersMap.containsKey(id)) {
            allWallpapers.add(othersMap[id]!);
          }
        }

        // Initialize PageController with correct initial page
        if (_pageController == null) {
          int initialPage = 0;
          if (widget.initialWallpaperId != null) {
            final idx = allWallpapers.indexWhere((w) => w.id == widget.initialWallpaperId);
            if (idx != -1) {
              initialPage = idx;
            }
          }
          _pageController = PageController(initialPage: initialPage);
        }

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
          return const Center(
            child: Text(
              'No wallpapers found',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
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
            }
          },
          itemBuilder: (context, index) {
            final wp = allWallpapers[index];
            // Only assign rank to the actual trending wallpapers at the top
            final int? displayRank = index < trendingCount ? index + 1 : null;
            
            return WallpaperReelCard(
              wallpaper: wp, 
              rank: displayRank,
            );
          },
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.goldMid),
      ),
      error: (err, _) => Center(
        child: Text(
          'Error loading reel: $err',
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}

class WallpaperReelCard extends ConsumerWidget {
  final WallpaperEntity wallpaper;
  final int? rank;

  const WallpaperReelCard({super.key, required this.wallpaper, this.rank});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    
    return Stack(
      fit: StackFit.expand,
      children: [
        // Full screen background image (Optimized for speed)
        CachedNetworkImage(
          imageUrl: wallpaper.optimizedUrl,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            color: AppColors.bg0,
            child: const Center(
              child: CircularProgressIndicator(
                color: AppColors.goldMid, 
                strokeWidth: 2
              ),
            ),
          ),
          errorWidget: (context, url, error) => const Icon(Icons.error, color: Colors.white54),
        ),

        // Multi-stop gradient for premium feel and text legibility
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

        // Content
        Positioned(
          bottom: 40 + bottomPadding,
          left: 20,
          right: 85,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Premium Title
              Text(
                wallpaper.title,
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
              ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.2, curve: Curves.easeOutExpo),
              
              const SizedBox(height: 12),
              
              // Tags with Glassmorphism
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (rank != null)
                    _buildGlassTag('#$rank', color: const Color(0xFFFF6B00), isGold: true),

                  if (wallpaper.isPremium) 
                    _buildGlassTag('PREMIUM', color: AppColors.goldMid, isGold: true)
                  else
                    _buildGlassTag('FREE', color: Colors.greenAccent, isGold: false),
                  
                  if (wallpaper.isUltraHD)
                    _buildGlassTag('4K', color: const Color(0xFF22D3EE)),
                  if (wallpaper.isEditorsChoice)
                    _buildGlassTag('EDITOR\'S PICK', color: const Color(0xFFFBBF24)),
                ],
              ).animate().fadeIn(delay: 300.ms, duration: 600.ms),
              
              const SizedBox(height: 20),
              
              // Creator Info
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24, width: 1),
                    ),
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: Colors.white.withAlpha(20),
                      child: const Icon(Icons.person, size: 18, color: Colors.white70),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '@royal_creator',
                    style: TextStyle(
                      color: Colors.white.withAlpha(200),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ).animate().fadeIn(delay: 500.ms),
            ],
          ),
        ),

        // Side Actions
        Positioned(
          right: 15,
          bottom: 100 + bottomPadding,
          child: Column(
            children: [
              Consumer(
                builder: (context, ref, _) {
                  final likedIds = ref.watch(feedLikesProvider);
                  final isLiked = likedIds.contains(wallpaper.id);
                  
                  return _buildActionButton(
                    Icons.favorite_rounded, 
                    _formatCount(wallpaper.likeCount),
                    onTap: () {
                      // Decoupled: Liking in feed does not add to favorites
                      ref.read(likesNotifierProvider.notifier).toggleLike(wallpaper.id, isFavorite: false);
                      if (!isLiked) {
                        RoyalSnackBar.show(context, 'Liked!', type: SnackBarType.info);
                      }
                    },
                    color: isLiked ? Colors.pink : Colors.grey,
                  );
                },
              ),
              _buildActionButton(
                Icons.remove_red_eye_rounded, 
                _formatCount(wallpaper.viewCount),
                color: Colors.white,
              ),
              const SizedBox(height: 24),
              _buildMainActionButton(context),
            ],
          ).animate().fadeIn(delay: 400.ms).slideX(begin: 0.5),
        ),
      ],
    );
  }
  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  Widget _buildGlassTag(String text, {Color? color, bool isGold = false}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: (color ?? Colors.white).withAlpha(isGold ? 40 : 25),
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
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, {VoidCallback? onTap, Color? color}) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withAlpha(40),
              ),
              child: Icon(icon, color: color ?? Colors.white, size: 28),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainActionButton(BuildContext context) {
    return GestureDetector(
      onTap: () => SafeTap.run('reel_action_${wallpaper.id}', () => context.push('/detail', extra: wallpaper)),
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
    ).animate(onPlay: (controller) => controller.repeat())
     .shimmer(duration: 2.seconds, color: Colors.white38);
  }
}
