import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/notification_item.dart';
import '../../domain/repositories/notification_repository.dart';
import '../models/notification_model.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  final FirebaseFirestore firestore;
  final SharedPreferences prefs;

  static const String _localNotificationsKey = 'local_notifications';

  NotificationRepositoryImpl({
    required this.firestore,
    required this.prefs,
  });

  @override
  Stream<List<NotificationItem>> getNotifications(String? userId) {
    if (userId == null) {
      // Return local notifications stream
      return _getLocalNotificationsStream();
    } else {
      // Return Firestore notifications stream
      return firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .orderBy('timestamp', descending: true)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) {
          return NotificationModel.fromFirestore(doc.data(), doc.id);
        }).toList();
      });
    }
  }

  Stream<List<NotificationItem>> _getLocalNotificationsStream() {
    // Since SharedPreferences doesn't have a native stream for keys,
    // we'll return a stream that emits once and we'll manually trigger updates if needed,
    // or just rely on a BehaviorSubject style if we were using a more complex setup.
    // For simplicity, we'll fetch once. The provider will handle the rest.
    return Stream.fromFuture(_getLocalNotifications());
  }

  Future<List<NotificationItem>> _getLocalNotifications() async {
    final String? data = prefs.getString(_localNotificationsKey);
    if (data == null) return [];
    final List<dynamic> jsonList = json.decode(data);
    return jsonList.map((j) => NotificationModel.fromJson(j)).toList();
  }

  @override
  Future<void> addNotification(
      String? userId, NotificationItem notification) async {
    final model = NotificationModel(
      id: notification.id,
      title: notification.title,
      message: notification.message,
      timestamp: notification.timestamp,
      type: notification.type,
      isRead: notification.isRead,
      imageUrl: notification.imageUrl,
      data: notification.data,
    );

    if (userId == null) {
      final List<NotificationItem> current = await _getLocalNotifications();
      final List<NotificationItem> updated = [model, ...current];
      // Limit to 50 notifications locally to avoid bloat
      if (updated.length > 50) updated.removeLast();

      await prefs.setString(
          _localNotificationsKey,
          json.encode(
              updated.map((n) => (n as NotificationModel).toJson()).toList()));
    } else {
      await firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(model.id)
          .set(model.toFirestore());
    }
  }

  @override
  Future<void> markAsRead(String? userId, String notificationId) async {
    if (userId == null) {
      final List<NotificationItem> current = await _getLocalNotifications();
      final List<NotificationItem> updated = current.map((n) {
        if (n.id == notificationId) {
          return n.copyWith(isRead: true);
        }
        return n;
      }).toList();
      await prefs.setString(
          _localNotificationsKey,
          json.encode(
              updated.map((n) => (n as NotificationModel).toJson()).toList()));
    } else {
      await firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
    }
  }

  @override
  Future<void> markAllAsRead(String? userId) async {
    if (userId == null) {
      final List<NotificationItem> current = await _getLocalNotifications();
      final List<NotificationItem> updated =
          current.map((n) => n.copyWith(isRead: true)).toList();
      await prefs.setString(
          _localNotificationsKey,
          json.encode(
              updated.map((n) => (n as NotificationModel).toJson()).toList()));
    } else {
      final unread = await firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .get();

      final batch = firestore.batch();
      for (var doc in unread.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    }
  }

  @override
  Future<void> clearAll(String? userId) async {
    if (userId == null) {
      await prefs.remove(_localNotificationsKey);
    } else {
      final all = await firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .get();

      final batch = firestore.batch();
      for (var doc in all.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  @override
  Future<void> deleteNotification(String? userId, String notificationId) async {
    if (userId == null) {
      final List<NotificationItem> current = await _getLocalNotifications();
      final List<NotificationItem> updated =
          current.where((n) => n.id != notificationId).toList();
      await prefs.setString(
          _localNotificationsKey,
          json.encode(
              updated.map((n) => (n as NotificationModel).toJson()).toList()));
    } else {
      await firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .delete();
    }
  }

  @override
  Stream<List<NotificationItem>> getBroadcastNotifications() {
    return firestore
        .collection('notifications_broadcast')
        .orderBy('timestamp', descending: true)
        .limit(10) // Only listen for recent broadcasts
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return NotificationModel.fromFirestore(doc.data(), doc.id);
      }).toList();
    });
  }
}
