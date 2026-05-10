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
    super.photoUrl,
    super.totalSpent = 0.0,
    super.activityScore = 0,
    super.diamonds = 0,
    super.streak = 0,
    super.isSubscribed = false,
    super.appVersion,
  });

  factory UserModel.fromFirestore(Map<String, dynamic> json, String uid) {
    return UserModel(
      uid: uid,
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      photoUrl: json['photo_url'],
      phoneNo: json['phone_no'],
      loginHistory: (json['login_history'] as Timestamp?)?.toDate(),
      ownedWallpaperCount: json['owned_wallpaper'] ?? 0,
      totalSpent: (json['total_spent'] ?? 0.0).toDouble(),
      activityScore: json['activity_score'] ?? 0,
      diamonds: json['diamonds'] ?? 0,
      streak: json['streak'] ?? 0,
      isSubscribed: json['is_subscribed'] ?? false,
      appVersion: json['app_version'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      if (photoUrl != null) 'photo_url': photoUrl,
      if (phoneNo != null) 'phone_no': phoneNo,
      if (loginHistory != null)
        'login_history': Timestamp.fromDate(loginHistory!),
      'owned_wallpaper': ownedWallpaperCount,
      'total_spent': totalSpent,
      'activity_score': activityScore,
      'diamonds': diamonds,
      'streak': streak,
      'is_subscribed': isSubscribed,
      if (appVersion != null) 'app_version': appVersion,
    };
  }
}
