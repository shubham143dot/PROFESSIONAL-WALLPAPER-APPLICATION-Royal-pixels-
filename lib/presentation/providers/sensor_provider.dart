import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';


/// Single shared accelerometer stream for all wallpaper cards.
///
/// Instead of each WallpaperCard creating its own sensor subscription
/// (N cards = N subscriptions = 60*N events/sec), this provider creates
/// ONE subscription and broadcasts the tilt offset to all listeners.
final tiltProvider = StateNotifierProvider<TiltNotifier, Offset>((ref) {
  return TiltNotifier(isEnabled: false);
});

class TiltNotifier extends StateNotifier<Offset> {
  StreamSubscription? _sub;
  final bool isEnabled;

  TiltNotifier({required this.isEnabled}) : super(Offset.zero) {
    if (isEnabled) _init();
  }

  Future<void> _init() async {
    try {
      // Check hardware support
      _sub = accelerometerEventStream(
        samplingPeriod:
            const Duration(milliseconds: 100), // 10 Hz is plenty for subtle parallax
      ).listen(
        (event) {
          if (!mounted) return;
          final tx = (event.x / 9.8).clamp(-1.0, 1.0);
          final ty = (event.y / 9.8).clamp(-1.0, 1.0);
          state = Offset(tx, ty);
        },
        onError: (_) {
          // Sensor not available — stay at zero
        },
        cancelOnError: true,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Accelerometer init failed: $e');
      }
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
