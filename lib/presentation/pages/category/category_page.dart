import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../domain/entities/wallpaper_entity.dart';
import '../../widgets/wallpaper_card.dart';

class CategoryPage extends StatelessWidget {
  final String categoryName;
  final List<WallpaperEntity> wallpapers;

  const CategoryPage({
    super.key,
    required this.categoryName,
    required this.wallpapers,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text(categoryName),
        backgroundColor: const Color(0xFF1E1E1E),
        leading: BackButton(
          onPressed: () => context.pop(),
        ),
      ),
      body: wallpapers.isEmpty 
          ? const Center(child: Text('No Wallpapers Found', style: TextStyle(color: Colors.white)))
          : MasonryGridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverSimpleGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
              ),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              itemCount: wallpapers.length,
              itemBuilder: (context, index) {
                final wp = wallpapers[index];
                final heights = [200.0, 260.0, 180.0, 240.0, 220.0];
                final h = heights[index % heights.length];
                return SizedBox(
                  height: h,
                  child: WallpaperCard(
                    key: ValueKey(wp.id),
                    wallpaper: wp,
                    onTap: () => context.push('/detail', extra: wp),
                  ),
                )
                    .animate(delay: (index * 40).ms)
                    .fade(duration: 350.ms, curve: Curves.easeOut)
                    .slideY(
                        begin: 0.08,
                        end: 0,
                        duration: 350.ms,
                        curve: Curves.easeOutQuart);
              },
            ),
    );
  }
}
