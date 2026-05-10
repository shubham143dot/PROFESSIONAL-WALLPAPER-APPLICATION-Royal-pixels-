import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'trending_provider.dart';
import '../../core/di/service_locator.dart';
import '../../core/services/adaptive_performance.dart';

import '../../domain/entities/wallpaper_entity.dart';
import '../../domain/usecases/get_wallpapers_usecase.dart';
import '../../domain/usecases/delete_wallpaper_usecase.dart';
import '../../domain/usecases/update_wallpaper_usecase.dart';
import '../../domain/repositories/wallpaper_repository.dart';
import '../../data/models/wallpaper_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:isolate';
import 'dart:convert';

final wallpaperProvider =
    NotifierProvider<WallpaperNotifier, WallpaperState>(() {
  return WallpaperNotifier();
});

class WallpaperState {
  final bool isLoading;
  final bool isLoadingMore;
  final List<WallpaperEntity> freeWallpapers;
  final List<WallpaperEntity> premiumWallpapers;
  final String? error;
  final int sessionSeed;
  final int freePage;
  final int premiumPage;
  final bool hasMoreFree;
  final bool hasMorePremium;

  WallpaperState({
    this.isLoading = false,
    this.isLoadingMore = false,
    this.freeWallpapers = const [],
    this.premiumWallpapers = const [],
    this.error,
    int? sessionSeed,
    this.freePage = 1,
    this.premiumPage = 1,
    this.hasMoreFree = true,
    this.hasMorePremium = true,
  }) : sessionSeed = sessionSeed ?? (DateTime.now().millisecondsSinceEpoch % 1000000);

  WallpaperState copyWith({
    bool? isLoading,
    bool? isLoadingMore,
    List<WallpaperEntity>? freeWallpapers,
    List<WallpaperEntity>? premiumWallpapers,
    String? error,
    int? sessionSeed,
    int? freePage,
    int? premiumPage,
    bool? hasMoreFree,
    bool? hasMorePremium,
  }) {
    return WallpaperState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      freeWallpapers: freeWallpapers ?? this.freeWallpapers,
      premiumWallpapers: premiumWallpapers ?? this.premiumWallpapers,
      error: error,
      sessionSeed: sessionSeed ?? this.sessionSeed,
      freePage: freePage ?? this.freePage,
      premiumPage: premiumPage ?? this.premiumPage,
      hasMoreFree: hasMoreFree ?? this.hasMoreFree,
      hasMorePremium: hasMorePremium ?? this.hasMorePremium,
    );
  }
}

class WallpaperNotifier extends Notifier<WallpaperState> {
  bool _loaded = false;
  bool _isFetching = false;
  DateTime? _lastFetchTime;

  /// Cache TTL — stale after 10 minutes, auto-refresh on next access.
  static const Duration _cacheTTL = Duration(minutes: 10);

  @override
  WallpaperState build() {
    return WallpaperState();
  }

  // ── Deduplication ─────────────────────────────────────────────────────────
  List<WallpaperEntity> _deduplicate(List<WallpaperEntity> wallpapers) {
    final seenIds = <String>{};
    return wallpapers.where((wp) {
      if (wp.id.isEmpty) return true;
      return seenIds.add(wp.id);
    }).toList();
  }

  // ── URL Validation — skip wallpapers with empty/broken URLs ───────────────
  List<WallpaperEntity> _validateUrls(List<WallpaperEntity> wallpapers) {
    return wallpapers.where((wp) => wp.imageUrl.isNotEmpty).toList();
  }

