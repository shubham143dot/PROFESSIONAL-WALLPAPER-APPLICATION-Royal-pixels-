import 'package:equatable/equatable.dart';

class WallpaperEntity extends Equatable {
  final String id;
  final String title;
  final String imageUrl;
  final String category;
  final bool isPremium;
  final double price;
  final List<String> tags;

  const WallpaperEntity({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.category,
    required this.isPremium,
    required this.price,
    required this.tags,
  });

  @override
  List<Object?> get props => [
        id,
        title,
        imageUrl,
        category,
        isPremium,
        price,
        tags,
      ];
}
