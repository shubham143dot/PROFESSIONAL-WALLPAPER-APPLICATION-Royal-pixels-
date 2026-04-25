import 'package:equatable/equatable.dart';

class UserEntity extends Equatable {
  final String uid;
  final String name;
  final String email;
  final String? phoneNo;
  final DateTime? loginHistory;
  final int ownedWallpaperCount;
  final double totalSpent;
  final int activityScore;
  final bool isSubscribed;
  final DateTime? subscriptionExpiry;

  // ── Diamond System fields ─────────────────────────────────────────────────
  final int diamonds;
  final int streak;
  final String? appVersion;
  final int adsWatchedToday;

  const UserEntity({
    required this.uid,
    required this.name,
    required this.email,
    this.phoneNo,
    this.loginHistory,
    required this.ownedWallpaperCount,
    this.totalSpent = 0.0,
    this.activityScore = 0,
    this.isSubscribed = false,
    this.subscriptionExpiry,
    this.diamonds = 0,
    this.streak = 0,
    this.appVersion,
    this.adsWatchedToday = 0,
  });

  UserEntity copyWith({
    String? uid,
    String? name,
    String? email,
    String? phoneNo,
    DateTime? loginHistory,
    int? ownedWallpaperCount,
    double? totalSpent,
    int? activityScore,
    bool? isSubscribed,
    DateTime? subscriptionExpiry,
    int? diamonds,
    int? streak,
    String? appVersion,
    int? adsWatchedToday,
  }) {
    return UserEntity(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      phoneNo: phoneNo ?? this.phoneNo,
      loginHistory: loginHistory ?? this.loginHistory,
      ownedWallpaperCount: ownedWallpaperCount ?? this.ownedWallpaperCount,
      totalSpent: totalSpent ?? this.totalSpent,
      activityScore: activityScore ?? this.activityScore,
      isSubscribed: isSubscribed ?? this.isSubscribed,
      subscriptionExpiry: subscriptionExpiry ?? this.subscriptionExpiry,
      diamonds: diamonds ?? this.diamonds,
      streak: streak ?? this.streak,
      appVersion: appVersion ?? this.appVersion,
      adsWatchedToday: adsWatchedToday ?? this.adsWatchedToday,
    );
  }

  @override
  List<Object?> get props => [
        uid,
        name,
        email,
        phoneNo,
        loginHistory,
        ownedWallpaperCount,
        totalSpent,
        activityScore,
        isSubscribed,
        subscriptionExpiry,
        diamonds,
        streak,
        appVersion,
        adsWatchedToday,
      ];
}
