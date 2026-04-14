import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.uid,
    required super.name,
    required super.email,
    super.phoneNo,
    super.loginHistory,
    required super.ownedWallpaperCount,
    super.totalSpent = 0.0,
    super.activityScore = 0,
    super.isSubscribed = false,
    super.subscriptionExpiry,
  });

  factory UserModel.fromFirestore(Map<String, dynamic> json, String uid) {
    return UserModel(
      uid: uid,
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phoneNo: json['phone_no'],
      loginHistory: (json['login_history'] as Timestamp?)?.toDate(),
      ownedWallpaperCount: json['owned_wallpaper'] ?? 0,
      totalSpent: (json['total_spent'] ?? 0.0).toDouble(),
      activityScore: json['activity_score'] ?? 0,
      isSubscribed: json['is_subscribed'] ?? false,
      subscriptionExpiry: (json['subscription_expiry'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      if (phoneNo != null) 'phone_no': phoneNo,
      if (loginHistory != null) 'login_history': Timestamp.fromDate(loginHistory!),
      'owned_wallpaper': ownedWallpaperCount,
      'total_spent': totalSpent,
      'activity_score': activityScore,
      'is_subscribed': isSubscribed,
      if (subscriptionExpiry != null) 'subscription_expiry': Timestamp.fromDate(subscriptionExpiry!),
    };
  }
}
