import 'dart:io' show Platform;

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:screen_protector/screen_protector.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:royal_pixels/core/constants/app_constants.dart';
import 'package:royal_pixels/core/l10n/app_localizations.dart';
import 'package:royal_pixels/core/di/service_locator.dart';
import 'package:royal_pixels/core/scroll/scroll.dart';
import 'package:royal_pixels/core/services/adaptive_performance.dart';
import 'package:royal_pixels/core/services/ad_service.dart';
import 'package:royal_pixels/core/services/reward_ad_service.dart';
import 'package:royal_pixels/core/services/notification_service.dart';
import 'package:royal_pixels/core/services/wallpaper_scheduler.dart';
import 'package:royal_pixels/core/theme/app_theme.dart';
import 'package:royal_pixels/core/utils/royal_snack_bar.dart';
import 'package:royal_pixels/presentation/navigation/app_router.dart';
import 'package:royal_pixels/presentation/providers/auth_provider.dart';
import 'package:royal_pixels/core/services/iap_service.dart';

void main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Set system UI as early as possible.
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
    statusBarIconBrightness: Brightness.light,
  ));

  await Future.wait([
    _initFirebase(),
    setupLocator(),
    _initNotifications(),
    _initDisplayMode(),
    _initScreenProtector(),
    WallpaperScheduler.init(),
    AdaptivePerformance.initialize(), // Phase 3: detect device tier at startup
    _initMobileAds(),              // AdMob SDK + AdService preload
  ]);

  // Phase 7: Even more aggressive image cache sizing for 2GB-4GB stability
  // Low-end (2GB): 40 items / 40MB — extreme limit to prevent background process kills
  // Standard (4GB): 100 items / 100MB 
  // High-end (8GB+): 250 items / 350MB
  final (maxItems, maxBytes) = switch (AdaptivePerformance.tier) {
    DeviceTier.high => (250, 350 * 1024 * 1024),
    DeviceTier.standard => (100, 100 * 1024 * 1024),
    DeviceTier.low => (40, 40 * 1024 * 1024),
  };
  PaintingBinding.instance.imageCache.maximumSize = maxItems;
  PaintingBinding.instance.imageCache.maximumSizeBytes = maxBytes;

  runApp(
    const ProviderScope(
      child: RoyalPixelsApp(),
    ),
  );

  FlutterNativeSplash.remove();
}

Future<void> _initFirebase() async {
  try {
    await Firebase.initializeApp();
    await FirebaseAppCheck.instance.activate(
      // ignore: deprecated_member_use
      androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      // ignore: deprecated_member_use
      appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.deviceCheck,
    );
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (e) {
    if (kDebugMode) {
      debugPrint('Firebase initialization failed: $e');
    }
  }
}

Future<void> _initNotifications() async {
  try {
    await NotificationService.initialize();
  } catch (_) {}
}

Future<void> _initScreenProtector() async {
  try {
    await ScreenProtector.preventScreenshotOn();
    await ScreenProtector.protectDataLeakageWithColor(Colors.black);
  } catch (e) {
    if (kDebugMode) {
      debugPrint('Screen protector init failed: $e');
    }
  }
}

Future<void> _initDisplayMode() async {
  try {
    if (Platform.isAndroid) {
      await FlutterDisplayMode.setHighRefreshRate();
    }
  } catch (_) {}
}

Future<void> _initMobileAds() async {
  try {
    await MobileAds.instance.initialize();
    // Pre-load the first interstitial so it's ready when the user first taps.
    await AdService.instance.initialize();
    await RewardAdService.instance.initialize();
    if (kDebugMode) debugPrint('[AdMob] SDK initialized ✓');
  } catch (e) {
    if (kDebugMode) debugPrint('[AdMob] Initialization failed: $e');
  }
}

class RoyalPixelsApp extends ConsumerStatefulWidget {
  const RoyalPixelsApp({super.key});

  @override
  ConsumerState<RoyalPixelsApp> createState() => _RoyalPixelsAppState();
}

class _RoyalPixelsAppState extends ConsumerState<RoyalPixelsApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyScreenshotPolicy(ref.read(authProvider));
      // Initialize In-App Purchases stream
      ref.read(iapServiceProvider);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Note: IapService disposes its own subscription, but we could explicitly dispose if needed
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App resumed.
    }
  }

  void _applyScreenshotPolicy(AuthState authState) async {
    try {
      if (authState.user?.email == 'subhamsoudeep@gmail.com') {
        await ScreenProtector.preventScreenshotOff();
        await ScreenProtector.protectDataLeakageWithColor(Colors.transparent);
      } else {
        await ScreenProtector.preventScreenshotOn();
        await ScreenProtector.protectDataLeakageWithColor(Colors.black);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Screen protector policy failed: $e');
      }
    }
  }

  void _updateAdServices(AuthState authState) {
    final isPremium = authState.user?.isSubscribed ?? false;
    AdService.instance.isPremium = isPremium;
    RewardAdService.instance.isPremium = isPremium;
    if (kDebugMode) {
      debugPrint('[AdServices] Premium status updated: $isPremium');
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authProvider, (previous, next) {
      _updateAdServices(next);
      if (previous?.user?.email != next.user?.email) {
        _applyScreenshotPolicy(next);
      }
    });

    // Initial sync
    WidgetsBinding.instance.addPostFrameCallback((_) {
       _updateAdServices(ref.read(authProvider));
    });

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: RoyalSnackBar.messengerKey,
      scrollBehavior: const PremiumScrollBehavior(),
      themeMode: ThemeMode.dark,
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      routerConfig: appRouter,
      // ── Localization ──────────────────────────────────────────────────
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,  // RTL support (Arabic, Urdu, etc.)
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // ─────────────────────────────────────────────────────────────────
    );
  }
}
