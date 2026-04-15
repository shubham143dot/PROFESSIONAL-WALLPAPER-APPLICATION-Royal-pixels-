import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/wallpaper_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../widgets/wallpaper_card.dart';
import '../../widgets/diamond_loader.dart';

/// Provider that loads the list of downloaded wallpaper IDs from SharedPreferences.
final myWallpaperIdsProvider = FutureProvider<List<String>>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getStringList('downloaded_wallpaper_ids') ?? [];
});

class MyWallpapersPage extends ConsumerStatefulWidget {
  final bool embeddedMode;
  final bool showFavoritesOnly;
  const MyWallpapersPage({super.key, this.embeddedMode = false, this.showFavoritesOnly = false});

  @override
  ConsumerState<MyWallpapersPage> createState() => _MyWallpapersPageState();
}

class _MyWallpapersPageState extends ConsumerState<MyWallpapersPage> {
  bool _showFavorites = false;

  @override
  void initState() {
    super.initState();
    // Lock to favorites view when embedded in the Favorites tab
    _showFavorites = widget.showFavoritesOnly;
    Future.microtask(() {
      // Always re-read SharedPreferences so newly downloaded wallpapers appear
      // immediately without requiring an app restart.
      ref.invalidate(myWallpaperIdsProvider);

      // Trigger wallpaper loading once when the page opens, not reactively in build.
      final state = ref.read(wallpaperProvider);
      final hasNoData = state.freeWallpapers.isEmpty && state.premiumWallpapers.isEmpty;
      if (hasNoData && !state.isLoading) {
        ref.read(wallpaperProvider.notifier).loadWallpapers();
      }
    });
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
      ref.read(favoritesProvider.notifier).toggleFavorite(wallpaperId);
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
      // ── 1. Delete from device gallery (MediaStore) ──────────────────────────
      await _deleteFromGallery(wallpaperId);

      // ── 2. Remove from SharedPreferences ─────────────────────────────────
      final prefs = await SharedPreferences.getInstance();
      final ids = prefs.getStringList('downloaded_wallpaper_ids') ?? [];
      ids.remove(wallpaperId);
      await prefs.setStringList('downloaded_wallpaper_ids', ids);

      // ── 3. Refresh the list UI ────────────────────────────────────────────
      ref.invalidate(myWallpaperIdsProvider);

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
            return; // Done — file found and deleted
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
    final wallpaperState = ref.watch(wallpaperProvider);
    final myIdsAsync = ref.watch(myWallpaperIdsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        leading: widget.embeddedMode
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => context.pop(),
              ),
        title: Text(
          _showFavorites ? 'Favorite Wallpapers' : 'My Wallpapers',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          // Only show the toggle when NOT locked to favorites-only mode
          if (!widget.showFavoritesOnly)
          IconButton(
            icon: Icon(
              _showFavorites ? Icons.favorite : Icons.favorite_border,
              color: Colors.amber,
            ),
            onPressed: () {
              setState(() => _showFavorites = !_showFavorites);
            },
          ),
        ],
      ),
      body: myIdsAsync.when(
        loading: () =>
            const Center(child: DiamondLoader()),
        error: (e, _) => Center(
          child: Text('Error: $e', style: const TextStyle(color: Colors.white)),
        ),
        data: (myIds) {
          final targetIds = _showFavorites ? ref.watch(favoritesProvider) : myIds;

          if (targetIds.isEmpty) {
            return _buildEmptyState();
          }

          // Still loading wallpapers from Firestore — show spinner once
          if (wallpaperState.isLoading) {
            return const Center(
              child: DiamondLoader(),
            );
          }

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

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    Icon(
                      _showFavorites ? Icons.favorite : Icons.download_done,
                      color: Colors.amber, 
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${myWallpapers.length} wallpaper${myWallpapers.length != 1 ? 's' : ''} ${_showFavorites ? 'favorited' : 'saved'}',
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: EdgeInsets.fromLTRB(12, 12, 12, widget.embeddedMode ? 100 : 12),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.65,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: myWallpapers.length,
                  itemBuilder: (context, index) {
                    final wp = myWallpapers[index];
                    return Stack(
                      children: [
                        // Full-size wallpaper card
                        Positioned.fill(
                          child: WallpaperCard(
                            wallpaper: wp,
                            onTap: () => context.push('/detail', extra: wp),
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: () {
                              if (_showFavorites) {
                                _removeFromFavorites(wp.id, wp.title);
                              } else {
                                _deleteWallpaper(wp.id, wp.title);
                              }
                            },
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: Colors.black.withAlpha(160),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _showFavorites
                                      ? Colors.pinkAccent.withAlpha(180)
                                      : Colors.redAccent.withAlpha(180),
                                  width: 1.2,
                                ),
                              ),
                              child: Icon(
                                _showFavorites
                                    ? Icons.heart_broken_rounded
                                    : Icons.delete_outline_rounded,
                                color: _showFavorites
                                    ? Colors.pinkAccent
                                    : Colors.redAccent,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.amber.withAlpha(25),
              shape: BoxShape.circle,
            ),
            child: Icon(_showFavorites ? Icons.favorite_border : Icons.download, size: 48, color: Colors.amber),
          ),
          const SizedBox(height: 24),
          Text(
            _showFavorites ? 'No Favorites Yet' : 'No Saved Wallpapers',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              _showFavorites 
                ? 'Tap the heart icon on any wallpaper to add it to your favorites.'
                : 'Download a wallpaper from the home screen and it will appear here.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}
