import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/service_locator.dart';
import '../../domain/entities/notification_item.dart';
import '../../domain/entities/notification_type.dart';
import '../../domain/repositories/notification_repository.dart';
import 'auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

final notificationProvider = AsyncNotifierProvider<NotificationNotifier, List<NotificationItem>>(() {
  return NotificationNotifier();
});

class NotificationNotifier extends AsyncNotifier<List<NotificationItem>> {
  StreamSubscription? _subscription;
  StreamSubscription? _broadcastSubscription;
  static const String _processedBroadcastsKey = 'processed_broadcast_ids';
  
  // Anti-spam / Idempotency
  String? _lastNotificationKey;
  DateTime? _lastNotificationTime;


  @override
  Future<List<NotificationItem>> build() async {
    final authState = ref.watch(authProvider);
    final String? userId = authState.isAuthenticated ? authState.user?.uid : null;
    
    // Cancel existing subscription if any
    await _subscription?.cancel();
    
    final repository = sl<NotificationRepository>();
    
    // We use a stream for real-time updates (Firestore) or periodic local updates
    final controller = StreamController<List<NotificationItem>>();
    
    _subscription = repository.getNotifications(userId).listen((notifications) {
      state = AsyncData(notifications);
      controller.add(notifications);
    });

    // Listen for global broadcasts
    await _broadcastSubscription?.cancel();
    _broadcastSubscription = repository.getBroadcastNotifications().listen((broadcasts) async {
      await _processBroadcasts(broadcasts);
    });

    // Initial fetch
    ref.onDispose(() {
      _subscription?.cancel();
      _broadcastSubscription?.cancel();
    });

    // Return current state or empty until stream emits
    return state.value ?? [];
  }

  Future<void> _processBroadcasts(List<NotificationItem> broadcasts) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> processedIds = prefs.getStringList(_processedBroadcastsKey) ?? [];
    bool updated = false;

    for (var broadcast in broadcasts) {
      if (!processedIds.contains(broadcast.id)) {
        // Add to user's personal list
        await addNotification(
          title: broadcast.title,
          message: broadcast.message,
          type: broadcast.type,
          imageUrl: broadcast.imageUrl,
          data: broadcast.data,
        );
        
        processedIds.add(broadcast.id);
        updated = true;
      }
    }

    if (updated) {
      // Limit to 100 IDs to avoid bloat
      if (processedIds.length > 100) processedIds.removeRange(0, processedIds.length - 100);
      await prefs.setStringList(_processedBroadcastsKey, processedIds);
    }
  }


  Future<void> addNotification({
    required String title,
    required String message,
    required NotificationType type,
    String? imageUrl,
    Map<String, dynamic>? data,
  }) async {
    // Generate a unique key for this specific content
    final String currentKey = '$title|$message';
    final now = DateTime.now();
    
    // Throttling: If the same notification is sent within 2 seconds, skip it.
    if (_lastNotificationKey == currentKey && 
        _lastNotificationTime != null && 
        now.difference(_lastNotificationTime!).inSeconds < 2) {
      return;
    }
    
    _lastNotificationKey = currentKey;
    _lastNotificationTime = now;

    final authState = ref.read(authProvider);
    final String? userId = authState.isAuthenticated ? authState.user?.uid : null;
    final repository = sl<NotificationRepository>();

    final notification = NotificationItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      message: message,
      timestamp: DateTime.now(),
      type: type,
      imageUrl: imageUrl,
      data: data,
    );

    await repository.addNotification(userId, notification);
    
    // For local notifications (Guest), we manually refresh since SharedPreferences 
    // doesn't have a native stream.
    if (userId == null) {
      ref.invalidate(notificationProvider);
    }
  }

  Future<void> markAsRead(String id) async {
    final authState = ref.read(authProvider);
    final String? userId = authState.isAuthenticated ? authState.user?.uid : null;
    await sl<NotificationRepository>().markAsRead(userId, id);
    if (userId == null) ref.invalidate(notificationProvider);
  }

  Future<void> markAllAsRead() async {
    final authState = ref.read(authProvider);
    final String? userId = authState.isAuthenticated ? authState.user?.uid : null;
    await sl<NotificationRepository>().markAllAsRead(userId);
    if (userId == null) ref.invalidate(notificationProvider);
  }

  Future<void> clearAll() async {
    final authState = ref.read(authProvider);
    final String? userId = authState.isAuthenticated ? authState.user?.uid : null;
    await sl<NotificationRepository>().clearAll(userId);
    if (userId == null) ref.invalidate(notificationProvider);
  }

  Future<void> deleteNotification(String id) async {
    final authState = ref.read(authProvider);
    final String? userId = authState.isAuthenticated ? authState.user?.uid : null;
    await sl<NotificationRepository>().deleteNotification(userId, id);
    if (userId == null) ref.invalidate(notificationProvider);
  }
}

/// Helper provider for unread count
final unreadNotificationCountProvider = Provider<int>((ref) {
  final notificationsAsync = ref.watch(notificationProvider);
  return notificationsAsync.maybeWhen(
    data: (notifications) => notifications.where((n) => !n.isRead).length,
    orElse: () => 0,
  );
});