  // ── Main Load Method ──────────────────────────────────────────────────────
  Future<void> loadWallpapers({bool forceRefresh = false}) async {
    // Skip if already fetching
    if (_isFetching) return;

    // Skip if loaded, not forced, and cache is still fresh
    if (_loaded && !forceRefresh && !_isCacheExpired()) return;

    _isFetching = true;

    // ── Pre-load from cache for "Instant" feel (first load only) ─────────
    if (!_loaded) {
      final cached = _loadFromCache();
      if (cached != null) {
        state = cached;
      }
    }

    state = state.copyWith(
      isLoading:
          state.freeWallpapers.isEmpty && state.premiumWallpapers.isEmpty,
      error: null,
      freePage: 1,
      premiumPage: 1,
      hasMoreFree: true,
      hasMorePremium: true,
    );

    try {
      final newState = await _fetchPage(page: 1);
      _loaded = true;
      _lastFetchTime = DateTime.now();
      state = newState;
      _saveToCache(state);
    } catch (e) {
      // If we have existing data, keep it visible — only show error on empty
      if (state.freeWallpapers.isEmpty && state.premiumWallpapers.isEmpty) {
        state = state.copyWith(isLoading: false, error: e.toString());
      } else {
        state = state.copyWith(isLoading: false);
      }
    } finally {
      _isFetching = false;
    }
  }

  /// Loads the next page of wallpapers for a specific type.
  Future<void> loadMoreWallpapers({required bool isPremium}) async {
    if (_isFetching || state.isLoadingMore) return;
    if (isPremium && !state.hasMorePremium) return;
    if (!isPremium && !state.hasMoreFree) return;

    state = state.copyWith(isLoadingMore: true);
    
    try {
      final page = isPremium ? state.premiumPage + 1 : state.freePage + 1;
      final pageSize = _getPageSize();
      
      final getWallpapersUseCase = sl<GetWallpapersUseCase>();
      final result = await getWallpapersUseCase(
          GetWallpapersParams(page: page, limit: pageSize, isPremium: isPremium));

      result.fold(
        (failure) {
          state = state.copyWith(isLoadingMore: false, error: failure.message);
        },
        (wallpapers) {
          final validated = _validateUrls(_deduplicate(wallpapers));
          final hasMore = validated.length >= pageSize;

          if (isPremium) {
            state = state.copyWith(
              isLoadingMore: false,
              premiumWallpapers: [...state.premiumWallpapers, ...validated],
              premiumPage: page,
              hasMorePremium: hasMore,
            );
          } else {
            state = state.copyWith(
              isLoadingMore: false,
              freeWallpapers: [...state.freeWallpapers, ...validated],
              freePage: page,
              hasMoreFree: hasMore,
            );
          }
        },
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, error: e.toString());
    }
  }

  int _getPageSize() {
    // Phase 10: Increased limits to ensure all 228 wallpapers are loaded instantly
    // and support for 1000+ items as requested.
    if (AdaptivePerformance.isLow) return 300; 
    return 1000;
  }

  bool _isCacheExpired() {
    if (_lastFetchTime == null) return true;
    return DateTime.now().difference(_lastFetchTime!) > _cacheTTL;
  }

  // ── Fetch single page logic ────────────────────────────────────────────────
  Future<WallpaperState> _fetchPage({required int page}) async {
    final pageSize = _getPageSize();
    final getWallpapersUseCase = sl<GetWallpapersUseCase>();

    final results = await Future.wait([
      getWallpapersUseCase(
          GetWallpapersParams(page: page, limit: pageSize, isPremium: false)),
      getWallpapersUseCase(
          GetWallpapersParams(page: page, limit: pageSize, isPremium: true)),
    ]);

    List<WallpaperEntity> freeList = [];
    List<WallpaperEntity> premiumList = [];
    String? errorMessage;

    results[0].fold(
      (failure) => errorMessage = failure.message,
      (wallpapers) => freeList = _validateUrls(_deduplicate(wallpapers)),
    );

    results[1].fold(
      (failure) => errorMessage ??= failure.message,
      (wallpapers) => premiumList = _validateUrls(_deduplicate(wallpapers)),
    );

    if (freeList.isEmpty && premiumList.isEmpty && errorMessage != null) {
      throw Exception(errorMessage);
    }

    return state.copyWith(
      isLoading: false,
      freeWallpapers: freeList,
      premiumWallpapers: premiumList,
      error: errorMessage,
      freePage: page,
      premiumPage: page,
      hasMoreFree: freeList.length >= pageSize,
      hasMorePremium: premiumList.length >= pageSize,
    );
  }

