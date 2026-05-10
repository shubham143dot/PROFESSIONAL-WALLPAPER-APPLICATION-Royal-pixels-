import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';
import '../../domain/entities/wallpaper_entity.dart';
import 'package:royal_pixels/core/services/adaptive_performance.dart';
import 'image_request_queue.dart';

/// Intelligence-layer image prefetch service.
///
/// Phase 3 upgrades over the original:
///  - Bidirectional preloading: tracks scroll direction and adjusts
///    look-ahead accordingly (forward gets more budget; backward gets less).
///  - Velocity-mode: fast scroll → queue only thumbnails (tiny); slow/idle → full medium.
///  - Smart cache priority: tap → urgent; visible → normal; speculative → background.
///  - Deduplication handled by [ImageRequestQueue].
class ImagePrefetchService {
  ImagePrefetchService._();

  // ── Grid initial warm-up ────────────────────────────────────────────────────

  /// Pre-fetches the first [count] medium-res URLs into cache immediately
  /// after the wallpaper state transitions loading → loaded.
  ///
  /// Uses [PrefetchPriority.normal] — these are the first visible cards.
  static Future<void> prefetchGrid(
    BuildContext context,
    List<WallpaperEntity> wallpapers, {
    int count = 20, // Increased to 20 — ensures first screen + next 2 rows are ready
  }) async {
    if (!context.mounted || !AdaptivePerformance.enablePrefetch) return;
    final toPrefetch = wallpapers.take(count);
    for (final wp in toPrefetch) {
      if (!context.mounted) break;
      final medUrl = wp.mediumUrl.isNotEmpty ? wp.mediumUrl : wp.optimizedUrl;
      if (medUrl.isNotEmpty) {
        ImageRequestQueue.instance.enqueue(
          medUrl,
          context,
          priority: PrefetchPriority.normal,
        );
      }
      // Thumbnail as ultra-fast fallback (enqueued as background to not crowd medium)
      final thumbUrl = wp.thumbnailUrl;
      if (thumbUrl.isNotEmpty && thumbUrl != medUrl) {
        ImageRequestQueue.instance.enqueue(
          thumbUrl,
          context,
          priority: PrefetchPriority.background,
        );
      }
    }
  }

  // ── Bidirectional smart preloading ─────────────────────────────────────────

  /// Preloads images in the direction the user is scrolling.
  ///
  /// [scrollDelta] > 0 = scrolling down (forward); < 0 = scrolling up (backward).
  /// [isFastScrolling] = true → load only thumbnails (tiny + fast to decode).
  ///
  /// Forward look-ahead: 12 images (phase 1 spec: 10–15).
  /// Backward look-ahead: 5 images (user may reverse; low probability).
  static void preloadBidirectional(
    BuildContext context,
    List<WallpaperEntity> wallpapers,
    int fromIndex, {
    required double scrollDelta,
    required bool isFastScrolling,
  }) {
    if (!context.mounted || !AdaptivePerformance.enablePrefetch) return;
    final isScrollingForward = scrollDelta > 0;

    // ── Forward look-ahead ──
    final forwardCount = isFastScrolling ? 4 : (AdaptivePerformance.isHigh ? 12 : 6);
    for (int i = fromIndex; i < fromIndex + forwardCount; i++) {
      if (i < 0 || i >= wallpapers.length) continue;
      final wp = wallpapers[i];

      if (isFastScrolling) {
        // Fast scroll: enqueue only thumbnail (smallest decode cost)
        final thumbUrl = wp.thumbnailUrl;
        if (thumbUrl.isNotEmpty) {
          ImageRequestQueue.instance.enqueue(
            thumbUrl,
            context,
            priority: PrefetchPriority.background,
          );
        }
      } else {
        // Slow scroll: full medium-res quality (what the user will see)
        final url = wp.mediumUrl.isNotEmpty ? wp.mediumUrl : wp.optimizedUrl;
        if (url.isNotEmpty) {
          ImageRequestQueue.instance.enqueue(
            url,
            context,
            priority: PrefetchPriority.normal,
          );
        }
      }
    }

    // ── Backward look-ahead (only when scrolling backward) ──
    if (!isScrollingForward) {
      const backwardCount = 5;
      for (int i = fromIndex - 1; i >= fromIndex - backwardCount; i--) {
        if (i < 0 || i >= wallpapers.length) continue;
        final wp = wallpapers[i];
        final url = wp.mediumUrl.isNotEmpty ? wp.mediumUrl : wp.optimizedUrl;
        if (url.isNotEmpty) {
          ImageRequestQueue.instance.enqueue(
            url,
            context,
            priority: PrefetchPriority.background,
          );
        }
      }
    }
  }

