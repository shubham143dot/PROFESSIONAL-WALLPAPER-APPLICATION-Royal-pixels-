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
    super.smallRewardEarnedToday = 0,
    super.adsWatchedToday = 0,
    super.isSubscribed = false,
    super.appVersion,
  });

  static DateTime? _parseDate(dynamic dateData) {
    if (dateData == null) return null;
    if (dateData is Timestamp) return dateData.toDate();
    if (dateData is String) return DateTime.tryParse(dateData);
    if (dateData is int) return DateTime.fromMillisecondsSinceEpoch(dateData);
    return null;
  }

  factory UserModel.fromFirestore(Map<String, dynamic> json, String uid) {
    // Midnight Reset Logic for real-time updates
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final lastSmallRewardDate = _parseDate(json['lastSmallRewardDate']);
    final smallRewardEarnedTodayRaw = json['smallRewardEarnedToday'] as int? ?? 0;
    final smallRewardEarnedToday = (lastSmallRewardDate != null &&
            DateTime(lastSmallRewardDate.year, lastSmallRewardDate.month,
                    lastSmallRewardDate.day) ==
                today)
        ? smallRewardEarnedTodayRaw
        : 0;

    final lastAdRewardDate = _parseDate(json['lastAdRewardDate']);
    final adsWatchedTodayRaw = json['adsWatchedToday'] as int? ?? 0;
    final adsWatchedToday = (lastAdRewardDate != null &&
            DateTime(lastAdRewardDate.year, lastAdRewardDate.month,
                    lastAdRewardDate.day) ==
                today)
        ? adsWatchedTodayRaw
        : 0;

    return UserModel(
      uid: uid,
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      photoUrl: json['photo_url'],
      phoneNo: json['phone_no'],
      loginHistory: _parseDate(json['login_history']),
      ownedWallpaperCount: json['owned_wallpaper'] ?? 0,
      totalSpent: (json['total_spent'] ?? 0.0).toDouble(),
      activityScore: json['activity_score'] ?? 0,
      diamonds: json['diamonds'] ?? 0,
      streak: json['streak'] ?? 0,
      smallRewardEarnedToday: smallRewardEarnedToday,
      adsWatchedToday: adsWatchedToday,
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
      'smallRewardEarnedToday': smallRewardEarnedToday,
      'adsWatchedToday': adsWatchedToday,
      'is_subscribed': isSubscribed,
      if (appVersion != null) 'app_version': appVersion,
    };
  }
}
