import 'package:equatable/equatable.dart';

class WallpaperEntity extends Equatable {
  final String id;
  final String title;
  final String imageUrl;
  final String category;
  final bool isPremium;
  final int diamondCost;
  final List<String> tags;
  final String size;
  final DateTime? createdAt;
  final int viewCount;
  final int likeCount;
  final int shareCount;
  final bool isTrending;

  /// True when the wallpaper is tagged with 'ultra_hd'
  bool get isUltraHD => tags.any((t) => t.toLowerCase() == 'ultra_hd');

  /// True when the wallpaper is tagged with 'editors_choice'
  bool get isEditorsChoice => tags.any((t) => t.toLowerCase() == 'editors_choice');

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

  /// Builds an ImageKit optimized preview URL (width-limited, webp, good quality).
  static String getOptimizedImageKitUrl(String url, {int width = 1080}) {
    if (url.isEmpty || !url.contains('ik.imagekit.io')) return url;
    // Avoid double-transforming if a `tr` param already exists
    if (url.contains('?tr=') || url.contains('&tr=')) return url;
    return '$url?tr=w-$width,f-webp,q-85';
  }

  /// Optimized preview URL (compressed) — used for displaying in the UI.
  /// For Cloudinary: w_1080, webp, auto quality.
  /// For ImageKit: w_1080, webp, q-85.
  /// For anything else: returns raw imageUrl.
  String get optimizedUrl {
    if (imageUrl.isEmpty) return '';
    if (imageUrl.contains('res.cloudinary.com')) {
      return getOptimizedCloudinaryUrl(imageUrl);
    }
    if (imageUrl.contains('ik.imagekit.io')) {
      return getOptimizedImageKitUrl(imageUrl, width: 1080);
    }
    return imageUrl;
  }

  /// Full-quality original URL — used for downloads and set-wallpaper.
  /// Always returns the raw, uncompressed imageUrl with zero transformations.
  String get fullQualityUrl => imageUrl;

  /// Low-res extreme blurred version (for instant placeholders)
  String get blurUrl {
    if (imageUrl.isEmpty) return '';
    if (imageUrl.contains('res.cloudinary.com')) {
      const String uploadPath = '/image/upload/';
      final int uploadIndex = imageUrl.indexOf(uploadPath);
      if (uploadIndex == -1) return imageUrl;
      final String baseUrl = imageUrl.substring(0, uploadIndex + uploadPath.length);
      final String remainingPart = imageUrl.substring(uploadIndex + uploadPath.length);
      // w_50 (tiny), e_blur:1000 (heavy blur), q_auto:low (mini size)
      return '${baseUrl}w_50,e_blur:1000,f_webp,q_auto:low,fl_progressive/$remainingPart';
    }
    if (imageUrl.contains('ik.imagekit.io')) {
      // Use a separate, stable blurUrl key (avoids collision with thumbnailUrl key)
      if (imageUrl.contains('?tr=') || imageUrl.contains('&tr=')) return imageUrl;
      return '$imageUrl?tr=w-50,bl-30,q-20,f-webp';
    }
    return imageUrl;
  }

  /// Thumbnail version for the grid view (400px width)
  String get thumbnailUrl {
    if (imageUrl.isEmpty) return '';
    if (imageUrl.contains('res.cloudinary.com')) {
      const String uploadPath = '/image/upload/';
      final int uploadIndex = imageUrl.indexOf(uploadPath);
      if (uploadIndex == -1) return imageUrl;
      final String baseUrl = imageUrl.substring(0, uploadIndex + uploadPath.length);
      final String remainingPart = imageUrl.substring(uploadIndex + uploadPath.length);
      return '${baseUrl}w_400,f_webp,q_auto:good,fl_progressive/$remainingPart';
    }
    if (imageUrl.contains('ik.imagekit.io')) {
      return getOptimizedImageKitUrl(imageUrl, width: 400);
    }
    return imageUrl;
  }

  const WallpaperEntity({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.category,
    required this.isPremium,
    required this.diamondCost,
    required this.tags,
    this.size = '',
    this.createdAt,
    this.viewCount = 0,
    this.likeCount = 0,
    this.shareCount = 0,
    this.isTrending = false,
  });

  @override
  List<Object?> get props => [
        id,
        title,
        imageUrl,
        category,
        isPremium,
        diamondCost,
        tags,
        size,
        createdAt,
        viewCount,
        likeCount,
        shareCount,
        isTrending,
      ];

  WallpaperEntity copyWith({
    String? id,
    String? title,
    String? imageUrl,
    String? category,
    bool? isPremium,
    int? diamondCost,
    List<String>? tags,
    String? size,
    DateTime? createdAt,
    int? viewCount,
    int? likeCount,
    int? shareCount,
    bool? isTrending,
  }) {
    return WallpaperEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      imageUrl: imageUrl ?? this.imageUrl,
      category: category ?? this.category,
      isPremium: isPremium ?? this.isPremium,
      diamondCost: diamondCost ?? this.diamondCost,
      tags: tags ?? this.tags,
      size: size ?? this.size,
      createdAt: createdAt ?? this.createdAt,
      viewCount: viewCount ?? this.viewCount,
      likeCount: likeCount ?? this.likeCount,
      shareCount: shareCount ?? this.shareCount,
      isTrending: isTrending ?? this.isTrending,
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
    return 'Feed';
  }
}
