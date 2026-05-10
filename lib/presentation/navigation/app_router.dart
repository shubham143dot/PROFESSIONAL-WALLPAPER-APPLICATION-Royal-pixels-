import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../domain/entities/wallpaper_entity.dart';
import '../pages/splash/splash_page.dart';
import '../pages/auth/login_page.dart';
import '../pages/home/home_page.dart';
import '../pages/detail/wallpaper_detail_page.dart';
import '../pages/my_wallpapers/my_wallpapers_page.dart';
import '../pages/about/about_page.dart';
import '../pages/upload/upload_wallpaper_page.dart';
import '../pages/category/category_page.dart';
import '../pages/category/categories_list_page.dart';
import '../pages/upload/upload_category_cover_page.dart';
import '../pages/upload/rename_category_page.dart';
import '../pages/payment/subscription_page.dart';

import '../pages/diamond/diamond_store_page.dart';
import '../pages/notifications/notifications_page.dart';
import '../pages/social_feed/social_feed_page.dart';
import '../pages/detail/wallpaper_deeplink_page.dart';

import '../../core/constants/animation_constants.dart';
import '../../core/animations/liquid_transition.dart';
import '../../core/services/adaptive_performance.dart';

CustomTransitionPage<T> buildPageWithDefaultTransition<T>({
  required BuildContext context,
  required GoRouterState state,
  required Widget child,
}) {
  // Phase 7: Bypass complex transitions on low-end devices to eliminate navigation lag
  if (!AdaptivePerformance.enableCustomPageTransitions) {
    return CustomTransitionPage<T>(
      key: state.pageKey,
      child: child,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      transitionsBuilder: (context, animation, secondaryAnimation, child) => child,
    );
  }

  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    // 320ms matches Android Material 3 standard transition
    // (iOS uses ~350ms; anything over 400ms feels sluggish)
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 280),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      // Material 3 deceleration curve — fast start, gentle finish
      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: AppAnimations.premiumCurve,
        reverseCurve: Curves.easeInQuint,
      );

      // iOS-level depth: Scale down the previous page as the new one arrives
      return ScaleTransition(
        scale: Tween<double>(begin: 1.0, end: 0.94).animate(
          CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeInOutCubic),
        ),
        child: FadeTransition(
          opacity: Tween<double>(begin: 1.0, end: 0.5).animate(
            CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeInOutCubic),
          ),
          child: FadeTransition(
            opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curvedAnimation),
            child: ScaleTransition(
              scale: Tween<double>(
                begin: AppAnimations.pageScaleBegin,
                end: 1.0,
              ).animate(curvedAnimation),
              child: child,
            ),
          ),
        ),
      );
    },
  );
}

