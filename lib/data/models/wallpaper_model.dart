import '../../domain/entities/wallpaper_entity.dart';

class WallpaperModel extends WallpaperEntity {
  const WallpaperModel({
    required super.id,
    required super.title,
    required super.imageUrl,
    required super.category,
    required super.isPremium,
    required super.price,
    required super.tags,
    super.size,
  });

  factory WallpaperModel.fromFirestore(Map<String, dynamic> json, String id) {
    return WallpaperModel(
      id: id,
      title: json['title'] ?? '',
      imageUrl: json['image_url'] ?? '',
      category: json['category'] ?? '',
      isPremium: json['is_premium'] ?? false,
      price: (json['price'] ?? 0.0).toDouble(),
      tags: List<String>.from(json['tags'] ?? []),
      size: json['size'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'image_url': imageUrl,
      'category': category,
      'is_premium': isPremium,
      'price': price,
      'tags': tags,
      'size': size,
    };
  }
}