  // ── Local Caching Logic ──────────────────────────────────────────────────

  static const String _kCacheKey = 'wallpaper_list_cache';
  static const String _kCacheTimeKey = 'wallpaper_cache_time';

  /// Serializes cache data in a background isolate so the UI thread
  /// never blocks on jsonEncode of hundreds of wallpapers.
  void _saveToCache(WallpaperState data) {
    // Fire-and-forget: serialize on background isolate, then persist.
    Isolate.run(() {
      return jsonEncode({
        'free': data.freeWallpapers
            .map((w) => (w as WallpaperModel).toJson())
            .toList(),
        'premium': data.premiumWallpapers
            .map((w) => (w as WallpaperModel).toJson())
            .toList(),
      });
    }).then((encoded) {
      try {
        final prefs = sl<SharedPreferences>();
        prefs.setString(_kCacheKey, encoded);
        prefs.setString(_kCacheTimeKey, DateTime.now().toIso8601String());
      } catch (_) {}
    }).catchError((_) {});
  }

  WallpaperState? _loadFromCache() {
    try {
      final prefs = sl<SharedPreferences>();

      // Check cache TTL before using cached data
      final cacheTimeStr = prefs.getString(_kCacheTimeKey);
      if (cacheTimeStr != null) {
        final cacheTime = DateTime.tryParse(cacheTimeStr);
        if (cacheTime != null) {
          _lastFetchTime = cacheTime;
          if (DateTime.now().difference(cacheTime) > _cacheTTL) {
            // Cache expired — don't use it
            prefs.remove(_kCacheKey);
            prefs.remove(_kCacheTimeKey);
            return null;
          }
        }
      }

      final jsonStr = prefs.getString(_kCacheKey);
      if (jsonStr == null) return null;

      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      final free = (map['free'] as List)
          .map((j) => WallpaperModel.fromJson(j))
          .where((w) => w.imageUrl.isNotEmpty) // URL validation on cache too
          .toList();
      final premium = (map['premium'] as List)
          .map((j) => WallpaperModel.fromJson(j))
          .where((w) => w.imageUrl.isNotEmpty)
          .toList();

      return WallpaperState(
        freeWallpapers: free,
        premiumWallpapers: premium,
        isLoading: false,
      );
    } catch (_) {
      return null;
    }
  }

  /// Clears all cached wallpaper data.
  void clearCache() {
    try {
      final prefs = sl<SharedPreferences>();
      prefs.remove(_kCacheKey);
      prefs.remove(_kCacheTimeKey);
    } catch (_) {}
  }

  // ── Optimistic Insert — Instantly show a newly uploaded wallpaper ─────
  /// Called right after a successful admin upload. Inserts the wallpaper into
  /// the local state so it appears in the UI immediately, without waiting for
  /// a full Firestore re-fetch. Also updates the cache.
  void addWallpaperLocally(WallpaperEntity wallpaper) {
    if (wallpaper.imageUrl.isEmpty) return; // Guard: don't add broken entries
    if (wallpaper.isPremium) {
      state = state.copyWith(
        premiumWallpapers: [wallpaper, ...state.premiumWallpapers],
      );
    } else {
      state = state.copyWith(
        freeWallpapers: [wallpaper, ...state.freeWallpapers],
      );
    }
    // Persist to cache so it survives hot-restart
    _saveToCache(state);
  }

