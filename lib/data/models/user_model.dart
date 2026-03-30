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
  });

  factory UserModel.fromFirestore(Map<String, dynamic> json, String uid) {
    return UserModel(
      uid: uid,
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phoneNo: json['phone_no'],
      loginHistory: (json['login_history'] as Timestamp?)?.toDate(),
      ownedWallpaperCount: json['owned_wallpaper'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      if (phoneNo != null) 'phone_no': phoneNo,
      if (loginHistory != null) 'login_history': Timestamp.fromDate(loginHistory!),
      'owned_wallpaper': ownedWallpaperCount,
    };
  }
}