  // ── Legacy API (kept for backward compat) ─────────────────────────────────

  /// Preloads grid-resolution images [count] items ahead of [fromIndex].
  /// Prefer [preloadBidirectional] for full intelligence.
  static void preloadAhead(
    BuildContext context,
    List<WallpaperEntity> wallpapers,
    int fromIndex, {
    int count = 10,
  }) {
    if (!context.mounted) return;
    for (int i = fromIndex; i < fromIndex + count; i++) {
      if (i < 0 || i >= wallpapers.length) continue;
      final wp = wallpapers[i];
      final url = wp.mediumUrl.isNotEmpty ? wp.mediumUrl : wp.optimizedUrl;
      if (url.isNotEmpty) {
        ImageRequestQueue.instance.enqueue(
          url,
          context,
          priority: PrefetchPriority.background,
        );
      }
    }
  }

  // ── On-tap pre-cache for Hero transition ───────────────────────────────────

  /// Urgent pre-cache — call immediately on card tap before pushing detail.
  ///
  /// Uses [PrefetchPriority.urgent] so it bypasses the queue head.
  /// Also directly calls [precacheImage] for the full-res URL so the
  /// hero transition starts with the best available image.
  static void prefetchForDetail(
    BuildContext context,
    WallpaperEntity wallpaper,
  ) {
    if (!context.mounted) return;

    // Medium-res (what hero starts with)
    final medUrl = wallpaper.mediumUrl.isNotEmpty
        ? wallpaper.mediumUrl
        : wallpaper.optimizedUrl;
    if (medUrl.isNotEmpty) {
      // Direct precacheImage (bypasses queue — highest urgency)
      precacheImage(
        CachedNetworkImageProvider(medUrl, cacheKey: medUrl),
        context,
      );
    }

    // Also start loading optimized/full in background so detail page
    // can upgrade to full quality during hero transition
    final fullUrl = wallpaper.optimizedUrl;
    if (fullUrl.isNotEmpty && fullUrl != medUrl) {
      ImageRequestQueue.instance.enqueue(
        fullUrl,
        context,
        priority: PrefetchPriority.urgent,
      );
    }
  }

  // ── Feed adjacent pages ────────────────────────────────────────────────────

  /// Pre-fetches high-quality and blur placeholders for vertical reel pages.
  static void prefetchReel(
    BuildContext context,
    List<WallpaperEntity> wallpapers,
    int currentIndex, {
    int lookAhead = 4,
  }) {
    if (!context.mounted || !AdaptivePerformance.enablePrefetch) return;
    for (int i = 1; i <= lookAhead; i++) {
      final nextIdx = currentIndex + i;
      if (nextIdx < wallpapers.length) {
        final wp = wallpapers[nextIdx];
        
        // 1. High-priority for the high-res reel image
        final reelUrl = wp.reelUrl;
        if (reelUrl.isNotEmpty) {
          ImageRequestQueue.instance.enqueue(
            reelUrl,
            context,
            priority: i <= 2 ? PrefetchPriority.normal : PrefetchPriority.background,
          );
        }

        // 2. Urgent-priority for the tiny blur placeholder
        final blurUrl = wp.blurUrl;
        if (blurUrl.isNotEmpty) {
          ImageRequestQueue.instance.enqueue(
            blurUrl,
            context,
            priority: PrefetchPriority.urgent,
          );
        }
      }
    }
  }

  // ── Pause / Resume for app lifecycle ─────────────────────────────────────

  /// Call on app pause to clear speculative loads and free bandwidth.
  static void pauseBackgroundLoads() {
    ImageRequestQueue.instance.cancelBackground();
  }
}
