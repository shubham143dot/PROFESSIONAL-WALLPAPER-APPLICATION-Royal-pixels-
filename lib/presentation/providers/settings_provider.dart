import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/di/service_locator.dart';
import '../../core/services/adaptive_performance.dart';

class SettingsState {
  final bool isAmoledMode;
  final bool isAutoDailyWallpaper;
  final bool isLowPowerMode;

  SettingsState({
    this.isAmoledMode = false,
    this.isAutoDailyWallpaper = false,
    this.isLowPowerMode = false,
  });

  SettingsState copyWith({
    bool? isAmoledMode,
    bool? isAutoDailyWallpaper,
    bool? isLowPowerMode,
  }) {
    return SettingsState(
      isAmoledMode: isAmoledMode ?? this.isAmoledMode,
      isAutoDailyWallpaper: isAutoDailyWallpaper ?? this.isAutoDailyWallpaper,
      isLowPowerMode: isLowPowerMode ?? this.isLowPowerMode,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  final SharedPreferences _prefs;

  SettingsNotifier(this._prefs)
    : super(SettingsState(
        isAmoledMode: _prefs.getBool('amoled_mode') ?? false,
        isAutoDailyWallpaper: _prefs.getBool('auto_daily_wallpaper') ?? false,
        isLowPowerMode: _prefs.getBool('low_power_mode') ?? false,
      )) {
    // Apply initial state to AdaptivePerformance
    importAdaptivePerf();
  }

  void importAdaptivePerf() {
     // This is a helper to avoid circular dependency if any, 
     // but here we just want to call it.
     AdaptivePerformance.initialize(lowPowerMode: state.isLowPowerMode);
  }

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

  void toggleLowPowerMode() {
    final newValue = !state.isLowPowerMode;
    _prefs.setBool('low_power_mode', newValue);
    state = state.copyWith(isLowPowerMode: newValue);
    AdaptivePerformance.initialize(lowPowerMode: newValue);
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  final prefs = sl<SharedPreferences>();
  return SettingsNotifier(prefs);
});
