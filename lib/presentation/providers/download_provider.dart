import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final downloadProvider =
    StateNotifierProvider<DownloadNotifier, List<String>>((ref) {
  return DownloadNotifier();
});

class DownloadNotifier extends StateNotifier<List<String>> {
  static const _key = 'downloaded_wallpaper_ids';

  DownloadNotifier() : super([]) {
    loadDownloads();
  }

  Future<void> loadDownloads() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_key) ?? [];
    state = ids;
  }

  Future<void> addDownload(String wallpaperId) async {
    if (state.contains(wallpaperId)) return;

    final prefs = await SharedPreferences.getInstance();
    final ids = List<String>.from(state);
    ids.add(wallpaperId);

    await prefs.setStringList(_key, ids);
    state = ids;
  }

  Future<void> removeDownload(String wallpaperId) async {
    if (!state.contains(wallpaperId)) return;

    final prefs = await SharedPreferences.getInstance();
    final ids = List<String>.from(state);
    ids.remove(wallpaperId);

    await prefs.setStringList(_key, ids);
    state = ids;
  }

  bool isDownloaded(String wallpaperId) {
    return state.contains(wallpaperId);
  }
}
