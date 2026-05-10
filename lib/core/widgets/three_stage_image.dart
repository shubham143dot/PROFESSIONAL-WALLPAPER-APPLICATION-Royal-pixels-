import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/adaptive_performance.dart';

/// 3-Stage Progressive Image Widget — Phase 1 + Phase 2 Perception Engine
///
/// Stage 0 (instant, 0ms):    Animated shimmer skeleton — always visible,
///                             zero layout shift, masks the network delay completely.
///
/// Stage 1 (fast, ~50-200ms): Tiny thumbnail (blur-upscaled) crossfades in.
///                             ImageFilter.blur applied in-widget — no extra network call.
///                             Gives user instant content signal ("it's a landscape").
///                             Disabled on low-end devices [AdaptivePerformance.enableBlurStage].
///
/// Stage 2 (normal, varies):  Full medium-res image fades + micro-zooms in (1.02→1.0).
///                             The zoom gives a "popping into focus" feel identical
///                             to iOS Photos app.
///
/// No layout shift: the widget always occupies [BoxFit.cover] space regardless
/// of which stage is loading — the skeleton fills 100% of the widget bounds.
import '../scroll/velocity_aware_controller.dart';

class ThreeStageImage extends StatefulWidget {
  /// The full-quality (medium-res) URL to display at stage 2.
  final String imageUrl;

  /// A smaller, faster-loading thumbnail URL for stage 1.
  /// If empty or same as [imageUrl], stage 1 is skipped.
  final String? thumbnailUrl;

  final BoxFit fit;
  final int memCacheWidth;
  final int memCacheHeight;

  /// Duration of the fade from stage 1 → stage 2.
  final Duration fadeInDuration;

  /// Key prefix for the hero tag (if this image is inside a Hero).
  final String? cacheKey;

  /// Optional controller to detect scroll state
  final VelocityAwareScrollController? scrollController;

  const ThreeStageImage({
    super.key,
    required this.imageUrl,
    this.thumbnailUrl,
    this.fit = BoxFit.cover,
    this.memCacheWidth = 400,
    this.memCacheHeight = 800,
    this.fadeInDuration = const Duration(milliseconds: 280),
    this.cacheKey,
    this.scrollController,
  });

  @override
  State<ThreeStageImage> createState() => _ThreeStageImageState();
}

class _ThreeStageImageState extends State<ThreeStageImage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _zoomController;
  late final Animation<double> _zoomAnimation;

  bool _stage2Loaded = false;

  @override
  void initState() {
    super.initState();

    // Micro-zoom: 1.05 → 1.0 over 450ms using easeOutExpo
    // Starts when stage 2 image first paints (see onImage callback).
    _zoomController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _zoomAnimation = Tween<double>(begin: 1.05, end: 1.0).animate(
      CurvedAnimation(
        parent: _zoomController,
        curve: const Cubic(0.16, 1.0, 0.3, 1.0), // easeOutExpo
      ),
    );
  }

  @override
  void dispose() {
    _zoomController.dispose();
    super.dispose();
  }

  void _onStage2Loaded() {
    if (!mounted || _stage2Loaded) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _stage2Loaded = true;
        });
        _zoomController.forward(from: 0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Decide whether to attempt stage 1 (blur thumbnail)
    final hasThumbnail = widget.thumbnailUrl != null &&
        widget.thumbnailUrl!.isNotEmpty &&
        widget.thumbnailUrl != widget.imageUrl;
    final useBlurStage = hasThumbnail && AdaptivePerformance.isHigh;

    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Stage 0: Shimmer skeleton (always present until stage 2 loads) ──
          if (!_stage2Loaded)
            _ShimmerSkeleton(
              scrollController: widget.scrollController,
            ),

          // ── Stage 1: Blurred thumbnail (fast preview) ─────────────────────
          if (useBlurStage && !_stage2Loaded)
            _BlurThumbnail(
              url: widget.thumbnailUrl!,
              fit: widget.fit,
            ),

          // ── Stage 2: Full medium-res with fade + zoom ─────────────────────
          _buildStage2WithDeferral(),
        ],
      ),
    );
  }

  Widget _buildStage2WithDeferral() {
    // Phase 7 Fix: No longer deferring Stage 2 building.
    // Deferring high-res loading during scroll caused a visible 'pop-in' flicker
    // when scrolling stopped. By allowing it to build immediately, we take 
    // advantage of the image cache and let loading happen in the background.
    return _buildStage2();
  }

  Widget _buildStage2() {
    return _Stage2Image(
      imageUrl: widget.imageUrl,
      fit: widget.fit,
      memCacheWidth: widget.memCacheWidth,
      memCacheHeight: widget.memCacheHeight,
      fadeInDuration: widget.fadeInDuration,
      zoomAnimation: _zoomAnimation,
      cacheKey: widget.cacheKey,
      onLoaded: _onStage2Loaded,
    );
  }
}

