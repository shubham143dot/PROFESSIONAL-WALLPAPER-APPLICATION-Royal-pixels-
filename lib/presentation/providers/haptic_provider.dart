import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';
import '../../core/di/service_locator.dart';
import '../../domain/entities/haptic_level.dart';

/// Provider to check if the device supports haptic feedback/vibration.
/// Returns true if a vibrator is present and functional.
final hapticSupportProvider = FutureProvider<bool>((ref) async {
  try {
    final hasVibrator = await Vibration.hasVibrator();
    return hasVibrator == true;
  } catch (e) {
    if (kDebugMode) print('Haptic Detection Error: $e');
    return false;
  }
});

final hapticProvider = NotifierProvider<HapticNotifier, HapticLevel>(() {
  return HapticNotifier();
});

class HapticNotifier extends Notifier<HapticLevel> {
  static const _key = 'user_haptic_level';
  
  // Cache hardware capabilities for speed
  bool? _hasVibrator;
  bool? _hasCustomVibrations;
  bool? _hasAmplitudeControl;

  @override
  HapticLevel build() {
    final prefs = sl<SharedPreferences>();
    final saved = prefs.getString(_key);
    
    // Warm up the hardware cache
    _initHardwareCache();
    
    return HapticLevel.fromString(saved);
  }

  Future<void> _initHardwareCache() async {
    try {
      _hasVibrator = await Vibration.hasVibrator();
      if (_hasVibrator == true) {
        _hasCustomVibrations = await Vibration.hasCustomVibrationsSupport();
        _hasAmplitudeControl = await Vibration.hasAmplitudeControl();
      }
    } catch (_) {
      _hasVibrator = false;
    }
  }

  Future<void> setLevel(HapticLevel level) async {
    state = level;
    final prefs = sl<SharedPreferences>();
    await prefs.setString(_key, level.name);
    // Give immediate feedback when setting (Preview)
    trigger(previewLevel: level);
  }

  /// Internal method to perform physical haptic feedback with high compatibility
  Future<void> _perform(HapticLevel physicalLevel) async {
    if (physicalLevel == HapticLevel.off) return;

    try {
      // Ensure cache is ready if it's the first time
      if (_hasVibrator == null) await _initHardwareCache();
      if (_hasVibrator == false) return;

      if (Platform.isAndroid) {
        // Android-specific: Vibration package is most reliable for timed pulses
        switch (physicalLevel) {
          case HapticLevel.light:
            if (_hasCustomVibrations == true) {
              Vibration.vibrate(duration: 15, amplitude: _hasAmplitudeControl == true ? 80 : -1);
            } else {
              HapticFeedback.lightImpact();
            }
            break;
          case HapticLevel.medium:
            if (_hasCustomVibrations == true) {
              Vibration.vibrate(duration: 30, amplitude: _hasAmplitudeControl == true ? 150 : -1);
            } else {
              HapticFeedback.mediumImpact();
            }
            break;
          case HapticLevel.strong:
            if (_hasCustomVibrations == true) {
              Vibration.vibrate(duration: 50, amplitude: _hasAmplitudeControl == true ? 255 : -1);
            } else {
              HapticFeedback.heavyImpact();
            }
            break;
          case HapticLevel.off:
            break;
        }
      } else if (Platform.isIOS) {
        // iOS-specific: Taptic Engine (HapticFeedback) is vastly superior to generic vibration
        switch (physicalLevel) {
          case HapticLevel.light:
            HapticFeedback.lightImpact();
            break;
          case HapticLevel.medium:
            HapticFeedback.mediumImpact();
            break;
          case HapticLevel.strong:
            HapticFeedback.heavyImpact();
            break;
          case HapticLevel.off:
            break;
        }
      } else {
        // Fallback for other platforms
        HapticFeedback.mediumImpact();
      }
    } catch (e) {
      // Final fallback to core Flutter haptics
      HapticFeedback.selectionClick();
    }
  }

  /// Triggers haptic feedback based on current settings or a specific override.
  void trigger({HapticLevel? previewLevel}) {
    if (previewLevel != null) {
      _perform(previewLevel);
      return;
    }
    if (state == HapticLevel.off) return;
    _perform(state);
  }

  /// Semantic trigger that applies intensity distribution based on global state.
  void _triggerSemantic(HapticLevel eventIntensity) {
    if (state == HapticLevel.off) return;

    HapticLevel finalLevel;
    switch (state) {
      case HapticLevel.light:
        finalLevel = (eventIntensity == HapticLevel.strong) 
            ? HapticLevel.medium 
            : HapticLevel.light;
        break;
      case HapticLevel.medium:
        finalLevel = eventIntensity;
        break;
      case HapticLevel.strong:
        finalLevel = (eventIntensity == HapticLevel.light)
            ? HapticLevel.medium
            : HapticLevel.strong;
        break;
      case HapticLevel.off:
        return;
    }
    _perform(finalLevel);
  }

  void lightImpact() => _triggerSemantic(HapticLevel.light);
  void mediumImpact() => _triggerSemantic(HapticLevel.medium);
  void heavyImpact() => _triggerSemantic(HapticLevel.strong);
  void selectionClick() => lightImpact();
}
