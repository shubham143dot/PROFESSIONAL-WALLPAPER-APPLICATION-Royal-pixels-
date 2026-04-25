/// A utility to prevent multiple rapid taps on UI elements.
/// Prevents race conditions and "recomposition overload" by ignoring
/// subsequent taps for a set duration.
class SafeTap {
  static final Map<String, DateTime> _lastTapTimes = {};
  
  /// The default debounce duration. 500ms is usually enough to 
  /// prevent accidental double-taps while feeling responsive.
  static const Duration defaultDuration = Duration(milliseconds: 500);

  /// Checks if a tap is "safe" to proceed.
  /// [key] should be a unique identifier for the button/action.
  /// If [key] is null, a global debounce is applied.
  static bool isSafe(String? key, {Duration? duration}) {
    final now = DateTime.now();
    final effectiveKey = key ?? 'global_debounce';
    final lastTap = _lastTapTimes[effectiveKey];
    final effectiveDuration = duration ?? defaultDuration;

    if (lastTap == null || now.difference(lastTap) > effectiveDuration) {
      _lastTapTimes[effectiveKey] = now;
      
      // Periodically clean up old entries to prevent memory leak
      if (_lastTapTimes.length > 100) {
        _lastTapTimes.removeWhere((k, v) => now.difference(v) > const Duration(minutes: 5));
      }
      
      return true;
    }
    return false;
  }

  /// Wraps a callback with debounce logic.
  static void run(String? key, void Function() action, {Duration? duration}) {
    if (isSafe(key, duration: duration)) {
      action();
    }
  }
}
