import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/animation_constants.dart';
import '../../../core/utils/safe_tap.dart';

import 'dart:ui';
import '../../../core/constants/app_constants.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:shimmer/shimmer.dart';
import '../../../domain/entities/wallpaper_entity.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/diamond_provider.dart';
import '../../providers/wallpaper_provider.dart';
import '../../providers/guest_streak_provider.dart';
import '../../widgets/wallpaper_card.dart';
import '../../widgets/diamond_counter_widget.dart';
import '../../widgets/wallpaper_long_press_preview.dart';
import '../../../core/widgets/login_required_sheet.dart';
import 'wallpaper_search_delegate.dart';
import '../my_wallpapers/my_wallpapers_page.dart';
import '../category/categories_list_page.dart';
import '../diamond/diamond_reward_popup.dart';
import '../../providers/notification_provider.dart';
import '../../providers/haptic_provider.dart';
import '../../widgets/haptic_settings_sheet.dart';
import '../../providers/parallax_provider.dart';


// ─── Filter enum ─────────────────────────────────────────────────────────────
enum WallpaperFilter { all, free, premium, editorsChoice, ultraHD }

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with TickerProviderStateMixin {
  // Bottom nav index: 0=Home, 1=Categories, 2=My Wallpapers, 3=Favorites, 4=Profile
  int _navIndex = 0;
  late final PageController _pageController;

  // Active wallpaper filter (on Home tab)
  WallpaperFilter _filter = WallpaperFilter.all;
  bool _rewardPopupShown = false;


  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _navIndex);
    Future.microtask(
        () => ref.read(wallpaperProvider.notifier).loadWallpapers());
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Show daily reward popup once per page lifecycle when user is logged in
    final diamond = ref.read(diamondProvider);
    if (!_rewardPopupShown &&
        diamond.canClaimToday &&
        diamond.pendingReward != null &&
        ref.read(authProvider).user != null) {
      _rewardPopupShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          showDailyRewardPopup(context, ref, diamond.pendingReward!);
        }
      });
    }
  }

  void _openSearch() {
    SafeTap.run('home_search', () {
      final wallpaperState = ref.read(wallpaperProvider);
      final allWallpapers = [
        ...wallpaperState.freeWallpapers,
        ...wallpaperState.premiumWallpapers,
      ];
      final isPro = ref.read(authProvider).user?.isSubscribed ?? false;
      showSearch(
        context: context,
        delegate: WallpaperSearchDelegate(allWallpapers, isPro: isPro),
      );
    });
  }

  // ── Apply filter to full wallpaper list ────────────────────────────────────
  List<WallpaperEntity> _filteredWallpapers(WallpaperState state) {
    final all = [...state.freeWallpapers, ...state.premiumWallpapers];
    switch (_filter) {
      case WallpaperFilter.free:
        return state.freeWallpapers;
      case WallpaperFilter.premium:
        return state.premiumWallpapers;
      case WallpaperFilter.editorsChoice:
        return all.where((wp) => wp.isEditorsChoice).toList();
      case WallpaperFilter.ultraHD:
        return all.where((wp) => wp.isUltraHD).toList();
      case WallpaperFilter.all:
        return all;
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallpaperState = ref.watch(wallpaperProvider);
    final userState = ref.watch(authProvider);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      // ── AppBar ─────────────────────────────────────────────────────────────
      appBar: AppBar(
        flexibleSpace: RepaintBoundary(
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.5),
                    radius: 1.5,
                    colors: [
                      AppColors.bg1.withAlpha(180),
                      AppColors.bg0.withAlpha(220),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        elevation: 4,
        shadowColor: Colors.black.withAlpha(100),
        title: ShaderMask(
          shaderCallback: (bounds) =>
              AppColors.goldGradient.createShader(bounds),
          child: Text(
            _getAppBarTitle(),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              letterSpacing: 2.0,
              color: Colors.white,
              fontSize: 20,
            ),
          ),
        ),
        actions: _getAppBarActions(userState),
      ),
      // ── Bottom Navigation Bar ──────────────────────────────────────────────
      bottomNavigationBar: _buildBottomNav(userState, bottomPadding),
      // ── Body ───────────────────────────────────────────────────────────────
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          if (_navIndex != index) {
            ref.read(hapticProvider.notifier).lightImpact();
            setState(() => _navIndex = index);
          }
        },
        physics: const BouncingScrollPhysics(),
        children: [
          // Tab 0: Home wallpaper grid
          _buildHomeTab(wallpaperState),
          // Tab 1: Categories
          const CategoriesListPage(embeddedMode: true),
          // Tab 2: My Wallpapers (downloaded)
          const MyWallpapersPage(embeddedMode: true),
          // Tab 3: Favorites (gated for guests)
          userState.isGuest
              ? _buildGuestLockedTab(
                  icon: Icons.favorite_rounded,
                  title: 'Save Your Favorites',
                  subtitle:
                      'Sign in to save and sync your favorite wallpapers across all your devices.',
                  reason: LoginRequiredReason.favorites,
                )
              : const MyWallpapersPage(
                  embeddedMode: true, showFavoritesOnly: true),
          // Tab 4: Profile
          userState.isGuest
              ? _buildGuestProfileTab()
              : _buildProfileTab(userState),
        ],
      ),
    );
  }

  // ── Bottom navigation bar ──────────────────────────────────────────────────
  Widget _buildBottomNav(AuthState userState, double bottomPadding) {
    final items = [
      _NavItem(Icons.home_rounded, Icons.home_outlined, 'Home'),
      _NavItem(Icons.grid_view_rounded, Icons.grid_view_outlined, 'Categories'),
      _NavItem(Icons.download_done_rounded, Icons.download_outlined, 'My Saved'),
      _NavItem(Icons.favorite_rounded, Icons.favorite_border_rounded, 'Favorites'),
      _NavItem(Icons.person_rounded, Icons.person_outline_rounded, 'Profile'),
    ];

    return RepaintBoundary(
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
          child: Container(
            padding: EdgeInsets.only(
              bottom: bottomPadding > 0 ? bottomPadding : 8,
              top: 8,
            ),
            decoration: BoxDecoration(
              border: const Border(
                top: BorderSide(color: AppColors.glassBorder, width: 0.5),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(120),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(items.length, (i) {
                final item = items[i];
                final isActive = _navIndex == i;
                return _buildNavItem(item, i, isActive);
              }),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(_NavItem item, int index, bool isActive) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          SafeTap.run('nav_item_$index', () {
            if (_navIndex != index) {
              ref.read(hapticProvider.notifier).selectionClick();
              _pageController.jumpToPage(index);
            }
          });
        },
        child: SizedBox(
          height: 72, 
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                scale: isActive ? 1.12 : 1.0,
                duration: AppAnimations.interactionQuick,
                curve: Curves.easeOutBack,
                child: AnimatedContainer(
                  duration: AppAnimations.interactionQuick,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.goldMid.withAlpha(35)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: AnimatedSwitcher(
                    duration: AppAnimations.interactionQuick,
                    child: isActive
                        ? ShaderMask(
                            key: const ValueKey('active'),
                            shaderCallback: (b) =>
                                AppColors.goldGradient.createShader(b),
                            child: Icon(item.activeIcon,
                                color: Colors.white, size: 24),
                          )
                        : Icon(item.inactiveIcon,
                            key: const ValueKey('inactive'),
                            color: AppColors.textMuted,
                            size: 22),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: AppAnimations.interactionQuick,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                  color: isActive ? AppColors.goldLight : AppColors.textMuted,
                  letterSpacing: 0.3,
                ),
                child: Text(item.label),
              ),
            ],
          ),
        ),
      ),
    );
  }


  // ── Home tab: filter chips + wallpaper grid ────────────────────────────────
  Widget _buildHomeTab(WallpaperState wallpaperState) {
    final filtered = _filteredWallpapers(wallpaperState);
    return Column(
      children: [
        // Filter chips strip
        _buildFilterStrip(wallpaperState),
        _buildColorSwatches(),
        const SizedBox(height: 12),
        // Grid
        Expanded(
          child: wallpaperState.isLoading
              ? _buildSkeleton()
              : filtered.isEmpty
                  ? _buildEmptyState()
                  : _buildGrid(filtered),
        ),
      ],
    );
  }

  // ── Filter chips ───────────────────────────────────────────────────────────
  Widget _buildFilterStrip(WallpaperState state) {
    final all = [...state.freeWallpapers, ...state.premiumWallpapers];
    final filters = [
      (WallpaperFilter.all,    Icons.auto_awesome_mosaic_outlined, 'All',          all.length),
      (WallpaperFilter.free,   Icons.wallpaper_outlined,           'Free',         state.freeWallpapers.length),
      (WallpaperFilter.premium, Icons.diamond_outlined,            'Premium',      state.premiumWallpapers.length),
      (WallpaperFilter.editorsChoice, Icons.star_rounded,          "Editor's",    all.where((w) => w.isEditorsChoice).length),
      (WallpaperFilter.ultraHD, Icons.hd_rounded,                  '4K',           all.where((w) => w.isUltraHD).length),
    ];

    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 64,
        bottom: 8,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: filters.map((f) {
            final isActive = _filter == f.$1;

            // Pick chip accent colour by filter type
            Color chipColor;
            LinearGradient? chipGradient;
            if (f.$1 == WallpaperFilter.editorsChoice) {
              chipColor = const Color(0xFFFBBF24);
              chipGradient = isActive
                  ? const LinearGradient(colors: [Color(0xFFFBBF24), Color(0xFFD97706)])
                  : null;
            } else if (f.$1 == WallpaperFilter.ultraHD) {
              chipColor = const Color(0xFF22D3EE);
              chipGradient = isActive
                  ? const LinearGradient(colors: [Color(0xFF22D3EE), Color(0xFF0E7490)])
                  : null;
            } else {
              chipColor = AppColors.goldMid;
              chipGradient = isActive ? AppColors.goldGradient : null;
            }

            // Text/icon dark for light-background chips, white for dark ones
            final bool lightBg = isActive &&
                (f.$1 == WallpaperFilter.premium ||
                    f.$1 == WallpaperFilter.all ||
                    f.$1 == WallpaperFilter.free ||
                    f.$1 == WallpaperFilter.editorsChoice);
            final contentColor = isActive
                ? (lightBg ? Colors.black : Colors.white)
                : AppColors.textSecondary;

            return GestureDetector(
              onTap: () {
                SafeTap.run('filter_${f.$1.name}', () {
                  ref.read(hapticProvider.notifier).selectionClick();
                  setState(() => _filter = f.$1);
                });
              },
              child: AnimatedContainer(
                duration: AppAnimations.interactionQuick,
                margin: const EdgeInsets.only(right: 10),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: chipGradient,
                  color: isActive ? null : AppColors.bg2.withAlpha(150),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: isActive ? Colors.white.withAlpha(100) : chipColor.withAlpha(40),
                    width: 0.8,
                  ),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: chipColor.withAlpha(100),
                            blurRadius: 20,
                            spreadRadius: 1,
                            offset: const Offset(0, 4),
                          )
                        ]
                      : [],
                ),
                child: AnimatedScale(
                  duration: AppAnimations.interactionQuick,
                  scale: isActive ? 1.06 : 1.0,
                  curve: Curves.easeOutBack,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(f.$2, size: 14, color: contentColor),
                      const SizedBox(width: 6),
                      Text(
                        f.$3,
                        style: TextStyle(
                          color: isActive ? contentColor : AppColors.textSecondary,
                          fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                      if (!state.isLoading && f.$4 > 0) ...[
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: isActive
                                ? Colors.black.withAlpha(50)
                                : chipColor.withAlpha(25),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${f.$4}',
                            style: TextStyle(
                              color: isActive
                                  ? (lightBg ? Colors.black54 : Colors.white70)
                                  : chipColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── Color Swatches ─────────────────────────────────────────────────────────
  Widget _buildColorSwatches() {
    final colors = [
      ('Black', Colors.black),
      ('White', Colors.white),
      ('Blue', Colors.blue),
      ('Purple', Colors.purple),
      ('Red', Colors.redAccent),
      ('Green', Colors.green),
      ('Pink', Colors.pinkAccent),
      ('Yellow', Colors.amber),
      ('Orange', Colors.orange),
      ('Teal', Colors.teal),
    ];

    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        physics: const BouncingScrollPhysics(),
        itemCount: colors.length,
        itemBuilder: (context, index) {
          final colorData = colors[index];
          return GestureDetector(
            onTap: () {
              ref.read(hapticProvider.notifier).lightImpact();
              SafeTap.run('color_search_${colorData.$1}', () {
                final wallpaperState = ref.read(wallpaperProvider);
                final allWallpapers = [
                  ...wallpaperState.freeWallpapers,
                  ...wallpaperState.premiumWallpapers,
                ];
                final isPro = ref.read(authProvider).user?.isSubscribed ?? false;
                
                showSearch(
                  context: context,
                  query: colorData.$1.toLowerCase(),
                  delegate: WallpaperSearchDelegate(allWallpapers, isPro: isPro),
                );
              });
            },
            child: Container(
              margin: const EdgeInsets.only(right: 14),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colorData.$2,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withAlpha(colorData.$2 == Colors.black ? 80 : 30),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: colorData.$2.withAlpha(80),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Skeleton ───────────────────────────────────────────────────────────────
  Widget _buildSkeleton() {
    return MasonryGridView.builder(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 110 + MediaQuery.of(context).padding.bottom),
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      gridDelegate:
          const SliverSimpleGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      itemCount: 10,
      cacheExtent: 800,
      addRepaintBoundaries: true,
      itemBuilder: (context, index) {
        final heights = [200.0, 260.0, 180.0, 240.0, 220.0];
        final h = heights[index % heights.length];
        return _SkeletonCard(height: h);
      },
    );
  }

  // ── Grid ───────────────────────────────────────────────────────────────────
  Widget _buildGrid(List<WallpaperEntity> wallpapers) {
    return MasonryGridView.builder(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 110 + MediaQuery.of(context).padding.bottom),
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      gridDelegate:
          const SliverSimpleGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      itemCount: wallpapers.length,
      cacheExtent: 1500,
      addRepaintBoundaries: true,
      itemBuilder: (context, index) {
        final wp = wallpapers[index];
        final heights = [200.0, 260.0, 180.0, 240.0, 220.0];
        final h = heights[index % heights.length];
        return SizedBox(
          height: h,
          child: WallpaperCard(
            key: ValueKey(wp.id),
            wallpaper: wp,
            onTap: () {
              // Pre-load full image for detail page
              precacheImage(CachedNetworkImageProvider(wp.optimizedUrl), context);
              context.push('/detail', extra: wp);
            },
            onLongPress: () => showWallpaperLongPressPreview(context, wp),
          ),
        )
            .animate(
              delay: (index * AppAnimations.staggeringDelay.inMilliseconds).ms,
            )
            .fade(duration: 600.ms, curve: Curves.easeOut)
            .slideY(
                begin: AppAnimations.cardSlideOffset,
                end: 0,
                duration: AppAnimations.smoothEntrance,
                curve: AppAnimations.easeOutExpo);
      },
    );
  }

  // ── Empty state ────────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ShaderMask(
            shaderCallback: (b) =>
                AppColors.goldGradient.createShader(b),
            child: const Icon(Icons.photo_library_outlined,
                size: 64, color: Colors.white),
          ),
          const SizedBox(height: 16),
          const Text(
            'No wallpapers here yet',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Try a different filter',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ],
      )
          .animate()
          .fade(duration: 500.ms)
          .scale(begin: const Offset(0.9, 0.9), duration: 500.ms),
    );
  }

  // ── Guest: locked tab placeholder ─────────────────────────────────────────
  Widget _buildGuestLockedTab({
    required IconData icon,
    required String title,
    required String subtitle,
    required LoginRequiredReason reason,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: AppColors.goldGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.goldMid.withAlpha(80),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.black, size: 38),
            )
                .animate()
                .scale(
                    begin: const Offset(0.7, 0.7),
                    duration: 500.ms,
                    curve: Curves.elasticOut)
                .fade(duration: 300.ms),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
              textAlign: TextAlign.center,
            ).animate().fade(delay: 100.ms, duration: 400.ms),
            const SizedBox(height: 10),
            Text(
              subtitle,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.55,
              ),
              textAlign: TextAlign.center,
            ).animate().fade(delay: 150.ms, duration: 400.ms),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
              onTap: () {
                ref.read(hapticProvider.notifier).lightImpact();
                showLoginRequiredSheet(context, reason: reason);
              },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: AppColors.goldGradient,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.goldMid.withAlpha(80),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/google_logo.png',
                          width: 20,
                          height: 20,
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Sign In with Google',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                ),
              ),
            ).animate().fade(delay: 200.ms, duration: 400.ms),
          ],
        ),
      ),
    );
  }

  // ── Guest profile tab ──────────────────────────────────────────────────────
  Widget _buildGuestProfileTab() {
    return Consumer(builder: (context, ref, _) {
      final streakState = ref.watch(guestStreakProvider);
      final streak = streakState.streak;

      return CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                  20, MediaQuery.of(context).padding.top + 80, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Guest identity card ─────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.bg1,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: AppColors.glassBorder, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(100),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 76,
                              height: 76,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.bg2,
                                border: Border.all(color: AppColors.glassBorder, width: 2),
                              ),
                              child: const Icon(Icons.person_outline_rounded,
                                  color: AppColors.textMuted, size: 38),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Guest User',
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  // Identity hint bar
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: AppColors.bg2.withAlpha(150),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: AppColors.glassBorder, width: 0.8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.info_outline_rounded, size: 12, color: AppColors.textMuted),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Sign in to sync your data',
                                          style: TextStyle(
                                            color: AppColors.textMuted.withAlpha(200),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppColors.bg2,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.glassBorder),
                              ),
                              child: const Text(
                                'GUEST',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Divider(color: AppColors.divider.withAlpha(50), height: 1),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatItem('Diamonds', '0', Icons.diamond_rounded, AppColors.textMuted),
                            _buildStatItem('Streak', '${streak}d', Icons.local_fire_department_rounded, Colors.orangeAccent),
                            _buildStatItem('Saved', '0', Icons.download_done_rounded, AppColors.textMuted),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ── Daily streak card (Interactive) ──────────────────
                  const _ProfileGroupLabel(label: 'DAILY REWARDS'),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.bg1,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.goldMid.withAlpha(40), width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('🔥', style: TextStyle(fontSize: 22)),
                            const SizedBox(width: 12),
                            Text(
                              '$streak Day Streak',
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const Spacer(),
                            if (streakState.canClaimToday)
                              GestureDetector(
                                onTap: () async {
                                  ref.read(hapticProvider.notifier).lightImpact();
                                  await ref.read(guestStreakProvider.notifier).claimStreak();
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    gradient: AppColors.goldGradient,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'CHECK IN',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(7, (i) {
                            final day = i + 1;
                            final isCollected = day <= (streak % 7 == 0 && streak > 0 ? 7 : streak % 7);
                            return Column(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: isCollected ? AppColors.goldGradient : null,
                                    color: isCollected ? null : AppColors.bg2,
                                    border: Border.all(
                                      color: isCollected ? Colors.transparent : AppColors.glassBorder,
                                      width: 1,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '$day',
                                      style: TextStyle(
                                        color: isCollected ? Colors.black : AppColors.textMuted,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(day == 7 ? '🎁' : '💎', style: const TextStyle(fontSize: 10)),
                              ],
                            );
                          }),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ── Sign In CTA ────────────────────────────────────
                  const _ProfileGroupLabel(label: 'ACCOUNT'),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () {
                      ref.read(hapticProvider.notifier).lightImpact();
                      showLoginRequiredSheet(context, reason: LoginRequiredReason.general);
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        gradient: AppColors.goldGradient,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.goldMid.withAlpha(80),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              'assets/google_logo.png',
                              width: 22,
                              height: 22,
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Sign In with Google',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  _ProfileMenuTile(
                    icon: Icons.info_outline_rounded,
                    label: 'About Royal Pixels',
                    subtitle: 'Version ${AppConstants.appVersion}',
                    onTap: () => context.push('/about'),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    });
  }

  // ── Profile tab ────────────────────────────────────────────────────────────
  Widget _buildProfileTab(AuthState userState) {
    final user = userState.user;
    final isSubscribed = user?.isSubscribed ?? false;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
                20, MediaQuery.of(context).padding.top + 80, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── User identity card ───────────────────────────────
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.bg1,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: isSubscribed 
                          ? AppColors.goldMid.withAlpha(60) 
                          : AppColors.glassBorder, 
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(100),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                      if (isSubscribed)
                        BoxShadow(
                          color: AppColors.goldMid.withAlpha(20),
                          blurRadius: 30,
                          spreadRadius: -5,
                        ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          // Avatar with gold/premium ring
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 76,
                                height: 76,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: isSubscribed 
                                      ? AppColors.goldRingGradient 
                                      : LinearGradient(colors: [AppColors.bg3, AppColors.bg2]),
                                ),
                              ),
                              Container(
                                width: 70,
                                height: 70,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.bg1,
                                ),
                                child: Center(
                                  child: Text(
                                    (user?.name ?? 'G')[0].toUpperCase(),
                                    style: TextStyle(
                                      color: isSubscribed ? AppColors.goldLight : AppColors.textPrimary,
                                      fontSize: 28,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                              if (isSubscribed)
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: AppColors.goldMid,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.check_rounded, color: Colors.black, size: 12),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        user?.name ?? 'Guest User',
                                        style: const TextStyle(
                                          color: AppColors.textPrimary,
                                          fontSize: 20,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -0.5,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (isSubscribed) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          gradient: AppColors.goldGradient,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Text(
                                          'PRO',
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 10),
                                // Gmail account bar
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.bg2.withAlpha(180),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AppColors.glassBorder, width: 0.8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.alternate_email_rounded, size: 12, color: AppColors.goldMid),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          user?.email ?? 'guest@royalpixels.app',
                                          style: const TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                      Divider(color: AppColors.divider.withAlpha(50), height: 1),
                      const SizedBox(height: 20),
                      
                      // ── Stats row ───────────────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem('Diamonds', '${user?.diamonds ?? 0}', Icons.diamond_rounded, AppColors.goldMid),
                          _buildStatItem('Streak', '${user?.streak ?? 0}d', Icons.local_fire_department_rounded, Colors.orangeAccent),
                          _buildStatItem('Saved', '${user?.ownedWallpaperCount ?? 0}', Icons.download_done_rounded, Colors.blueAccent),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // ── Membership Group ─────────────────────────────────
                const _ProfileGroupLabel(label: 'MEMBERSHIP & WALLET'),
                const SizedBox(height: 12),
                Opacity(
                  opacity: 0.5,
                  child: _ProfileMenuTile(
                    icon: Icons.workspace_premium_rounded,
                    label: isSubscribed ? 'PRO Membership' : 'Upgrade to PRO',
                    subtitle: isSubscribed
                        ? 'Enjoy all exclusive features'
                        : null,
                    isGold: false,
                    trailingWidget: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.bg2,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.glassBorder),
                      ),
                      child: Text(
                        isSubscribed ? 'ACTIVE' : 'COMING SOON',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    onTap: null,
                  ),
                ),
                const SizedBox(height: 12),

                Consumer(
                  builder: (context, ref, _) {
                    return Opacity(
                      opacity: 0.5,
                      child: _ProfileMenuTile(
                        icon: Icons.account_balance_wallet_rounded,
                        label: 'Diamond Store',
                        isGold: false,
                        trailingWidget: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.bg2,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.glassBorder),
                          ),
                          child: const Text(
                            'COMING SOON',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        onTap: null,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 32),

                // ── App Settings Group ───────────────────────────────
                const _ProfileGroupLabel(label: 'PREFERENCES'),
                const SizedBox(height: 12),
                
                Consumer(
                  builder: (context, ref, _) {
                    final hapticSupported = ref.watch(hapticSupportProvider).value ?? true;
                    return _ProfileMenuTile(
                      icon: Icons.vibration_rounded,
                      label: 'Haptic Feedback',
                      subtitle: !hapticSupported 
                          ? 'Not Supported' 
                          : 'Current: ${ref.watch(hapticProvider).label}',
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: Colors.transparent,
                          isScrollControlled: true,
                          builder: (context) => const HapticSettingsSheet(),
                        );
                      },
                    );
                  }
                ),
                const SizedBox(height: 12),
                
                Consumer(
                  builder: (context, ref, _) {
                    final parallaxSupported = ref.watch(parallaxSupportProvider).value ?? true;
                    final isParallaxEnabled = ref.watch(parallaxProvider);
                    
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ProfileMenuTile(
                          icon: Icons.threed_rotation_rounded,
                          label: 'Gyroscope Effect',
                          subtitle: !parallaxSupported 
                              ? 'Not Supported on this device' 
                              : (isParallaxEnabled ? 'Enabled' : 'Disabled'),
                          onTap: !parallaxSupported ? null : () {
                            ref.read(parallaxProvider.notifier).toggle();
                          },
                        ),
                        if (!parallaxSupported)
                          Padding(
                            padding: const EdgeInsets.only(left: 16, top: 8, right: 16),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline_rounded, color: Colors.amber.withAlpha(150), size: 14),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Note: This feature requires a Gyroscope or Accelerometer sensor which was not detected on your device.',
                                    style: TextStyle(color: AppColors.textMuted, fontSize: 11, height: 1.4),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    );
                  }
                ),
                const SizedBox(height: 12),
                _ProfileMenuTile(
                  icon: Icons.info_outline_rounded,
                  label: 'About Royal Pixels',
                  subtitle: 'Version ${AppConstants.appVersion}',
                  onTap: () => context.push('/about'),
                ),

                // ── Admin section ────────────────────────────────────
                if (user?.email == 'subhamsoudeep@gmail.com') ...[
                  const SizedBox(height: 32),
                  const _ProfileGroupLabel(label: 'ADMIN CONTROL', color: AppColors.goldMid),
                  const SizedBox(height: 12),
                  _ProfileMenuTile(
                    icon: Icons.admin_panel_settings_rounded,
                    label: 'Admin Upload',
                    isGold: true,
                    onTap: () => context.push('/upload'),
                  ),
                  const SizedBox(height: 12),
                  _ProfileMenuTile(
                    icon: user?.isSubscribed == true
                        ? Icons.toggle_on_rounded
                        : Icons.toggle_off_rounded,
                    label: 'Toggle Premium UI',
                    subtitle: user?.isSubscribed == true
                        ? 'Currently: PREMIUM'
                        : 'Currently: FREE',
                    isGold: true,
                    onTap: () {
                      ref.read(authProvider.notifier).toggleAdminPremiumOverride();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(user?.isSubscribed == true
                              ? 'Switched to FREE mode.'
                              : 'Switched to PREMIUM mode.'),
                          backgroundColor: AppColors.bg0,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _ProfileMenuTile(
                    icon: Icons.edit_note_rounded,
                    label: 'Rename Category',
                    isGold: true,
                    onTap: () => context.push('/rename-category'),
                  ),
                  const SizedBox(height: 12),
                  _ProfileMenuTile(
                    icon: Icons.category_rounded,
                    label: 'Category Covers',
                    isGold: true,
                    onTap: () => context.push('/upload-category-cover'),
                  ),
                ],

                const SizedBox(height: 32),
                const _ProfileGroupLabel(label: 'ACCOUNT'),
                const SizedBox(height: 12),

                // ── Logout ────────────────────────────────────────────
                _ProfileMenuTile(
                  icon: Icons.logout_rounded,
                  label: 'Logout',
                  isDanger: true,
                  onTap: () async {
                    await ref.read(authProvider.notifier).logout();
                    if (mounted) context.go('/login');
                  },
                ),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withAlpha(20),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }


  String _getAppBarTitle() {
    switch (_navIndex) {
      case 0:
        return 'Royal Pixels';
      case 1:
        return 'Categories';
      case 2:
        return 'My Saved';
      case 3:
        return 'Favorites';
      case 4:
        return 'Profile';
      default:
        return 'Royal Pixels';
    }
  }

  List<Widget> _getAppBarActions(AuthState userState) {
    if (_navIndex == 0) {
      return [
        // 💎 Diamond counter — auth-aware
        Consumer(
          builder: (context, ref, _) {
            final authState = ref.watch(authProvider);
            if (authState.isGuest) {
              return GestureDetector(
                onTap: () => showLoginRequiredSheet(
                  context,
                  reason: LoginRequiredReason.diamonds,
                ),
                child: Container(
                  margin: const EdgeInsets.only(right: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.white.withAlpha(30), width: 1),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('💎', style: TextStyle(fontSize: 16)),
                      SizedBox(width: 5),
                      Text('Sign In',
                          style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              );
            }
            final diamonds = ref.watch(diamondProvider).diamonds;
            return RepaintBoundary(
              child: DiamondCounterWidget(
                diamonds: diamonds,
                onTap: null,
              ),
            );
          },
        ),
        IconButton(
          tooltip: 'Search',
          icon: const Icon(Icons.search, color: AppColors.textSecondary),
          onPressed: _openSearch,
        ),
        // 🔔 Notification bell — auth-aware
        Consumer(
          builder: (context, ref, _) {
            final unreadCount = ref.watch(unreadNotificationCountProvider);
            return Stack(
              children: [
                IconButton(
                  tooltip: 'Notifications',
                  icon: const Icon(Icons.notifications_none_rounded,
                      color: AppColors.textSecondary),
                  onPressed: () => context.push('/notifications'),
                ),
                if (unreadCount > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.black, width: 1.5),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        unreadCount > 9 ? '9+' : '$unreadCount',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ).animate().scale(duration: 300.ms, curve: Curves.bounceOut),
              ],
            );
          },
        ),
      ];
    }
    
    // For other tabs, maybe just search or nothing
    if (_navIndex == 1 || _navIndex == 2 || _navIndex == 3) {
      return [
        IconButton(
          tooltip: 'Search',
          icon: const Icon(Icons.search, color: AppColors.textSecondary),
          onPressed: _openSearch,
        ),
      ];
    }

    return [];
  }
}

// ─── Nav item data class ──────────────────────────────────────────────────────
class _NavItem {
  final IconData activeIcon;
  final IconData inactiveIcon;
  final String label;
  const _NavItem(this.activeIcon, this.inactiveIcon, this.label);
}

// ─── Profile menu tile ─────────────────────────────────────────────────────────
class _ProfileMenuTile extends ConsumerWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool isGold;
  final bool isDanger;
  final VoidCallback? onTap;
  final Widget? trailingWidget;

  const _ProfileMenuTile({
    required this.icon,
    required this.label,
    this.onTap,
    this.subtitle,
    this.isGold = false,
    this.isDanger = false,
    this.trailingWidget,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Color iconColor = isDanger
        ? Colors.redAccent
        : isGold
            ? AppColors.goldMid
            : AppColors.textSecondary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap != null ? () {
          ref.read(hapticProvider.notifier).lightImpact();
          onTap!();
        } : null,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.bg1,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isGold
                  ? AppColors.goldMid.withAlpha(50)
                  : AppColors.glassBorder,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDanger
                      ? Colors.red.withAlpha(15)
                      : isGold
                          ? AppColors.goldMid.withAlpha(20)
                          : AppColors.bg2,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: isDanger
                            ? Colors.redAccent
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              trailingWidget ??
                  Icon(Icons.chevron_right_rounded,
                      color: AppColors.textMuted.withAlpha(150), size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Profile group label ──────────────────────────────────────────────────────
class _ProfileGroupLabel extends StatelessWidget {
  final String label;
  final Color? color;
  const _ProfileGroupLabel({required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label,
        style: TextStyle(
          color: color ?? AppColors.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

// ─── Skeleton card ────────────────────────────────────────────────────────────
class _SkeletonCard extends StatelessWidget {
  final double height;
  const _SkeletonCard({required this.height});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.bg2,
      highlightColor: AppColors.bg3,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: Colors.white,
        ),
      ),
    );
  }
}

