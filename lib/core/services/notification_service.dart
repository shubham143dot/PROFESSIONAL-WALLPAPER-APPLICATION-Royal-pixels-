import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../constants/app_constants.dart';
import '../di/service_locator.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const String _lastPushKey = 'last_push_timestamp';
  static const String _channelId = 'royal_pixels_channel';
  static const String _channelName = 'Royal Pixels Notifications';

  static Future<void> initialize() async {
    // 1. Request permissions (especially for iOS and Android 13+)
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    // 2. Create Notification Channel (Android)
    await createNotificationChannel();

    // 3. Initialize Local Notifications (for foreground notifications)
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();

    await _localNotifications.initialize(
      settings: const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: (details) {
        // Handle notification click if needed
      },
    );

    // 4. Listen for foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showLocalNotification(message);
    });

    // 5. Handle token refresh
    messaging.onTokenRefresh.listen((newToken) async {
      // If a user is currently logged in, we should update their token
      // This will be handled by AuthProvider typically, but we can
      // trigger a check if we have the UID.
    });
  }

  static Future<void> createNotificationChannel() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidPlugin =
          _localNotifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        const channel = AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: 'Premium wallpaper updates and elite rewards',
          importance: Importance.max,
          enableVibration: true,
          playSound: true,
        );
        await androidPlugin.createNotificationChannel(channel);
      }
    }
  }

  static Future<void> uploadFCMToken(String userId) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;

      final firestore = sl<FirebaseFirestore>();
      // Save token in a sub-collection for multiple-device reliability
      await firestore
          .collection('users')
          .doc(userId)
          .collection('tokens')
          .doc(token)
          .set({
        'token': token,
        'platform': defaultTargetPlatform.toString(),
        'updatedAt': FieldValue.serverTimestamp(),
        'appVersion': AppConstants.appVersion,
      });

      if (kDebugMode) {
        debugPrint('FCM Token uploaded for $userId: $token');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to upload FCM token: $e');
      }
    }
  }

  static Future<void> _showLocalNotification(RemoteMessage message) async {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      importance: Importance.max,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    await _localNotifications.show(
      id: message.hashCode,
      title: message.notification?.title ?? AppConstants.appName,
      body: message.notification?.body ?? '',
      notificationDetails: NotificationDetails(android: androidDetails, iOS: iosDetails),
    );
  }

  static Future<bool> canReceivePush() async {
    final prefs = await SharedPreferences.getInstance();
    final lastPushStr = prefs.getString(_lastPushKey);

    if (lastPushStr == null) return true;

    try {
      final lastPush = DateTime.parse(lastPushStr);
      final now = DateTime.now();
      return now.difference(lastPush).inDays >= 1;
    } catch (_) {
      return true;
    }
  }

  static Future<void> recordPushReceived() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastPushKey, DateTime.now().toIso8601String());
  }

  static Future<String?> getFCMToken() async {
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to get FCM token: $e');
      }
      return null;
    }
  }
}

/// Top-level background message handler for Firebase Messaging
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If we wanted to ignore the notification based on the 1-per-day limit,
  // we could check it here. However, background notifications are often
  // automatically displayed by the OS if they have a 'notification' payload.
  if (kDebugMode) {
    debugPrint("Handling a background message: ${message.messageId}");
  }
}
