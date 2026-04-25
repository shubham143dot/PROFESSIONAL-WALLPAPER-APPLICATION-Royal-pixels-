import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:ui';
import '../../../core/constants/animation_constants.dart';
import '../../../core/utils/safe_tap.dart';
import '../../../domain/entities/wallpaper_entity.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/wallpaper_provider.dart';
import '../../providers/haptic_provider.dart';
import '../../providers/category_cover_provider.dart';

class CategoriesListPage extends ConsumerStatefulWidget {
  final bool embeddedMode;
  const CategoriesListPage({super.key, this.embeddedMode = false});

  @override
  ConsumerState<CategoriesListPage> createState() => _CategoriesListPageState();
}

class _CategoriesListPageState extends ConsumerState<CategoriesListPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for KeepAlive
    final wallpaperState = ref.watch(wallpaperProvider);
    final userState = ref.watch(authProvider);
    final isAdmin = userState.user?.email == 'subhamsoudeep@gmail.com';
    final categoryCoversAsync = ref.watch(categoryCoverProvider);
    final categoryCovers = categoryCoversAsync.value ?? {};

    final allWallpapers = [
      ...wallpaperState.freeWallpapers,
      ...wallpaperState.premiumWallpapers,
    ];

    final content = wallpaperState.isLoading
        ? const Center(child: CircularProgressIndicator(color: AppColors.goldMid))
        : wallpaperState.error != null
            ? _buildErrorState(wallpaperState.error!)
            : _buildCategoriesList(context, allWallpapers, categoryCovers, isAdmin);

    if (widget.embeddedMode) {
      return content;
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        toolbarHeight: 56,
        flexibleSpace: RepaintBoundary(
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18.0, sigmaY: 18.0),
              child: Container(color: AppColors.bg0.withAlpha(160)),
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.goldLight),
          onPressed: () => context.pop(),
        ),
        title: ShaderMask(
          shaderCallback: (bounds) => AppColors.goldGradient.createShader(bounds),
          child: const Text(
            'CATEGORIES',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              letterSpacing: 2.0,
              color: Colors.white,
              fontSize: 20,
            ),
          ),
        ),
      ),
      body: content,
    );
  }

  Widget _buildErrorState(String message) {
    bool isPermissionDenied = message.contains('permission-denied');

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 72, color: Colors.redAccent),
            const SizedBox(height: 24),
            Text(
              isPermissionDenied ? 'Access Denied' : 'Something went wrong',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isPermissionDenied
                  ? 'It looks like you don\'t have permission to view this content. Please make sure you are logged in or contact support.'
                  : message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            if (isPermissionDenied) ...[
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  // Option to retry or redirect to login
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.goldMid,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Try Again', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.category_outlined, size: 72, color: Colors.white10),
          const SizedBox(height: 16),
          const Text(
            'No categories yet',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ).animate().fade(duration: 500.ms).scale(begin: const Offset(0.9, 0.9), duration: 500.ms),
    );
  }

  Widget _buildCategoriesList(
      BuildContext context, List<WallpaperEntity> allWallpapers, Map<String, String> categoryCovers, bool isAdmin) {
    if (allWallpapers.isEmpty) {
      return _buildEmptyState();
    }

    final Map<String, List<WallpaperEntity>> grouped = {};
    for (var wp in allWallpapers) {
      grouped.putIfAbsent(wp.autoCategory, () => []).add(wp);
    }
    final categories = grouped.keys.toList()..sort();

    return ListView.builder(
      padding: EdgeInsets.only(
        top: widget.embeddedMode ? (MediaQuery.of(context).padding.top + 64) : 90, 
        bottom: MediaQuery.of(context).padding.bottom + 80
      ),
      itemCount: categories.length,
      cacheExtent: 1000,
      addRepaintBoundaries: true,
      itemBuilder: (context, index) {
        final categoryName = categories[index];
        final wallpapers = grouped[categoryName]!;
        final wp = wallpapers.first;

        final String coverImageUrl = categoryCovers[categoryName.toLowerCase()] ?? wp.imageUrl;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          child: GestureDetector(
            onTap: () {
              SafeTap.run('category_$categoryName', () {
                ref.read(hapticProvider.notifier).lightImpact();
                context.push('/category', extra: {
                  'categoryName': categoryName,
                  'wallpapers': wallpapers,
                });
              });
            },
            child: Container(
              height: 220,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                color: AppColors.bg2,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(90),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: WallpaperEntity.getOptimizedCloudinaryUrl(coverImageUrl),
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(color: AppColors.bg2),
                      errorWidget: (context, url, err) => Container(color: AppColors.bg2),
                    ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.transparent, Color(0xCC000000)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: [0.45, 1.0],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        decoration: BoxDecoration(
                          // Using a high-opacity background instead of Blur.
                          // This looks very similar but is much smoother when scrolling.
                          color: Colors.black.withAlpha(210),
                          border: Border(
                            top: BorderSide(color: AppColors.glassBorder, width: 1.0),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  categoryName.toUpperCase(),
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 2.5,
                                    height: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${wallpapers.length} Wallpapers',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                              if (isAdmin)
                                GestureDetector(
                                  onTap: () {
                                    ref.read(hapticProvider.notifier).lightImpact();
                                    context.push('/rename-category', extra: categoryName);
                                  },
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    margin: const EdgeInsets.only(right: 8),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.amber.withAlpha(30),
                                      border: Border.all(color: Colors.amber.withAlpha(80), width: 1),
                                    ),
                                    child: const Icon(
                                      Icons.edit_note_rounded,
                                      color: Colors.amber,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.goldMid.withAlpha(30),
                                  border: Border.all(color: AppColors.goldMid.withAlpha(80), width: 1),
                                ),
                                child: const Icon(
                                  Icons.arrow_forward_rounded,
                                  color: AppColors.goldLight,
                                  size: 16,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ).animate(delay: (index * AppAnimations.staggeringDelay.inMilliseconds).ms)
            .fade(duration: 600.ms, curve: Curves.easeOut)
            .slideY(
                begin: AppAnimations.cardSlideOffset,
                end: 0,
                duration: AppAnimations.smoothEntrance,
                curve: AppAnimations.easeOutExpo),
          ),
        );
      },
    );
  }
}
