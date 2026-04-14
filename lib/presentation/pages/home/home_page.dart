import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'dart:ui';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:shimmer/shimmer.dart';
import '../../../domain/entities/wallpaper_entity.dart';
import '../../../core/theme/app_colors.dart';
import 'package:flutter/services.dart';
import '../../providers/auth_provider.dart';
import '../../providers/wallpaper_provider.dart';
import '../../widgets/wallpaper_card.dart';
import 'wallpaper_search_delegate.dart';
import '../my_wallpapers/my_wallpapers_page.dart';
import '../category/categories_list_page.dart';

// ─── Filter enum ─────────────────────────────────────────────────────────────
enum WallpaperFilter { all, free, premium, special }

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with TickerProviderStateMixin {
  // Bottom nav index: 0=Home, 1=Categories, 2=Favorites, 3=Profile
  int _navIndex = 0;

  // Active wallpaper filter (on Home tab)
  WallpaperFilter _filter = WallpaperFilter.all;


  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.read(wallpaperProvider.notifier).loadWallpapers());
  }

  void _openSearch() {
    final wallpaperState = ref.read(wallpaperProvider);
    final allWallpapers = [
      ...wallpaperState.freeWallpapers,
      ...wallpaperState.premiumWallpapers,
    ];
    showSearch(
      context: context,
      delegate: WallpaperSearchDelegate(allWallpapers),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  // ── Apply filter to full wallpaper list ────────────────────────────────────
  List<WallpaperEntity> _filteredWallpapers(WallpaperState state) {
    switch (_filter) {
      case WallpaperFilter.free:
        return state.freeWallpapers;
      case WallpaperFilter.premium:
        return state.premiumWallpapers;
      case WallpaperFilter.special:
        return state.specialWallpapers;
      case WallpaperFilter.all:
        return [
          ...state.freeWallpapers,
          ...state.premiumWallpapers,
          ...state.specialWallpapers,
        ];
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
      appBar: _navIndex == 0
          ? AppBar(
              toolbarHeight: 56,
              flexibleSpace: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18.0, sigmaY: 18.0),
                  child: Container(color: AppColors.bg0.withAlpha(160)),
                ),
              ),
              title: ShaderMask(
                shaderCallback: (bounds) =>
                    AppColors.goldGradient.createShader(bounds),
                child: const Text(
                  'Royal Pixels',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.0,
                    color: Colors.white,
                    fontSize: 20,
                  ),
                ),
              ),
              actions: [
                IconButton(
                  tooltip: 'Search',
                  icon: const Icon(Icons.search,
                      color: AppColors.textSecondary),
                  onPressed: _openSearch,
                ),
              ],
            )
          : null,
      // ── Bottom Navigation Bar ──────────────────────────────────────────────
      bottomNavigationBar: _buildBottomNav(userState, bottomPadding),
      // ── Body ───────────────────────────────────────────────────────────────
      body: IndexedStack(
        index: _navIndex,
        children: [
          // Tab 0: Home wallpaper grid
          _buildHomeTab(wallpaperState),
          // Tab 1: Categories
          const CategoriesListPage(embeddedMode: true),
          // Tab 2: Favorites
          const MyWallpapersPage(embeddedMode: true),
          // Tab 3: Profile
          _buildProfileTab(userState),
        ],
      ),
    );
  }

  // ── Bottom navigation bar ──────────────────────────────────────────────────
  Widget _buildBottomNav(AuthState userState, double bottomPadding) {
    final items = [
      _NavItem(Icons.home_rounded, Icons.home_outlined, 'Home'),
      _NavItem(Icons.grid_view_rounded, Icons.grid_view_outlined, 'Categories'),
      _NavItem(Icons.favorite_rounded, Icons.favorite_border_rounded,
          'Favorites'),
      _NavItem(Icons.person_rounded, Icons.person_outline_rounded, 'Profile'),
    ];

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          padding: EdgeInsets.only(
            bottom: bottomPadding > 0 ? bottomPadding : 8,
            top: 8,
          ),
          decoration: BoxDecoration(
            color: AppColors.bg0.withAlpha(200),
            border: const Border(
              top: BorderSide(color: AppColors.glassBorder, width: 0.8),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              final item = items[i];
              final isActive = _navIndex == i;
              return _buildNavItem(item, i, isActive);
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(_NavItem item, int index, bool isActive) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _navIndex = index);
      },
      child: AnimatedScale(
        scale: isActive ? 1.05 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutBack,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.goldMid.withAlpha(25)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: AppColors.goldMid.withAlpha(35),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    )
                  ]
                : [],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
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
                      size: 24),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 10,
                fontWeight:
                    isActive ? FontWeight.w700 : FontWeight.w500,
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
    final filters = [
      (WallpaperFilter.all, Icons.auto_awesome_mosaic_outlined, 'All',
          [
            ...state.freeWallpapers,
            ...state.premiumWallpapers,
            ...state.specialWallpapers,
          ].length),
      (WallpaperFilter.free, Icons.wallpaper_outlined, 'Free',
          state.freeWallpapers.length),
      (WallpaperFilter.premium, Icons.diamond_outlined, 'Premium',
          state.premiumWallpapers.length),
      (WallpaperFilter.special, Icons.auto_awesome_outlined, 'Special',
          state.specialWallpapers.length),
    ];

    return Container(
      // Top padding for AppBar height
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
            Color chipColor;
            LinearGradient? chipGradient;
            if (f.$1 == WallpaperFilter.special) {
              chipColor = AppColors.accentPurple;
              chipGradient =
                  isActive ? AppColors.specialGradient : null;
            } else if (f.$1 == WallpaperFilter.premium) {
              chipColor = AppColors.goldMid;
              chipGradient = isActive ? AppColors.goldGradient : null;
            } else {
              chipColor = AppColors.goldMid;
              chipGradient = isActive ? AppColors.goldGradient : null;
            }

            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _filter = f.$1);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 10),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: chipGradient,
                  color: isActive ? null : AppColors.bg2,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: isActive
                        ? Colors.transparent
                        : chipColor.withAlpha(50),
                    width: 1.2,
                  ),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: chipColor.withAlpha(90),
                            blurRadius: 16,
                            spreadRadius: 2,
                            offset: const Offset(0, 4),
                          )
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      f.$2,
                      size: 14,
                      color: isActive
                          ? (f.$1 == WallpaperFilter.special
                              ? Colors.white
                              : Colors.black)
                          : chipColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      f.$3,
                      style: TextStyle(
                        color: isActive
                            ? (f.$1 == WallpaperFilter.special
                                ? Colors.white
                                : Colors.black)
                            : AppColors.textSecondary,
                        fontWeight: isActive
                            ? FontWeight.w700
                            : FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                    if (!state.isLoading && f.$4 > 0) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: isActive
                              ? Colors.black.withAlpha(40)
                              : chipColor.withAlpha(30),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${f.$4}',
                          style: TextStyle(
                            color: isActive
                                ? (f.$1 == WallpaperFilter.special
                                    ? Colors.white70
                                    : Colors.black54)
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
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── Skeleton ───────────────────────────────────────────────────────────────
  Widget _buildSkeleton() {
    return MasonryGridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      gridDelegate:
          const SliverSimpleGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      itemCount: 10,
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      gridDelegate:
          const SliverSimpleGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      itemCount: wallpapers.length,
      itemBuilder: (context, index) {
        final wp = wallpapers[index];
        final heights = [200.0, 260.0, 180.0, 240.0, 220.0];
        final h = heights[index % heights.length];
        return SizedBox(
          height: h,
          child: WallpaperCard(
            key: ValueKey(wp.id),
            wallpaper: wp,
            onTap: () => context.push('/detail', extra: wp),
          ),
        )
            .animate(delay: (index * 35).ms)
            .fade(duration: 300.ms, curve: Curves.easeOut)
            .slideY(
                begin: 0.06,
                end: 0,
                duration: 300.ms,
                curve: Curves.easeOutQuart);
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
                20, MediaQuery.of(context).padding.top + 24, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── User card ────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.bg1,
                    borderRadius: BorderRadius.circular(24),
                    border:
                        Border.all(color: AppColors.glassBorder, width: 1),
                  ),
                  child: Row(
                    children: [
                      // Avatar with gold ring
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppColors.goldRingGradient,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(2.5),
                          child: CircleAvatar(
                            backgroundColor: AppColors.bg0,
                            child: const Icon(Icons.diamond,
                                color: AppColors.goldMid, size: 30),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.name ?? 'Guest User',
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              user?.email ?? '',
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      // PRO badge
                      if (isSubscribed)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            gradient: AppColors.goldGradient,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'PRO',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── PRO membership tile ───────────────────────────────
                _ProfileMenuTile(
                  icon: Icons.workspace_premium,
                  label: isSubscribed ? 'PRO Member' : 'Get PRO',
                  subtitle: isSubscribed
                      ? 'All Premium wallpapers unlocked'
                      : 'Unlock all Premium wallpapers',
                  isGold: true,
                  trailingWidget: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: AppColors.goldGradient,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isSubscribed ? 'ACTIVE' : 'UPGRADE',
                      style: const TextStyle(
                          color: Colors.black,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5),
                    ),
                  ),
                  onTap: () => context.push('/subscription'),
                ),
                const SizedBox(height: 14),

                // ── Navigation items ─────────────────────────────────
                const Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 10),
                  child: Text('Navigation',
                      style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2)),
                ),
                _ProfileMenuTile(
                  icon: Icons.leaderboard_rounded,
                  label: 'Leaderboard',
                  onTap: () => context.push('/leaderboard'),
                ),
                const SizedBox(height: 8),
                _ProfileMenuTile(
                  icon: Icons.info_outline_rounded,
                  label: 'About',
                  onTap: () => context.push('/about'),
                ),

                // ── Admin section ────────────────────────────────────
                if (user?.email == 'subhamsoudeep@gmail.com') ...[
                  const SizedBox(height: 20),
                  const Padding(
                    padding: EdgeInsets.only(left: 4, bottom: 10),
                    child: Text('Admin',
                        style: TextStyle(
                            color: AppColors.goldMid,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2)),
                  ),
                  _ProfileMenuTile(
                    icon: Icons.admin_panel_settings_rounded,
                    label: 'Admin Upload',
                    isGold: true,
                    onTap: () => context.push('/upload'),
                  ),
                  const SizedBox(height: 8),
                  _ProfileMenuTile(
                    icon: Icons.edit_note_rounded,
                    label: 'Rename Category',
                    isGold: true,
                    onTap: () => context.push('/rename-category'),
                  ),
                  const SizedBox(height: 8),
                  _ProfileMenuTile(
                    icon: Icons.category_rounded,
                    label: 'Category Covers',
                    isGold: true,
                    onTap: () => context.push('/upload-category-cover'),
                  ),
                ],

                const SizedBox(height: 20),
                Divider(color: AppColors.divider, height: 1),
                const SizedBox(height: 8),

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
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ],
    );
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
class _ProfileMenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool isGold;
  final bool isDanger;
  final VoidCallback onTap;
  final Widget? trailingWidget;

  const _ProfileMenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.isGold = false,
    this.isDanger = false,
    this.trailingWidget,
  });

  @override
  Widget build(BuildContext context) {
    final Color iconColor = isDanger
        ? Colors.redAccent
        : isGold
            ? AppColors.goldMid
            : AppColors.textSecondary;

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.bg1,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isGold
                  ? AppColors.goldMid.withAlpha(40)
                  : AppColors.glassBorder,
              width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isDanger
                    ? Colors.red.withAlpha(20)
                    : isGold
                        ? AppColors.goldMid.withAlpha(25)
                        : AppColors.bg2,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
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
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
            trailingWidget ??
                Icon(Icons.chevron_right_rounded,
                    color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}

// ─── Skeleton card ────────────────────────────────────────────────────────────
class _SkeletonCard extends StatelessWidget {
  final double height;
  const _SkeletonCard({super.key, required this.height});

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

