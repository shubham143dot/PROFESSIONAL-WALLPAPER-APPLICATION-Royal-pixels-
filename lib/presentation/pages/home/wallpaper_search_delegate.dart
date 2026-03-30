import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../../domain/entities/wallpaper_entity.dart';
import '../../widgets/diamond_loader.dart';

class WallpaperSearchDelegate extends SearchDelegate<WallpaperEntity?> {
  final List<WallpaperEntity> allWallpapers;

  WallpaperSearchDelegate(this.allWallpapers);

  @override
  String get searchFieldLabel => 'Search wallpapers...';

  @override
  ThemeData appBarTheme(BuildContext context) {
    return Theme.of(context).copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF121212),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: InputBorder.none,
        hintStyle: TextStyle(color: Colors.white54),
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(color: Colors.white, fontSize: 18),
      ),
    );
  }

  List<WallpaperEntity> _getResults() {
    if (query.trim().isEmpty) return [];
    final q = query.trim().toLowerCase();
    return allWallpapers.where((w) {
      return w.title.toLowerCase().contains(q) ||
          w.category.toLowerCase().contains(q) ||
          w.tags.any((t) => t.toLowerCase().contains(q));
    }).toList();
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            query = '';
            showSuggestions(context);
          },
        ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildList(context, _getResults());
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildList(context, _getResults());
  }

  Widget _buildList(BuildContext context, List<WallpaperEntity> results) {
    if (query.trim().isEmpty) {
      return Container(
        color: const Color(0xFF121212),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search, size: 64, color: Colors.white24),
              SizedBox(height: 16),
              Text(
                'Search by title, category or tag',
                style: TextStyle(color: Colors.white38, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    if (results.isEmpty) {
      return Container(
        color: const Color(0xFF121212),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.image_not_supported_outlined, size: 64, color: Colors.white24),
              const SizedBox(height: 16),
              Text(
                'No results for "$query"',
                style: const TextStyle(color: Colors.white38, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: const Color(0xFF121212),
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.65,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: results.length,
        itemBuilder: (context, index) {
          final wp = results[index];
          return GestureDetector(
            onTap: () {
              close(context, wp);
              context.push('/detail', extra: wp);
            },
            child: Card(
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 6,
              shadowColor: wp.isPremium ? Colors.amber.withAlpha(128) : Colors.black45,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: wp.imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[800],
                      child: const Center(
                        child: DiamondLoader(size: 30),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[900],
                      child: const Icon(Icons.error, color: Colors.white),
                    ),
                  ),
                  if (wp.isPremium)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber, width: 1),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.diamond, color: Colors.amber, size: 14),
                            SizedBox(width: 4),
                            Text(
                              'Premium',
                              style: TextStyle(color: Colors.amber, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.transparent, Colors.black87],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      child: Text(
                        wp.title.isNotEmpty ? wp.title : wp.category,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