/// Slide-up transition for bottom-sheet-style pages (detail).
CustomTransitionPage<T> buildSlideUpTransition<T>({
  required BuildContext context,
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 380),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curvedAnim = CurvedAnimation(
        parent: animation,
        curve: AppAnimations.premiumCurve,
        reverseCurve: Curves.easeInQuint,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.0, 0.08),
          end: Offset.zero,
        ).animate(curvedAnim),
        child: FadeTransition(
          opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curvedAnim),
          child: child,
        ),
      );
    },
  );
}

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: 'splash',
      pageBuilder: (context, state) => buildPageWithDefaultTransition(
          context: context, state: state, child: const SplashPage()),
    ),
    GoRoute(
      path: '/login',
      name: 'login',
      pageBuilder: (context, state) => buildPageWithDefaultTransition(
          context: context, state: state, child: const LoginPage()),
    ),
    GoRoute(
      path: '/home',
      name: 'home',
      pageBuilder: (context, state) => buildPageWithDefaultTransition(
          context: context, state: state, child: const HomePage()),
    ),
    GoRoute(
      path: '/detail',
      name: 'detail',
      pageBuilder: (context, state) {
        WallpaperEntity wallpaper;
        double velocity = 0.0;

        if (state.extra is WallpaperEntity) {
          wallpaper = state.extra as WallpaperEntity;
        } else if (state.extra is Map<String, dynamic>) {
          final extra = state.extra as Map<String, dynamic>;
          wallpaper = extra['wallpaper'] as WallpaperEntity;
          velocity = extra['velocity'] as double? ?? 0.0;
        } else {
          // Fallback if extra is null or wrong type
          return buildPageWithDefaultTransition(
              context: context, state: state, child: const Scaffold());
        }

        if (AdaptivePerformance.isLow) {
          return buildPageWithDefaultTransition(
            context: context,
            state: state,
            child: WallpaperDetailPage(wallpaper: wallpaper),
          );
        }

        return LiquidTransitionPage(
          key: state.pageKey,
          scrollVelocity: velocity,
          child: WallpaperDetailPage(wallpaper: wallpaper),
        );
      },
    ),
    GoRoute(
      path: '/my-wallpapers',
      name: 'my-wallpapers',
      pageBuilder: (context, state) => buildPageWithDefaultTransition(
          context: context, state: state, child: const MyWallpapersPage()),
    ),
    GoRoute(
      path: '/about',
      name: 'about',
      pageBuilder: (context, state) => buildPageWithDefaultTransition(
          context: context, state: state, child: const AboutPage()),
    ),
    GoRoute(
      path: '/upload',
      name: 'upload',
      pageBuilder: (context, state) => buildPageWithDefaultTransition(
          context: context, state: state, child: const UploadWallpaperPage()),
    ),
    GoRoute(
      path: '/category',
      name: 'category',
      pageBuilder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return buildPageWithDefaultTransition(
            context: context,
            state: state,
            child: CategoryPage(
              categoryName: extra['categoryName'] as String,
              wallpapers: extra['wallpapers'] as List<WallpaperEntity>,
            ));
      },
    ),
    GoRoute(
      path: '/categories-list',
      name: 'categories-list',
      pageBuilder: (context, state) => buildPageWithDefaultTransition(
          context: context, state: state, child: const CategoriesListPage()),
    ),
    GoRoute(
      path: '/upload-category-cover',
      name: 'upload-category-cover',
      pageBuilder: (context, state) => buildPageWithDefaultTransition(
          context: context,
          state: state,
          child: const UploadCategoryCoverPage()),
    ),

    GoRoute(
      path: '/rename-category',
      name: 'rename-category',
      pageBuilder: (context, state) {
        final initialCategory = state.extra as String?;
        return buildPageWithDefaultTransition(
            context: context,
            state: state,
            child: RenameCategoryPage(initialCategory: initialCategory));
      },
    ),
    GoRoute(
      path: '/diamonds',
      name: 'diamonds',
      pageBuilder: (context, state) => buildPageWithDefaultTransition(
        context: context,
        state: state,
        child: const DiamondStorePage(),
      ),
    ),
    GoRoute(
      path: '/subscription',
      name: 'subscription',
      pageBuilder: (context, state) => buildPageWithDefaultTransition(
        context: context,
        state: state,
        child: const SubscriptionPage(),
      ),
    ),
    GoRoute(
      path: '/notifications',
      name: 'notifications',
      pageBuilder: (context, state) => buildPageWithDefaultTransition(
        context: context,
        state: state,
        child: const NotificationsPage(),
      ),
    ),
    GoRoute(
      path: '/social-feed',
      name: 'social-feed',
      pageBuilder: (context, state) {
        final initialWallpaperId = state.extra as String?;
        return buildPageWithDefaultTransition(
          context: context,
          state: state,
          child: SocialFeedPage(initialWallpaperId: initialWallpaperId),
        );
      },
    ),
    GoRoute(
      path: '/wallpaper/:id',
      name: 'wallpaper-by-id',
      pageBuilder: (context, state) {
        final id = state.pathParameters['id']!;
        return buildPageWithDefaultTransition(
          context: context,
          state: state,
          child: WallpaperDeepLinkPage(wallpaperId: id),
        );
      },
    ),
  ],
);
