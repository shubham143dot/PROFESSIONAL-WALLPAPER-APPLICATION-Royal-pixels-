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

  // ── Diamond System fields ─────────────────────────────────────────────────
  final int diamonds;
  final int streak;
  final String? appVersion;

  final bool isSubscribed;
  final String? photoUrl;

  const UserEntity({
    required this.uid,
    required this.name,
    required this.email,
    this.photoUrl,
    this.phoneNo,
    this.loginHistory,
    required this.ownedWallpaperCount,
    this.totalSpent = 0.0,
    this.activityScore = 0,
    this.diamonds = 0,
    this.streak = 0,
    this.isSubscribed = false,
    this.appVersion,
  });

  UserEntity copyWith({
    String? uid,
    String? name,
    String? email,
    String? photoUrl,
    String? phoneNo,
    DateTime? loginHistory,
    int? ownedWallpaperCount,
    double? totalSpent,
    int? activityScore,
    int? diamonds,
    int? streak,
    bool? isSubscribed,
    String? appVersion,
  }) {
    return UserEntity(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      phoneNo: phoneNo ?? this.phoneNo,
      loginHistory: loginHistory ?? this.loginHistory,
      ownedWallpaperCount: ownedWallpaperCount ?? this.ownedWallpaperCount,
      totalSpent: totalSpent ?? this.totalSpent,
      activityScore: activityScore ?? this.activityScore,
      diamonds: diamonds ?? this.diamonds,
      streak: streak ?? this.streak,
      isSubscribed: isSubscribed ?? this.isSubscribed,
      appVersion: appVersion ?? this.appVersion,
    );
  }

  @override
  List<Object?> get props => [
        uid,
        name,
        email,
        photoUrl,
        phoneNo,
        loginHistory,
        ownedWallpaperCount,
        totalSpent,
        activityScore,
        diamonds,
        streak,
        isSubscribed,
        appVersion,
      ];
}
