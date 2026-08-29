import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/animation_constants.dart';
import '../../../core/utils/safe_tap.dart';
import 'dart:ui';
import '../../../core/constants/app_constants.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/diamond_provider.dart';
import '../../providers/payment_provider.dart';
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
import '../../widgets/weather_banner.dart';
import '../../widgets/festival_banner.dart';
import '../../providers/settings_provider.dart';
import '../social_feed/social_feed_page.dart';
import '../../providers/discover_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../../core/services/wallpaper_scheduler.dart';
import '../../widgets/premium_floating_nav_bar.dart';
import '../../../core/scroll/velocity_aware_controller.dart';
import 'package:royal_pixels/core/services/image_prefetch_service.dart';
import 'package:royal_pixels/domain/entities/haptic_level.dart';
import '../../../core/scroll/elite_scroll_physics.dart';
import '../../../core/services/adaptive_performance.dart';
import 'package:royal_pixels/presentation/providers/admin_stats_provider.dart';
import 'package:royal_pixels/data/datasources/firestore_data_source.dart';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';


// â”€â”€â”€ Filter enum â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
enum WallpaperFilter { all, newlyAdded, free, premium, editorsChoice, ultraHD }

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with TickerProviderStateMixin {
  // â”€â”€ Navigation state â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  /// PageController â€” source of truth for swipe position.
  late final PageController _pageController;
  
  /// Home grid scroll controller for bidirectional prefetching.
  late final VelocityAwareScrollController _homeScrollController;

  /// Fractional page position broadcast to nav bar â€” updated every frame.
  /// Range: 0.0 â†’ (itemCount - 1). Sub-integer during swipe.
  late final ValueNotifier<double> _pageNotifier;

  // Active wallpaper filter (on Home tab)
  WallpaperFilter _filter = WallpaperFilter.all;
  bool _rewardPopupShown = false;

  @override
  void initState() {
    super.initState();

    final initialIndex = ref.read(navigationProvider);
    _pageController = PageController(initialPage: initialIndex);
    _pageNotifier = ValueNotifier<double>(initialIndex.toDouble());

    _pageController.addListener(_onPageScroll);

    _homeScrollController = VelocityAwareScrollController();
    _homeScrollController.addListener(_onHomeScroll);

    Future.microtask(
        () => ref.read(wallpaperProvider.notifier).loadWallpapers());
  }

  void _onHomeScroll() {
    if (!mounted) return;

    // ── Infinite Scroll Trigger ──────────────────────────────────────────────
    // When within 1200px of bottom, trigger next page load
    if (_homeScrollController.hasClients && 
        _homeScrollController.position.pixels >= _homeScrollController.position.maxScrollExtent - 1200) {
      
      final state = ref.read(wallpaperProvider);
      if (!state.isLoadingMore) {
        if (_filter == WallpaperFilter.all) {
          if (state.hasMoreFree) ref.read(wallpaperProvider.notifier).loadMoreWallpapers(isPremium: false);
          if (state.hasMorePremium) ref.read(wallpaperProvider.notifier).loadMoreWallpapers(isPremium: true);
        } else if (_filter == WallpaperFilter.free) {
          if (state.hasMoreFree) ref.read(wallpaperProvider.notifier).loadMoreWallpapers(isPremium: false);
        } else if (_filter == WallpaperFilter.premium) {
          if (state.hasMorePremium) ref.read(wallpaperProvider.notifier).loadMoreWallpapers(isPremium: true);
        }
      }
    }

    final filtered = ref.read(homeFilteredWallpapersProvider(_filter));
    if (filtered.isEmpty) return;

    final rowIndex = (_homeScrollController.offset / 320).floor();
    final itemIndex = rowIndex * 3;

    ImagePrefetchService.preloadBidirectional(
      context,
      filtered,
      itemIndex,
      scrollDelta: _homeScrollController.velocity.value, 
      isFastScrolling: _homeScrollController.velocity.value.abs() > 3000,
    );
  }

  void _onPageScroll() {
    if (_pageController.hasClients && _pageController.page != null) {
      _pageNotifier.value = _pageController.page!;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final diamond = ref.read(diamondProvider);
    final isSubscribed = ref.read(authProvider).user?.isSubscribed ?? false;
    
    if (!_rewardPopupShown &&
        !isSubscribed &&
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

  @override
  void dispose() {
    _pageController.removeListener(_onPageScroll);
    _pageController.dispose();
    _pageNotifier.dispose();
    _homeScrollController.removeListener(_onHomeScroll);
    _homeScrollController.dispose();
    super.dispose();
  }

  void _navigateToPage(int index) {
    // Immediately update state - the listener below will handle the UI jump
    ref.read(navigationProvider.notifier).setIndex(index);
    
    // Selection haptic is already handled in the listener/onPageChanged
  }

  void _openSearch() {
    SafeTap.run('home_search', () {
      final wallpaperState = ref.read(wallpaperProvider);
      final allWallpapers = [
        ...wallpaperState.freeWallpapers,
        ...wallpaperState.premiumWallpapers,
      ];
      showSearch(
        context: context,
        delegate: WallpaperSearchDelegate(allWallpapers),
      );
    });
  }

  // Filter logic now moved to homeFilteredWallpapersProvider for high-performance memoization

  // â”€â”€ Premium nav items definition â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  static const List<NavBarItem> _navItems = [
    NavBarItem(
      activeIcon: Icons.home_rounded,
      inactiveIcon: Icons.home_outlined,
      label: 'HOME',
    ),
    NavBarItem(
      activeIcon: Icons.local_fire_department_rounded,
      inactiveIcon: Icons.local_fire_department_outlined,
      label: 'FEEDS',
    ),
    NavBarItem(
      activeIcon: Icons.grid_view_rounded,
      inactiveIcon: Icons.grid_view_outlined,
      label: 'EXPLORE',
    ),
    NavBarItem(
      activeIcon: Icons.favorite_rounded,
      inactiveIcon: Icons.favorite_outline_rounded,
      label: 'FAVORITES',
    ),
    NavBarItem(
      activeIcon: Icons.download_done_rounded,
      inactiveIcon: Icons.download_outlined,
      label: 'SAVED',
    ),
    NavBarItem(
      activeIcon: Icons.person_rounded,
      inactiveIcon: Icons.person_outline_rounded,
      label: 'PROFILE',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final wallpaperState = ref.watch(wallpaperProvider);
    final userState = ref.watch(authProvider);
    final navIndex = ref.watch(navigationProvider);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    // Listen to navigation changes to sync PageController when updated externally or via tab tap
    ref.listen<int>(navigationProvider, (previous, next) {
      if (_pageController.hasClients) {
        final currentPage = _pageController.page?.round();
        if (currentPage != next) {
          // Use jumpToPage for "direct" transition as requested
          _pageController.jumpToPage(next);
        }
      }

      // Trigger specific data logic per tab (centralized here for all navigation sources)
      if (next == 1) { // FEEDS
        ref.read(feedWallpapersProvider.notifier).refresh();
      } else if (next == 2) { // EXPLORE
        ref.read(discoverSeedProvider.notifier).state = DateTime.now().millisecondsSinceEpoch;
        ref.read(wallpaperProvider.notifier).shuffleSessionSeed();
      } else if (next == 0) { // HOME
        ref.read(wallpaperProvider.notifier).shuffleSessionSeed();
      }
    });

    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      // â”€â”€ AppBar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: ValueListenableBuilder<double>(
          valueListenable: _pageNotifier,
          builder: (context, page, _) {
            double appBarOpacity = 1.0;
            if (page <= 1.0) {
              appBarOpacity = (1.0 - page).clamp(0.0, 1.0);
            } else if (page <= 2.0) {
              appBarOpacity = (page - 1.0).clamp(0.0, 1.0);
            }
            return Opacity(
              opacity: appBarOpacity,
              child: AppBar(
                flexibleSpace: RepaintBoundary(
                  child: ClipRect(
                    child: AdaptivePerformance.enableBackdropBlur
                        ? BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 25.0, sigmaY: 25.0),
                            child: _buildAppBarBackground(),
                          )
                        : _buildAppBarBackground(opaque: true),
                  ),
                ),
                elevation: 4,
                shadowColor: Colors.black.withAlpha(100),
                title: _CrossFadingAppBarTitle(page: page, onSearchTap: _openSearch),
                actions: _getAppBarActions(userState, page),
              ),
            );
          },
        ),
      ),
      // â”€â”€ Body + Floating Nav overlay â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
      body: Stack(
        children: [
          // â”€â”€ PageView â€” gesture-driven, iOS-physics swipe navigation â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          // keepAlive: each page is wrapped in AutomaticKeepAlive inside.
          PageView(
            controller: _pageController,
            physics: const EliteScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            // Update _navIndex ONLY when page fully settles (not during swipe)
            // so AppBar title and haptic only fire once per completed nav.
            onPageChanged: (index) {
              ref.read(hapticProvider.notifier).selectionClick();
              ref.read(navigationProvider.notifier).setIndex(index);
            },
            children: [
              // Tab 0: Home wallpaper grid
              _PremiumParallaxWrapper(
                index: 0,
                pageNotifier: _pageNotifier,
                child: _buildHomeTab(wallpaperState),
              ),
              // Tab 1: Social Feed (Reels)
              _PremiumParallaxWrapper(
                index: 1,
                pageNotifier: _pageNotifier,
                child: const _KeepAlivePage(child: SocialFeedPage()),
              ),
              // Tab 2: Categories
              _PremiumParallaxWrapper(
                index: 2,
                pageNotifier: _pageNotifier,
                child: const _KeepAlivePage(
                  child: CategoriesListPage(embeddedMode: true),
                ),
              ),
              // Tab 3: Favorites (only favorites)
              _PremiumParallaxWrapper(
                index: 3,
                pageNotifier: _pageNotifier,
                child: const _KeepAlivePage(
                  child: MyWallpapersPage(
                    embeddedMode: true,
                    showFavoritesOnly: true,
                  ),
                ),
              ),
              // Tab 4: My Wallpapers (downloaded)
              _PremiumParallaxWrapper(
                index: 4,
                pageNotifier: _pageNotifier,
                child: const _KeepAlivePage(
                  child: MyWallpapersPage(embeddedMode: true),
                ),
              ),
              // Tab 5: Profile
              _PremiumParallaxWrapper(
                index: 5,
                pageNotifier: _pageNotifier,
                child: _KeepAlivePage(
                  child: userState.isGuest
                      ? _buildGuestProfileTab()
                      : _buildProfileTab(userState),
                ),
              ),
            ],
          ),

          // â”€â”€ Floating nav bar â€” pinned at bottom of Stack â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: PremiumFloatingNavBar(
              currentIndex: navIndex,
              pageNotifier: _pageNotifier,
              items: _navItems,
              bottomSafeArea: bottomPadding,
              onTap: (index) {
                ref.read(hapticProvider.notifier).selectionClick();
                _navigateToPage(index);
              },
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildHomeTab(WallpaperState wallpaperState) {
    final filtered = ref.watch(homeFilteredWallpapersProvider(_filter));

    final isHigh = AdaptivePerformance.isHigh;

    return CustomScrollView(
      controller: _homeScrollController,
      physics: const EliteAlwaysScrollPhysics(),
      // Reduced cacheExtent for non-high devices to save memory/build time
      // Phase 8: aggressively reduced on LOW tier to prevent scroll lag
      cacheExtent: isHigh ? 1200 : (AdaptivePerformance.isLow ? 250 : 500),
      slivers: [
        // â”€â”€ Filter chips strip (pinned-like via padding top) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        SliverToBoxAdapter(child: _buildFilterStrip(wallpaperState)),

        // â”€â”€ Weather Reactive Banner â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        const SliverToBoxAdapter(child: FestivalBanner()),
        const SliverToBoxAdapter(child: WeatherBanner()),







        // â”€â”€ Section divider label â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 32, 16, 20),
            child: Center(
              child: _AppBarTitleText('ROYAL COLLECTION', fontSize: 15),
            ),
          ),
        ),

        // â”€â”€ Main wallpaper grid â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        if (wallpaperState.isLoading)
          SliverToBoxAdapter(child: _buildSkeleton())
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
                16, 0, 16, 20),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, // Changed from 2 to 3 for "maximum" wallpapers
                childAspectRatio: 0.56, // Adjusted for 3-column phone-ratio look
                crossAxisSpacing: 8, // Reduced spacing to maximize screen usage
                mainAxisSpacing: 8,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final wp = filtered[index];
                  final card = RepaintBoundary(
                    child: WallpaperCard(
                      key: ValueKey(wp.id),
                      wallpaper: wp,
                      scrollController: _homeScrollController,
                      onTap: () {
                        ImagePrefetchService.prefetchForDetail(context, wp);
                        context.push('/detail', extra: wp);
                      },
                      onLongPress: () =>
                          showWallpaperLongPressPreview(context, wp),
                    ),
                  );

                  // Phase 7: Staggered animations are visually nice but can cause frame drops on budget SOCs
                  // We bypass them completely on LOW tier to ensure instant list rendering.
                  if (!AdaptivePerformance.enableStaggerAnimation) {
                    return card;
                  }

                  return card
                      .animate()
                      .fade(
                        duration: 300.ms, 
                        curve: Curves.easeOut,
                        // Only stagger the first few items to keep initial load smooth
                        delay: (index < 12 ? (index % 3 * 60).ms : 0.ms),
                      )
                      .scale(
                        begin: const Offset(0.96, 0.96),
                        end: const Offset(1.0, 1.0),
                        duration: 400.ms,
                        curve: Curves.easeOutCubic,
                      );
                },
                childCount: filtered.length,
              ),
            ),
          ),

        // ── Load More Indicator ──────────────────────────────────────────────
        if (wallpaperState.isLoadingMore)
          SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Shimmer.fromColors(
                  baseColor: AppColors.goldMid.withAlpha(50),
                  highlightColor: AppColors.goldLight.withAlpha(150),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(AppColors.goldMid),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'LOADING MORE...',
                        style: TextStyle(
                          color: AppColors.goldMid,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // Bottom spacing for FAB/Nav
        SliverToBoxAdapter(
          child: SizedBox(height: 110 + MediaQuery.of(context).padding.bottom),
        ),
      ],
    );
  }

  // â”€â”€ Filter chips â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildFilterStrip(WallpaperState state) {
    final all = [...state.freeWallpapers, ...state.premiumWallpapers];
    final filters = [
      (WallpaperFilter.all,    Icons.auto_awesome_mosaic_outlined, 'All',          all.length),
      (WallpaperFilter.newlyAdded, Icons.new_releases_rounded,     'New',          () {
        final now = DateTime.now();
        var recent = all.where((wp) => wp.createdAt != null && now.difference(wp.createdAt!).inHours <= 24).toList();
        if (recent.isEmpty && all.isNotEmpty) {
          // Phase 9: Removed the 15-item limiter to show maximum available collection size
          return (all.length > 50) ? 50 : all.length;
        }
        return recent.length;
      }()),
      (WallpaperFilter.free,   Icons.wallpaper_outlined,           'Free',         state.freeWallpapers.length),
      (WallpaperFilter.premium, Icons.diamond_outlined,            'Premium',      state.premiumWallpapers.length),
      (WallpaperFilter.editorsChoice, Icons.star_rounded,          "Editor's",    all.where((w) => w.isEditorsChoice).length),
      (WallpaperFilter.ultraHD, Icons.hd_rounded,                  '4K',           all.where((w) => w.isUltraHD).length),
    ];

    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 64,
        bottom: 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.05),
            width: 0.5,
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const EliteScrollPhysics(),
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
            } else if (f.$1 == WallpaperFilter.newlyAdded) {
              chipColor = const Color(0xFFF43F5E); // Rose color for new items
              chipGradient = isActive
                  ? const LinearGradient(colors: [Color(0xFFF43F5E), Color(0xFFBE123C)])
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
              child: AdaptivePerformance.isLow
                  ? Container(
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: chipGradient,
                        color: isActive ? null : Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isActive 
                              ? Colors.white.withValues(alpha: 0.3) 
                              : Colors.white.withValues(alpha: 0.1),
                          width: 0.8,
                        ),
                      ),
                      child: Transform.scale(
                        scale: isActive ? 1.06 : 1.0,
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
                                    color: isActive ? contentColor : AppColors.textMuted,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    )
                  : AnimatedContainer(
                      duration: AppAnimations.interactionQuick,
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: chipGradient,
                        color: isActive ? null : Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isActive 
                              ? Colors.white.withValues(alpha: 0.3) 
                              : Colors.white.withValues(alpha: 0.1),
                          width: 0.8,
                        ),
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color: chipColor.withValues(alpha: 0.3),
                                  blurRadius: 15,
                                  spreadRadius: -2,
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
                                    color: isActive ? contentColor : AppColors.textMuted,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
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


  // ——— Skeleton ——————————————————————————————————————————————————————
  Widget _buildSkeleton() {
    return GridView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.fromLTRB(16, 8, 16, 110 + MediaQuery.of(context).padding.bottom),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.65,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: 10,
      cacheExtent: 800,
      addRepaintBoundaries: true,
      itemBuilder: (context, index) {
        return const _SkeletonCard();
      },
    );
  }


  // ——— Guest profile tab —————————————————————————————————————————————
  Widget _buildGuestProfileTab() {
    return Consumer(builder: (context, ref, _) {
      final streakState = ref.watch(guestStreakProvider);
      final streak = streakState.streak;

      return CustomScrollView(
        key: const PageStorageKey<String>('guest_profile_scroll'),
        physics: const EliteAlwaysScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                  20, MediaQuery.of(context).padding.top + 70, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ——— Guest identity card ———————————————————————————
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                    decoration: BoxDecoration(
                      color: AppColors.bg1,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: AppColors.glassBorder, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(120),
                          blurRadius: 25,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 78,
                              height: 78,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.bg2.withAlpha(150),
                                border: Border.all(color: AppColors.glassBorder, width: 1.5),
                              ),
                              child: const Icon(Icons.person_outline_rounded,
                                  color: AppColors.textMuted, size: 36),
                            ),
                            const SizedBox(width: 18),
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
                                      letterSpacing: -0.6,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  // Identity hint bar
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: AppColors.bg2.withAlpha(150),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: AppColors.glassBorder.withAlpha(100), width: 0.8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.info_outline_rounded, size: 12, color: AppColors.goldMid),
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
                          ],
                        ),
                        const SizedBox(height: 24),
                        Divider(color: AppColors.divider.withAlpha(50), height: 1),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildStatItem('Diamonds', '0', Icons.diamond_rounded, AppColors.textMuted),
                            _buildStatItem('Streak', '${streak}d', Icons.local_fire_department_rounded, Colors.orangeAccent),
                            _buildStatItem('Saved', '0', Icons.download_done_rounded, AppColors.textMuted),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ——— Daily streak card (Interactive) —————————————————
                  const _ProfileGroupLabel(label: 'DAILY REWARDS'),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.bg1,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: AppColors.goldMid.withAlpha(40), width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(80),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.orangeAccent.withAlpha(20),
                                shape: BoxShape.circle,
                              ),
                              child: const Text('🔥', style: TextStyle(fontSize: 18)),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$streak Day Streak',
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.4,
                                  ),
                                ),
                                Text(
                                  streakState.canClaimToday 
                                      ? 'Ready to claim today\'s reward!' 
                                      : 'Come back tomorrow for more',
                                  style: TextStyle(
                                    color: AppColors.textMuted.withAlpha(180),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            if (streakState.canClaimToday)
                              GestureDetector(
                                onTap: () async {
                                  ref.read(hapticProvider.notifier).lightImpact();
                                  await ref.read(guestStreakProvider.notifier).claimStreak();
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    gradient: AppColors.goldGradient,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.goldMid.withAlpha(50),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: const Text(
                                    'CLAIM',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(7, (i) {
                            final day = i + 1;
                            final isCollected = day <= (streak % 7 == 0 && streak > 0 ? 7 : streak % 7);
                            return Column(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: isCollected ? AppColors.goldGradient : null,
                                    color: isCollected ? null : AppColors.bg2.withAlpha(150),
                                    border: Border.all(
                                      color: isCollected ? Colors.transparent : AppColors.glassBorder.withAlpha(120),
                                      width: 1,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '$day',
                                      style: TextStyle(
                                        color: isCollected ? Colors.black : AppColors.textMuted,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(day == 7 ? '🎁' : '💎', style: const TextStyle(fontSize: 10)),
                              ],
                            );
                          }),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ——— Grouped Actions ————————————————————————————————
                  const _ProfileGroupLabel(label: 'ACCOUNT & APP'),
                  const SizedBox(height: 12),
                  _ProfileGroupWrapper(
                    children: [
                      _ProfileMenuTile(
                        icon: Icons.login_rounded,
                        label: 'Sign In with Google',
                        subtitle: 'Sync your favorites and progress',
                        isGold: true,
                        useCardStyle: false,
                        onTap: () {
                          ref.read(hapticProvider.notifier).lightImpact();
                          showLoginRequiredSheet(context, reason: LoginRequiredReason.general);
                        },
                      ),
                      _ProfileMenuTile(
                        icon: Icons.info_outline_rounded,
                        label: 'About Royal Pixels',
                        subtitle: 'Version ${AppConstants.appVersion}',
                        useCardStyle: false,
                        onTap: () => context.push('/about'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),
                  const _ProfileGroupLabel(label: 'APP FEEL'),
                  const SizedBox(height: 12),
                  const _HapticControlCenter(),

                  const SizedBox(height: 120),

                ],
              ),
            ),
          ),
        ],
      );
    });
  }

  // ——— Profile tab —————————————————————————————————————————————————————
  Widget _buildAppBarBackground({bool opaque = false}) {
    return Container(
      decoration: BoxDecoration(
        color: opaque ? AppColors.bg1 : Colors.white.withValues(alpha: 0.04),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.12),
            width: 0.8,
          ),
        ),
        gradient: opaque
            ? null
            : LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: 0.08),
                  Colors.white.withValues(alpha: 0.01),
                ],
              ),
      ),
    );
  }

  Widget _buildProfileTab(AuthState userState) {
    final user = userState.user;
    final isSubscribed = user?.isSubscribed ?? false;

    return CustomScrollView(
      key: const PageStorageKey<String>('user_profile_scroll'),
      physics: const EliteAlwaysScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
                20, MediaQuery.of(context).padding.top + 64, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ——— User identity card ——————————————————————————————
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  decoration: BoxDecoration(
                    color: AppColors.bg1,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: isSubscribed
                          ? AppColors.goldMid.withAlpha(60)
                          : AppColors.glassBorder, 
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(120),
                        blurRadius: 25,
                        offset: const Offset(0, 12),
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
                          // Avatar with Premium Glow
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              // ── Layer 1: Premium Ambient Glow ──
                              if (isSubscribed)
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.goldMid.withAlpha(80),
                                          blurRadius: 20,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                  ).animate(onPlay: (c) => c.repeat(reverse: true))
                                   .scale(begin: const Offset(0.9, 0.9), end: const Offset(1.1, 1.1), duration: 2.seconds, curve: Curves.easeInOut)
                                   .fadeIn(duration: 1.seconds),
                                ),

                              // ── Layer 2: Main Profile Ring ──
                              Container(
                                width: 78,
                                height: 78,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: isSubscribed
                                      ? AppColors.goldRingGradient
                                      : LinearGradient(colors: [AppColors.bg3, AppColors.bg2]),
                                ),
                                child: Center(
                                  child: Container(
                                    width: 72,
                                    height: 72,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.bg1,
                                    ),
                                    child: ClipOval(
                                      child: (user?.photoUrl != null && user!.photoUrl!.isNotEmpty)
                                          ? CachedNetworkImage(
                                              imageUrl: user.photoUrl!,
                                              fit: BoxFit.cover,
                                              placeholder: (context, url) => Container(
                                                color: AppColors.bg2,
                                                child: const Center(
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: AppColors.goldMid,
                                                  ),
                                                ),
                                              ),
                                              errorWidget: (context, url, error) => Center(
                                                child: Text(
                                                  (user.name.isNotEmpty ? user.name : 'G')[0].toUpperCase(),
                                                  style: const TextStyle(
                                                    color: AppColors.textPrimary,
                                                    fontSize: 28,
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                              ),
                                            )
                                          : Center(
                                              child: Text(
                                                (user?.name ?? 'G')[0].toUpperCase(),
                                                style: const TextStyle(
                                                  color: AppColors.textPrimary,
                                                  fontSize: 28,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                              ).animate(onPlay: (c) => c.repeat(reverse: true))
                               .shimmer(
                                  duration: 3.seconds,
                                  color: isSubscribed ? Colors.white.withAlpha(60) : Colors.transparent,
                                ),

                              // ── Layer 3: PRO Badge ──
                              if (isSubscribed)
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      gradient: AppColors.goldGradient,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: AppColors.bg0, width: 2),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withAlpha(50),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Text(
                                      'PRO',
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ).animate(onPlay: (c) => c.repeat())
                                   .shimmer(duration: 2.seconds, color: Colors.white.withAlpha(100)),
                                ),
                            ],
                          ),
                          const SizedBox(width: 18),
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
                                          letterSpacing: -0.6,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                // Gmail account bar
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.bg2.withAlpha(150),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AppColors.glassBorder.withAlpha(100), width: 0.8),
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
                                            fontSize: 11,
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
                      
                      // ——— Stats row ——————————————————————————————————————
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (!isSubscribed) ...[
                            _buildStatItem('Diamonds', '${user?.diamonds ?? 0}', Icons.diamond_rounded, AppColors.goldMid),
                            _buildStatItem('Streak', '${user?.streak ?? 0}d', Icons.local_fire_department_rounded, Colors.orangeAccent),
                          ],
                          _buildStatItem('Saved', '${user?.ownedWallpaperCount ?? 0}', Icons.download_done_rounded, Colors.blueAccent),
                          if (isSubscribed)
                            _buildStatItem('Membership', 'PRO', Icons.workspace_premium_rounded, AppColors.goldMid),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // ——— Membership Group ————————————————————————————————
                const _ProfileGroupLabel(label: 'MEMBERSHIP & WALLET'),
                const SizedBox(height: 12),
                _ProfileGroupWrapper(
                  children: [
                    _ProfileMenuTile(
                      icon: Icons.workspace_premium_rounded,
                      label: isSubscribed ? 'PRO Membership' : 'Upgrade to PRO',
                      subtitle: isSubscribed
                          ? 'Enjoy all exclusive features'
                          : 'Unlock exclusive premium wallpapers',
                      isGold: true,
                      useCardStyle: false,
                      trailingWidget: Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: isSubscribed ? null : AppColors.goldGradient,
                          color:
                              isSubscribed ? AppColors.goldMid.withAlpha(40) : null,
                          borderRadius: BorderRadius.circular(12),
                          border: isSubscribed
                              ? Border.all(color: AppColors.goldMid.withAlpha(100))
                              : null,
                        ),
                        child: Text(
                          isSubscribed ? 'ACTIVE' : 'UPGRADE',
                          style: TextStyle(
                            color:
                                isSubscribed ? AppColors.goldLight : Colors.black,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      onTap: () => context.push('/subscription'),
                    ),
                    if (!isSubscribed)
                      Consumer(
                        builder: (context, ref, _) {
                          final diamonds = ref.watch(diamondProvider).diamonds;
                          return _ProfileMenuTile(
                            icon: Icons.account_balance_wallet_rounded,
                            label: 'Diamond Store',
                            subtitle: 'Current balance: 💎 $diamonds',
                            isGold: false,
                            useCardStyle: false,
                            trailingWidget: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.bg2,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.glassBorder),
                              ),
                              child: const Text(
                                'TOP UP',
                                style: TextStyle(
                                  color: AppColors.goldMid,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            onTap: () => context.push('/diamonds'),
                          );
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 32),

                // ——— App Settings Group —————————————————————————————
                const _ProfileGroupLabel(label: 'PREFERENCES'),
                const SizedBox(height: 12),
                
                Consumer(
                  builder: (context, ref, _) {
                    final settings = ref.watch(settingsProvider);

                    return Column(
                      children: [
                        // Integrated Haptic Control Center (Stand-alone premium module)
                        const _HapticControlCenter(),
                        
                        const SizedBox(height: 20),

                        _ProfileGroupWrapper(
                          children: [
                            _ProfileMenuTile(
                              icon: Icons.brightness_medium_rounded,
                              label: 'AMOLED Mode',
                              subtitle: settings.isAmoledMode ? 'Prioritize deep blacks' : 'Standard dark',
                              useCardStyle: false,
                              trailingWidget: Switch(
                                value: settings.isAmoledMode,
                                activeThumbColor: AppColors.goldMid,
                                trackColor: WidgetStateProperty.all(AppColors.bg3),
                                onChanged: (_) {
                                  ref.read(hapticProvider.notifier).lightImpact();
                                  ref.read(settingsProvider.notifier).toggleAmoledMode();
                                },
                              ),
                            ),
                            _ProfileMenuTile(
                              icon: Icons.auto_mode_rounded,
                              label: 'Auto Daily Wallpaper',
                              subtitle: settings.isAutoDailyWallpaper ? 'Schedule active' : 'Off',
                              useCardStyle: false,
                              trailingWidget: Switch(
                                value: settings.isAutoDailyWallpaper,
                                activeThumbColor: AppColors.goldMid,
                                trackColor: WidgetStateProperty.all(AppColors.bg3),
                                onChanged: (_) async {
                                  ref.read(hapticProvider.notifier).lightImpact();
                                  ref.read(settingsProvider.notifier).toggleAutoDailyWallpaper();
                                  if (!settings.isAutoDailyWallpaper) {
                                    await WallpaperScheduler.scheduleDailyTask();
                                  } else {
                                    await WallpaperScheduler.cancelDailyTask();
                                  }
                                },
                              ),
                            ),
                            _ProfileMenuTile(
                              icon: Icons.info_outline_rounded,
                              label: 'About Royal Pixels',
                              subtitle: 'Version ${AppConstants.appVersion}',
                              useCardStyle: false,
                              onTap: () => context.push('/about'),
                            ),
                          ],
                        ),
                      ],
                    );
                  }
                ),

                // ——— Admin section —————————————————————————————————
                if (user?.email == 'subhamsoudeep@gmail.com') ...[
                  const SizedBox(height: 28),
                  const _ProfileGroupLabel(label: 'ADMIN CONTROL', color: AppColors.goldMid),
                  const SizedBox(height: 12),
                  _ProfileGroupWrapper(
                    children: [
                      // PREMIUM TOGGLE for Testing
                      Consumer(
                        builder: (context, ref, _) {
                          return _ProfileMenuTile(
                            icon: Icons.workspace_premium_rounded,
                            label: 'Premium Membership',
                            subtitle: isSubscribed ? 'PRO Active (Testing)' : 'FREE Version (Testing)',
                            isGold: true,
                            useCardStyle: false,
                            trailingWidget: Switch(
                              value: isSubscribed,
                              activeThumbColor: AppColors.goldLight,
                              activeTrackColor: AppColors.goldMid.withAlpha(100),
                              inactiveThumbColor: AppColors.textMuted,
                              inactiveTrackColor: AppColors.bg3,
                              onChanged: (val) async {
                                ref.read(hapticProvider.notifier).mediumImpact();
                                
                                // Show immediate loading toast or similar if needed
                                final repo = ref.read(paymentRepositoryProvider);
                                final result = await repo.updateSubscription(
                                  userId: user!.uid,
                                  isSubscribed: val,
                                );

                                result.fold(
                                  (failure) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Failed to update: ${failure.message}')),
                                    );
                                  },
                                  (_) async {
                                    // Refresh local state to trigger global UI changes (glow, etc)
                                    await ref.read(authProvider.notifier).refreshUser();
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          backgroundColor: AppColors.goldMid,
                                          content: Text(
                                            val ? 'PREMIUM ACTIVATED' : 'PREMIUM DEACTIVATED',
                                            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                );
                              },
                            ),
                          );
                        },
                      ),

                      _ProfileMenuTile(
                        icon: Icons.admin_panel_settings_rounded,
                        label: 'Admin Upload',
                        isGold: true,
                        useCardStyle: false,
                        onTap: () => context.push('/upload'),
                      ),

                      _ProfileMenuTile(
                        icon: Icons.edit_note_rounded,
                        label: 'Rename Category',
                        isGold: true,
                        useCardStyle: false,
                        onTap: () => context.push('/rename-category'),
                      ),
                      _ProfileMenuTile(
                        icon: Icons.category_rounded,
                        label: 'Category Covers',
                        isGold: true,
                        useCardStyle: false,
                        onTap: () => context.push('/upload-category-cover'),
                      ),

                      // ── Daily Active Users card ──────────────────────
                      const _DauStatsCard(),
                    ],
                  ),
                ],

                const SizedBox(height: 28),
                const _ProfileGroupLabel(label: 'ACCOUNT'),
                const SizedBox(height: 12),

                // ——— Logout ————————————————————————————————————————
                _ProfileGroupWrapper(
                  children: [
                    _ProfileMenuTile(
                      icon: Icons.logout_rounded,
                      label: 'Logout',
                      isDanger: true,
                      useCardStyle: false,
                      onTap: () async {
                        await ref.read(authProvider.notifier).logout();
                        if (mounted) context.go('/login');
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 120),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.bg2.withAlpha(100),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.glassBorder, width: 0.8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: AppColors.textMuted.withAlpha(180),
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }


  

  List<Widget> _getAppBarActions(AuthState userState, double page) {
    // We only show Diamond and Notification on the Home tab (page 0)
    // They fade out quickly as the user swipes away from Home.
    final double actionsOpacity = (1.0 - page * 3.0).clamp(0.0, 1.0);
    
    if (actionsOpacity <= 0) return [];

    return [
      // Diamond counter — wrapped in Opacity for smooth transition
      Opacity(
        opacity: actionsOpacity,
        child: Consumer(
          builder: (context, ref, _) {
            final authState = ref.watch(authProvider);
            final diamonds = ref.watch(diamondProvider).diamonds;
            
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
            final isSubscribed = userState.user?.isSubscribed ?? false;
            return RepaintBoundary(
              child: DiamondCounterWidget(
                diamonds: diamonds,
                isPremium: isSubscribed,
                onTap: null,
                onPlusTap: () => context.push('/diamonds'),
              ),
            );
          },
        ),
      ),

      // Notification bell — wrapped in Opacity
      Opacity(
        opacity: actionsOpacity,
        child: Consumer(
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
      ),
    ];
  }
}


// ——— Profile menu tile —————————————————————————————————————————————
class _ProfileMenuTile extends ConsumerWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool isGold;
  final bool isDanger;
  final VoidCallback? onTap;
  final Widget? trailingWidget;
  final bool useCardStyle;

  const _ProfileMenuTile({
    required this.icon,
    required this.label,
    this.onTap,
    this.subtitle,
    this.isGold = false,
    this.isDanger = false,
    this.trailingWidget,
    this.useCardStyle = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Color iconColor = isDanger
        ? Colors.redAccent
        : isGold
            ? AppColors.goldMid
            : AppColors.textSecondary;

    final tileContent = Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: isDanger
                ? Colors.red.withAlpha(25)
                : isGold
                    ? AppColors.goldMid.withAlpha(25)
                    : AppColors.bg2.withAlpha(150),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: iconColor, size: 20),
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
    );

    if (!useCardStyle) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap != null ? () {
            ref.read(hapticProvider.notifier).lightImpact();
            onTap!();
          } : null,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: tileContent,
          ),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap != null ? () {
          ref.read(hapticProvider.notifier).lightImpact();
          onTap!();
        } : null,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.bg1.withAlpha(180),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isGold
                  ? AppColors.goldMid.withAlpha(80)
                  : AppColors.glassBorder.withAlpha(120),
              width: 1,
            ),
          ),
          child: tileContent,
        ),
      ),
    );
  }
}

