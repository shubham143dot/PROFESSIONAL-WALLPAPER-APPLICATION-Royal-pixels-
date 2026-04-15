import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/entities/wallpaper_entity.dart';
import '../providers/favorites_provider.dart';
import '../providers/diamond_provider.dart';
import '../../core/utils/royal_snack_bar.dart';

// ─── Public entry-point ───────────────────────────────────────────────────────

/// Shows the ultra-premium long-press preview overlay.
/// Call this instead of `Navigator.push` — it uses [showGeneralDialog]
/// so the underlying grid stays visible beneath the blur.
Future<void> showWallpaperLongPressPreview(
  BuildContext context,
  WallpaperEntity wallpaper, {
  /// Original card's render-box, used to position the "floating" card
  /// in the exact same place before it scales up.
  RenderBox? cardBox,
}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: false, // We handle dismissal ourselves for animation
    barrierColor: Colors.transparent, // We paint our own animated overlay
    transitionDuration: Duration.zero,
    pageBuilder: (ctx, _, __) => _WallpaperLongPressOverlay(
      wallpaper: wallpaper,
    ),
  );
}

// ─── Overlay widget ───────────────────────────────────────────────────────────

class _WallpaperLongPressOverlay extends ConsumerStatefulWidget {
  final WallpaperEntity wallpaper;

  const _WallpaperLongPressOverlay({required this.wallpaper});

  @override
  ConsumerState<_WallpaperLongPressOverlay> createState() =>
      _WallpaperLongPressOverlayState();
}

