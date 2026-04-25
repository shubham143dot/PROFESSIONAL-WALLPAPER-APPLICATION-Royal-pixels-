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
import '../pages/subscription/subscription_page.dart';
import '../pages/diamond/diamond_store_page.dart';
import '../pages/notifications/notifications_page.dart';


import '../../core/constants/animation_constants.dart';

CustomTransitionPage buildPageWithDefaultTransition<T>({
  required BuildContext context, 
  required GoRouterState state, 
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: AppAnimations.premiumTransition,
    reverseTransitionDuration: AppAnimations.premiumTransition,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: AppAnimations.premiumCurve,
        reverseCurve: AppAnimations.premiumCurve.flipped,
      );
      return FadeTransition(
        opacity: curvedAnimation,
        child: ScaleTransition(
          scale: Tween<double>(
            begin: AppAnimations.pageScaleBegin, 
            end: 1.0
          ).animate(curvedAnimation),
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
        context: context, 
        state: state, 
        child: const SplashPage()
      ),
    ),
    GoRoute(
      path: '/login',
      name: 'login',
      pageBuilder: (context, state) => buildPageWithDefaultTransition(
        context: context, 
        state: state, 
        child: const LoginPage()
      ),
    ),
    GoRoute(
      path: '/home',
      name: 'home',
      pageBuilder: (context, state) => buildPageWithDefaultTransition(
        context: context, 
        state: state, 
        child: const HomePage()
      ),
    ),
    GoRoute(
      path: '/detail',
      name: 'detail',
      pageBuilder: (context, state) {
        final wallpaper = state.extra as WallpaperEntity;
        return buildPageWithDefaultTransition(
          context: context, 
          state: state, 
          child: WallpaperDetailPage(wallpaper: wallpaper)
        );
      },
    ),
    GoRoute(
      path: '/my-wallpapers',
      name: 'my-wallpapers',
      pageBuilder: (context, state) => buildPageWithDefaultTransition(
        context: context, 
        state: state, 
        child: const MyWallpapersPage()
      ),
    ),
    GoRoute(
      path: '/about',
      name: 'about',
      pageBuilder: (context, state) => buildPageWithDefaultTransition(
        context: context, 
        state: state, 
        child: const AboutPage()
      ),
    ),
    GoRoute(
      path: '/upload',
      name: 'upload',
      pageBuilder: (context, state) => buildPageWithDefaultTransition(
        context: context, 
        state: state, 
        child: const UploadWallpaperPage()
      ),
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
          )
        );
      },
    ),
    GoRoute(
      path: '/categories-list',
      name: 'categories-list',
      pageBuilder: (context, state) => buildPageWithDefaultTransition(
        context: context, 
        state: state, 
        child: const CategoriesListPage()
      ),
    ),
    GoRoute(
      path: '/upload-category-cover',
      name: 'upload-category-cover',
      pageBuilder: (context, state) => buildPageWithDefaultTransition(
        context: context, 
        state: state, 
        child: const UploadCategoryCoverPage()
      ),
    ),
    GoRoute(
      path: '/subscription',
      name: 'subscription',
      pageBuilder: (context, state) => buildPageWithDefaultTransition(
        context: context, 
        state: state, 
        child: const SubscriptionPage()
      ),
    ),
    GoRoute(
      path: '/rename-category',
      name: 'rename-category',
      pageBuilder: (context, state) {
        final initialCategory = state.extra as String?;
        return buildPageWithDefaultTransition(
          context: context, 
          state: state, 
          child: RenameCategoryPage(initialCategory: initialCategory)
        );
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
      path: '/notifications',
      name: 'notifications',
      pageBuilder: (context, state) => buildPageWithDefaultTransition(
        context: context,
        state: state,
        child: const NotificationsPage(),
      ),
    ),
  ],
);

