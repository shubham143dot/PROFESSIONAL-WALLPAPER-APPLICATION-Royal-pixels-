import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/animation_constants.dart';
import '../../../domain/entities/wallpaper_entity.dart';
import '../../widgets/wallpaper_card.dart';
import '../../widgets/wallpaper_long_press_preview.dart';
import '../../providers/auth_provider.dart';
import '../../providers/haptic_provider.dart';
import '../../../core/services/adaptive_performance.dart';

class CategoryPage extends ConsumerWidget {
  final String categoryName;
  final List<WallpaperEntity> wallpapers;

  const CategoryPage({
    super.key,
    required this.categoryName,
    required this.wallpapers,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userState = ref.watch(authProvider);
    final isAdmin = userState.user?.email == 'subhamsoudeep@gmail.com';

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
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
        title: Text(
          categoryName,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: BackButton(
          onPressed: () => context.pop(),
          color: AppColors.goldLight,
        ),
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.edit_note_rounded, color: Colors.amber),
              onPressed: () {
                ref.read(hapticProvider.notifier).lightImpact();
                context.push('/rename-category', extra: categoryName);
              },
            ),
        ],
      ),
      body: wallpapers.isEmpty 
          ? const Center(child: Text('No Wallpapers Found', style: TextStyle(color: Colors.white)))
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.56,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: wallpapers.length,
              // Phase 8 optimization: Adaptive cacheExtent for Category Grid
              cacheExtent: AdaptivePerformance.isHigh ? 1200 : (AdaptivePerformance.isLow ? 250 : 500),
              addRepaintBoundaries: true,
              itemBuilder: (context, index) {
                final wp = wallpapers[index];
                return WallpaperCard(
                  key: ValueKey(wp.id),
                  wallpaper: wp,
                  onTap: () => context.push('/detail', extra: wp),
                  onLongPress: () => showWallpaperLongPressPreview(context, wp),
                )
                    .animate(delay: (index * AppAnimations.staggeringDelay.inMilliseconds).ms)
                    .fade(duration: 600.ms, curve: Curves.easeOut)
                    .slideY(
                        begin: AppAnimations.cardSlideOffset,
                        end: 0,
                        duration: AppAnimations.smoothEntrance,
                        curve: AppAnimations.easeOutExpo);
              },
            ),
    );
  }
}
