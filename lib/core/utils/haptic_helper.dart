import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';
import '../../domain/entities/haptic_level.dart';

/// Lightweight cross-platform Haptic Helper for immediate zero-latency tactile feedback.
/// Fully synchronized with [HapticLevel] user settings and [hapticProvider].
class HapticHelper {
  HapticHelper._();

  static const String _storageKey = 'user_haptic_level';
  static HapticLevel _level = HapticLevel.medium;
  static DateTime _lastVibrateTime = DateTime.fromMillisecondsSinceEpoch(0);

  // Cached hardware flags
  static bool? _hasVibrator;
  static bool? _hasCustomVibrations;
  static bool? _hasAmplitudeControl;

  /// Whether haptics are enabled (false when user selects [HapticLevel.off])
  static bool get enabled => _level != HapticLevel.off;

  static set enabled(bool value) {
    if (!value) {
      _level = HapticLevel.off;
    } else if (_level == HapticLevel.off) {
      _level = HapticLevel.medium;
    }
  }

  /// Current active haptic level
  static HapticLevel get currentLevel => _level;

  /// Update the active level (called by [HapticNotifier] or UI)
  static void setLevel(HapticLevel level) {
    _level = level;
  }

  /// Synchronize cached hardware capabilities
  static void updateHardwareCapabilities({
    bool? hasVibrator,
    bool? hasCustomVibrations,
    bool? hasAmplitudeControl,
  }) {
    _hasVibrator = hasVibrator;
    _hasCustomVibrations = hasCustomVibrations;
    _hasAmplitudeControl = hasAmplitudeControl;
  }

  /// Initialize from SharedPreferences at startup
  static void init([SharedPreferences? prefs]) {
    try {
      if (prefs != null) {
        final saved = prefs.getString(_storageKey);
        _level = HapticLevel.fromString(saved);
      }
    } catch (_) {}
  }

  /// Perform physical vibration according to level and hardware support.
  /// Throttled to 35ms minimum separation to avoid queue lag.
  static Future<void> perform(HapticLevel physicalLevel) async {
    if (_level == HapticLevel.off || physicalLevel == HapticLevel.off) return;

    final now = DateTime.now();
    if (now.difference(_lastVibrateTime).inMilliseconds < 35) return;
    _lastVibrateTime = now;

    try {
      if (kIsWeb) return;
      if (_hasVibrator == false) return;

      switch (physicalLevel) {
        case HapticLevel.light:
          await HapticFeedback.selectionClick();
          break;
        case HapticLevel.medium:
          await HapticFeedback.mediumImpact();
          break;
        case HapticLevel.strong:
          if (!kIsWeb && Platform.isAndroid && _hasCustomVibrations == true) {
            Vibration.vibrate(
              duration: 40,
              amplitude: _hasAmplitudeControl == true ? 255 : -1,
            );
          } else {
            await HapticFeedback.heavyImpact();
          }
          break;
        case HapticLevel.off:
          break;
      }
    } catch (_) {
      try {
        await HapticFeedback.selectionClick();
      } catch (_) {}
    }
  }

  /// Semantic trigger that modulates event intensity according to the user's selected level
  static void triggerSemantic(HapticLevel eventIntensity) {
    if (_level == HapticLevel.off) return;

    HapticLevel finalLevel;
    if (_level == HapticLevel.medium) {
      finalLevel = eventIntensity;
    } else if (_level == HapticLevel.light) {
      if (eventIntensity == HapticLevel.strong) {
        finalLevel = HapticLevel.medium;
      } else {
        finalLevel = HapticLevel.light;
      }
    } else { // _level == HapticLevel.strong
      if (eventIntensity == HapticLevel.light) {
        finalLevel = HapticLevel.medium;
      } else {
        finalLevel = HapticLevel.strong;
      }
    }

    perform(finalLevel);
  }

  /// Trigger haptic directly corresponding to an explicit [HapticLevel]
  static void triggerLevel(HapticLevel targetLevel) {
    if (_level == HapticLevel.off || targetLevel == HapticLevel.off) return;
    triggerSemantic(targetLevel);
  }

  static void lightImpact() => triggerSemantic(HapticLevel.light);
  static void mediumImpact() => triggerSemantic(HapticLevel.medium);
  static void heavyImpact() => triggerSemantic(HapticLevel.strong);
  static void selectionClick() => lightImpact();
  static void success() => heavyImpact();
}