/// Redesigned Integrated Haptic Control Center — Ultra Smooth Glassmorphism
class _HapticControlCenter extends ConsumerWidget {
  const _HapticControlCenter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLevel = ref.watch(hapticProvider);
    final notifier = ref.read(hapticProvider.notifier);
    final hapticSupported = ref.watch(hapticSupportProvider).value ?? true;

    if (!hapticSupported) return const SizedBox.shrink();

    final levels = HapticLevel.values;
    final selectedIndex = levels.indexOf(currentLevel);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.bg1.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: AppColors.glassBorder.withValues(alpha: 0.4),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(60),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: AdaptivePerformance.enableBackdropBlur
            ? BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: _buildHapticContent(
                  currentLevel: currentLevel,
                  notifier: notifier,
                  levels: levels,
                  selectedIndex: selectedIndex,
                ),
              )
            : _buildHapticContent(
                currentLevel: currentLevel,
                notifier: notifier,
                levels: levels,
                selectedIndex: selectedIndex,
                opaque: true,
              ),
      ),
    ).animate(target: AdaptivePerformance.enableAnimations ? null : 1.0).fadeIn(duration: 800.ms).slideY(begin: 0.1, curve: Curves.easeOutCubic);
  }

  Widget _buildHapticContent({
    required HapticLevel currentLevel,
    required HapticNotifier notifier,
    required List<HapticLevel> levels,
    required int selectedIndex,
    bool opaque = false,
  }) {
    return Container(
      color: opaque ? AppColors.bg1 : null,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with status indicator
          Padding(
            padding: const EdgeInsets.only(left: 10, bottom: 18, top: 6),
            child: Row(
              children: [
                _buildHeaderIcon(currentLevel),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'HAPTIC ENGINE',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.4,
                        ),
                      ),
                      Text(
                        'Precision-tuned vibration response',
                        style: TextStyle(
                          color: AppColors.textMuted.withValues(alpha: 0.8),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(currentLevel),
              ],
            ),
          ),
          
          // Sliding Segmented Control (iOS style)
          Container(
            height: 68,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(80),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withAlpha(15),
                width: 0.5,
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final segmentWidth = constraints.maxWidth / levels.length;
                
                return Stack(
                  children: [
                    // Animated Glass Selection Pill
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.elasticOut,
                      left: selectedIndex * segmentWidth,
                      top: 0,
                      bottom: 0,
                      width: segmentWidth,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.goldMid.withValues(alpha: 0.3),
                              AppColors.goldMid.withValues(alpha: 0.05),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: AppColors.goldMid.withValues(alpha: 0.45),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.goldMid.withValues(alpha: 0.2),
                              blurRadius: 15,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ).animate(onPlay: (c) => c.repeat(reverse: true), target: AdaptivePerformance.enableAnimations ? null : 1.0)
                       .shimmer(duration: 3.seconds, color: Colors.white.withAlpha(10)),
                    ),
                    
                    // Interaction Labels
                    Row(
                      children: levels.map((level) {
                        final isSelected = currentLevel == level;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () {
                              if (currentLevel != level) {
                                notifier.setLevel(level);
                              }
                            },
                            behavior: HitTestBehavior.opaque,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _getIconForLevel(level),
                                  color: isSelected 
                                      ? AppColors.goldLight 
                                      : AppColors.textSecondary.withValues(alpha: 0.6),
                                  size: isSelected ? 24 : 20,
                                  ).animate(target: isSelected && AdaptivePerformance.enableAnimations ? 1 : 0)
                                   .scale(begin: const Offset(0.85, 0.85), end: const Offset(1.1, 1.1), curve: Curves.easeOutBack),
                                const SizedBox(height: 5),
                                Text(
                                  level.label.toUpperCase(),
                                  style: TextStyle(
                                    color: isSelected ? AppColors.textPrimary : AppColors.textMuted,
                                    fontSize: 8,
                                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderIcon(HapticLevel level) {
    final bool isOff = level == HapticLevel.off;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isOff 
            ? Colors.white.withAlpha(10) 
            : AppColors.goldMid.withValues(alpha: 0.2),
        shape: BoxShape.circle,
        border: Border.all(
          color: isOff ? Colors.white10 : AppColors.goldMid.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Icon(
        isOff ? Icons.vibration_rounded : Icons.sensors_rounded, 
        color: isOff ? AppColors.textMuted : AppColors.goldLight, 
        size: 18,
      ).animate(target: (!isOff && AdaptivePerformance.enableAnimations) ? 1 : 0)
       .shimmer(duration: 2.seconds, color: Colors.white24),
    );
  }

  Widget _buildStatusBadge(HapticLevel level) {
    final bool isOff = level == HapticLevel.off;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isOff ? Colors.red.withAlpha(20) : AppColors.goldMid.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isOff ? Colors.red.withAlpha(40) : AppColors.goldMid.withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        isOff ? 'DISABLED' : 'ACTIVE',
        style: TextStyle(
          color: isOff ? Colors.redAccent : AppColors.goldLight,
          fontSize: 8,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  IconData _getIconForLevel(HapticLevel level) {
    if (level == HapticLevel.off) return Icons.do_not_disturb_on_rounded;
    if (level == HapticLevel.light) return Icons.blur_on_rounded;
    if (level == HapticLevel.medium) return Icons.vibration_rounded;
    if (level == HapticLevel.strong) return Icons.bolt_rounded;
    return Icons.vibration_rounded;
  }
}



// â”€â”€â”€ Profile group label â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _ProfileGroupLabel extends StatelessWidget {
  final String label;
  final Color? color;
  const _ProfileGroupLabel({required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 12,
            decoration: BoxDecoration(
              color: color ?? AppColors.goldMid.withAlpha(150),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color ?? AppColors.textMuted.withAlpha(200),
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

// â”€â”€â”€ Skeleton card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.bg2,
      highlightColor: AppColors.bg3,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: Colors.white,
        ),
      ),
    );
  }
}

// â”€â”€ Profile group wrapper â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _ProfileGroupWrapper extends StatelessWidget {
  final List<Widget> children;
  const _ProfileGroupWrapper({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg1.withAlpha(180),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.glassBorder.withAlpha(100), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(50),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: List.generate(children.length, (index) {
          final isLast = index == children.length - 1;
          return Column(
            children: [
              children[index],
              if (!isLast)
                Padding(
                  padding: const EdgeInsets.only(left: 60, right: 16),
                  child: Divider(color: AppColors.divider.withAlpha(50), height: 1),
                ),
            ],
          );
        }),
      ),
    );
  }
}


// -- KeepAlivePage -------------------------------------------------------------
// Wraps each PageView child so it stays alive (state + scroll position preserved)
// even when swiped off screen — replicates IndexedStack's keep-alive guarantee.

/// A premium wrapper that provides parallax, scale, and opacity transitions
/// to PageView tabs based on their scroll position.
class _PremiumParallaxWrapper extends StatelessWidget {
  final int index;
  final ValueNotifier<double> pageNotifier;
  final Widget child;

  const _PremiumParallaxWrapper({
    required this.index,
    required this.pageNotifier,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: pageNotifier,
      builder: (context, page, child) {
        final double offset = index - page;
        final double absOffset = offset.abs();
        
        if (absOffset > 1.0) return child!;

        if (AdaptivePerformance.isLow) {
          return Opacity(
            opacity: (1.0 - absOffset).clamp(0.0, 1.0),
            child: child,
          );
        }

        final double scale = (1.0 - absOffset * 0.06).clamp(0.94, 1.0);
        final double opacity = (1.0 - absOffset * 0.7).clamp(0.0, 1.0);
        final double parallaxX = offset * MediaQuery.of(context).size.width * 0.4;

        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(parallaxX, 0),
            child: Transform.scale(
              scale: scale,
              child: child,
            ),
          ),
        );
      },
      child: child,
    );
  }
}

class _KeepAlivePage extends StatefulWidget {
  final Widget child;
  const _KeepAlivePage({required this.child});

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class _CrossFadingAppBarTitle extends StatelessWidget {
  final double page;
  final VoidCallback onSearchTap;
  const _CrossFadingAppBarTitle({required this.page, required this.onSearchTap});

  @override
  Widget build(BuildContext context) {
    final int index1 = page.floor();
    final int index2 = page.ceil();
    final double fraction = page - index1;

    return Stack(
      alignment: Alignment.center,
      children: [
        Opacity(
          opacity: (1.0 - fraction).clamp(0.0, 1.0),
          child: index1 == 0 
              ? _PremiumSearchBar(onTap: onSearchTap) 
              : _AppBarTitleText(_getTitleForIndex(index1)),
        ),
        if (index1 != index2)
          Opacity(
            opacity: fraction.clamp(0.0, 1.0),
            child: index2 == 0 
                ? _PremiumSearchBar(onTap: onSearchTap) 
                : _AppBarTitleText(_getTitleForIndex(index2)),
          ),
      ],
    );
  }

  String _getTitleForIndex(int index) {
    switch (index) {
      case 0: return 'ROYAL PIXELS';
      case 1: return 'LIVE FEED';
      case 2: return 'EXPLORE';
      case 3: return 'FAVORITES';
      case 4: return 'MY SAVED';
      case 5: return 'PROFILE';
      default: return 'ROYAL PIXELS';
    }
  }
}

class _AppBarTitleText extends StatelessWidget {
  final String text;
  final double fontSize;
  const _AppBarTitleText(this.text, {this.fontSize = 18});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Background Glow
        Text(
          text,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 2.5,
            fontSize: fontSize,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..color = AppColors.goldMid.withValues(alpha: 0.25),
          ),
        ),
        // Main Text with Gradient and Shadows
        ShaderMask(
          shaderCallback: (bounds) => AppColors.goldGradient.createShader(bounds),
          child: Text(
            text,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              letterSpacing: 2.5,
              color: Colors.white,
              fontSize: fontSize,
              shadows: const [
                Shadow(
                  color: AppColors.goldMid,
                  blurRadius: 12,
                  offset: Offset(0, 0),
                ),
                Shadow(
                  color: AppColors.goldLight,
                  blurRadius: 25,
                  offset: Offset(0, 0),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PremiumSearchBar extends StatelessWidget {
  final VoidCallback onTap;
  const _PremiumSearchBar({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 38,
        constraints: const BoxConstraints(maxWidth: 260),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(19),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
            width: 0.8,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.search_rounded, 
                 size: 18, 
                 color: AppColors.goldMid.withValues(alpha: 0.8)),
            const SizedBox(width: 10),
            Text(
              'Search Wallpapers...',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 13,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    ).animate(target: AdaptivePerformance.enableAnimations ? null : 1.0).fadeIn(duration: 400.ms).scale(begin: const Offset(0.95, 0.95));
  }
}

// ─── Daily Active Users Card ──────────────────────────────────────────────────

// ─── Admin: Daily Active Users ──────────────────────────────────────────────
// Shows per-day user counts as number rows (no chart) with PDF export.
// Guard: only rendered when user email == admin email.

class _DauStatsCard extends ConsumerWidget {
  const _DauStatsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dauAsync = ref.watch(dauProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.goldMid.withValues(alpha: 0.12),
              AppColors.bg2.withValues(alpha: 0.9),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.goldMid.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: dauAsync.when(
          loading: () => const _DauLoadingState(),
          error: (e, _) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'DAU data unavailable',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ),
          data: (records) => _DauNumberContent(records: records),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 500.ms, delay: 150.ms)
        .slideY(begin: 0.1, end: 0, duration: 400.ms, curve: Curves.easeOutCubic);
  }
}

// ─── Number-only content (no chart) ─────────────────────────────────────────
class _DauNumberContent extends StatefulWidget {
  final List<DauDayRecord> records;
  const _DauNumberContent({required this.records});

  @override
  State<_DauNumberContent> createState() => _DauNumberContentState();
}

class _DauNumberContentState extends State<_DauNumberContent> {
  bool _isGeneratingPdf = false;

  int get _weekTotal => widget.records.fold(0, (sum, r) => sum + r.count);

  Future<void> _downloadPdf() async {
    setState(() => _isGeneratingPdf = true);
    try {
      final pdfBytes = await _generateDauPdf(widget.records);
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: 'royal_pixels_dau_report_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate PDF: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.records.isEmpty) return const SizedBox.shrink();

    final today = widget.records.isNotEmpty ? widget.records.last : null;
    final maxCount = widget.records.map((r) => r.count).fold(0, (a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ─────────────────────────────────────────────────────────
        Row(
          children: [
            const Icon(Icons.people_alt_rounded, color: AppColors.goldLight, size: 20),
            const SizedBox(width: 8),
            Text(
              'Daily Active Users',
              style: const TextStyle(
                color: AppColors.goldLight,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
            const Spacer(),
            // Today's count badge
            if (today != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.goldMid.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.goldMid.withValues(alpha: 0.5)),
                ),
                child: Text(
                  'Today: ${today.count}',
                  style: const TextStyle(
                    color: AppColors.goldLight,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),

        const SizedBox(height: 4),
        Text(
          '7-day total: $_weekTotal users',
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 10,
            letterSpacing: 0.3,
          ),
        ),

        const SizedBox(height: 14),
        Divider(color: AppColors.divider.withAlpha(40), height: 1),
        const SizedBox(height: 10),

        // ── Per-day number rows ─────────────────────────────────────────────
        ...widget.records.reversed.map((record) {
          final isToday = record == widget.records.last;
          final fillRatio = maxCount > 0 ? record.count / maxCount : 0.0;

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                // Day label
                SizedBox(
                  width: 38,
                  child: Text(
                    record.label,
                    style: TextStyle(
                      color: isToday ? AppColors.goldLight : AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Progress bar (thin, decorative only)
                Expanded(
                  child: Stack(
                    children: [
                      Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: AppColors.bg3.withAlpha(120),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: fillRatio.clamp(0.02, 1.0),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 700),
                          curve: Curves.easeOutCubic,
                          height: 6,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isToday
                                  ? [AppColors.goldLight, AppColors.goldMid]
                                  : [
                                      AppColors.goldMid.withValues(alpha: 0.6),
                                      AppColors.goldMid.withValues(alpha: 0.25),
                                    ],
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // User count — big, bold number
                Container(
                  width: 42,
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${record.count}',
                    style: TextStyle(
                      color: isToday ? AppColors.goldLight : AppColors.textPrimary,
                      fontSize: isToday ? 16 : 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'users',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }),

        const SizedBox(height: 12),
        Divider(color: AppColors.divider.withAlpha(40), height: 1),
        const SizedBox(height: 14),

        // ── Download PDF button ─────────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          child: GestureDetector(
            onTap: _isGeneratingPdf ? null : _downloadPdf,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                gradient: _isGeneratingPdf
                    ? null
                    : const LinearGradient(
                        colors: [Color(0xFFFBBF24), Color(0xFFD97706)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                color: _isGeneratingPdf ? AppColors.bg3 : null,
                borderRadius: BorderRadius.circular(12),
                boxShadow: _isGeneratingPdf
                    ? []
                    : [
                        BoxShadow(
                          color: AppColors.goldMid.withAlpha(80),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isGeneratingPdf)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(AppColors.goldMid),
                      ),
                    )
                  else
                    const Icon(Icons.picture_as_pdf_rounded, size: 18, color: Colors.black),
                  const SizedBox(width: 8),
                  Text(
                    _isGeneratingPdf ? 'Generating PDF...' : 'Download PDF Report',
                    style: TextStyle(
                      color: _isGeneratingPdf ? AppColors.textMuted : Colors.black,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── PDF generation helper ───────────────────────────────────────────────────
Future<Uint8List> _generateDauPdf(List<DauDayRecord> records) async {
  final doc = pw.Document();
  final now = DateTime.now();
  final dateStr =
      '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
  final weekTotal = records.fold(0, (sum, r) => sum + r.count);

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (pw.Context ctx) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // ── Title / Header ──────────────────────────────────────────────
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 14, horizontal: 18),
              decoration: pw.BoxDecoration(
                color: const PdfColor.fromInt(0xFF1a1a2e),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'ROYAL PIXELS',
                        style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                          color: const PdfColor.fromInt(0xFFFBBF24),
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Admin — Daily Active Users Report',
                        style: pw.TextStyle(
                          fontSize: 11,
                          color: const PdfColor.fromInt(0xFFCCCCCC),
                        ),
                      ),
                    ],
                  ),
                  pw.Text(
                    'Generated: $dateStr',
                    style: pw.TextStyle(
                      fontSize: 9,
                      color: const PdfColor.fromInt(0xFFAAAAAA),
                    ),
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 24),

            // ── Summary stats ───────────────────────────────────────────────
            pw.Row(
              children: [
                _pdfStatBox('7-Day Total', '$weekTotal users'),
                pw.SizedBox(width: 12),
                _pdfStatBox('Today', '${records.isNotEmpty ? records.last.count : 0} users'),
                pw.SizedBox(width: 12),
                _pdfStatBox(
                  'Peak Day',
                  records.isEmpty
                      ? '—'
                      : '${records.reduce((a, b) => a.count > b.count ? a : b).label}: '
                          '${records.map((r) => r.count).fold(0, (a, b) => a > b ? a : b)} users',
                ),
              ],
            ),

            pw.SizedBox(height: 24),

            // ── Table header ────────────────────────────────────────────────
            pw.Text(
              'PER-DAY BREAKDOWN (LAST 7 DAYS)',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: const PdfColor.fromInt(0xFF888888),
                letterSpacing: 1.2,
              ),
            ),
            pw.SizedBox(height: 8),

            // ── Data table ──────────────────────────────────────────────────
            pw.Table(
              border: pw.TableBorder.all(
                color: const PdfColor.fromInt(0xFFDDDDDD),
                width: 0.5,
              ),
              columnWidths: const {
                0: pw.FlexColumnWidth(2),
                1: pw.FlexColumnWidth(3),
                2: pw.FlexColumnWidth(2),
              },
              children: [
                // Header row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    color: PdfColor.fromInt(0xFF1a1a2e),
                  ),
                  children: [
                    _pdfTableHeader('Day'),
                    _pdfTableHeader('Date'),
                    _pdfTableHeader('Users'),
                  ],
                ),
                // Data rows (newest first)
                ...records.reversed.map((r) {
                  final isToday = r == records.last;
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: isToday
                          ? const PdfColor.fromInt(0xFFFFF9E6)
                          : const PdfColor.fromInt(0xFFFFFFFF),
                    ),
                    children: [
                      _pdfTableCell(
                        isToday ? 'Today' : r.label,
                        bold: isToday,
                      ),
                      _pdfTableCell(r.dateKey),
                      _pdfTableCell(
                        '${r.count}',
                        bold: isToday,
                      ),
                    ],
                  );
                }),
                // Total row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    color: PdfColor.fromInt(0xFFF5F5F5),
                  ),
                  children: [
                    _pdfTableCell('TOTAL', bold: true),
                    _pdfTableCell(''),
                    _pdfTableCell('$weekTotal', bold: true),
                  ],
                ),
              ],
            ),

            pw.SizedBox(height: 32),

            // ── Footer ──────────────────────────────────────────────────────
            pw.Divider(color: const PdfColor.fromInt(0xFFDDDDDD)),
            pw.SizedBox(height: 8),
            pw.Text(
              'Royal Pixels — Admin Report  •  Confidential  •  Do not distribute',
              style: pw.TextStyle(
                fontSize: 8,
                color: const PdfColor.fromInt(0xFFAAAAAA),
              ),
            ),
          ],
        );
      },
    ),
  );

  return Uint8List.fromList(await doc.save());
}

pw.Widget _pdfStatBox(String label, String value) {
  return pw.Expanded(
    child: pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFF9FAFB),
        border: pw.Border.all(
          color: const PdfColor.fromInt(0xFFE5E7EB),
          width: 0.5,
        ),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label.toUpperCase(),
            style: pw.TextStyle(
              fontSize: 8,
              color: const PdfColor.fromInt(0xFF9CA3AF),
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
              color: const PdfColor.fromInt(0xFF111827),
            ),
          ),
        ],
      ),
    ),
  );
}

pw.Widget _pdfTableHeader(String text) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    child: pw.Text(
      text.toUpperCase(),
      style: pw.TextStyle(
        fontSize: 9,
        fontWeight: pw.FontWeight.bold,
        color: const PdfColor.fromInt(0xFFFBBF24),
      ),
    ),
  );
}

pw.Widget _pdfTableCell(String text, {bool bold = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: 10,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        color: const PdfColor.fromInt(0xFF374151),
      ),
    ),
  );
}

// ─── Loading state (shimmer rows instead of shimmer bars) ────────────────────
class _DauLoadingState extends StatelessWidget {
  const _DauLoadingState();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header shimmer
        Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: AppColors.goldMid.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 140,
              height: 14,
              decoration: BoxDecoration(
                color: AppColors.goldMid.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Divider(color: AppColors.divider.withAlpha(40), height: 1),
        const SizedBox(height: 10),
        // Row shimmers
        ...List.generate(7, (i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppColors.goldMid.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: AppColors.bg3.withAlpha(120),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 32,
                  height: 14,
                  decoration: BoxDecoration(
                    color: AppColors.goldMid.withValues(alpha: i == 0 ? 0.2 : 0.08),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