  Future<void> deleteWallpaper(String id) async {
    final usecase = sl<DeleteWallpaperUseCase>();
    final result = await usecase(id);
    result.fold(
      (failure) {
        // Option to handle error or set state.error
      },
      (_) {
        state = state.copyWith(
          freeWallpapers:
              state.freeWallpapers.where((w) => w.id != id).toList(),
          premiumWallpapers:
              state.premiumWallpapers.where((w) => w.id != id).toList(),
        );
        _saveToCache(state);
      },
    );
  }

  Future<void> updateWallpaper(
    String id, {
    required String newTitle,
    required String newCategory,
    required bool isPremium,
    required int diamondCost,
    required List<String> tags,
  }) async {
    final usecase = sl<UpdateWallpaperUseCase>();
    final result = await usecase(
      id,
      newTitle: newTitle,
      newCategory: newCategory,
      isPremium: isPremium,
      diamondCost: diamondCost,
      tags: tags,
    );
    result.fold(
      (failure) {
        state = state.copyWith(error: failure.message);
      },
      (_) {
        // Build updated entity
        WallpaperEntity? updated;

        // First look in free list
        final freeIdx = state.freeWallpapers.indexWhere((w) => w.id == id);
        if (freeIdx != -1) {
          updated = state.freeWallpapers[freeIdx].copyWith(
            title: newTitle,
            category: newCategory,
            isPremium: isPremium,
            diamondCost: diamondCost,
            tags: tags,
          );
        }

        // Otherwise look in premium list
        final premIdx = state.premiumWallpapers.indexWhere((w) => w.id == id);
        if (premIdx != -1) {
          updated = state.premiumWallpapers[premIdx].copyWith(
            title: newTitle,
            category: newCategory,
            isPremium: isPremium,
            diamondCost: diamondCost,
            tags: tags,
          );
        }

        if (updated == null) return; // not in state yet — ignore

        // ── Seamlessly migrate between free/premium lists ──────────────
        List<WallpaperEntity> newFree = List.from(state.freeWallpapers);
        List<WallpaperEntity> newPremium = List.from(state.premiumWallpapers);

        // Remove from both (it will be added to the correct list below)
        newFree.removeWhere((w) => w.id == id);
        newPremium.removeWhere((w) => w.id == id);

        if (isPremium) {
          newPremium.insert(premIdx != -1 ? premIdx : 0, updated);
        } else {
          newFree.insert(freeIdx != -1 ? freeIdx : 0, updated);
        }

        state = state.copyWith(
          freeWallpapers: newFree,
          premiumWallpapers: newPremium,
          error: null,
        );
      },
    );
  }

  void incrementViews(String id, {String? userId}) {
    final repo = sl<WallpaperRepository>();
    repo.incrementViewCount(id, userId: userId); // Fire and forget for remote

    // Targeted update: only rebuild the single card that changed
    // (avoids full list map() which triggers full grid recomposition)
    final freeIdx = state.freeWallpapers.indexWhere((w) => w.id == id);
    if (freeIdx != -1) {
      final updated = List<WallpaperEntity>.from(state.freeWallpapers);
      updated[freeIdx] =
          updated[freeIdx].copyWith(viewCount: updated[freeIdx].viewCount + 1);
      state = state.copyWith(freeWallpapers: updated);
      return;
    }
    final premIdx = state.premiumWallpapers.indexWhere((w) => w.id == id);
    if (premIdx != -1) {
      final updated = List<WallpaperEntity>.from(state.premiumWallpapers);
      updated[premIdx] =
          updated[premIdx].copyWith(viewCount: updated[premIdx].viewCount + 1);
      state = state.copyWith(premiumWallpapers: updated);
    }
  }

