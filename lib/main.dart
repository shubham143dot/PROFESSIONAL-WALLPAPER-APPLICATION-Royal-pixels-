import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'core/theme/app_theme.dart';
import 'presentation/navigation/app_router.dart';
import 'core/di/service_locator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  setupLocator(); // setup GetIt Dependency Injection
  
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

class RoyalPixelsApp extends StatelessWidget {
  const RoyalPixelsApp({super.key});

  @override
  Widget build(BuildContext context) {
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
