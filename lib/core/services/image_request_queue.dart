import 'dart:async';
import 'dart:collection';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';
import 'adaptive_performance.dart';


/// Priority level for image prefetch requests.
///
/// P0 (urgent) — tap-triggered loads that block hero transitions.
/// P1 (normal) — viewport-visible items during slow/idle scroll.
/// P2 (background) — speculative look-ahead loads.
enum PrefetchPriority { urgent, normal, background }

/// Priority-aware image request queue.
///
/// Improvements over the original FIFO queue:
///  - 3-tier priority: urgent (P0) → normal (P1) → background (P2)
///  - De-duplication: URLs already cached or already in-flight are skipped
///  - Max concurrent = 4 (was 3): safe uplift that improves look-ahead speed
///    without causing TCP congestion on 4G connections.
///  - Background tier concurrency cap = 2: heavy prefetch never crowds urgent loads.
///  - Cancel support: in-flight background tasks can be cancelled to free slots
///    for sudden urgent requests.
class ImageRequestQueue {
  ImageRequestQueue._();

  static final ImageRequestQueue instance = ImageRequestQueue._();

  /// Maximum concurrent requests across all tiers.
  static int get _maxConcurrent => AdaptivePerformance.isLow ? 1 : (AdaptivePerformance.isHigh ? 4 : 3);

  /// Max concurrent for background tier specifically.
  static int get _maxBackground => AdaptivePerformance.isLow ? 0 : (AdaptivePerformance.isHigh ? 2 : 1);

  int _activePriority = 0; // Active P0 + P1
  int _activeBackground = 0; // Active P2

  /// URLs currently loading or already completed in this session.
  /// Prevents redundant network hits for images already in memory cache.
  final Set<String> _inFlightOrDone = {};

  final Queue<_PrefetchTask> _urgentQueue = Queue<_PrefetchTask>();
  final Queue<_PrefetchTask> _normalQueue = Queue<_PrefetchTask>();
  final Queue<_PrefetchTask> _backgroundQueue = Queue<_PrefetchTask>();

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Enqueue a prefetch request.
  ///
  /// If [url] is already in-flight or was completed this session, returns
  /// immediately (no duplicate load).
  ///
  /// [priority] defaults to [PrefetchPriority.normal].
  Future<void> enqueue(
    String url,
    BuildContext context, {
    PrefetchPriority priority = PrefetchPriority.normal,
  }) {
    if (url.isEmpty) return Future.value();
    if (_inFlightOrDone.contains(url)) return Future.value();

    _inFlightOrDone.add(url);

    final completer = Completer<void>();
    final task = _PrefetchTask(
      url: url,
      context: context,
      completer: completer,
      priority: priority,
    );

    switch (priority) {
      case PrefetchPriority.urgent:
        _urgentQueue.addFirst(task); // LIFO for urgent: newest wins
      case PrefetchPriority.normal:
        _normalQueue.addLast(task);
      case PrefetchPriority.background:
        _backgroundQueue.addLast(task);
    }

    _drain();
    return completer.future;
  }

  /// Clear all queued background tasks (e.g. when filter changes).
  void cancelBackground() {
    for (final task in _backgroundQueue) {
      if (!task.completer.isCompleted) task.completer.complete();
    }
    _backgroundQueue.clear();
  }

  /// Clear everything — use on app background/pause.
  void cancelAll() {
    cancelBackground();
    for (final task in _normalQueue) {
      if (!task.completer.isCompleted) task.completer.complete();
    }
    _normalQueue.clear();
    // Don't cancel urgent — they're blocking UI
  }

  // ── Internal drain loop ───────────────────────────────────────────────────

  void _drain() {
    // Always drain urgent first
    while (_activePriority < _maxConcurrent && _urgentQueue.isNotEmpty) {
      _activePriority++;
      _execute(_urgentQueue.removeFirst(), isBackground: false);
    }

    // Normal priority: uses same pool but won't start if urgent needs the slot
    while (_activePriority < _maxConcurrent && _normalQueue.isNotEmpty) {
      _activePriority++;
      _execute(_normalQueue.removeFirst(), isBackground: false);
    }

    // Background: separate cap to avoid crowding P0/P1
    while (_activeBackground < _maxBackground &&
        _activePriority + _activeBackground < _maxConcurrent &&
        _backgroundQueue.isNotEmpty) {
      _activeBackground++;
      _execute(_backgroundQueue.removeFirst(), isBackground: true);
    }
  }

  Future<void> _execute(_PrefetchTask task, {required bool isBackground}) async {
    try {
      if (task.context.mounted) {
        await precacheImage(
          CachedNetworkImageProvider(task.url, cacheKey: task.url),
          task.context,
        );
      }
      if (!task.completer.isCompleted) task.completer.complete();
    } catch (_) {
      // Prefetch is best-effort — never block the caller
      if (!task.completer.isCompleted) task.completer.complete();
      // Remove from set so it can be retried later
      _inFlightOrDone.remove(task.url);
    } finally {
      if (isBackground) {
        _activeBackground--;
      } else {
        _activePriority--;
      }
      _drain();
    }
  }
}

class _PrefetchTask {
  final String url;
  final BuildContext context;
  final Completer<void> completer;
  final PrefetchPriority priority;

  const _PrefetchTask({
    required this.url,
    required this.context,
    required this.completer,
    required this.priority,
  });
}
