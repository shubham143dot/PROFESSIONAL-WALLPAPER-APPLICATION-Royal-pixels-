import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/notification_type.dart';
import 'notification_provider.dart';

final favoritesProvider = StateNotifierProvider<FavoritesNotifier, List<String>>((ref) {
  return FavoritesNotifier(ref);
});

class FavoritesNotifier extends StateNotifier<List<String>> {
  final Ref _ref;
  static const _key = 'favorite_wallpaper_ids';

  FavoritesNotifier(this._ref) : super([]) {
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final favs = prefs.getStringList(_key) ?? [];
    state = favs;
  }

  bool _isToggling = false;
  
  Future<void> toggleFavorite(String wallpaperId) async {
    if (_isToggling) return;
    _isToggling = true;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final favs = List<String>.from(state);
      
      if (favs.contains(wallpaperId)) {
        favs.remove(wallpaperId);
      } else {
        favs.add(wallpaperId);
        // Trigger notification only when adding
        _ref.read(notificationProvider.notifier).addNotification(
          title: 'Added to Favorites',
          message: 'Wallpaper has been added to your collection.',
          type: NotificationType.reward,
        );
      }
      
      await prefs.setStringList(_key, favs);
      state = favs;
    } finally {
      _isToggling = false;
    }
  }

  bool isFavorite(String wallpaperId) {
    return state.contains(wallpaperId);
  }
}
