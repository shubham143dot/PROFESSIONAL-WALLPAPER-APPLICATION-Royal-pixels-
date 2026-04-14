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
  });

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
      ];
}
