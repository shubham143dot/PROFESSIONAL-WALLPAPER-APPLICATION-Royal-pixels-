import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/service_locator.dart';
import '../../data/datasources/firestore_data_source.dart';
import '../../domain/entities/wallpaper_entity.dart';

/// Provides the top trending wallpapers, fetched lazily from Firestore.
final trendingProvider =
    AsyncNotifierProvider<TrendingNotifier, List<WallpaperEntity>>(() {
  return TrendingNotifier();
});

class TrendingNotifier extends AsyncNotifier<List<WallpaperEntity>> {
  @override
  Future<List<WallpaperEntity>> build() async {
    return _fetch();
  }

  Future<List<WallpaperEntity>> _fetch() async {
    try {
      final ds = sl<FirestoreDataSource>();
      final results = await ds.getTrendingWallpapers(limit: 30);
      // Sort by viewCount descending client-side for safety
      results.sort((a, b) => b.viewCount.compareTo(a.viewCount));
      return results;
    } catch (_) {
      return [];
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  void incrementViews(String id, {String? userId}) {
    if (state.hasValue) {
      final list = state.value!;
      state = AsyncValue.data(list
          .map((w) => w.id == id ? w.copyWith(viewCount: w.viewCount + 1) : w)
          .toList());
    }
  }

  void updateLikeCount(String id, int adjustment) {
    if (state.hasValue) {
      final list = state.value!;
      state = AsyncValue.data(list
          .map((w) => w.id == id
              ? w.copyWith(
                  likeCount: (w.likeCount + adjustment).clamp(0, 9999999))
              : w)
          .toList());
    }
  }

  void incrementShares(String id) {
    if (state.hasValue) {
      final list = state.value!;
      state = AsyncValue.data(list
          .map((w) => w.id == id ? w.copyWith(shareCount: w.shareCount + 1) : w)
          .toList());
    }
  }
}
