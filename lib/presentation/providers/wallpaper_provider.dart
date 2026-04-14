import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/service_locator.dart';
import '../../domain/entities/wallpaper_entity.dart';
import '../../domain/usecases/get_wallpapers_usecase.dart';
import '../../domain/usecases/delete_wallpaper_usecase.dart';
import '../../domain/usecases/update_wallpaper_usecase.dart';

final wallpaperProvider = NotifierProvider<WallpaperNotifier, WallpaperState>(() {
  return WallpaperNotifier();
});

class WallpaperState {
  final bool isLoading;
  final List<WallpaperEntity> freeWallpapers;
  final List<WallpaperEntity> premiumWallpapers;
  final String? error;

  List<WallpaperEntity> get specialWallpapers {
    final all = [...freeWallpapers, ...premiumWallpapers];
    return all.where((wp) {
      final isCategorySpecial = wp.category.toLowerCase() == 'special' ||
          wp.autoCategory.toLowerCase() == 'special';
      final hasSpecialTag =
          wp.tags.any((t) => t.toLowerCase() == 'special');
      return isCategorySpecial || hasSpecialTag;
    }).toList();
  }

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

  @override
  WallpaperState build() {
    return WallpaperState();
  }

  List<WallpaperEntity> _deduplicate(List<WallpaperEntity> wallpapers) {
    final seenUrls = <String>{};
    return wallpapers.where((wp) => seenUrls.add(wp.imageUrl)).toList();
  }

  Future<void> loadWallpapers({bool forceRefresh = false}) async {
    // Prevent redundant fetches on hot-restarts / tab switches
    if (_loaded && !forceRefresh) return;

    state = state.copyWith(isLoading: true, error: null);

    final getWallpapersUseCase = sl<GetWallpapersUseCase>();

    // ── Fetch both in parallel to cut load time in half ──────────────
    final results = await Future.wait([
      getWallpapersUseCase(GetWallpapersParams(page: 1, limit: 30, isPremium: false)),
      getWallpapersUseCase(GetWallpapersParams(page: 1, limit: 30, isPremium: true)),
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

  Future<void> updateWallpaper(String id, String newTitle, String newCategory) async {
    final usecase = sl<UpdateWallpaperUseCase>();
    final result = await usecase(id, newTitle, newCategory);
    result.fold(
      (failure) {
        // Can handle the error if necessary
      },
      (_) {
        state = state.copyWith(
          freeWallpapers: state.freeWallpapers.map((w) {
            if (w.id == id) {
              return w.copyWith(title: newTitle, category: newCategory);
            }
            return w;
          }).toList(),
          premiumWallpapers: state.premiumWallpapers.map((w) {
            if (w.id == id) {
              return w.copyWith(title: newTitle, category: newCategory);
            }
            return w;
          }).toList(),
        );
      },
    );
  }
}
