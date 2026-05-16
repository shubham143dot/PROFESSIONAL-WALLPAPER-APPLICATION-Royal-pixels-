// ignore_for_file: deprecated_member_use
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import '../../core/services/adaptive_performance.dart';

import '../../core/theme/app_colors.dart';

// ─── Data model ──────────────────────────────────────────────────────────────

class NavBarItem {
  final IconData activeIcon;
  final IconData inactiveIcon;
  final String label;

  const NavBarItem({
    required this.activeIcon,
    required this.inactiveIcon,
    required this.label,
  });
}

// ─── Main floating nav bar ───────────────────────────────────────────────────
//
// ARCHITECTURE NOTES:
// ─────────────────────────────────────────────────────────────────────────────
// • pageNotifier: a ValueNotifier<double> wired to PageController.page.
//   Updated every frame via PageController.addListener — zero rebuilds.
// • The pill indicator and icon appearances are driven SOLELY by this notifier
//   through AnimatedBuilder / ValueListenableBuilder.
// • Tapping a tab calls onTap(index) → parent animates PageController →
//   notifier updates automatically → pill follows smoothly.
// • During swipe: PageController.page gives sub-integer fractional values →
//   pill and icons interpolate continuously — identical to iOS WhatsApp.
// ─────────────────────────────────────────────────────────────────────────────

class PremiumFloatingNavBar extends StatefulWidget {
  /// Current active page index (integer) — used for haptics & tap routing.
  final int currentIndex;

  /// Called when user taps a tab button.
  final ValueChanged<int> onTap;

  final List<NavBarItem> items;

  /// Extra bottom padding (safe area / system nav bar height).
  final double bottomSafeArea;

  /// The page notifier — must be updated by parent every frame from
  /// PageController.addListener. Drives all continuous animation.
  final ValueNotifier<double> pageNotifier;

  const PremiumFloatingNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    required this.pageNotifier,
    this.bottomSafeArea = 0,
  });

  @override
  State<PremiumFloatingNavBar> createState() => _PremiumFloatingNavBarState();
}

