import 'dart:io';
import 'dart:async';
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
    if (kIsWeb) return false;
    // On most modern mobile devices, haptics are supported.
    // Vibration.hasVibrator() is the source of truth but we'll fallback to true on iOS
    // because all supported iOS devices since iPhone 7 have Taptic Engine.
    if (Platform.isIOS) return true;
    
    final hasVibrator = await Vibration.hasVibrator();
    return hasVibrator == true;
  } catch (e) {
    if (kDebugMode) print('Haptic Detection Error: $e');
    return true; // Optimistic fallback
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
  Completer<void>? _initCompleter;

  @override
  HapticLevel build() {
    final prefs = sl<SharedPreferences>();
    final saved = prefs.getString(_key);

    // Warm up the hardware cache immediately
    _initHardwareCache();

    return HapticLevel.fromString(saved);
  }

  Future<void> _initHardwareCache() async {
    if (_initCompleter != null) return _initCompleter!.future;
    _initCompleter = Completer<void>();

    try {
      if (kIsWeb) {
        _hasVibrator = false;
      } else {
        _hasVibrator = await Vibration.hasVibrator();
        if (_hasVibrator == true) {
          _hasCustomVibrations = await Vibration.hasCustomVibrationsSupport();
          _hasAmplitudeControl = await Vibration.hasAmplitudeControl();
        }
      }
    } catch (_) {
      _hasVibrator = true; // Optimistic fallback for standard haptics
    } finally {
      _initCompleter!.complete();
    }
  }

  Future<void> setLevel(HapticLevel level) async {
    if (state == level) return;
    state = level;
    
    // Give immediate feedback when setting (Preview)
    trigger(previewLevel: level);

    // Persist in background
    final prefs = sl<SharedPreferences>();
    prefs.setString(_key, level.name);
  }

  // Throttle physical vibration to once per 35ms to prevent hardware queue lag
  // 35ms is optimized for fast taps (up to 28 taps per second)
  DateTime _lastVibrateTime = DateTime.fromMillisecondsSinceEpoch(0);

  /// Internal method to perform physical haptic feedback with high compatibility
  Future<void> _perform(HapticLevel physicalLevel) async {
    if (physicalLevel == HapticLevel.off) return;

    final now = DateTime.now();
    if (now.difference(_lastVibrateTime).inMilliseconds < 35) return;
    _lastVibrateTime = now;

    try {
      // Ensure cache is ready
      if (_hasVibrator == null) await _initHardwareCache();
      if (_hasVibrator == false) return;

      // Platform-agnostic approach using Flutter's native HapticFeedback
      // supplemented by Vibration package where native falls short.
      
      switch (physicalLevel) {
        case HapticLevel.light:
          // Selection click is the lightest OS-level feedback
          await HapticFeedback.selectionClick();
          break;
          
        case HapticLevel.medium:
          // Medium impact is crisp and noticeable
          await HapticFeedback.mediumImpact();
          break;
          
        case HapticLevel.strong:
          if (Platform.isAndroid && _hasCustomVibrations == true) {
            // On Android, "heavyImpact" can sometimes be subtle. 
            // We use a custom pulse for a "Strong" premium feel.
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
    } catch (e) {
      // Final fallback to core Flutter haptics which never fails
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

    // Use a simpler, more direct mapping. 
    // If user sets 'Strong', everything is one notch stronger.
    // If user sets 'Light', everything is one notch lighter.
    
    HapticLevel finalLevel;
    if (state == HapticLevel.medium) {
      finalLevel = eventIntensity;
    } else if (state == HapticLevel.light) {
      // Downgrade intensity
      if (eventIntensity == HapticLevel.strong) {
        finalLevel = HapticLevel.medium;
      } else {
        finalLevel = HapticLevel.light;
      }
    } else { // state == HapticLevel.strong
      // Upgrade intensity
      if (eventIntensity == HapticLevel.light) {
        finalLevel = HapticLevel.medium;
      } else {
        finalLevel = HapticLevel.strong;
      }
    }
    
    _perform(finalLevel);
  }

  void lightImpact() => _triggerSemantic(HapticLevel.light);
  void mediumImpact() => _triggerSemantic(HapticLevel.medium);
  void heavyImpact() => _triggerSemantic(HapticLevel.strong);
  void selectionClick() => lightImpact();
}
