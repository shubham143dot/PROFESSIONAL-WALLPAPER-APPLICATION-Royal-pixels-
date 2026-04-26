import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/di/service_locator.dart';

class SettingsState {
  final bool isAmoledMode;
  final bool isAutoDailyWallpaper;

  SettingsState({
    this.isAmoledMode = false,
    this.isAutoDailyWallpaper = false,
  });

  SettingsState copyWith({
    bool? isAmoledMode,
    bool? isAutoDailyWallpaper,
  }) {
    return SettingsState(
      isAmoledMode: isAmoledMode ?? this.isAmoledMode,
      isAutoDailyWallpaper: isAutoDailyWallpaper ?? this.isAutoDailyWallpaper,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  final SharedPreferences _prefs;

  SettingsNotifier(this._prefs)
      : super(SettingsState(
          isAmoledMode: _prefs.getBool('amoled_mode') ?? false,
          isAutoDailyWallpaper: _prefs.getBool('auto_daily_wallpaper') ?? false,
        ));

  void toggleAmoledMode() {
    final newValue = !state.isAmoledMode;
    _prefs.setBool('amoled_mode', newValue);
    state = state.copyWith(isAmoledMode: newValue);
  }

  void toggleAutoDailyWallpaper() {
    final newValue = !state.isAutoDailyWallpaper;
    _prefs.setBool('auto_daily_wallpaper', newValue);
    state = state.copyWith(isAutoDailyWallpaper: newValue);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  final prefs = sl<SharedPreferences>();
  return SettingsNotifier(prefs);
});
