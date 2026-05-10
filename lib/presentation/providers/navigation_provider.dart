import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Manages the active tab index for the main navigation (HomePage).
/// 0: Home, 1: Feeds, 2: Explore, 3: Favorites, 4: Saved, 5: Profile
final navigationProvider = StateNotifierProvider<NavigationNotifier, int>((ref) {
  return NavigationNotifier();
});

class NavigationNotifier extends StateNotifier<int> {
  NavigationNotifier() : super(0);

  void setIndex(int index) {
    if (state != index) state = index;
  }

  void goToHome() => state = 0;
  
  void goToFeeds({String? wallpaperId, WidgetRef? ref}) {
    if (wallpaperId != null && ref != null) {
      ref.read(feedTargetWallpaperProvider.notifier).state = wallpaperId;
    }
    state = 1;
  }
  
  void goToExplore() => state = 2;
  void goToFavorites() => state = 3;
  void goToSaved() => state = 4;
  void goToProfile() => state = 5;
}

/// Stores the ID of a wallpaper to jump to when navigating to the Feeds tab.
final feedTargetWallpaperProvider = StateProvider<String?>((ref) => null);

