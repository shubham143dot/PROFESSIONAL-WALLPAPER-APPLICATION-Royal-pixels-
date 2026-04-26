import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/wallpaper_entity.dart';
import 'wallpaper_provider.dart';

final discoverWallpapersProvider = Provider<List<WallpaperEntity>>((ref) {
  final wallpaperState = ref.watch(wallpaperProvider);
  final all = [...wallpaperState.freeWallpapers, ...wallpaperState.premiumWallpapers];
  
  if (all.isEmpty) return [];

  // 1. Sort by newest first to identify candidates for "New Uploads"
  final sorted = [...all]..sort((a, b) {
    final dateA = a.createdAt ?? DateTime(2000);
    final dateB = b.createdAt ?? DateTime(2000);
    return dateB.compareTo(dateA);
  });

  // 2. Take top 12 as "New Uploads" to show at the start
  final newCount = sorted.length > 12 ? 12 : sorted.length;
  final newest = sorted.take(newCount).toList();
  
  // 3. Take the rest and shuffle them
  final rest = sorted.skip(newCount).toList()..shuffle();
  
  // Combine: New uploads first, then shuffled rest
  return [...newest, ...rest];
});
