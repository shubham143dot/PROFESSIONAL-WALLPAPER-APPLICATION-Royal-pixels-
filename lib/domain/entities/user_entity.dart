import 'package:equatable/equatable.dart';

class UserEntity extends Equatable {
  final String uid;
  final String name;
  final String email;
  final String? phoneNo;
  final DateTime? loginHistory;
  final int ownedWallpaperCount;

  const UserEntity({
    required this.uid,
    required this.name,
    required this.email,
    this.phoneNo,
    this.loginHistory,
    required this.ownedWallpaperCount,
  });

  @override
  List<Object?> get props => [
        uid,
        name,
        email,
        phoneNo,
        loginHistory,
        ownedWallpaperCount,
      ];
}
