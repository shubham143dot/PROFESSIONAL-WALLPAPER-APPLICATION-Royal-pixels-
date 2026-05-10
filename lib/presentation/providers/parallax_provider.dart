import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider to check if the device supports gyroscope/accelerometer for parallax.
final parallaxSupportProvider = FutureProvider<bool>((ref) async {
  try {
    // Check for either Accelerometer or Gyroscope.
    // Some devices lack one but have the other.
    final accelStream = accelerometerEventStream();
    final gyroStream = gyroscopeEventStream();

    final completer = Completer<bool>();
    StreamSubscription? subAccel;
    StreamSubscription? subGyro;

    void onSensorData() {
      if (!completer.isCompleted) {
        completer.complete(true);
        subAccel?.cancel();
        subGyro?.cancel();
      }
    }

    subAccel = accelStream.listen((_) => onSensorData(),
        onError: (_) => null, cancelOnError: true);

    subGyro = gyroStream.listen((_) => onSensorData(),
        onError: (_) => null, cancelOnError: true);

    // Timeout fallback after 600ms
    Timer(const Duration(milliseconds: 600), () {
      if (!completer.isCompleted) {
        completer.complete(false);
        subAccel?.cancel();
        subGyro?.cancel();
      }
    });

    return await completer.future;
  } catch (e) {
    if (kDebugMode) print('Parallax Detection Error: $e');
    return false;
  }
});

final parallaxProvider = StateNotifierProvider<ParallaxNotifier, bool>((ref) {
  return ParallaxNotifier();
});

class ParallaxNotifier extends StateNotifier<bool> {
  static const _key = 'is_parallax_enabled';

  ParallaxNotifier([super.initialState = true]) {
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_key)) {
      state = prefs.getBool(_key) ?? true;
    } else {
      state = true;
    }
  }

  Future<void> toggle() async {
    final prefs = await SharedPreferences.getInstance();
    final newState = !state;
    await prefs.setBool(_key, newState);
    state = newState;
  }
}
