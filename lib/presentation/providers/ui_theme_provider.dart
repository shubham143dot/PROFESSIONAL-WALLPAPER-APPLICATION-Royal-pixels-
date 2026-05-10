import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'wallpaper_provider.dart';
import 'trending_provider.dart';
import '../../core/services/palette_service.dart';
import '../../core/theme/app_colors.dart';

/// Provider that extracts a signature UI color from the most prominent wallpaper.
/// This color is used for premium glow effects on the AppBar and BottomNav.
final uiThemeColorProvider = FutureProvider<Color>((ref) async {
  // First try to get it from trending wallpapers
  final trendingAsync = ref.watch(trendingProvider);
  final wallpaperState = ref.watch(wallpaperProvider);
  final paletteService = ref.read(paletteServiceProvider);

  String? targetUrl;

  trendingAsync.whenData((trending) {
    if (trending.isNotEmpty) {
      targetUrl = trending.first.optimizedUrl;
    }
  });

  if (targetUrl == null) {
    // Fallback to the first regular wallpaper
    if (wallpaperState.freeWallpapers.isNotEmpty) {
      targetUrl = wallpaperState.freeWallpapers.first.optimizedUrl;
    } else if (wallpaperState.premiumWallpapers.isNotEmpty) {
      targetUrl = wallpaperState.premiumWallpapers.first.optimizedUrl;
    }
  }

  if (targetUrl != null) {
    return await paletteService.getDominantColor(targetUrl!);
  }

  return AppColors.goldMid; // Global brand fallback
});
