import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter/services.dart';
import 'package:screen_protector/screen_protector.dart';

import 'package:royal_pixels/core/theme/app_theme.dart';
import 'package:royal_pixels/presentation/navigation/app_router.dart';
import 'package:royal_pixels/core/di/service_locator.dart';
import 'package:royal_pixels/presentation/providers/auth_provider.dart';
import 'package:royal_pixels/core/services/notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:royal_pixels/core/constants/app_constants.dart';


import 'package:flutter_native_splash/flutter_native_splash.dart';

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Set system UI as early as possible
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
    statusBarIconBrightness: Brightness.light,
  ));

  // Parallelize non-dependent initializations for faster startup
  await Future.wait([
    _initFirebase(),
    setupLocator(),
    _initNotifications(),
    _initDisplayMode(),
    _initScreenProtector(),
  ]);

  runApp(
    const ProviderScope(
      child: RoyalPixelsApp(),
    ),
  );
  
  // Remove splash after first frame or shortly after
  FlutterNativeSplash.remove();
}

Future<void> _initFirebase() async {
  try {
    await Firebase.initializeApp();
    await FirebaseAppCheck.instance.activate(
      providerAndroid: AndroidPlayIntegrityProvider(),
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


class RoyalPixelsApp extends ConsumerStatefulWidget {
  const RoyalPixelsApp({super.key});

  @override
  ConsumerState<RoyalPixelsApp> createState() => _RoyalPixelsAppState();
}

class _RoyalPixelsAppState extends ConsumerState<RoyalPixelsApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyScreenshotPolicy(ref.read(authProvider));
    });
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

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (previous?.user?.email != next.user?.email) {
        _applyScreenshotPolicy(next);
      }
    });

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark, // Enforce dark theme based on requirements
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      routerConfig: appRouter, 
    );
  }
}
