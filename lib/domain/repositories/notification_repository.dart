import '../entities/notification_item.dart';

abstract class NotificationRepository {
  Stream<List<NotificationItem>> getNotifications(String? userId);
  Future<void> addNotification(String? userId, NotificationItem notification);
  Future<void> markAsRead(String? userId, String notificationId);
  Future<void> markAllAsRead(String? userId);
  Future<void> clearAll(String? userId);
  Future<void> deleteNotification(String? userId, String notificationId);

  /// Streams global announcements for all users.
  Stream<List<NotificationItem>> getBroadcastNotifications();
}
