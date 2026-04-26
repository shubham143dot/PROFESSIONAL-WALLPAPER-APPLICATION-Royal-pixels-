import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/entities/wallpaper_entity.dart';
import '../providers/likes_provider.dart';
import '../providers/diamond_provider.dart';
import '../../core/utils/royal_snack_bar.dart';
import '../providers/haptic_provider.dart';
import '../providers/auth_provider.dart';
import '../../../core/widgets/login_required_sheet.dart';


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
    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  void _onViewDetail() {
    _dismiss().then((_) {
      if (mounted) context.push('/detail', extra: widget.wallpaper);
    });
  }

  void _onToggleFavorite() {
    ref.read(hapticProvider.notifier).lightImpact();
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated) {
      showLoginRequiredSheet(context, reason: LoginRequiredReason.favorites);
      return;
    }
    ref.read(likesNotifierProvider.notifier).toggleLike(widget.wallpaper.id);

    final isLikedNow = ref.read(likesProvider).contains(widget.wallpaper.id);
    RoyalSnackBar.show(
      context,
      isLikedNow ? 'Added to Favorites ❤️' : 'Removed from Favorites',
      type: isLikedNow ? SnackBarType.success : SnackBarType.info,
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
    final isUltraHD = widget.wallpaper.isUltraHD;
    final isEditorsChoice = widget.wallpaper.isEditorsChoice;
    final likedIds = ref.watch(likesProvider);
    final isLiked = likedIds.contains(widget.wallpaper.id);
    final diamonds = ref.watch(diamondProvider).diamonds;

    // Tier colour for premium glow
    const Color tierColor = AppColors.goldMid;
    const LinearGradient tierGradient = AppColors.goldGradient;

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
                              color: tierColor.withValues(alpha: isPremium ? 0.45 : 0.18),
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
                                        style: const TextStyle(
                                          color: AppColors.goldLight,
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

                              // Tier badges stack (top-right)
                              Positioned(
                                top: 12,
                                right: 12,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isPremium)
                                      _OverlayBadge(
                                        gradient: AppColors.goldGradient,
                                        glowColor: AppColors.goldMid,
                                        icon: Icons.lock_rounded,
                                        iconColor: Colors.black,
                                        label: 'PRO',
                                        labelColor: Colors.black,
                                      ),
                                    if (isUltraHD) ...[
                                      if (isPremium) const SizedBox(height: 4),
                                      const _OverlayBadge(
                                        gradient: LinearGradient(
                                          colors: [Color(0xFF22D3EE), Color(0xFF0E7490)],
                                        ),
                                        glowColor: Color(0xFF22D3EE),
                                        icon: Icons.hd_rounded,
                                        iconColor: Colors.white,
                                        label: '4K',
                                        labelColor: Colors.white,
                                      ),
                                    ],
                                    if (isEditorsChoice) ...[
                                      if (isPremium || isUltraHD) const SizedBox(height: 4),
                                      const _OverlayBadge(
                                        gradient: LinearGradient(
                                          colors: [Color(0xFFFBBF24), Color(0xFFD97706)],
                                        ),
                                        glowColor: Color(0xFFFBBF24),
                                        icon: Icons.star_rounded,
                                        iconColor: Colors.black,
                                        label: 'PICK',
                                        labelColor: Colors.black,
                                      ),
                                    ],
                                  ],
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
                      isFavorite: isLiked,
                      diamonds: diamonds,
                      tierGradient: tierGradient,
                      tierColor: tierColor,
                      onDownload: _onDownload,
                      onSetWallpaper: _onSetWallpaper,
                      onToggleFavorite: _onToggleFavorite,
                      onUnlockPremium: _onUnlockPremium,
                      onDismiss: _dismiss,
                      onGoToFeed: () async {
                        await _dismiss();
                        if (context.mounted) {
                          context.push('/social-feed', extra: widget.wallpaper.id);
                        }
                      },
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

// ─── Overlay badge (used inside the preview card) ─────────────────────────────

class _OverlayBadge extends StatelessWidget {
  final LinearGradient gradient;
  final Color glowColor;
  final IconData icon;
  final Color iconColor;
  final String label;
  final Color labelColor;

  const _OverlayBadge({
    required this.gradient,
    required this.glowColor,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: 0.5),
            blurRadius: 12,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 9),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              color: labelColor,
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

class _ActionPanel extends ConsumerWidget {

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
  final VoidCallback onGoToFeed;

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
    required this.onGoToFeed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {

    final bottomPad = MediaQuery.of(context).padding.bottom;
    final showPremiumGate = wallpaper.isPremium;

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

              // Tag chips row (Ultra HD + Editor's Choice)
              if (wallpaper.isUltraHD || wallpaper.isEditorsChoice) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (wallpaper.isUltraHD)
                      _TagChip(
                        label: '4K Ultra HD',
                        icon: Icons.hd_rounded,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF22D3EE), Color(0xFF0E7490)],
                        ),
                        textColor: Colors.white,
                      ),
                    if (wallpaper.isUltraHD && wallpaper.isEditorsChoice)
                      const SizedBox(width: 8),
                    if (wallpaper.isEditorsChoice)
                      const _TagChip(
                        label: "Editor's Pick",
                        icon: Icons.star_rounded,
                        gradient: LinearGradient(
                          colors: [Color(0xFFFBBF24), Color(0xFFD97706)],
                        ),
                        textColor: Colors.black,
                      ),
                  ],
                ),
                const SizedBox(height: 14),
              ],

              // Quick action row
              Row(
                children: [
                  _QuickAction(
                    icon: Icons.movie_filter_rounded,
                    label: 'Feed',
                    gradient: const LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)]),
                    onTap: () {
                      ref.read(hapticProvider.notifier).mediumImpact();
                      onGoToFeed();
                    },
                  ),
                  const SizedBox(width: 8),
                  _QuickAction(
                    icon: Icons.download_rounded,
                    label: 'Save',
                    gradient: const LinearGradient(
                        colors: [Color(0xFF34D399), Color(0xFF059669)]),
                    onTap: () {
                      ref.read(hapticProvider.notifier).mediumImpact();
                      onDownload();
                    },
                  ),
                  const SizedBox(width: 8),
                  _QuickAction(
                    icon: Icons.wallpaper_rounded,
                    label: 'Set',
                    gradient: const LinearGradient(
                        colors: [Color(0xFF60A5FA), Color(0xFF2563EB)]),
                    onTap: () {
                      ref.read(hapticProvider.notifier).mediumImpact();
                      onSetWallpaper();
                    },
                  ),
                  const SizedBox(width: 8),
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
                      ref.read(hapticProvider.notifier).lightImpact();
                      onToggleFavorite();
                    },

                  ),
                ],
              ),

              // Premium gate row
              if (showPremiumGate) ...[
                const SizedBox(height: 14),
                _PremiumGateButton(
                  diamonds: diamonds,
                  diamondCost: wallpaper.diamondCost > 0 ? wallpaper.diamondCost : 100,
                  gradient: tierGradient,
                  tierColor: tierColor,
                  onTap: () {
                    ref.read(hapticProvider.notifier).mediumImpact();
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

// ─── Tag chip (ultra HD / editors choice info strip) ─────────────────────────

class _TagChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final LinearGradient gradient;
  final Color textColor;

  const _TagChip({
    required this.label,
    required this.icon,
    required this.gradient,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: textColor, size: 13),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ],
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
  final int diamonds;
  final int diamondCost;
  final LinearGradient gradient;
  final Color tierColor;
  final VoidCallback onTap;

  const _PremiumGateButton({
    required this.diamonds,
    required this.diamondCost,
    required this.gradient,
    required this.tierColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final int requiredDiamonds = diamondCost > 0 ? diamondCost : 100;
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
              Icons.workspace_premium,
              color: canAfford ? Colors.black : tierColor,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              canAfford
                  ? 'Unlock with $requiredDiamonds 💎'
                  : 'Need $requiredDiamonds 💎 · View Details',
              style: TextStyle(
                color: canAfford ? Colors.black : AppColors.textSecondary,
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
