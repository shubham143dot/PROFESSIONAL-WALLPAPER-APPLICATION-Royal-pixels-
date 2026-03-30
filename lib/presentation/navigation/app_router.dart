import 'package:go_router/go_router.dart';
import '../../domain/entities/wallpaper_entity.dart';
import '../pages/splash/splash_page.dart';
import '../pages/auth/login_page.dart';
import '../pages/home/home_page.dart';
import '../pages/detail/wallpaper_detail_page.dart';
import '../pages/my_wallpapers/my_wallpapers_page.dart';
import '../pages/about/about_page.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: 'splash',
      builder: (context, state) => const SplashPage(),
    ),
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: '/home',
      name: 'home',
      builder: (context, state) => const HomePage(),
    ),
    GoRoute(
      path: '/detail',
      name: 'detail',
      builder: (context, state) {
        final wallpaper = state.extra as WallpaperEntity;
        return WallpaperDetailPage(wallpaper: wallpaper);
      },
    ),
    GoRoute(
      path: '/my-wallpapers',
      name: 'my-wallpapers',
      builder: (context, state) => const MyWallpapersPage(),
    ),
    GoRoute(
      path: '/about',
      name: 'about',
      builder: (context, state) => const AboutPage(),
    ),
  ],
);
