import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui';
import 'package:photo_manager/photo_manager.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/download_provider.dart';
import '../../providers/wallpaper_provider.dart';
import '../../providers/likes_provider.dart';
import '../../providers/haptic_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../widgets/wallpaper_card.dart';
import '../../widgets/diamond_loader.dart';
import '../../../core/utils/safe_tap.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/animation_constants.dart';
import '../../../core/scroll/velocity_aware_controller.dart';
import '../../../core/scroll/elite_scroll_physics.dart';
import '../../../core/services/adaptive_performance.dart';

class MyWallpapersPage extends ConsumerStatefulWidget {
  final bool embeddedMode;
  final bool showFavoritesOnly;
  const MyWallpapersPage({super.key, this.embeddedMode = false, this.showFavoritesOnly = false});

  @override
  ConsumerState<MyWallpapersPage> createState() => _MyWallpapersPageState();
}

class _MyWallpapersPageState extends ConsumerState<MyWallpapersPage>
    with AutomaticKeepAliveClientMixin {
  late final VelocityAwareScrollController _scrollController;
  @override
  bool get wantKeepAlive => true;

  bool _showFavorites = false;

  @override
  void initState() {
    super.initState();
    _scrollController = VelocityAwareScrollController();
    // Lock to favorites view when embedded in the Favorites tab
    _showFavorites = widget.showFavoritesOnly;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Trigger refresh of downloads from SharedPreferences
      ref.read(downloadProvider.notifier).loadDownloads();

      // Trigger wallpaper loading once when the page opens, not reactively in build.
      final state = ref.read(wallpaperProvider);
      final hasNoData = state.freeWallpapers.isEmpty && state.premiumWallpapers.isEmpty;
      if (hasNoData && !state.isLoading) {
        ref.read(wallpaperProvider.notifier).loadWallpapers();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Shows a confirmation sheet and removes the wallpaper from favorites.
  Future<void> _removeFromFavorites(String wallpaperId, String wallpaperTitle) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.pinkAccent.withAlpha(30),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.heart_broken_rounded,
                color: Colors.pinkAccent,
                size: 30,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Remove from Favorites',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Remove "$wallpaperTitle" from your favorites?',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white60, fontSize: 14),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pinkAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Remove',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      ref.read(likesNotifierProvider.notifier).toggleLike(wallpaperId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.heart_broken_rounded,
                    color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '"$wallpaperTitle" removed from favorites',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF2A2A2A),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// Shows a confirmation sheet and removes the wallpaper ID from SharedPreferences.
  Future<void> _deleteWallpaper(String wallpaperId, String wallpaperTitle) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.red.withAlpha(30),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.redAccent,
                size: 30,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Remove Wallpaper',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Remove "$wallpaperTitle" from your saved wallpapers?',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white60, fontSize: 14),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Remove',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      // â”€â”€ 1. Delete from device gallery (MediaStore) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
      await _deleteFromGallery(wallpaperId);

      // â”€â”€ 2. Remove from global state â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
      ref.read(downloadProvider.notifier).removeDownload(wallpaperId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline,
                    color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '"$wallpaperTitle" deleted from device',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF2A2A2A),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// Finds the gallery asset whose filename starts with 'royal_pixel_{wallpaperId}'
  /// and permanently deletes it from the device gallery via photo_manager.
  Future<void> _deleteFromGallery(String wallpaperId) async {
    try {
      // Request gallery permission (read + write needed to delete)
      final PermissionState ps =
          await PhotoManager.requestPermissionExtend();
      if (!ps.hasAccess) return;

      // The filename the Gal package used when saving:
      // Gal.putImageBytes(bytes, name: 'rp_$id.jpg')
      final String targetPrefix = 'rp_$wallpaperId';

      // Search recent images (last 500) in the gallery
      final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        filterOption: FilterOptionGroup(
          imageOption: const FilterOption(needTitle: true),
          orders: [const OrderOption(type: OrderOptionType.createDate, asc: false)],
        ),
      );

      for (final album in albums) {
        final int count = await album.assetCountAsync;
        final List<AssetEntity> assets =
            await album.getAssetListRange(start: 0, end: count.clamp(0, 500));

        for (final asset in assets) {
          final String title = await asset.titleAsync;
          if (title.startsWith(targetPrefix)) {
            // Delete permanently from device
            await PhotoManager.editor.deleteWithIds([asset.id]);
            return; // Done â€” file found and deleted
          }
        }
      }
    } catch (_) {
      // Silently ignore: if we can't delete from gallery, we still
      // remove the ID from SharedPreferences so the UI stays clean.
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for KeepAlive
    final wallpaperState = ref.watch(wallpaperProvider);
    final myIds = ref.watch(downloadProvider);
    final targetIds = _showFavorites ? ref.watch(likesProvider) : myIds;

    final content = (targetIds.isEmpty)
        ? _buildEmptyState()
        : (wallpaperState.isLoading)
            ? const Center(child: DiamondLoader())
            : () {
                // Get all wallpapers loaded in the provider
                final allWallpapers = [
                  ...wallpaperState.freeWallpapers,
                  ...wallpaperState.premiumWallpapers,
                ];

                // Match saved IDs against loaded wallpapers
                final myWallpapers =
                    allWallpapers.where((w) => targetIds.contains(w.id)).toList();

                // Loaded but no match found (e.g. wallpapers deleted from DB)
                if (myWallpapers.isEmpty) {
                  return _buildEmptyState();
                }

                return CustomScrollView(
                  controller: _scrollController,
                  physics: const EliteAlwaysScrollPhysics(),
                  cacheExtent: 1500, // Pre-render buffer for smoother scroll
                  slivers: [
                    if (widget.embeddedMode)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 70, 20, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _showFavorites ? 'ROYAL FAVORITES' : 'SAVED COLLECTION',
                                style: TextStyle(
                                  color: AppColors.goldMid,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2.0,
                                  shadows: [
                                    Shadow(
                                      color: AppColors.goldMid.withOpacity(0.5),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                              ).animate().fade(duration: 400.ms).slideX(begin: -0.1),
                              const SizedBox(height: 8),
                              Text(
                                '${myWallpapers.length} Wallpapers',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                ),
                              ).animate(delay: 100.ms).fade(duration: 400.ms).slideX(begin: -0.1),
                            ],
                          ),
                        ),
                      ),
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        16, 
                        widget.embeddedMode ? 0 : 20, 
                        16, 
                        widget.embeddedMode ? (MediaQuery.of(context).padding.bottom + 110) : 20
                      ),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3, // Changed from 2 for maximum view
                          childAspectRatio: 0.56, // Adjusted for 3-column look
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final wp = myWallpapers[index];
                            final card = Stack(
                              children: [
                                Positioned.fill(
                                  child: WallpaperCard(
                                    wallpaper: wp,
                                    scrollController: _scrollController,
                                    onTap: () => context.push('/detail', extra: wp),
                                  ),
                                ),
                                Positioned(
                                  top: 10,
                                  right: 10,
                                  child: GestureDetector(
                                    onTap: () {
                                      SafeTap.run('my_wp_action_${wp.id}', () {
                                        ref.read(hapticProvider.notifier).lightImpact();
                                        if (_showFavorites) {
                                          _removeFromFavorites(wp.id, wp.title);
                                        } else {
                                          _deleteWallpaper(wp.id, wp.title);
                                        }
                                      });
                                    },
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(20),
                                      child: Builder(
                                        builder: (context) {
                                          final content = Container(
                                            width: 36,
                                            height: 36,
                                            decoration: BoxDecoration(
                                              color: Colors.black.withAlpha(AdaptivePerformance.enableBackdropBlur ? 90 : 200),
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: _showFavorites
                                                    ? Colors.pinkAccent.withAlpha(120)
                                                    : Colors.white24,
                                                width: 1.0,
                                              ),
                                            ),
                                            child: Icon(
                                              _showFavorites
                                                  ? Icons.favorite
                                                  : Icons.delete_outline_rounded,
                                              color: _showFavorites
                                                  ? Colors.pinkAccent
                                                  : Colors.white,
                                              size: 18,
                                            ),
                                          );
                                          return AdaptivePerformance.enableBackdropBlur
                                              ? BackdropFilter(
                                                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                                                  child: content,
                                                )
                                              : content;
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                            
                            return RepaintBoundary(
                              child: card.animate(delay: (index % 12 * AppAnimations.staggeringDelay.inMilliseconds).ms)
                                .fade(duration: 600.ms, curve: Curves.easeOut)
                                .slideY(
                                    begin: AppAnimations.cardSlideOffset,
                                    end: 0,
                                    duration: AppAnimations.smoothEntrance,
                                    curve: AppAnimations.easeOutExpo),
                            );
                          },
                          childCount: myWallpapers.length,
                        ),
                      ),
                    ),
                  ],
                );
              }();

    if (widget.embeddedMode) {
      return Container(
        color: const Color(0xFF121212),
        child: content,
      );
    }

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: RepaintBoundary(
          child: ClipRect(
            child: Builder(
              builder: (context) {
                final content = Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(AdaptivePerformance.enableBackdropBlur ? 0.04 : 0.08),
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.white.withOpacity(0.12),
                        width: 0.8,
                      ),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withOpacity(AdaptivePerformance.enableBackdropBlur ? 0.08 : 0.15),
                        Colors.white.withOpacity(AdaptivePerformance.enableBackdropBlur ? 0.01 : 0.05),
                      ],
                    ),
                  ),
                );
                return AdaptivePerformance.enableBackdropBlur
                    ? BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 25.0, sigmaY: 25.0),
                        child: content,
                      )
                    : content;
              },
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.goldLight),
          onPressed: () => context.pop(),
        ),
        title: Text(
          _showFavorites ? 'Favorite Wallpapers' : 'My Wallpapers',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
          ),
        ),
        actions: [
          if (!widget.showFavoritesOnly)
            IconButton(
              icon: Icon(
                _showFavorites ? Icons.favorite : Icons.favorite_border,
                color: Colors.amber,
              ),
              onPressed: () {
                SafeTap.run('toggle_fav_view', () {
                  setState(() => _showFavorites = !_showFavorites);
                });
              },
            ),
        ],
      ),
      body: content,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.goldMid.withAlpha(20),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.goldMid.withAlpha(10),
                  blurRadius: 40,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: Icon(
              _showFavorites ? Icons.favorite_border_rounded : Icons.cloud_download_outlined, 
              size: 54, 
              color: AppColors.goldMid
            ),
          ).animate().scale(delay: 200.ms, duration: 600.ms, curve: Curves.easeOutBack)
           .fadeIn(duration: 600.ms),
          const SizedBox(height: 32),
          Text(
            _showFavorites ? 'No Favorites Yet' : 'No Saved Wallpapers',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ).animate().slideY(begin: 0.5, duration: 500.ms, curve: Curves.easeOutQuart)
           .fadeIn(duration: 500.ms),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              _showFavorites 
                ? 'Start curating your royal collection by hearting your favorite wallpapers.'
                : 'Your downloaded wallpapers will appear here for quick access.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white54, 
                fontSize: 15,
                height: 1.5,
              ),
            ),
          ).animate(delay: 100.ms).slideY(begin: 0.5, duration: 500.ms, curve: Curves.easeOutQuart)
           .fadeIn(duration: 500.ms),
          const SizedBox(height: 40),
          GestureDetector(
            onTap: () {
              ref.read(hapticProvider.notifier).lightImpact();
              
              if (widget.embeddedMode) {
                // Navigate back to Home tab (index 0)
                ref.read(navigationProvider.notifier).goToHome();
              } else {
                context.pop();
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.goldMid, AppColors.goldDeep],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.goldMid.withAlpha(80),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Text(
                'Explore Now',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ).animate(delay: 200.ms).slideY(begin: 0.5, duration: 500.ms, curve: Curves.easeOutQuart)
           .fadeIn(duration: 500.ms),
        ],
      ),
    );
  }
}
