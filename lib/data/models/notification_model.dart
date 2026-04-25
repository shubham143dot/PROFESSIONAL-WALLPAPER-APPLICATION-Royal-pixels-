import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/notification_item.dart';
import '../../domain/entities/notification_type.dart';

class NotificationModel extends NotificationItem {
  const NotificationModel({
    required super.id,
    required super.title,
    required super.message,
    required super.timestamp,
    required super.type,
    super.isRead,
    super.imageUrl,
    super.data,
  });

  factory NotificationModel.fromFirestore(Map<String, dynamic> json, String id) {
    return NotificationModel(
      id: id,
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      timestamp: (json['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      type: NotificationType.fromJson(json['type'] as String? ?? 'system'),
      isRead: json['isRead'] as bool? ?? false,
      imageUrl: json['imageUrl'] as String?,
      data: json['data'] as Map<String, dynamic>?,
    );
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      timestamp: DateTime.parse(json['timestamp'] as String),
      type: NotificationType.fromJson(json['type'] as String? ?? 'system'),
      isRead: json['isRead'] as bool? ?? false,
      imageUrl: json['imageUrl'] as String?,
      data: json['data'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'message': message,
      'timestamp': FieldValue.serverTimestamp(),
      'type': type.toJson(),
      'isRead': isRead,
      'imageUrl': imageUrl,
      'data': data,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      'type': type.toJson(),
      'isRead': isRead,
      'imageUrl': imageUrl,
      'data': data,
    };
  }
}
