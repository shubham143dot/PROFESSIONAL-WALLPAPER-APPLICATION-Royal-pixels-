import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/service_locator.dart';
import '../../domain/entities/wallpaper_entity.dart';
import '../../domain/usecases/get_wallpapers_usecase.dart';
import '../../domain/usecases/delete_wallpaper_usecase.dart';
import '../../domain/usecases/update_wallpaper_usecase.dart';
import '../../data/models/wallpaper_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

final wallpaperProvider = NotifierProvider<WallpaperNotifier, WallpaperState>(() {
  return WallpaperNotifier();
});

class WallpaperState {
  final bool isLoading;
  final List<WallpaperEntity> freeWallpapers;
  final List<WallpaperEntity> premiumWallpapers;
  final String? error;

  WallpaperState({
    this.isLoading = false,
    this.freeWallpapers = const [],
    this.premiumWallpapers = const [],
    this.error,
  });

  WallpaperState copyWith({
    bool? isLoading,
    List<WallpaperEntity>? freeWallpapers,
    List<WallpaperEntity>? premiumWallpapers,
    String? error,
  }) {
    return WallpaperState(
      isLoading: isLoading ?? this.isLoading,
      freeWallpapers: freeWallpapers ?? this.freeWallpapers,
      premiumWallpapers: premiumWallpapers ?? this.premiumWallpapers,
      error: error,
    );
  }
}

class WallpaperNotifier extends Notifier<WallpaperState> {
  bool _loaded = false;
  bool _isFetching = false;

  @override
  WallpaperState build() {
    return WallpaperState();
  }

  List<WallpaperEntity> _deduplicate(List<WallpaperEntity> wallpapers) {
    // Deduplicate by Firestore document ID — NOT imageUrl.
    // Deduplicating by imageUrl caused wallpapers to silently vanish when two
    // different Firestore docs happened to share the same image (e.g. re-uploads).
    final seenIds = <String>{};
    return wallpapers.where((wp) => wp.id.isNotEmpty && seenIds.add(wp.id)).toList();
  }

  Future<void> loadWallpapers({bool forceRefresh = false}) async {
    // Prevent redundant fetches on hot-restarts / tab switches
    if ((_loaded && !forceRefresh) || _isFetching) return;
    _isFetching = true;

    // ── Pre-load from cache for "Instant" feel ──────────────────────
    if (!_loaded) {
      final cached = _loadFromCache();
      if (cached != null) {
        state = cached;
      }
    }

    state = state.copyWith(isLoading: state.freeWallpapers.isEmpty && state.premiumWallpapers.isEmpty, error: null);

    try {
      final getWallpapersUseCase = sl<GetWallpapersUseCase>();

      // ── Fetch both in parallel to cut load time in half ──────────────
      final results = await Future.wait([
        getWallpapersUseCase(GetWallpapersParams(page: 1, limit: 50, isPremium: false)),
        getWallpapersUseCase(GetWallpapersParams(page: 1, limit: 50, isPremium: true)),
      ]);

      List<WallpaperEntity> freeList = [];
      List<WallpaperEntity> premiumList = [];
      String? errorMessage;

      results[0].fold(
        (failure) => errorMessage = failure.message,
        (wallpapers) => freeList = _deduplicate(wallpapers),
      );

      results[1].fold(
        (failure) => errorMessage ??= failure.message,
        (wallpapers) => premiumList = _deduplicate(wallpapers),
      );

      _loaded = true;
      state = state.copyWith(
        isLoading: false,
        freeWallpapers: freeList,
        premiumWallpapers: premiumList,
        error: errorMessage,
      );

      // Save to cache after successful network load
      if (errorMessage == null) {
        _saveToCache(state);
      }
    } finally {
      _isFetching = false;
    }
  }

  // ── Local Caching Logic ──────────────────────────────────────────────

  static const String _kCacheKey = 'wallpaper_list_cache';

  void _saveToCache(WallpaperState data) {
    try {
      final prefs = sl<SharedPreferences>();
      final map = {
        'free': data.freeWallpapers.map((w) => (w as WallpaperModel).toJson()).toList(),
        'premium': data.premiumWallpapers.map((w) => (w as WallpaperModel).toJson()).toList(),
      };
      prefs.setString(_kCacheKey, jsonEncode(map));
    } catch (_) {
      // Silent fail for cache
    }
  }

  WallpaperState? _loadFromCache() {
    try {
      final prefs = sl<SharedPreferences>();
      final jsonStr = prefs.getString(_kCacheKey);
      if (jsonStr == null) return null;

      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      final free = (map['free'] as List).map((j) => WallpaperModel.fromJson(j)).toList();
      final premium = (map['premium'] as List).map((j) => WallpaperModel.fromJson(j)).toList();

      return WallpaperState(
        freeWallpapers: free,
        premiumWallpapers: premium,
        isLoading: false,
      );
    } catch (_) {
      return null;
    }
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
          freeWallpapers: state.freeWallpapers.where((w) => w.id != id).toList(),
          premiumWallpapers: state.premiumWallpapers.where((w) => w.id != id).toList(),
        );
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
}
