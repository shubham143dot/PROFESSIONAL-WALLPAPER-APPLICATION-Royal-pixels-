import 'package:royal_pixels/core/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:ui';
import '../../../core/services/adaptive_performance.dart';
import '../../../core/constants/animation_constants.dart';
import '../../../core/utils/safe_tap.dart';
import '../../../domain/entities/wallpaper_entity.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/wallpaper_provider.dart';
import '../../providers/haptic_provider.dart';
import '../../providers/category_cover_provider.dart';

import '../../../core/scroll/elite_scroll_physics.dart';
import '../../../core/scroll/velocity_aware_controller.dart';

class CategoriesListPage extends ConsumerStatefulWidget {
  final bool embeddedMode;
  const CategoriesListPage({super.key, this.embeddedMode = false});

  @override
  ConsumerState<CategoriesListPage> createState() => _CategoriesListPageState();
}

class _CategoriesListPageState extends ConsumerState<CategoriesListPage>
    with AutomaticKeepAliveClientMixin {
  late final VelocityAwareScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = VelocityAwareScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for KeepAlive
    final wallpaperState = ref.watch(wallpaperProvider);
    final userState = ref.watch(authProvider);
    final isAdmin = userState.user?.email == 'subhamsoudeep@gmail.com';

    final grouped = ref.watch(groupedCategoriesProvider);
    final categories = grouped.keys.toList()..sort();

    final content = wallpaperState.isLoading && grouped.isEmpty
        ? const Center(child: CircularProgressIndicator(color: AppColors.goldMid))
        : wallpaperState.error != null
            ? _buildErrorState(wallpaperState.error!)
            : _buildCategoriesList(context, categories, grouped, isAdmin);

    if (widget.embeddedMode) {
      return content;
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        toolbarHeight: 56,
        flexibleSpace: RepaintBoundary(
          child: ClipRect(
            child: Builder(
              builder: (context) {
                final content = Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: AdaptivePerformance.enableBackdropBlur ? 0.04 : 0.08),
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.white.withValues(alpha: 0.12),
                        width: 0.8,
                      ),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: AdaptivePerformance.enableBackdropBlur ? 0.08 : 0.15),
                        Colors.white.withValues(alpha: AdaptivePerformance.enableBackdropBlur ? 0.01 : 0.05),
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.goldLight),
          onPressed: () => context.pop(),
        ),
        title: Stack(
          alignment: Alignment.center,
          children: [
            Text(AppLocalizations.of(context)!.categories,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: 2.5,
                fontSize: 18,
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 3
                  ..color = AppColors.goldMid.withValues(alpha: 0.25),
              ),
            ),
            ShaderMask(
              shaderCallback: (bounds) => AppColors.goldGradient.createShader(bounds),
              child: Text(AppLocalizations.of(context)!.categories,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.5,
                  color: Colors.white,
                  fontSize: 18,
                  shadows: [
                    Shadow(
                      color: AppColors.goldMid,
                      blurRadius: 12,
                    ),
                    Shadow(
                      color: AppColors.goldLight,
                      blurRadius: 25,
                    ),
                  ],
                ),
              ),
            ),
          ],
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
                child: Text(AppLocalizations.of(context)!.tryAgain, style: TextStyle(fontWeight: FontWeight.bold)),
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
          Text(AppLocalizations.of(context)!.noCategoriesYet,
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
      BuildContext context, List<String> categories, Map<String, List<WallpaperEntity>> grouped, bool isAdmin) {
    if (categories.isEmpty) {
      return _buildEmptyState();
    }

    final categoryCoversAsync = ref.watch(categoryCoverProvider);
    final categoryCovers = categoryCoversAsync.value ?? {};

    return GridView.builder(
      controller: _scrollController,
      physics: const EliteAlwaysScrollPhysics(),
      padding: EdgeInsets.only(
        top: widget.embeddedMode ? (MediaQuery.of(context).padding.top + 64) : 90, 
        bottom: MediaQuery.of(context).padding.bottom + 110,
        left: 16,
        right: 16,
      ),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, // Changed from 2 for maximum view
        childAspectRatio: 0.70, // Taller premium look for 3 columns
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: categories.length,
      cacheExtent: 1000,
      itemBuilder: (context, index) {
        final categoryName = categories[index];
        final wallpapers = grouped[categoryName]!;
        final wp = wallpapers.first;

        final String coverImageUrl = categoryCovers[categoryName.toLowerCase()] ?? wp.imageUrl;

        final card = GestureDetector(
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
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: AppColors.bg2,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(120),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: WallpaperEntity.getOptimizedCloudinaryUrl(coverImageUrl),
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(color: AppColors.bg2),
                    errorWidget: (context, url, err) => Container(color: AppColors.bg2),
                  ),
                  // Premium glassmorphic gradient overlay
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, Colors.black.withAlpha(200)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.3, 1.0],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(150),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(24),
                          bottomRight: Radius.circular(24),
                        ),
                        border: Border(
                          top: BorderSide(color: AppColors.glassBorder, width: 1.0),
                        ),
                      ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                categoryName.toUpperCase(),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.5,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.goldMid.withAlpha(40),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.goldMid.withAlpha(80), width: 0.5),
                                ),
                                child: Text(
                                  '${wallpapers.length} Wallpapers',
                                  style: const TextStyle(
                                    color: AppColors.goldMid,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (isAdmin)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: GestureDetector(
                        onTap: () {
                          ref.read(hapticProvider.notifier).lightImpact();
                          context.push('/rename-category', extra: categoryName);
                        },
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.amber.withAlpha(50),
                            border: Border.all(color: Colors.amber.withAlpha(100), width: 1),
                          ),
                          child: const Icon(
                            Icons.edit_note_rounded,
                            color: Colors.amber,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ).animate(delay: (index % 12 * AppAnimations.staggeringDelay.inMilliseconds).ms)
           .fade(duration: 600.ms, curve: Curves.easeOut)
           .slideY(
               begin: AppAnimations.cardSlideOffset,
               end: 0,
               duration: AppAnimations.smoothEntrance,
               curve: AppAnimations.easeOutExpo),
        );

        return RepaintBoundary(child: card);
      },
    );
  }
}
