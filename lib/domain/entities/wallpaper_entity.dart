import 'package:equatable/equatable.dart';

class WallpaperEntity extends Equatable {
  final String id;
  final String title;
  final String imageUrl;
  final String category;
  final bool isPremium;
  final double price;
  final List<String> tags;
  final String size;

  bool get isSpecial {
    return category.toLowerCase() == 'special' ||
           autoCategory.toLowerCase() == 'special' ||
           tags.any((t) => t.toLowerCase() == 'special');
  }

  static String getOptimizedCloudinaryUrl(String url) {
    if (url.isEmpty || !url.contains('res.cloudinary.com')) return url;
    
    const String uploadPath = '/image/upload/';
    final int uploadIndex = url.indexOf(uploadPath);
    
    if (uploadIndex == -1) return url;
    
    final String baseUrl = url.substring(0, uploadIndex + uploadPath.length);
    final String remainingPart = url.substring(uploadIndex + uploadPath.length);
    
    if (remainingPart.contains('f_webp') || remainingPart.contains('w_1080')) {
      return url;
    }
    
    const String transformations = 'w_1080,f_webp,q_auto:good,fl_progressive,fl_strip_profile/';
    return '$baseUrl$transformations$remainingPart';
  }

  String get optimizedUrl => getOptimizedCloudinaryUrl(imageUrl);

  const WallpaperEntity({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.category,
    required this.isPremium,
    required this.price,
    required this.tags,
    this.size = '',
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
        size,
      ];

  WallpaperEntity copyWith({
    String? id,
    String? title,
    String? imageUrl,
    String? category,
    bool? isPremium,
    double? price,
    List<String>? tags,
    String? size,
  }) {
    return WallpaperEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      imageUrl: imageUrl ?? this.imageUrl,
      category: category ?? this.category,
      isPremium: isPremium ?? this.isPremium,
      price: price ?? this.price,
      tags: tags ?? this.tags,
      size: size ?? this.size,
    );
  }

  /// Intelligent auto-categorization algorithm based on title and tags.
  /// This dynamically generates categories whenever a new wallpaper is uploaded.
  String get autoCategory {
    // If a specific, non-general category is already set in the database, use it.
    if (category.isNotEmpty && category.trim().toLowerCase() != 'general') {
      final parts = category.trim().split(RegExp(r'\s+'));
      return parts.map((e) => e.isNotEmpty ? '${e[0].toUpperCase()}${e.substring(1).toLowerCase()}' : '').join(' ');
    }

    final t = title.toLowerCase();
    final allTags = tags.map((e) => e.toLowerCase()).join(' ');

    // 1. Anime / Manga
    if (t.contains('anime') || t.contains('makima') || t.contains('madara') || 
        t.contains('naruto') || t.contains('gojo') || t.contains('luffy') ||
        allTags.contains('anime') || allTags.contains('manga')) {
      return 'Anime';
    }
    // 2. Superheroes
    if (t.contains('spider') || t.contains('batman') || t.contains('iron') || 
        t.contains('superman') || t.contains('marvel') || t.contains('venom') ||
        allTags.contains('hero')) {
      return 'Heroes';
    }
    // 3. Cars / Vehicles
    if (t.contains('car') || t.contains('auto') || t.contains('bmw') || 
        t.contains('porsche') || t.contains('mustang') || t.contains('lambo') ||
        allTags.contains('car') || allTags.contains('vehicle')) {
      return 'Cars';
    }
    // 4. Cyberpunk / Neon
    if (t.contains('neon') || t.contains('cyber') || t.contains('punk') ||
        allTags.contains('neon') || allTags.contains('cyberpunk')) {
      return 'Cyberpunk';
    }
    // 5. Nature / Landscapes
    if (t.contains('nature') || t.contains('forest') || t.contains('mountain') || 
        t.contains('ocean') || t.contains('landscape') || t.contains('sunset') ||
        t.contains('tree') || allTags.contains('nature')) {
      return 'Nature';
    }
    // 6. Abstract / 3D / Geometric
    if (t.contains('abstract') || t.contains('poly') || t.contains('pattern') || 
        t.contains('3d') || t.contains('gradient') || t.contains('minimal') ||
        allTags.contains('abstract') || allTags.contains('minimal')) {
      return 'Abstract';
    }
    // 7. Space / Galaxy
    if (t.contains('space') || t.contains('galaxy') || t.contains('star') || 
        t.contains('planet') || t.contains('moon') || t.contains('astro') ||
        allTags.contains('space') || allTags.contains('universe')) {
      return 'Space';
    }
    // 8. Dark / Black
    if (t.contains('dark') || t.contains('black') || t.contains('amoled') ||
        allTags.contains('dark') || allTags.contains('black')) {
      return 'Dark';
    }

    // Default Fallback
    return 'Trending';
  }
}
