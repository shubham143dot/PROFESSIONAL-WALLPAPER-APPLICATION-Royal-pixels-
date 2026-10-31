import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/haptic_helper.dart';
import '../../domain/entities/haptic_level.dart';

/// Navigation item model for [GlassFloatingNavBar].
@immutable
class GlassNavItemData {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const GlassNavItemData({
    required this.icon,
    required this.label,
    IconData? selectedIcon,
  }) : selectedIcon = selectedIcon ?? icon;
}

/// Transparent frosted glass floating bottom navigation bar with an organic
/// crystal-clear water bubble that slides across tabs, illuminating buttons
/// with Gold/Apple Blue (dark mode) / Royal Purple (light mode) only when the bubble touches them.
class GlassFloatingNavBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;
  final bool isDark;
  final List<GlassNavItemData> items;
  final ValueNotifier<double>? pageNotifier;
  final double bottomSafeArea;
  final HapticLevel? hapticLevel;

  const GlassFloatingNavBar({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
    this.isDark = true,
    required this.items,
    this.pageNotifier,
    this.bottomSafeArea = 0,
    this.hapticLevel,
  });

  @override
  State<GlassFloatingNavBar> createState() => _GlassFloatingNavBarState();
}

class _GlassFloatingNavBarState extends State<GlassFloatingNavBar>
    with TickerProviderStateMixin {
  // Fluid physics constants
  static const double _barHeight = 68.0;
  static const double _maxWidth = 480.0;
  static const double _horizontalMargin = 16.0;
  static const double _innerPadding = 6.0;

  void _triggerTabHaptic() {
    final level = widget.hapticLevel ?? HapticHelper.currentLevel;
    if (level == HapticLevel.off) return;
    HapticHelper.triggerLevel(level);
  }
  static const double _capsuleVerticalInset = 5.0;
  static const double _blobHorizontalInset = 3.0;
  static const double _dragMagnify = 0.12;
  static const double _dragWiden = 0.35;
  static const double _dragStretch = 0.25;
  static const double _dragTopOverflow = 6.0;
  static const double _dragBottomOverflow = 6.0;
  static const double _lensIconGain = 0.26;
  static const double _lensLabelGain = 0.12;
  static const double _dragVerticalSwell = 0.03;
  static const double _maxSquash = 0.06;
  static const double _refVelocity = 16.0;
  static const double _velRelax = 0.05;
  static const double _stretchEase = 0.06;
  static const double _actEase = 0.11;
  late final AnimationController _controller;
  late final Listenable _capsuleRepaint;
  late int _fromIndex;
  late int _toIndex;

  double? _animStartLeft;
  double? _animStartWidth;
  double _currentLeft = 0.0;
  double _currentWidth = 0.0;
  double _lastItemWidth = 0.0;
  bool _isFlowing = false;

  final ValueNotifier<double?> _dragLeft = ValueNotifier<double?>(null);
  bool _settling = false;
  double _settleFromLeft = 0;
  double _settleToLeft = 0;

  final ValueNotifier<_WaterDragFx> _dragFx =
      ValueNotifier<_WaterDragFx>(_WaterDragFx.rest);
  late final Ticker _fxTicker;
  bool _dragging = false;
  double _vel = 0;
  double _fxActivation = 0;
  double _fxStretch = 0;
  int _lastTickMicros = 0;

  @override
  void initState() {
    super.initState();
    _fromIndex = widget.currentIndex;
    _toIndex = widget.currentIndex;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: 1.0,
    )..addStatusListener(_onControllerStatus);
    _fxTicker = createTicker(_onFxTick);

    final notifiers = <Listenable>[_controller, _dragLeft, _dragFx];
    if (widget.pageNotifier != null) {
      notifiers.add(widget.pageNotifier!);
    }
    _capsuleRepaint = Listenable.merge(notifiers);
  }

  void _onControllerStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _settling = false;
      _isFlowing = false;
      _animStartLeft = null;
      _animStartWidth = null;
    }
  }

  @override
  void didUpdateWidget(covariant GlassFloatingNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentIndex != _toIndex) {
      _flowTo(widget.currentIndex);
    }
  }

  void _flowTo(int target) {
    if (target < 0 || target >= widget.items.length) return;
    if (target == _toIndex && !_isFlowing && !_settling) return;

    final itemWidth = _lastItemWidth > 0 ? _lastItemWidth : 70.0;

    // Capture the exact physical on-screen position of the bubble right now
    if (_animStartLeft == null && !_isFlowing && !_settling) {
      _currentLeft = _slotLeft(_toIndex, itemWidth);
      _currentWidth = itemWidth;
    }
    _animStartLeft = _currentLeft;
    _animStartWidth = _currentWidth > 0 ? _currentWidth : itemWidth;
    _fromIndex = _nearestIndex(_currentLeft, itemWidth);
    _toIndex = target;
    _settling = false;
    _isFlowing = true;

    if (MediaQuery.of(context).disableAnimations) {
      _controller.value = 1.0;
      _isFlowing = false;
      _currentLeft = _slotLeft(target, itemWidth);
      _currentWidth = itemWidth;
    } else {
      final targetLeft = _slotLeft(target, itemWidth);
      final distance = ((targetLeft - _currentLeft) / itemWidth).abs();
      // Distance-proportional duration: 240ms for adjacent, up to 360ms for 4 tabs
      final durationMs = (240 + math.min(distance * 30.0, 120.0)).round();
      _controller.duration = Duration(milliseconds: durationMs);
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _fxTicker.dispose();
    _controller.dispose();
    _dragLeft.dispose();
    _dragFx.dispose();
    super.dispose();
  }

  double _slotLeft(int i, double itemWidth) =>
      _innerPadding + itemWidth * i;

  double _clampLeft(double rawLeft, double itemWidth) => rawLeft.clamp(
        _slotLeft(0, itemWidth),
        _slotLeft(widget.items.length - 1, itemWidth),
      );

  int _nearestIndex(double left, double itemWidth) {
    if (itemWidth <= 0) return widget.currentIndex;
    final slot = ((left - _innerPadding) / itemWidth).round();
    return slot.clamp(0, widget.items.length - 1);
  }


  void _dragTo(double localX, double itemWidth) {
    _settling = false;
    _dragLeft.value = _clampLeft(localX - itemWidth / 2, itemWidth);
  }

  void _beginDragFx() {
    if (MediaQuery.of(context).disableAnimations) return;
    _dragging = true;
    _vel = 0;
    if (!_fxTicker.isTicking) {
      _lastTickMicros = 0;
      _fxTicker.start();
    }
  }

  void _feedDragVelocity(double dx) {
    if (!_dragging) return;
    _vel = _vel * 0.45 + dx * 0.55;
  }

  void _endDragFx() {
    _dragging = false;
  }

  void _onFxTick(Duration elapsed) {
    final micros = elapsed.inMicroseconds;
    var dt = (micros - _lastTickMicros) / 1e6;
    _lastTickMicros = micros;
    if (dt <= 0) dt = 0.016;
    if (dt > 0.05) dt = 0.05;

    _vel *= math.exp(-dt / _velRelax);

    final intensity = (_vel / _refVelocity).clamp(-1.0, 1.0);
    final targetStretch = _dragging ? intensity : 0.0;
    final targetActivation = _dragging ? 1.0 : 0.0;

    _fxStretch +=
        (targetStretch - _fxStretch) * (1 - math.exp(-dt / _stretchEase));
    _fxActivation +=
        (targetActivation - _fxActivation) * (1 - math.exp(-dt / _actEase));

    if (!_dragging && _fxActivation.abs() < 0.001 && _fxStretch.abs() < 0.001) {
      _fxActivation = 0;
      _fxStretch = 0;
      _vel = 0;
      _lastTickMicros = 0;
      _dragFx.value = _WaterDragFx.rest;
      _fxTicker.stop();
      return;
    }
    _dragFx.value = _WaterDragFx(activation: _fxActivation, stretch: _fxStretch);
  }

  void _commitDrag(double itemWidth) {
    final start = _dragLeft.value;
    _dragLeft.value = null;
    if (start == null) return;
    final target = _nearestIndex(start, itemWidth);
    _beginSettle(start, target, itemWidth);
    if (target != widget.currentIndex) {
      _triggerTabHaptic();
      widget.onTabSelected(target);
    }
  }

  void _cancelDrag(double itemWidth) {
    final start = _dragLeft.value;
    _dragLeft.value = null;
    if (start == null) return;
    _beginSettle(start, widget.currentIndex, itemWidth);
  }

  void _beginSettle(double fromLeft, int target, double itemWidth) {
    _settleFromLeft = fromLeft;
    _settleToLeft = _slotLeft(target, itemWidth);
    _fromIndex = target;
    _toIndex = target;
    _isFlowing = false;
    if (MediaQuery.of(context).disableAnimations) {
      _settling = false;
      _controller.value = 1.0;
    } else {
      _settling = true;
      _controller.duration = const Duration(milliseconds: 280);
      _controller.forward(from: 0.0);
    }
  }

  ({double left, double width}) _resolveCapsule(double itemWidth) {
    _lastItemWidth = itemWidth;

    // 1. Manual user drag override
    final dragLeft = _dragLeft.value;
    if (dragLeft != null) {
      _currentLeft = dragLeft;
      _currentWidth = itemWidth;
      return (left: _currentLeft, width: _currentWidth);
    }

    // 2. Drag release settle animation
    if (_settling) {
      final t = Curves.easeOutBack.transform(_controller.value);
      _currentLeft = lerpDouble(_settleFromLeft, _settleToLeft, t)!;
      _currentWidth = itemWidth;
      return (left: _currentLeft, width: _currentWidth);
    }

    // 3. PageNotifier continuous swipe (if provided)
    if (widget.pageNotifier != null) {
      final pageVal = widget.pageNotifier!.value;
      _currentLeft = (_innerPadding + itemWidth * pageVal).clamp(
        _slotLeft(0, itemWidth),
        _slotLeft(widget.items.length - 1, itemWidth),
      );
      _currentWidth = itemWidth;
      return (left: _currentLeft, width: _currentWidth);
    }

    // 4. Settled at target slot
    final targetLeft = _slotLeft(_toIndex, itemWidth);
    if (!_isFlowing || _controller.value >= 1.0) {
      _currentLeft = targetLeft;
      _currentWidth = itemWidth;
      return (left: _currentLeft, width: _currentWidth);
    }

    // 5. Active liquid flow animation
    final t = _controller.value;
    final startLeft = _animStartLeft ?? _slotLeft(_fromIndex, itemWidth);
    final startWidth = _animStartWidth ?? itemWidth;

    // High-precision fluid curve: rapid launch, graceful decelerated landing
    const flowCurve = Cubic(0.20, 0.95, 0.30, 1.0);
    final progress = flowCurve.transform(t);

    final startCenter = startLeft + startWidth / 2;
    final targetCenter = targetLeft + itemWidth / 2;
    final currentCenter = lerpDouble(startCenter, targetCenter, progress)!;

    // Surface tension liquid elongation along movement vector
    final distance = ((targetLeft - startLeft) / itemWidth).abs();
    final maxStretch = math.min(distance * 7.0, 15.0);
    final flightStretch =
        math.sin((progress * math.pi).clamp(0.0, math.pi)) * maxStretch;

    // Micro-viscoelastic cushion as droplet settles into target slot
    double settleDelta = 0.0;
    if (t > 0.75) {
      final settleT = (t - 0.75) / 0.25;
      settleDelta = math.sin(settleT * math.pi * 2) * (1.0 - settleT) * 1.5;
    }

    final dynamicWidth = (lerpDouble(startWidth, itemWidth, progress)! +
            flightStretch +
            settleDelta)
        .clamp(itemWidth * 0.90, itemWidth * 1.45);

    _currentWidth = dynamicWidth;
    _currentLeft = currentCenter - dynamicWidth / 2;
    return (left: _currentLeft, width: _currentWidth);
  }

  double _coverageFor(int index, double itemWidth) {
    if (itemWidth <= 0) return index == _toIndex ? 1.0 : 0.0;

    if (!_isFlowing &&
        !_settling &&
        _dragLeft.value == null &&
        widget.pageNotifier == null) {
      return index == _toIndex ? 1.0 : 0.0;
    }

    final capsule = _resolveCapsule(itemWidth);
    final bubbleCenter = capsule.left + capsule.width / 2;
    final itemCenter = _slotLeft(index, itemWidth) + itemWidth / 2;
    final dist = (bubbleCenter - itemCenter).abs() / itemWidth;

    if (dist >= 1.0) return 0.0;
    // Hermite smoothstep for natural liquid light diffusion
    final x = (1.0 - dist).clamp(0.0, 1.0);
    return x * x * (3.0 - 2.0 * x);
  }

  @override
  Widget build(BuildContext context) {
    final bool highContrast = MediaQuery.of(context).highContrast;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    // Active button color: Luxury Gold
    const Color buttonActiveColor = AppColors.goldLight;

    // Completely monochrome neutral for unselected tabs
    const Color buttonNeutralColor = Color(0xFF8E8E93);

    // Ultra-transparent glassfrost surface for the floating capsule.
    final Color glassfrostFill = highContrast
        ? const Color(0xFF0F172A)
        : Colors.white.withValues(alpha: 0.05);

    final Color glassfrostBorder = highContrast
        ? Colors.white
        : Colors.white.withValues(alpha: 0.16);

    // Pure crystal-clear transparent water bubble colors (ZERO colored tint inside bubble)
    final _WaterBubbleColors waterColors = _WaterBubbleColors(
      fillTop: Colors.white.withValues(alpha: 0.14),
      fillBottom: Colors.white.withValues(alpha: 0.04),
      border: Colors.white.withValues(alpha: 0.30),
      rimLight: Colors.white.withValues(alpha: 0.80),
      specular: Colors.white.withValues(alpha: 0.65),
      innerShade: Colors.black.withValues(alpha: 0.24),
      glow: Colors.white.withValues(alpha: 0.12),
    );

    final barRadius = BorderRadius.circular(_barHeight / 2);
    final liftHeadroom = _dragTopOverflow + 6.0;
    final bottomHeadroom = 8.0;
    final bottomPadding = math.max(widget.bottomSafeArea, 10.0);

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          _horizontalMargin,
          0,
          _horizontalMargin,
          bottomPadding,
        ),
        child: Align(
          alignment: Alignment.bottomCenter,
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxWidth),
            child: SizedBox(
              height: _barHeight + liftHeadroom + bottomHeadroom,
              child: RepaintBoundary(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final contentWidth =
                        constraints.maxWidth - _innerPadding * 2;
                    final itemWidth = contentWidth / widget.items.length;

                    // Frosted transparent glass bar
                    final glassBar = DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: barRadius,
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x22000000),
                            blurRadius: 28,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: barRadius,
                        child: BackdropFilter(
                          filter: ImageFilter.blur(
                            sigmaX: highContrast ? 0 : 24,
                            sigmaY: highContrast ? 0 : 24,
                          ),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: glassfrostFill,
                              borderRadius: barRadius,
                              border: Border.all(
                                color: glassfrostBorder,
                                width: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );

                    // Row of interactive tab items
                    final itemsRow = Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: _innerPadding,
                        ),
                        child: Row(
                          children: [
                            for (var i = 0; i < widget.items.length; i++)
                              Expanded(
                                child: _GlassNavItemWidget(
                                  item: widget.items[i],
                                  selected: i == widget.currentIndex,
                                  buttonActiveColor: buttonActiveColor,
                                  buttonNeutralColor: buttonNeutralColor,
                                  reduceMotion: reduceMotion,
                                  repaint: _capsuleRepaint,
                                  coverage: () => _coverageFor(i, itemWidth),
                                  lensIconGain: _lensIconGain,
                                  lensLabelGain: _lensLabelGain,
                                  onTap: () {
                                    _triggerTabHaptic();
                                    _flowTo(i);
                                    widget.onTabSelected(i);
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                    );

                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: bottomHeadroom,
                          height: _barHeight,
                          child: glassBar,
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: bottomHeadroom,
                          height: _barHeight,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onHorizontalDragStart: (d) {
                              _beginDragFx();
                              _dragTo(d.localPosition.dx, itemWidth);
                            },
                            onHorizontalDragUpdate: (d) {
                              _feedDragVelocity(d.delta.dx);
                              _dragTo(d.localPosition.dx, itemWidth);
                            },
                            onHorizontalDragEnd: (_) {
                              _endDragFx();
                              _commitDrag(itemWidth);
                            },
                            onHorizontalDragCancel: () {
                              _endDragFx();
                              _cancelDrag(itemWidth);
                            },
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                // Pure transparent water bubble
                                Positioned.fill(
                                  child: AnimatedBuilder(
                                    animation: _capsuleRepaint,
                                    builder: (context, _) {
                                      final m = _resolveCapsule(itemWidth);
                                      final fx = _dragFx.value;

                                      Widget bubble = _WaterBubble(
                                        colors: waterColors,
                                        blobHorizontalInset:
                                            _blobHorizontalInset,
                                        glowBoost: fx.activation,
                                      );

                                      final stretch = fx.stretch;
                                      if (stretch != 0) {
                                        bubble = Transform.scale(
                                          scaleX:
                                              1 + _dragStretch * stretch.abs(),
                                          scaleY:
                                              1 - _maxSquash * stretch.abs(),
                                          alignment: stretch >= 0
                                              ? Alignment.centerLeft
                                              : Alignment.centerRight,
                                          child: bubble,
                                        );
                                      }
                                      if (fx.activation != 0) {
                                        bubble = Transform.scale(
                                          scaleX: 1 +
                                              (_dragMagnify + _dragWiden) *
                                                  fx.activation,
                                          scaleY: 1 +
                                              _dragVerticalSwell *
                                                  fx.activation,
                                          alignment: Alignment.center,
                                          child: bubble,
                                        );
                                      }

                                      final a = fx.activation;
                                      final topInset = _capsuleVerticalInset -
                                          _dragTopOverflow * a;
                                      final bottomInset =
                                          _capsuleVerticalInset -
                                              _dragBottomOverflow * a;

                                      return Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          Positioned(
                                            left: m.left,
                                            width: m.width,
                                            top: topInset,
                                            bottom: bottomInset,
                                            child: bubble,
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                                // Items on top
                                itemsRow,
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Live drag dynamics for the water bubble.
@immutable
class _WaterDragFx {
  const _WaterDragFx({required this.activation, required this.stretch});

  final double activation;
  final double stretch;

  static const _WaterDragFx rest = _WaterDragFx(activation: 0, stretch: 0);
}

/// Pure transparent water bubble colors.
@immutable
class _WaterBubbleColors {
  const _WaterBubbleColors({
    required this.fillTop,
    required this.fillBottom,
    required this.border,
    required this.rimLight,
    required this.specular,
    required this.innerShade,
    required this.glow,
  });

  final Color fillTop;
  final Color fillBottom;
  final Color border;
  final Color rimLight;
  final Color specular;
  final Color innerShade;
  final Color glow;
}

/// Renders the transparent liquid water droplet bubble.
class _WaterBubble extends StatelessWidget {
  const _WaterBubble({
    required this.colors,
    required this.blobHorizontalInset,
    this.glowBoost = 0,
  });

  final _WaterBubbleColors colors;
  final double blobHorizontalInset;
  final double glowBoost;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: blobHorizontalInset),
      child: CustomPaint(
        painter: _WaterBubblePainter(colors: colors, glowBoost: glowBoost),
      ),
    );
  }
}

/// Photorealistic transparent water bubble painter.
class _WaterBubblePainter extends CustomPainter {
  _WaterBubblePainter({required this.colors, required this.glowBoost});

  final _WaterBubbleColors colors;
  final double glowBoost;

  static const double _squircleN = 3.2;
  static const double _lensTaper = 0.24;
  static const double _restWaist = 0.05;
  static const double _squircleBulge = 0.08;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final bulge = glowBoost;
    final body = _squirclePath(rect, bulge: bulge);

    // 1) Soft transparent water halo
    final glowPaint = Paint()
      ..color = colors.glow
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 + 10 * glowBoost);
    canvas.drawPath(
      _squirclePath(rect.inflate(1.5 + 2.0 * glowBoost), bulge: bulge),
      glowPaint,
    );

    // 2) Subtle depth shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.10 + 0.08 * glowBoost)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 5 + 5 * glowBoost);
    canvas.drawPath(
      _squirclePath(rect.shift(Offset(0, 2.0 + 2.5 * glowBoost)), bulge: bulge),
      shadowPaint,
    );

    canvas.save();
    canvas.clipPath(body);

    // 3) Pure water transparent body fill
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [colors.fillTop, colors.fillBottom],
      ).createShader(rect);
    canvas.drawRect(rect, fillPaint);

    // 4) Refractive liquid shading (creates water volume)
    final shadePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.center,
        end: Alignment.bottomCenter,
        colors: [const Color(0x00000000), colors.innerShade],
      ).createShader(rect);
    canvas.drawRect(rect, shadePaint);

    // 5) Bright white specular dome (water surface shine catch)
    final specRect = Rect.fromLTWH(
      size.width * 0.08,
      -size.height * 0.12,
      size.width * 0.84,
      size.height * 0.78,
    );
    final specPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.6,
        colors: [colors.specular, const Color(0x00FFFFFF)],
      ).createShader(specRect);
    canvas.drawOval(specRect, specPaint);

    canvas.restore();

    // 6) Clean crystal meniscus rim light along top edge
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          colors.rimLight,
          colors.border,
          colors.border.withValues(alpha: 0),
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(rect);
    canvas.drawPath(
      _squirclePath(rect.deflate(0.6), bulge: bulge),
      borderPaint,
    );
  }

  Path _squirclePath(Rect rect, {double bulge = 0}) {
    final cx = rect.center.dx;
    final cy = rect.center.dy;
    final a = rect.width / 2;
    final b = rect.height / 2;
    final exp = 2 / _squircleN;
    const steps = 64;
    final path = Path();
    for (var i = 0; i <= steps; i++) {
      final theta = (i / steps) * 2 * math.pi;
      final ct = math.cos(theta);
      final st = math.sin(theta);
      final sx = ct.sign * math.pow(ct.abs(), exp).toDouble();
      final sy = st.sign * math.pow(st.abs(), exp).toDouble();
      final taper = 1 - _lensTaper * sx * sx;
      final swell = 1 + (_restWaist + bulge * _squircleBulge) * (1 - sy.abs());
      final x = cx + a * sx * swell;
      final y = cy + b * sy * taper;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    return path..close();
  }

  @override
  bool shouldRepaint(covariant _WaterBubblePainter old) =>
      old.glowBoost != glowBoost || old.colors != colors;
}

/// Navigation tab item: color illuminates ONLY when the transparent water bubble
/// touches / is centered over the tab.
class _GlassNavItemWidget extends StatefulWidget {
  const _GlassNavItemWidget({
    required this.item,
    required this.selected,
    required this.buttonActiveColor,
    required this.buttonNeutralColor,
    required this.reduceMotion,
    required this.repaint,
    required this.coverage,
    required this.lensIconGain,
    required this.lensLabelGain,
    required this.onTap,
  });

  final GlassNavItemData item;
  final bool selected;
  final Color buttonActiveColor;
  final Color buttonNeutralColor;
  final bool reduceMotion;
  final Listenable repaint;
  final double Function() coverage;
  final double lensIconGain;
  final double lensLabelGain;
  final VoidCallback onTap;

  @override
  State<_GlassNavItemWidget> createState() => _GlassNavItemWidgetState();
}

class _GlassNavItemWidgetState extends State<_GlassNavItemWidget> {
  bool _down = false;

  void _setDown(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    const pressDuration = Duration(milliseconds: 100);
    const switchDuration = Duration(milliseconds: 140);

    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.item.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setDown(true),
        onTapUp: (_) => _setDown(false),
        onTapCancel: () => _setDown(false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down ? 0.90 : 1.0,
          duration: widget.reduceMotion ? Duration.zero : pressDuration,
          curve: Curves.easeOutCubic,
          child: AnimatedBuilder(
            animation: widget.repaint,
            builder: (context, _) {
              final cov = widget.reduceMotion
                  ? (widget.selected ? 1.0 : 0.0)
                  : widget.coverage();

              final color = Color.lerp(
                widget.buttonNeutralColor,
                widget.buttonActiveColor,
                cov,
              )!;

              final isFilled = cov > 0.45;
              final iconData =
                  isFilled ? widget.item.selectedIcon : widget.item.icon;

              Widget icon = AnimatedSwitcher(
                duration: widget.reduceMotion ? Duration.zero : switchDuration,
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: animation,
                  child: FadeTransition(opacity: animation, child: child),
                ),
                child: Icon(
                  iconData,
                  key: ValueKey(isFilled),
                  size: 21,
                  color: color,
                ),
              );

              // Proximity-based magnification & lens refraction
              final iconScale = 1.0 + (0.10 + widget.lensIconGain) * cov;
              icon = Transform.scale(
                scale: iconScale,
                child: icon,
              );

              final labelScale = 1.0 + widget.lensLabelGain * cov;
              Widget label = Transform.scale(
                scale: labelScale,
                child: Text(
                  widget.item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    height: 1.0,
                    fontWeight: cov > 0.45 ? FontWeight.w700 : FontWeight.w500,
                    color: color,
                    letterSpacing: cov > 0.45 ? -0.1 : 0.0,
                  ),
                ),
              );

              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  icon,
                  const SizedBox(height: 3),
                  label,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
