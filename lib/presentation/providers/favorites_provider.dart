import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final favoritesProvider = StateNotifierProvider<FavoritesNotifier, List<String>>((ref) {
  return FavoritesNotifier();
});

class FavoritesNotifier extends StateNotifier<List<String>> {
  static const _key = 'favorite_wallpaper_ids';

  FavoritesNotifier() : super([]) {
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final favs = prefs.getStringList(_key) ?? [];
    state = favs;
  }

  Future<void> toggleFavorite(String wallpaperId) async {
    final prefs = await SharedPreferences.getInstance();
    final favs = prefs.getStringList(_key) ?? [];
    
    if (favs.contains(wallpaperId)) {
      favs.remove(wallpaperId);
    } else {
      favs.add(wallpaperId);
    }
    
    await prefs.setStringList(_key, favs);
    state = favs;
  }

  bool isFavorite(String wallpaperId) {
    return state.contains(wallpaperId);
  }
}