class _PremiumFloatingNavBarState extends State<PremiumFloatingNavBar>
    with SingleTickerProviderStateMixin {
  int? _previousIndex;
  // ── Glow pulse controller (selection feedback only) ───────────────────────
  late AnimationController _glowController;
  late Animation<double> _glowAnim;

  // ── Per-icon press-down state ─────────────────────────────────────────────
  late List<ValueNotifier<bool>> _pressedNotifiers;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _glowAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeOutExpo),
    );
    _pressedNotifiers =
        List.generate(widget.items.length, (_) => ValueNotifier(false));
  }

  @override
  void didUpdateWidget(PremiumFloatingNavBar old) {
    super.didUpdateWidget(old);
    if (old.currentIndex != widget.currentIndex) {
      _previousIndex = old.currentIndex;
      _glowController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    for (final n in _pressedNotifiers) {
      n.dispose();
    }
    super.dispose();
  }

  void _handleTap(int index) {
    if (index == widget.currentIndex) return;
    widget.onTap(index);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: math.max(widget.bottomSafeArea, 12) + 4,
        ),
        child: LayoutBuilder(
          builder: (ctx, constraints) {
            final totalWidth = constraints.maxWidth;

            return _GlassContainer(
              child: SizedBox(
                height: 68,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // ── Layer 1: Pill indicator — continuous motion ───────
                    _ContinuousPill(
                      pageNotifier: widget.pageNotifier,
                      glowAnim: _glowAnim,
                      totalWidth: totalWidth,
                      itemCount: widget.items.length,
                      currentIndex: widget.currentIndex,
                      previousIndex: _previousIndex,
                    ),

                    // ── Layer 2: Icons + labels ───────────────────────────
                    Positioned.fill(
                      child: Row(
                        children: List.generate(widget.items.length, (i) {
                          return _SwipeableNavIcon(
                            item: widget.items[i],
                            index: i,
                            pageNotifier: widget.pageNotifier,
                            currentIndex: widget.currentIndex,
                            previousIndex: _previousIndex,
                            pressedNotifier: _pressedNotifiers[i],
                            onTap: () => _handleTap(i),
                            onTapDown: () => _pressedNotifiers[i].value = true,
                            onTapUp: () => _pressedNotifiers[i].value = false,
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─── Glass container ─────────────────────────────────────────────────────────

class _GlassContainer extends StatelessWidget {
  final Widget child;
  const _GlassContainer({required this.child});

  @override
  Widget build(BuildContext context) {
    final blurEnabled = AdaptivePerformance.enableBackdropBlur;

    if (!blurEnabled) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(35),
          // Phase 9: Added subtle transparency even for low-tier devices
          color: AppColors.bg1.withValues(alpha: 0.92),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 30,
              spreadRadius: -5,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: child,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(35),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(35),
            // Premium glass effect with variable opacity
            color: Colors.white.withValues(alpha: 0.06), 
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.10),
                Colors.white.withValues(alpha: 0.01),
              ],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.18),
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 40,
                spreadRadius: -5,
                offset: const Offset(0, 15),
              ),
              // Subtlest gold highlight for premium feel
              BoxShadow(
                color: AppColors.goldMid.withValues(alpha: 0.04),
                blurRadius: 15,
                spreadRadius: -1,
                offset: const Offset(0, -1),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

// ─── Continuous pill indicator ────────────────────────────────────────────────
//
// Uses Transform.translate — GPU-composited, never triggers layout.
// The notifier value (0.0 → itemCount-1) maps directly to pixel position.

class _ContinuousPill extends StatelessWidget {
  final ValueNotifier<double> pageNotifier;
  final Animation<double> glowAnim;
  final double totalWidth;
  final int itemCount;
  final int currentIndex;
  final int? previousIndex;

  const _ContinuousPill({
    required this.pageNotifier,
    required this.glowAnim,
    required this.totalWidth,
    required this.itemCount,
    required this.currentIndex,
    this.previousIndex,
  });

  @override
  Widget build(BuildContext context) {
    const pillW = 60.0;
    const pillH = 40.0;

    return ValueListenableBuilder<double>(
      valueListenable: pageNotifier,
      builder: (_, page, __) {
        final clamped = page.clamp(0.0, (itemCount - 1).toDouble());
        final slotW = totalWidth / itemCount;
        final dx = clamped * slotW;


        // Determine if we're in a "jump" (transition between non-adjacent tabs)
        final bool isJump = previousIndex != null && (currentIndex - previousIndex!).abs() > 1;
        
        double finalStretch = 0.0;
        if (isJump) {
          // Single smooth stretch for the entire jump distance
          final double totalDist = (currentIndex - previousIndex!).abs().toDouble();
          if (totalDist > 0) {
            final double progress = (page - previousIndex!).abs() / totalDist;
            finalStretch = (0.5 - (0.5 - progress.clamp(0.0, 1.0)).abs()) * 2.0;
          }
        } else {
          // Standard magnetic stretch for adjacent tabs/swipes
          final fraction = (clamped - clamped.round()).abs();
          finalStretch = (0.5 - (0.5 - fraction).abs()) * 2.0;
        }

        final double currentPillW = pillW + (finalStretch * (isJump ? 25 : 15));
        final double currentVisualH = pillH - (finalStretch * (isJump ? 6 : 4));

        return Positioned(
          top: (68 - currentVisualH) / 2,
          left: (slotW / 2) - (currentPillW / 2),
          width: currentPillW,
          height: currentVisualH,
          child: Transform.translate(
            offset: Offset(dx, 0),
            child: AnimatedBuilder(
              animation: glowAnim,
              builder: (context, _) {
                final glowVal = glowAnim.value;
                final double selectionOpacity = (0.8 - glowVal * 0.8).clamp(0.0, 1.0);

                return Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    // 1. Premium Ambient Glow (Persistent soft aura) — High tier only
                    if (AdaptivePerformance.enableComplexShadows)
                      Container(
                        width: pillW * 1.4,
                        height: pillH * 1.2,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.goldMid.withValues(alpha: 0.18),
                              blurRadius: 35,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                      ),

                    // 2. Selection Burst Glow (Fades after click)
                    if (selectionOpacity > 0.01)
                      Container(
                        width: pillW * (1.2 + glowVal * 0.6),
                        height: pillH * (1.2 + glowVal * 0.6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.goldMid.withValues(alpha: selectionOpacity * 0.6),
                              blurRadius: 40 * (1.0 + glowVal),
                              spreadRadius: 8 * glowVal,
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

// ─── Individual swipeable nav icon ───────────────────────────────────────────
//
// Each icon interpolates its appearance based on how close the current page
// is to its own index. At distance = 0 → fully active. At distance ≥ 1 → muted.
// All interpolation done inside ValueListenableBuilder — zero setState.

class _SwipeableNavIcon extends StatelessWidget {
  final NavBarItem item;
  final int index;
  final ValueNotifier<double> pageNotifier;
  final int currentIndex;
  final int? previousIndex;
  final ValueNotifier<bool> pressedNotifier;
  final VoidCallback onTap;
  final VoidCallback onTapDown;
  final VoidCallback onTapUp;

  const _SwipeableNavIcon({
    required this.item,
    required this.index,
    required this.pageNotifier,
    required this.currentIndex,
    this.previousIndex,
    required this.pressedNotifier,
    required this.onTap,
    required this.onTapDown,
    required this.onTapUp,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onTapDown: (_) => onTapDown(),
        onTapUp: (_) => onTapUp(),
        onTapCancel: onTapUp,
        child: ValueListenableBuilder<double>(
          valueListenable: pageNotifier,
          builder: (context, page, _) {
            // Calculate activity based on distance from this icon's index
            final distance = (page - index).abs();
            
            // Logic to prevent intermediate icons from highlighting during a "jump"
            final bool isJump = previousIndex != null && (currentIndex - previousIndex!).abs() > 1;
            final bool isSourceOrTarget = index == currentIndex || index == previousIndex;
            
            double activity;
            if (isJump && !isSourceOrTarget) {
              // Stay muted if we are an intermediate icon during a long jump
              activity = 0.0;
            } else {
              // Normal interpolation (distance 0.0 -> activity 1.0)
              activity = (1.0 - distance).clamp(0.0, 1.0);
            }

            return ValueListenableBuilder<bool>(
              valueListenable: pressedNotifier,
              builder: (_, isPressed, __) {
                // Scale: lerp 0.92 → 1.0 based on activity
                final scale = 0.94 + activity * 0.06;
                // Extra scale squish when pressed
                final finalScale = isPressed ? scale * 0.90 : scale;

                // Vertical lift: active icon rises slightly
                final lift = -activity * 5.0;

                // Opacity: 0.45 → 1.0
                final opacity = 0.5 + activity * 0.5;

                return Transform.translate(
                  offset: Offset(0, lift),
                  child: Transform.scale(
                    scale: finalScale,
                    child: Opacity(
                      opacity: opacity,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Icon — gold ShaderMask fades in with activity
                          _InterpolatedIcon(
                            item: item,
                            activity: activity,
                          ),

                          const SizedBox(height: 5),

                          // Label — weight & color interpolated
                          _InterpolatedLabel(
                            label: item.label,
                            activity: activity,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}


// ─── Interpolated icon (ShaderMask cross-fades in/out) ────────────────────────

class _InterpolatedIcon extends StatelessWidget {
  final NavBarItem item;
  final double activity; // 0.0 → 1.0

  const _InterpolatedIcon({required this.item, required this.activity});

  @override
  Widget build(BuildContext context) {
    // Use Stack to cross-fade between inactive and gold active icon
    return SizedBox(
      width: 26,
      height: 26,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Inactive icon (fades out as activity increases)
          Opacity(
            opacity: (1.0 - activity).clamp(0.0, 1.0),
            child: Icon(
              item.inactiveIcon,
              color: AppColors.textSecondary,
              size: 22,
            ),
          ),

          // Active gold icon (fades in as activity increases)
          Opacity(
            opacity: activity.clamp(0.0, 1.0),
            child: ShaderMask(
              shaderCallback: (b) => AppColors.goldGradient.createShader(b),
              blendMode: BlendMode.srcIn,
              child: Icon(
                item.activeIcon,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Interpolated label ───────────────────────────────────────────────────────

class _InterpolatedLabel extends StatelessWidget {
  final String label;
  final double activity; // 0.0 → 1.0

  const _InterpolatedLabel({required this.label, required this.activity});

  @override
  Widget build(BuildContext context) {
    // Interpolate color: muted → goldLight
    final color = Color.lerp(AppColors.textMuted, AppColors.goldLight, activity)!;

    // Interpolate font weight is hard to do fractionally, so we switch at 0.5
    final weight = activity > 0.5 ? FontWeight.w800 : FontWeight.w500;

    // Letter spacing
    final spacing = 0.2 + activity * 0.2;

    return Text(
      label,
      style: TextStyle(
        fontSize: 9.5,
        fontWeight: weight,
        color: color,
        letterSpacing: spacing,
      ),
    );
  }
}
