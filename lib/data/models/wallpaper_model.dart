import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/wallpaper_entity.dart';

class WallpaperModel extends WallpaperEntity {
  const WallpaperModel({
    required super.id,
    required super.title,
    required super.imageUrl,
    required super.category,
    required super.isPremium,
    required super.diamondCost,
    required super.tags,
    super.size,
    super.createdAt,
    super.viewCount,
    super.likeCount,
    super.shareCount,
    super.isTrending,
  });

  factory WallpaperModel.fromFirestore(Map<String, dynamic> json, String id) {
    final createdAtData = json['created_at'];
    DateTime? createdAt;
    if (createdAtData is Timestamp) {
      createdAt = createdAtData.toDate();
    } else if (createdAtData is String) {
      createdAt = DateTime.tryParse(createdAtData);
    }

    // Prefer new 'diamond_cost' field; fall back to legacy 'price' (safely cast it)
    final rawCost = json['diamond_cost'];
    final rawPrice = json['price'];
    
    int cost = 100; // Sensible default
    if (rawCost != null) {
      cost = rawCost is num ? rawCost.toInt() : int.tryParse(rawCost.toString()) ?? 100;
    } else if (rawPrice != null) {
      cost = rawPrice is num ? rawPrice.toInt() : int.tryParse(rawPrice.toString()) ?? 100;
    }

    final String docId = id.isNotEmpty ? id : (json['id']?.toString() ?? '');

    return WallpaperModel(
      id: docId,
      title: json['title']?.toString() ?? '',
      imageUrl: json['image_url']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      isPremium: json['is_premium'] == true || json['is_premium'] == 'true',
      diamondCost: cost,
      tags: json['tags'] is Iterable 
          ? (json['tags'] as Iterable).map((e) => e.toString()).toList() 
          : const [],
      size: json['size']?.toString() ?? '',
      createdAt: createdAt,
      viewCount: json['view_count'] is num ? (json['view_count'] as num).toInt() : 0,
      likeCount: json['like_count'] is num ? (json['like_count'] as num).toInt() : 0,
      shareCount: json['share_count'] is num ? (json['share_count'] as num).toInt() : 0,
      isTrending: json['is_trending'] == true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return toJson();
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'image_url': imageUrl,
      'category': category,
      'is_premium': isPremium,
      'diamond_cost': diamondCost,
      'tags': tags,
      'size': size,
      'view_count': viewCount,
      'like_count': likeCount,
      'share_count': shareCount,
      'is_trending': isTrending,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  factory WallpaperModel.fromJson(Map<String, dynamic> json) {
    return WallpaperModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      imageUrl: json['image_url']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      isPremium: json['is_premium'] == true,
      diamondCost: json['diamond_cost'] is num ? (json['diamond_cost'] as num).toInt() : 100,
      tags: json['tags'] is Iterable ? (json['tags'] as Iterable).map((e) => e.toString()).toList() : [],
      size: json['size']?.toString() ?? '',
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      viewCount: json['view_count'] is num ? (json['view_count'] as num).toInt() : 0,
      likeCount: json['like_count'] is num ? (json['like_count'] as num).toInt() : 0,
      shareCount: json['share_count'] is num ? (json['share_count'] as num).toInt() : 0,
      isTrending: json['is_trending'] == true,
    );
  }
}
