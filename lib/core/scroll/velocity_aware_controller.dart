import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';

/// Global provider to track if any high-velocity scrolling is happening.
/// Used by expensive widgets (like Parallax) to pause updates and save GPU/CPU.
final globalScrollingProvider = StateProvider<bool>((ref) => false);

/// A base mixin for velocity tracking logic to be shared across controller types.
mixin VelocityTrackingBase {
  /// Current absolute scroll velocity in logical pixels/second.
  final ValueNotifier<double> velocity = ValueNotifier<double>(0.0);

  /// Normalized scroll speed: 0.0 = idle, 1.0 = maximum speed.
  final ValueNotifier<double> normalizedSpeed = ValueNotifier<double>(0.0);

  /// Whether the user is currently scrolling fast enough to skip expensive effects.
  final ValueNotifier<bool> isFastScrolling = ValueNotifier<bool>(false);

  /// Whether any scroll movement is currently active (even slow).
  final ValueNotifier<bool> isScrolling = ValueNotifier<bool>(false);

  // ── Thresholds ──────────────────────────────────────────────────────────
  static const double _fastThreshold = 1200.0;
  static const double _idleThreshold = 20.0;
  
  double _previousOffset = 0.0;
  int _previousTimestamp = 0;
  Timer? _resetTimer;

  bool get hasClients;
  double get offset;

  /// Attach this to a [NotificationListener<ScrollNotification>]
  bool handleScrollNotification(ScrollNotification notification, [WidgetRef? ref]) {
    if (notification.depth != 0) return false;

    if (notification is ScrollUpdateNotification) {
      updateVelocity(notification.metrics.pixels);
      if (ref != null) {
        if (isScrolling.value != ref.read(globalScrollingProvider)) {
           ref.read(globalScrollingProvider.notifier).state = isScrolling.value;
        }
      }
    } else if (notification is ScrollEndNotification) {
      resetVelocity();
      if (ref != null) {
         ref.read(globalScrollingProvider.notifier).state = false;
      }
    }
    return false;
  }

  void updateVelocity([double? currentOffset]) {
    final now = DateTime.now().microsecondsSinceEpoch;
    final effectiveOffset = currentOffset ?? (hasClients ? offset : 0.0);

    if (_previousTimestamp != 0) {
      final dt = (now - _previousTimestamp) / 1000000.0;
      if (dt > 0.008) {
        final v = ((effectiveOffset - _previousOffset) / dt).abs();
        velocity.value = velocity.value * 0.7 + v * 0.3;

        if (velocity.value > _idleThreshold) {
          isScrolling.value = true;
        } else if (velocity.value < _idleThreshold * 0.3) {
          isScrolling.value = false;
        }

        const double effectiveMaxVelocity = 6000.0;
        final double newNormalized = (velocity.value / effectiveMaxVelocity).clamp(0.0, 1.0);
        
        if ((newNormalized - normalizedSpeed.value).abs() > 0.015) {
          normalizedSpeed.value = newNormalized;
        }

        if (velocity.value > _fastThreshold && !isFastScrolling.value) {
          isFastScrolling.value = true;
          _resetTimer?.cancel();
        } else if (velocity.value < _fastThreshold * 0.5 && isFastScrolling.value) {
          if (_resetTimer == null || !_resetTimer!.isActive) {
            _resetTimer = Timer(const Duration(milliseconds: 150), () {
              if (hasClients) {
                 isFastScrolling.value = false;
              }
            });
          }
        }
        
        _previousOffset = effectiveOffset;
        _previousTimestamp = now;
      }
    } else {
      _previousOffset = effectiveOffset;
      _previousTimestamp = now;
    }
  }

  void resetVelocity() {
    _resetTimer?.cancel();
    velocity.value = 0.0;
    normalizedSpeed.value = 0.0;
    isScrolling.value = false;
    isFastScrolling.value = false;
    _previousTimestamp = 0;
  }

  void disposeVelocityTracking() {
    _resetTimer?.cancel();
    velocity.dispose();
    normalizedSpeed.dispose();
    isFastScrolling.dispose();
    isScrolling.dispose();
  }
}

/// A standard scroll controller that exposes real-time scroll velocity.
/// Use this for non-paginated vertical lists (Home, Explore, Profile).
class VelocityAwareScrollController extends ScrollController with VelocityTrackingBase {
  VelocityAwareScrollController({
    super.initialScrollOffset,
    super.keepScrollOffset,
    super.debugLabel,
  });

  @override
  void dispose() {
    disposeVelocityTracking();
    super.dispose();
  }
}

/// A page controller that exposes real-time scroll velocity.
/// Use this for paginated views (Social Feed).
class VelocityAwarePageController extends PageController with VelocityTrackingBase {
  VelocityAwarePageController({
    super.initialPage,
    super.keepPage,
    super.viewportFraction,
  });

  @override
  void dispose() {
    disposeVelocityTracking();
    super.dispose();
  }
}

/// Mixin for widgets that want velocity-adaptive scroll behavior.
mixin VelocityAwareMixin<T extends StatefulWidget> on State<T> {
  late final VelocityAwareScrollController velocityController;

  @override
  void initState() {
    super.initState();
    velocityController = VelocityAwareScrollController();
    velocityController.addListener(_onScroll);
  }

  void _onScroll() {
    velocityController.updateVelocity();
  }

  bool handleScrollNotification(ScrollNotification notification, [WidgetRef? ref]) {
    return velocityController.handleScrollNotification(notification, ref);
  }

  @override
  void dispose() {
    velocityController.removeListener(_onScroll);
    velocityController.dispose();
    super.dispose();
  }
}
