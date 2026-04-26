import 'package:equatable/equatable.dart';

enum CreatorTier { emerging, rising, elite }

class CreatorProfile extends Equatable {
  final String uid;
  final String displayName;
  final String? bio;
  final String? avatarUrl;
  final int totalEarnings; // In diamonds
  final int totalDownloads;
  final int totalViews;
  final int wallpaperCount;
  final CreatorTier tier;
  final bool isVerified;

  const CreatorProfile({
    required this.uid,
    required this.displayName,
    this.bio,
    this.avatarUrl,
    this.totalEarnings = 0,
    this.totalDownloads = 0,
    this.totalViews = 0,
    this.wallpaperCount = 0,
    this.tier = CreatorTier.emerging,
    this.isVerified = false,
  });

  @override
  List<Object?> get props => [
        uid,
        displayName,
        bio,
        avatarUrl,
        totalEarnings,
        totalDownloads,
        totalViews,
        wallpaperCount,
        tier,
        isVerified,
      ];

  CreatorProfile copyWith({
    String? uid,
    String? displayName,
    String? bio,
    String? avatarUrl,
    int? totalEarnings,
    int? totalDownloads,
    int? totalViews,
    int? wallpaperCount,
    CreatorTier? tier,
    bool? isVerified,
  }) {
    return CreatorProfile(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      bio: bio ?? this.bio,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      totalEarnings: totalEarnings ?? this.totalEarnings,
      totalDownloads: totalDownloads ?? this.totalDownloads,
      totalViews: totalViews ?? this.totalViews,
      wallpaperCount: wallpaperCount ?? this.wallpaperCount,
      tier: tier ?? this.tier,
      isVerified: isVerified ?? this.isVerified,
    );
  }
}
