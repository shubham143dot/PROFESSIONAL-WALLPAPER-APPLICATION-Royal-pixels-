import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/service_locator.dart';
import '../../domain/entities/wallpaper_entity.dart';
import '../../domain/usecases/get_wallpapers_usecase.dart';

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
  @override
  WallpaperState build() {
    return WallpaperState();
  }

  Future<void> loadWallpapers() async {
    state = state.copyWith(isLoading: true, error: null);
    
    final getWallpapersUseCase = sl<GetWallpapersUseCase>();
    
    // Fetch Free Wallpapers
    final freeResult = await getWallpapersUseCase(GetWallpapersParams(page: 1, limit: 20, isPremium: false));
    // Fetch Premium Wallpapers
    final premiumResult = await getWallpapersUseCase(GetWallpapersParams(page: 1, limit: 20, isPremium: true));
    
    List<WallpaperEntity> freeList = [];
    List<WallpaperEntity> premiumList = [];
    String? errorMessage;

    freeResult.fold(
      (failure) => errorMessage = failure.message,
      (wallpapers) => freeList = wallpapers,
    );
    
    premiumResult.fold(
      (failure) => errorMessage = failure.message,
      (wallpapers) => premiumList = wallpapers,
    );

    state = state.copyWith(
      isLoading: false,
      freeWallpapers: freeList,
      premiumWallpapers: premiumList,
      error: errorMessage,
    );
  }
}
