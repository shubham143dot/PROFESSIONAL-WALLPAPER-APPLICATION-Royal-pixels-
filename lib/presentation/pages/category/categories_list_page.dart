import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:ui';
import '../../../domain/entities/wallpaper_entity.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/wallpaper_provider.dart';
import '../../providers/category_cover_provider.dart';

class CategoriesListPage extends ConsumerWidget {
  final bool embeddedMode;
  const CategoriesListPage({super.key, this.embeddedMode = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallpaperState = ref.watch(wallpaperProvider);
    final categoryCoversAsync = ref.watch(categoryCoverProvider);
    final categoryCovers = categoryCoversAsync.value ?? {};

    final allWallpapers = [
      ...wallpaperState.freeWallpapers,
      ...wallpaperState.premiumWallpapers,
    ];

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        toolbarHeight: 56,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18.0, sigmaY: 18.0),
            child: Container(color: AppColors.bg0.withAlpha(160)),
          ),
        ),
        leading: embeddedMode
            ? null
            : IconButton(
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
      body: wallpaperState.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.goldMid))
          : _buildCategoriesList(context, allWallpapers, categoryCovers),
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
      BuildContext context, List<WallpaperEntity> allWallpapers, Map<String, String> categoryCovers) {
    if (allWallpapers.isEmpty) {
      return _buildEmptyState();
    }

    final Map<String, List<WallpaperEntity>> grouped = {};
    for (var wp in allWallpapers) {
      grouped.putIfAbsent(wp.autoCategory, () => []).add(wp);
    }
    final categories = grouped.keys.toList()..sort();

    return ListView.builder(
      padding: EdgeInsets.only(top: embeddedMode ? 88 : 100, bottom: 100),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final categoryName = categories[index];
        final wallpapers = grouped[categoryName]!;
        final wp = wallpapers.first;

        final String coverImageUrl = categoryCovers[categoryName.toLowerCase()] ?? wp.imageUrl;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              context.push('/category', extra: {
                'categoryName': categoryName,
                'wallpapers': wallpapers,
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
                      child: ClipRect(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            decoration: BoxDecoration(
                              color: AppColors.glassFill,
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
                      ),
                    ),
                  ],
                ),
              ),
            ).animate(delay: (index * 50).ms).fade(duration: 400.ms, curve: Curves.easeOut).slideY(
                begin: 0.1, end: 0, duration: 400.ms, curve: Curves.easeOutQuart),
          ),
        );
      },
    );
  }
}