  void incrementLikesLocally(String id, int adjustment) {
    // Targeted update: only rebuild the single card that changed
    final freeIdx = state.freeWallpapers.indexWhere((w) => w.id == id);
    if (freeIdx != -1) {
      final updated = List<WallpaperEntity>.from(state.freeWallpapers);
      updated[freeIdx] = updated[freeIdx].copyWith(
        likeCount: (updated[freeIdx].likeCount + adjustment).clamp(0, 9999999),
      );
      state = state.copyWith(freeWallpapers: updated);
      return;
    }
    final premIdx = state.premiumWallpapers.indexWhere((w) => w.id == id);
    if (premIdx != -1) {
      final updated = List<WallpaperEntity>.from(state.premiumWallpapers);
      updated[premIdx] = updated[premIdx].copyWith(
        likeCount: (updated[premIdx].likeCount + adjustment).clamp(0, 9999999),
      );
      state = state.copyWith(premiumWallpapers: updated);
    }
  }

  void incrementShares(String id) {
    final repo = sl<WallpaperRepository>();
    repo.incrementShareCount(id);

    // Targeted update: only rebuild the single card that changed
    final freeIdx = state.freeWallpapers.indexWhere((w) => w.id == id);
    if (freeIdx != -1) {
      final updated = List<WallpaperEntity>.from(state.freeWallpapers);
      updated[freeIdx] = updated[freeIdx]
          .copyWith(shareCount: updated[freeIdx].shareCount + 1);
      state = state.copyWith(freeWallpapers: updated);
      return;
    }
    final premIdx = state.premiumWallpapers.indexWhere((w) => w.id == id);
    if (premIdx != -1) {
      final updated = List<WallpaperEntity>.from(state.premiumWallpapers);
      updated[premIdx] = updated[premIdx]
          .copyWith(shareCount: updated[premIdx].shareCount + 1);
      state = state.copyWith(premiumWallpapers: updated);
    }
  }

  void shuffleSessionSeed() {
    state = state.copyWith(
      sessionSeed: DateTime.now().millisecondsSinceEpoch % 1000000,
    );
  }
}

/// Stable provider for the Social Feed.
/// This Notifier ensures the list order remains persistent (no reshuffling)
/// during a session, even when view counts or likes update.
final feedWallpapersProvider = NotifierProvider<FeedNotifier, List<WallpaperEntity>>(() {
  return FeedNotifier();
});

class FeedNotifier extends Notifier<List<WallpaperEntity>> {
  List<WallpaperEntity> _shuffledOthers = [];
  String _lastBaseIds = '';

  @override
  List<WallpaperEntity> build() {
    // Only rebuild the full list order if the IDs of wallpapers change.
    // We watch the counts/lists but we handle the stabilization manually.
    final wallpaperState = ref.watch(wallpaperProvider);
    final trendingAsync = ref.watch(trendingProvider);

    return trendingAsync.maybeWhen(
      data: (trending) {
        final List<WallpaperEntity> allAvailable = [];
        final Set<String> seenIds = {};

        // Collect all wallpapers (trending, free, premium)
        for (final wp in trending) {
          if (wp.id.isNotEmpty && seenIds.add(wp.id)) {
            allAvailable.add(wp);
          }
        }

        for (final wp in wallpaperState.freeWallpapers) {
          if (wp.id.isNotEmpty && seenIds.add(wp.id)) allAvailable.add(wp);
        }
        for (final wp in wallpaperState.premiumWallpapers) {
          if (wp.id.isNotEmpty && seenIds.add(wp.id)) allAvailable.add(wp);
        }

        // Stabilization Logic
        // We only reshuffle if the base set of IDs has changed.
        // This prevents the feed from jumping around when counts update.
        final currentIdsString = allAvailable.map((e) => e.id).join(',');
        
        if (currentIdsString != _lastBaseIds) {
          _lastBaseIds = currentIdsString;
          _shuffledOthers = List.from(allAvailable)..shuffle();
        } else {
          // Optimization: Only update the entities in our shuffled list 
          // if they actually changed in the source state.
          final newIdMap = {for (var wp in allAvailable) wp.id: wp};
          for (int i = 0; i < _shuffledOthers.length; i++) {
            final oldWp = _shuffledOthers[i];
            final newWp = newIdMap[oldWp.id];
            if (newWp != null && !identical(oldWp, newWp)) {
              _shuffledOthers[i] = newWp;
            }
          }
        }

        return List<WallpaperEntity>.from(_shuffledOthers);
      },
      orElse: () => [],
    );
  }

