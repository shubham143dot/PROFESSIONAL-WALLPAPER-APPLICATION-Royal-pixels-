import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/wallpaper_entity.dart';
import 'wallpaper_provider.dart';

/// Provides wallpapers for the Discover / explore screen.
///
/// Uses a stable shuffle seed so the order doesn't jump around when
/// wallpaper state updates (e.g. like counts, view counts change).
/// The shuffle only produces a new order when the seed is regenerated
/// (app restart) or when the set of wallpapers changes length.
final discoverSeedProvider = StateProvider<int>(
  (ref) => DateTime.now().millisecondsSinceEpoch,
);

void refreshDiscoverSeed(WidgetRef ref) {
  ref.read(discoverSeedProvider.notifier).state = DateTime.now().millisecondsSinceEpoch;
}

final discoverWallpapersProvider = Provider<List<WallpaperEntity>>((ref) {
  final wallpaperState = ref.watch(wallpaperProvider);
  final all = [
    ...wallpaperState.freeWallpapers,
    ...wallpaperState.premiumWallpapers
  ];

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

  // 3. Take the rest and shuffle with a STABLE seed
  //    Same seed → same order, so wallpapers don't jump around
  //    when like/view counts update in state.
  final seed = ref.watch(discoverSeedProvider);
  final rest = sorted.skip(newCount).toList()..shuffle(Random(seed));

  // Combine: New uploads first, then shuffled rest
  return [...newest, ...rest];
});
