import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/di/service_locator.dart';
import '../../../data/datasources/firestore_data_source.dart';
import '../../../domain/entities/wallpaper_entity.dart';
import '../../widgets/diamond_loader.dart';
import '../../../core/theme/app_colors.dart';
import 'wallpaper_detail_page.dart';

class WallpaperDeepLinkPage extends ConsumerStatefulWidget {
  final String wallpaperId;

  const WallpaperDeepLinkPage({super.key, required this.wallpaperId});

  @override
  ConsumerState<WallpaperDeepLinkPage> createState() =>
      _WallpaperDeepLinkPageState();
}

class _WallpaperDeepLinkPageState extends ConsumerState<WallpaperDeepLinkPage> {
  bool _isLoading = true;
  String? _error;
  WallpaperEntity? _wallpaper;

  @override
  void initState() {
    super.initState();
    _fetchWallpaper();
  }

  Future<void> _fetchWallpaper() async {
    try {
      final dataSource = sl<FirestoreDataSource>();
      final wallpaper = await dataSource.getWallpaperById(widget.wallpaperId);

      if (mounted) {
        if (wallpaper != null) {
          setState(() {
            _wallpaper = wallpaper;
            _isLoading = false;
          });
        } else {
          setState(() {
            _error = 'Wallpaper not found';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load wallpaper: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.bg0,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const DiamondLoader(size: 40),
              const SizedBox(height: 16),
              Text(
                'Opening wallpaper...',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: AppColors.bg0,
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  color: Colors.redAccent, size: 48),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go('/home'),
                child: const Text('Go Home'),
              ),
            ],
          ),
        ),
      );
    }

    if (_wallpaper != null) {
      return WallpaperDetailPage(wallpaper: _wallpaper!);
    }

    return const SizedBox.shrink();
  }
}