// ─── Stage 0: Shimmer ─────────────────────────────────────────────────────────

class _ShimmerSkeleton extends StatefulWidget {
  final VelocityAwareScrollController? scrollController;
  const _ShimmerSkeleton({this.scrollController});

  @override
  State<_ShimmerSkeleton> createState() => _ShimmerSkeletonState();
}

class _ShimmerSkeletonState extends State<_ShimmerSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    
    // Auto-pause shimmer if already scrolling fast at init
    if (widget.scrollController?.isFastScrolling.value != true && !AdaptivePerformance.isLow) {
      _ctrl.repeat(reverse: true);
    }

    _pulse = Tween<double>(begin: 0.05, end: 0.12).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutSine),
    );

    widget.scrollController?.isFastScrolling.addListener(_onVelocityChange);
  }

  void _onVelocityChange() {
    if (!mounted || AdaptivePerformance.isLow) return;
    if (widget.scrollController?.isFastScrolling.value == true) {
      _ctrl.stop();
    } else {
      _ctrl.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    widget.scrollController?.isFastScrolling.removeListener(_onVelocityChange);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (AdaptivePerformance.useStaticPlaceholders) {
      return const DecoratedBox(
        decoration: BoxDecoration(color: Color(0xFF0E1120)),
        child: SizedBox.expand(),
      );
    }
    
    // Premium pulsing background shimmer - less jittery than moving bar
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) => DecoratedBox(
        decoration: BoxDecoration(
          color: Color.lerp(
            const Color(0xFF0E1120),
            const Color(0xFF1A1F35),
            _pulse.value,
          ),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

// ─── Stage 1: Blurred Thumbnail ───────────────────────────────────────────────

class _BlurThumbnail extends StatelessWidget {
  final String url;
  final BoxFit fit;

  const _BlurThumbnail({
    required this.url,
    required this.fit,
  });

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      memCacheWidth: 60, 
      memCacheHeight: 120,
      fadeInDuration: const Duration(milliseconds: 100),
      fadeOutDuration: Duration.zero,
      placeholder: (_, __) => const SizedBox.expand(),
      errorWidget: (_, __, ___) => const SizedBox.expand(),
      imageBuilder: (context, imageProvider) {
        // Phase 7 Fix: Always show blurred thumbnail to prevent visual flicker 
        // when scroll state changes. Swapping between blurred/unblurred 
        // widgets mid-scroll is jarring.
        return ImageFiltered(
          imageFilter: ui.ImageFilter.blur(
            sigmaX: 10,
            sigmaY: 10,
            tileMode: ui.TileMode.clamp,
          ),
          child: Image(image: imageProvider, fit: BoxFit.cover),
        );
      },
    );
  }
}

// ─── Stage 2: Full Image with Fade + Zoom ─────────────────────────────────────

class _Stage2Image extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final int memCacheWidth;
  final int memCacheHeight;
  final Duration fadeInDuration;
  final Animation<double> zoomAnimation;
  final String? cacheKey;
  final VoidCallback onLoaded;

  const _Stage2Image({
    required this.imageUrl,
    required this.fit,
    required this.memCacheWidth,
    required this.memCacheHeight,
    required this.fadeInDuration,
    required this.zoomAnimation,
    required this.onLoaded,
    this.cacheKey,
  });

  @override
  Widget build(BuildContext context) {
    final imageWidget = CachedNetworkImage(
      imageUrl: imageUrl,
      cacheKey: cacheKey ?? imageUrl,
      fit: fit,
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
      fadeInDuration: fadeInDuration,
      fadeInCurve: Curves.easeOutCubic,
      fadeOutDuration: Duration.zero,
      useOldImageOnUrlChange: true,
      placeholder: (_, __) => const SizedBox.expand(),
      errorWidget: (context, url, error) {
        if (kDebugMode) {
          debugPrint('❌ ThreeStageImage Error [$url]: $error');
        }
        return const ColoredBox(
          color: Color(0xFF161C2D),
          child: Icon(Icons.broken_image_outlined, color: Colors.white24, size: 24),
        );
      },
      imageBuilder: (context, imageProvider) {
        // Trigger zoom animation on first paint
        onLoaded();
        
        // Skip micro-zoom on low-tier to save GPU/CPU
        if (AdaptivePerformance.isLow) {
          return Image(image: imageProvider, fit: fit);
        }

        return AnimatedBuilder(
          animation: zoomAnimation,
          builder: (_, child) => Transform.scale(
            scale: zoomAnimation.value,
            filterQuality: ui.FilterQuality.none,
            child: child,
          ),
          child: Image(image: imageProvider, fit: fit),
        );
      },
    );

    return imageWidget;
  }
}