class _WallpaperLongPressOverlayState
    extends ConsumerState<_WallpaperLongPressOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  // ── Tween intervals on the single controller ──────────────────────────────
  late final Animation<double> _blur;      // 0 → 10 sigma
  late final Animation<double> _dim;       // 0 → 0.55 opacity
  late final Animation<double> _cardScale; // 1.0 → 1.08
  late final Animation<double> _radius;   // 22 → 28
  late final Animation<double> _panelSlide; // 30px → 0 offset
  late final Animation<double> _panelFade;  // 0 → 1

  bool _dismissed = false;

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Background effects  (0% – 70% of timeline)
    _blur = Tween<double>(begin: 0, end: 10).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0, 0.70, curve: Curves.easeOut)),
    );
    _dim = Tween<double>(begin: 0, end: 0.55).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0, 0.70, curve: Curves.easeOut)),
    );

    // Card scale + radius  (0% – 80%)
    _cardScale = Tween<double>(begin: 1.0, end: 1.09).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0, 0.80, curve: Curves.fastOutSlowIn)),
    );
    _radius = Tween<double>(begin: 22, end: 28).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0, 0.80, curve: Curves.fastOutSlowIn)),
    );

    // Action panel  (delayed to 30% – 100%)
    _panelSlide = Tween<double>(begin: 30, end: 0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.30, 1.0, curve: Curves.easeOutCubic)),
    );
    _panelFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.30, 1.0, curve: Curves.easeOut)),
    );

    // Start immediately — feels instant
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    if (_dismissed) return;
    _dismissed = true;
    await _ctrl.reverse();
    if (mounted) Navigator.of(context).pop();
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  void _onViewDetail() {
    _dismiss().then((_) {
      if (mounted) context.push('/detail', extra: widget.wallpaper);
    });
  }

  void _onToggleFavorite() {
    HapticFeedback.lightImpact();
    ref.read(favoritesProvider.notifier).toggleFavorite(widget.wallpaper.id);
    final isFav = ref.read(favoritesProvider).contains(widget.wallpaper.id);
    RoyalSnackBar.show(
      context,
      isFav ? 'Added to Favorites ❤️' : 'Removed from Favorites',
      type: isFav ? SnackBarType.success : SnackBarType.info,
    );
  }

  void _onDownload() {
    _dismiss().then((_) {
      if (mounted) context.push('/detail', extra: widget.wallpaper);
      // The detail page has the full download workflow (ad gating, permissions, etc.)
    });
  }

  void _onSetWallpaper() {
    _dismiss().then((_) {
      if (mounted) context.push('/detail', extra: widget.wallpaper);
    });
  }

  void _onUnlockPremium() {
    _dismiss().then((_) {
      if (mounted) context.push('/detail', extra: widget.wallpaper);
    });
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isPremium = widget.wallpaper.isPremium;
    final isSpecial = widget.wallpaper.isSpecial;
    final favorites = ref.watch(favoritesProvider);
    final isFavorite = favorites.contains(widget.wallpaper.id);
    final diamonds = ref.watch(diamondProvider).diamonds;

    // Tier colours
    final Color tierColor = isSpecial
        ? AppColors.accentPurple
        : isPremium
            ? AppColors.goldMid
            : const Color(0xFF3B82F6);

    final LinearGradient tierGradient = isSpecial
        ? AppColors.specialGradient
        : isPremium
            ? AppColors.goldGradient
            : const LinearGradient(
                colors: [Color(0xFF60A5FA), Color(0xFF2563EB)]);

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Material(
          color: Colors.transparent,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── 1. Tap-outside barrier ────────────────────────────────────
              GestureDetector(
                onTap: _dismiss,
                child: Container(color: Colors.transparent),
              ),

              // ── 2. Blurred + dimmed background ───────────────────────────
              IgnorePointer(
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: _blur.value,
                    sigmaY: _blur.value,
                  ),
                  child: Container(
                    color: Colors.black.withValues(alpha: _dim.value),
                  ),
                ),
              ),

              // ── 3. Floating wallpaper card (scaled-up, centred) ──────────
              Center(
                child: GestureDetector(
                  onTap: _onViewDetail,
                  child: Transform.scale(
                    scale: _cardScale.value,
                    child: RepaintBoundary(
                      child: Container(
                        width: size.width * 0.72,
                        height: size.height * 0.52,
                        decoration: BoxDecoration(
                          borderRadius:
                              BorderRadius.circular(_radius.value),
                          boxShadow: [
                            BoxShadow(
                              color: tierColor.withValues(alpha: 0.45),
                              blurRadius: 40,
                              spreadRadius: 4,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius:
                              BorderRadius.circular(_radius.value),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              // Image
                              CachedNetworkImage(
                                imageUrl: widget.wallpaper.optimizedUrl,
                                fit: BoxFit.cover,
                                memCacheHeight: 800,
                                errorWidget: (_, __, ___) => Container(
                                  color: AppColors.bg2,
                                  child: const Icon(
                                      Icons.broken_image_outlined,
                                      color: Colors.white24,
                                      size: 48),
                                ),
                              ),

                              // Bottom gradient
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                height: 120,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.transparent,
                                        Colors.black.withValues(alpha: 0.85),
                                      ],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                  ),
                                ),
                              ),

                              // Title + category
                              Positioned(
                                bottom: 14,
                                left: 14,
                                right: 14,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (widget.wallpaper.category.isNotEmpty)
                                      Text(
                                        widget.wallpaper.category.toUpperCase(),
                                        style: TextStyle(
                                          color: tierColor.withValues(alpha: 0.9),
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    const SizedBox(height: 3),
                                    Text(
                                      widget.wallpaper.title.isNotEmpty
                                          ? widget.wallpaper.title
                                          : widget.wallpaper.category,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.2,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),

                              // Tier badge (top-right)
                              Positioned(
                                top: 12,
                                right: 12,
                                child: _TierBadge(
                                  isSpecial: isSpecial,
                                  isPremium: isPremium,
                                  gradient: tierGradient,
                                ),
                              ),

                              // "Tap to view" hint (top-left)
                              Positioned(
                                top: 12,
                                left: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.45),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.touch_app_rounded,
                                          color: Colors.white70, size: 11),
                                      SizedBox(width: 4),
                                      Text(
                                        'Tap to open',
                                        style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ── 4. Glassmorphism action panel (bottom) ───────────────────
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Transform.translate(
                  offset: Offset(0, _panelSlide.value),
                  child: Opacity(
                    opacity: _panelFade.value,
                    child: _ActionPanel(
                      wallpaper: widget.wallpaper,
                      isFavorite: isFavorite,
                      diamonds: diamonds,
                      tierGradient: tierGradient,
                      tierColor: tierColor,
                      onDownload: _onDownload,
                      onSetWallpaper: _onSetWallpaper,
                      onToggleFavorite: _onToggleFavorite,
                      onUnlockPremium: _onUnlockPremium,
                      onDismiss: _dismiss,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Tier badge ───────────────────────────────────────────────────────────────

class _TierBadge extends StatelessWidget {
  final bool isSpecial;
  final bool isPremium;
  final LinearGradient gradient;

  const _TierBadge({
    required this.isSpecial,
    required this.isPremium,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    if (!isSpecial && !isPremium) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isSpecial ? AppColors.accentPurple : AppColors.goldMid)
                .withValues(alpha: 0.5),
            blurRadius: 12,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSpecial ? Icons.auto_awesome : Icons.lock_rounded,
            color: isSpecial ? Colors.white : Colors.black,
            size: 9,
          ),
          const SizedBox(width: 3),
          Text(
            isSpecial ? 'SPECIAL' : 'PRO',
            style: TextStyle(
              color: isSpecial ? Colors.white : Colors.black,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Action panel ─────────────────────────────────────────────────────────────

class _ActionPanel extends StatelessWidget {
  final WallpaperEntity wallpaper;
  final bool isFavorite;
  final int diamonds;
  final LinearGradient tierGradient;
  final Color tierColor;
  final VoidCallback onDownload;
  final VoidCallback onSetWallpaper;
  final VoidCallback onToggleFavorite;
  final VoidCallback onUnlockPremium;
  final VoidCallback onDismiss;

  const _ActionPanel({
    required this.wallpaper,
    required this.isFavorite,
    required this.diamonds,
    required this.tierGradient,
    required this.tierColor,
    required this.onDownload,
    required this.onSetWallpaper,
    required this.onToggleFavorite,
    required this.onUnlockPremium,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final showPremiumGate = wallpaper.isPremium || wallpaper.isSpecial;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 24 + bottomPad),
          decoration: BoxDecoration(
            color: AppColors.bg0.withValues(alpha: 0.75),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: const Border(
              top: BorderSide(color: AppColors.glassBorder, width: 0.8),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),

              // Quick action row
              Row(
                children: [
                  _QuickAction(
                    icon: Icons.download_rounded,
                    label: 'Download',
                    gradient: const LinearGradient(
                        colors: [Color(0xFF34D399), Color(0xFF059669)]),
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      onDownload();
                    },
                  ),
                  const SizedBox(width: 12),
                  _QuickAction(
                    icon: Icons.wallpaper_rounded,
                    label: 'Set Wallpaper',
                    gradient: const LinearGradient(
                        colors: [Color(0xFF60A5FA), Color(0xFF2563EB)]),
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      onSetWallpaper();
                    },
                  ),
                  const SizedBox(width: 12),
                  _QuickAction(
                    icon: isFavorite
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    label: isFavorite ? 'Unfave' : 'Favorite',
                    gradient: LinearGradient(
                      colors: isFavorite
                          ? [const Color(0xFFF87171), const Color(0xFFDC2626)]
                          : [
                              Colors.white.withValues(alpha: 0.15),
                              Colors.white.withValues(alpha: 0.08),
                            ],
                    ),
                    iconColor: isFavorite ? Colors.white : Colors.white70,
                    labelColor: isFavorite ? Colors.white : Colors.white60,
                    hasBorder: !isFavorite,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      onToggleFavorite();
                    },
                  ),
                ],
              ),

              // Premium gate row
              if (showPremiumGate) ...[
                const SizedBox(height: 14),
                _PremiumGateButton(
                  isSpecial: wallpaper.isSpecial,
                  diamonds: diamonds,
                  price: wallpaper.price,
                  gradient: tierGradient,
                  tierColor: tierColor,
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    onUnlockPremium();
                  },
                ),
              ],

              const SizedBox(height: 10),

              // Close hint
              GestureDetector(
                onTap: onDismiss,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    'Tap anywhere to close',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontSize: 11,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Quick action button ──────────────────────────────────────────────────────

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final LinearGradient gradient;
  final Color iconColor;
  final Color labelColor;
  final bool hasBorder;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.gradient,
    required this.onTap,
    this.iconColor = Colors.white,
    this.labelColor = Colors.white,
    this.hasBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedScale(
          scale: 1.0,
          duration: const Duration(milliseconds: 120),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              gradient: hasBorder ? null : gradient,
              color: hasBorder ? Colors.transparent : null,
              borderRadius: BorderRadius.circular(18),
              border: hasBorder
                  ? Border.all(color: Colors.white.withValues(alpha: 0.18), width: 1)
                  : null,
              boxShadow: hasBorder
                  ? []
                  : [
                      BoxShadow(
                        color: gradient.colors.last.withValues(alpha: 0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: iconColor, size: 22),
                const SizedBox(height: 5),
                Text(
                  label,
                  style: TextStyle(
                    color: labelColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Premium gate button ──────────────────────────────────────────────────────

class _PremiumGateButton extends StatelessWidget {
  final bool isSpecial;
  final int diamonds;
  final double price;
  final LinearGradient gradient;
  final Color tierColor;
  final VoidCallback onTap;

  const _PremiumGateButton({
    required this.isSpecial,
    required this.diamonds,
    required this.price,
    required this.gradient,
    required this.tierColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final int requiredDiamonds = isSpecial ? 70 : 30;
    final bool canAfford = diamonds >= requiredDiamonds;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
        decoration: BoxDecoration(
          gradient: canAfford ? gradient : null,
          color: canAfford ? null : AppColors.bg2,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: canAfford
                ? Colors.transparent
                : tierColor.withValues(alpha: 0.30),
          ),
          boxShadow: canAfford
              ? [
                  BoxShadow(
                    color: tierColor.withValues(alpha: 0.40),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  )
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSpecial ? Icons.auto_awesome : Icons.workspace_premium,
              color: canAfford
                  ? (isSpecial ? Colors.white : Colors.black)
                  : tierColor,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              canAfford
                  ? 'Unlock with $requiredDiamonds 💎'
                  : 'Need $requiredDiamonds 💎 · View Details',
              style: TextStyle(
                color: canAfford
                    ? (isSpecial ? Colors.white : Colors.black)
                    : AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
