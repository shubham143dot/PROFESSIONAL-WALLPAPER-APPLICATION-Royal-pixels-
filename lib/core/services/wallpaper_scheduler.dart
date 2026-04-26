import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import 'package:wallpaper_manager_plus/wallpaper_manager_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

class WallpaperScheduler {
  static const String taskName = "com.royal_pixels.daily_wallpaper_task";

  static void callbackDispatcher() {
    Workmanager().executeTask((task, inputData) async {
      try {
        await Firebase.initializeApp();
        final prefs = await SharedPreferences.getInstance();
        final bool isEnabled = prefs.getBool('auto_daily_wallpaper') ?? false;
        if (!isEnabled) return true;

        // 1. Fetch today's pick from Firestore
        final date = DateTime.now().toIso8601String().split('T')[0];
        final snapshot = await FirebaseFirestore.instance
            .collection('daily_picks')
            .doc(date)
            .get();

        String? imageUrl;
        if (snapshot.exists) {
          imageUrl = snapshot.data()?['morning_wallpaper_url'];
        } else {
          // Fallback: Pick a trending one
          final trending = await FirebaseFirestore.instance
              .collection('wallpapers')
              .orderBy('viewCount', descending: true)
              .limit(1)
              .get();
          if (trending.docs.isNotEmpty) {
            imageUrl = trending.docs.first.data()['imageUrl'];
          }
        }

        if (imageUrl != null) {
          await _setWallpaperFromUrl(imageUrl);
        }
        return true;
      } catch (e) {
        if (kDebugMode) {
          debugPrint("WorkManager Task Error: $e");
        }
        return false;
      }
    });
  }

  static Future<void> _setWallpaperFromUrl(String url) async {
    final response = await http.get(Uri.parse(url));
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/daily_wp.jpg');
    await file.writeAsBytes(response.bodyBytes);

    await WallpaperManagerPlus().setWallpaper(
      file,
      WallpaperManagerPlus.bothScreens,
    );
  }

  static Future<void> init() async {
    await Workmanager().initialize(
      callbackDispatcher,
    );
  }

  static Future<void> scheduleDailyTask() async {
    await Workmanager().registerPeriodicTask(
      "1",
      taskName,
      frequency: const Duration(hours: 12),
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: false,
      ),
    );
  }

  static Future<void> cancelDailyTask() async {
    await Workmanager().cancelByUniqueName("1");
  }
}
