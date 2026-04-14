import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter/services.dart';
import 'package:screen_protector/screen_protector.dart';

import 'core/theme/app_theme.dart';
import 'presentation/navigation/app_router.dart';
import 'core/di/service_locator.dart';
import 'presentation/providers/auth_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await MobileAds.instance.initialize();
  setupLocator(); // setup GetIt Dependency Injection

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
    statusBarIconBrightness: Brightness.light,
  ));
  
  try {
    await ScreenProtector.preventScreenshotOn();
    await ScreenProtector.protectDataLeakageWithColor(Colors.black);
  } catch (e) {
    debugPrint('Screen protector init failed: $e');
  }
  
  try {
    if (Platform.isAndroid) {
      await FlutterDisplayMode.setHighRefreshRate();
    }
  } catch (_) {
    // Ignore error if device doesn't support it or if it's not applicable
  }
  
  runApp(
    const ProviderScope(
      child: RoyalPixelsApp(),
    ),
  );
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
      debugPrint('Screen protector policy failed: $e');
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
      title: 'Royal Pixels',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark, // Enforce dark theme based on requirements
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      routerConfig: appRouter, 
    );
  }
}