  void refresh() {
    _lastBaseIds = '';
    // Also trigger a session seed update if possible to affect other randomized lists
    ref.read(wallpaperProvider.notifier).shuffleSessionSeed();
    state = build();
  }
}

// ─── Specialized Performance-Optimized Providers ──────────────────────────────

/// Specialized provider for grouped categories.
/// Memoizes the category mapping to avoid expensive grouping loops in UI build().
/// Ensures 90/120Hz scroll throughput even with 1000+ wallpapers.
final groupedCategoriesProvider = Provider<Map<String, List<WallpaperEntity>>>((ref) {
  final state = ref.watch(wallpaperProvider);
  final all = [...state.freeWallpapers, ...state.premiumWallpapers];
  
  if (all.isEmpty) return const {};
  
  final Map<String, List<WallpaperEntity>> grouped = {};
  for (var wp in all) {
    // Use the intelligent auto-categorization algorithm
    final category = wp.autoCategory;
    grouped.putIfAbsent(category, () => []).add(wp);
  }
  return grouped;
});

/// Specialized provider for filtered wallpaper lists (Favorites/Saved).
/// Deduplicates and stabilizes the list for smooth grid rendering.
final filteredWallpapersProvider = Provider.family<List<WallpaperEntity>, Set<String>>((ref, targetIds) {
  final state = ref.watch(wallpaperProvider);
  final all = [...state.freeWallpapers, ...state.premiumWallpapers];
  
  if (targetIds.isEmpty) return const [];
  
  return all.where((w) => targetIds.contains(w.id)).toList();
});

/// Optimized provider for the Live Feed (Chronological).
final liveWallpapersProvider = Provider<List<WallpaperEntity>>((ref) {
  final state = ref.watch(wallpaperProvider);
  final all = [...state.freeWallpapers, ...state.premiumWallpapers];
  if (all.isEmpty) return const [];
  
  // Sort by date descending
  return List<WallpaperEntity>.from(all)
    ..sort((a, b) => (b.createdAt ?? DateTime(2000)).compareTo(a.createdAt ?? DateTime(2000)));
});

/// Specialized provider for Home screen filtered lists.
final homeFilteredWallpapersProvider = Provider.family<List<WallpaperEntity>, dynamic>((ref, filter) {
  final state = ref.watch(wallpaperProvider);
  final all = [...state.freeWallpapers, ...state.premiumWallpapers];
  
  if (all.isEmpty) return const [];

  List<WallpaperEntity> filtered = all;
  final filterName = filter.toString();
  
  if (filterName.contains('free')) {
    filtered = state.freeWallpapers;
  } else if (filterName.contains('premium')) {
    filtered = state.premiumWallpapers;
  } else if (filterName.contains('editorsChoice')) {
    filtered = all.where((wp) => wp.isEditorsChoice).toList();
  } else if (filterName.contains('ultraHD')) {
    filtered = all.where((wp) => wp.isUltraHD).toList();
  } else if (filterName.contains('newlyAdded')) {
    final now = DateTime.now();
    filtered = all.where((wp) => wp.createdAt != null && now.difference(wp.createdAt!).inHours <= 24).toList();
    if (filtered.isEmpty) {
      filtered = List<WallpaperEntity>.from(all)
        ..sort((a, b) => (b.createdAt ?? DateTime(2000)).compareTo(a.createdAt ?? DateTime(2000)));
    }
  }

  if (!filterName.contains('newlyAdded') && filtered.isNotEmpty) {
    // Phase 8 optimization: Removed shuffle() here because it breaks pagination stability.
    // With pagination, we want a stable sort order (e.g. CreatedAt) so items don't
    // jump around when the next page is appended.
    return filtered;
  }

  return filtered;
});
