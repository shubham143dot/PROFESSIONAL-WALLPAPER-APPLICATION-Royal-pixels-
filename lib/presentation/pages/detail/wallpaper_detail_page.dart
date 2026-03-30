import 'dart:developer' as dev;
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallpaper_manager_plus/wallpaper_manager_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/di/service_locator.dart';
import '../../../domain/entities/wallpaper_entity.dart';
import '../../../domain/repositories/payment_repository.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/diamond_loader.dart';
import '../payment/payment_bottom_sheet.dart';

class WallpaperDetailPage extends ConsumerStatefulWidget {
  final WallpaperEntity wallpaper;

  const WallpaperDetailPage({super.key, required this.wallpaper});

  @override
  ConsumerState<WallpaperDetailPage> createState() => _WallpaperDetailPageState();
}

class _WallpaperDetailPageState extends ConsumerState<WallpaperDetailPage> {
  bool _isSetting = false;
  bool _isUnlocked = false;
  bool _isCheckingUnlock = false;

  @override
  void initState() {
    super.initState();
    // For free wallpapers, skip the check
    if (widget.wallpaper.isPremium) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkIfAlreadyUnlocked();
      });
    }
  }

  /// Silently checks Firestore to see if user has already paid for this wallpaper.
  /// If yes, automatically removes the blur & lock UI.
  Future<void> _checkIfAlreadyUnlocked() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    setState(() => _isCheckingUnlock = true);

    final repo = sl<PaymentRepository>();
    final result = await repo.checkUnlockStatus(user.uid, widget.wallpaper.id);

    if (!mounted) return;
    result.fold(
      (_) => setState(() => _isCheckingUnlock = false), // On error, leave locked
      (isUnlocked) => setState(() {
        _isCheckingUnlock = false;
        _isUnlocked = isUnlocked;
      }),
    );
  }

  Future<void> _buyPremium() async {
    final user = ref.read(authProvider).user;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to unlock this wallpaper')),
      );
      return;
    }

    // Open the QR payment bottom sheet
    final paid = await showPaymentBottomSheet(
      context,
      wallpaperId: widget.wallpaper.id,
      wallpaperTitle: widget.wallpaper.title,
      amount: widget.wallpaper.price,
    );

    if (paid && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Payment confirmed! Wallpaper unlocked.'),
          backgroundColor: Colors.green,
        ),
      );
      setState(() => _isUnlocked = true);
    }
  }

  Future<void> _downloadWallpaper() async {
    try {
      // Request the correct permission based on Android version
      if (Platform.isAndroid) {
        // Use Gal's own permission check: it handles Android 10+/13+ internally
        // But we still need to request for older Androids
        final hasAccess = await Gal.hasAccess();
        if (!hasAccess) {
          final granted = await Gal.requestAccess();
          if (!granted) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Storage permission denied. Please allow in Settings.'),
                ),
              );
            }
            return;
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Downloading...')),
        );
      }

      // Use http package (reliable, no deprecated APIs)
      final response = await http.get(
        Uri.parse(widget.wallpaper.imageUrl),
        headers: {'User-Agent': 'RoyalPixels/1.0'},
      );

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final Uint8List bytes = response.bodyBytes;

      await Gal.putImageBytes(bytes, name: 'royal_pixel_${widget.wallpaper.id}');

      // ✅ Save wallpaper ID to SharedPreferences so it appears in My Wallpapers
      final prefs = await SharedPreferences.getInstance();
      final ids = prefs.getStringList('downloaded_wallpaper_ids') ?? [];
      if (!ids.contains(widget.wallpaper.id)) {
        ids.add(widget.wallpaper.id);
        await prefs.setStringList('downloaded_wallpaper_ids', ids);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Saved to Gallery!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _setWallpaper() async {
    // Show dialog to choose where to set
    final choice = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Set as Wallpaper',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dialogOption(ctx, Icons.home_outlined, 'Home Screen', WallpaperManagerPlus.homeScreen),
            const SizedBox(height: 8),
            _dialogOption(ctx, Icons.lock_outline, 'Lock Screen', WallpaperManagerPlus.lockScreen),
            const SizedBox(height: 8),
            _dialogOption(ctx, Icons.phonelink_outlined, 'Both', WallpaperManagerPlus.bothScreens),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );

    if (choice == null || !mounted) return;

    setState(() => _isSetting = true);
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Setting wallpaper...')),
        );
      }

      // Download image using http package (no deprecated API)
      final response = await http.get(
        Uri.parse(widget.wallpaper.imageUrl),
        headers: {'User-Agent': 'RoyalPixels/1.0'},
      );

      if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');

      final Uint8List bytes = response.bodyBytes;
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/rp_wallpaper_${widget.wallpaper.id}.jpg');
      await tempFile.writeAsBytes(bytes);

      await WallpaperManagerPlus().setWallpaper(tempFile, choice);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Wallpaper set successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to set wallpaper: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSetting = false);
    }
  }

  Widget _dialogOption(BuildContext ctx, IconData icon, String label, int value) {
    return InkWell(
      onTap: () => Navigator.pop(ctx, value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(13),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.amber, size: 22),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 15)),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 14),
          ],
        ),
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    // Debug: log the URL so we can verify what's stored in Firestore
    dev.log('WallpaperDetail imageUrl: "${widget.wallpaper.imageUrl}"', name: 'RoyalPixels');

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Hero(
            tag: 'wallpaper_${widget.wallpaper.id}',
            child: widget.wallpaper.imageUrl.isEmpty
                ? _buildBrokenImagePlaceholder('No image URL stored in database')
                : CachedNetworkImage(
                    imageUrl: widget.wallpaper.imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[900],
                      child: const Center(
                        child: DiamondLoader(size: 30),
                      ),
                    ),
                    errorWidget: (context, url, error) {
                      dev.log('Image load error for url: $url\nError: $error', name: 'RoyalPixels');
                      return _buildBrokenImagePlaceholder(
                        'Could not load image.\nCheck your internet connection\nor re-seed the wallpaper URL in Firestore.',
                      );
                    },
                  ),
          ),
          
          // Blur if premium and not yet unlocked
          // Show blur only if premium, not yet unlocked, AND not still checking
          if (widget.wallpaper.isPremium && !_isUnlocked && !_isCheckingUnlock)
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
              child: Container(
                color: Colors.black.withValues(alpha: 0.3),
              ),
            ),
            
          // Bottom Actions
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Column(
              children: [
                if (widget.wallpaper.isPremium && _isCheckingUnlock) ...[
                  // Silently checking unlock status — show small spinner
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: DiamondLoader(size: 28),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Checking access...',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ] else if (widget.wallpaper.isPremium && !_isUnlocked) ...[
                  const Icon(Icons.lock, color: Colors.white, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Premium Wallpaper',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '₹${widget.wallpaper.price.toStringAsFixed(2)}',
                    style: const TextStyle(color: Colors.amber, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    onPressed: _buyPremium,
                    icon: const Icon(Icons.shopping_cart),
                    label: const Text('Unlock with UPI', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ] else ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildActionButton(Icons.download, 'Download', _downloadWallpaper),
                      _isSetting
                          ? const Column(
                              children: [
                                DiamondLoader(size: 40),
                                SizedBox(height: 8),
                                Text('Setting...', style: TextStyle(color: Colors.white)),
                              ],
                            )
                          : _buildActionButton(Icons.wallpaper, 'Set as Wallpaper', _setWallpaper),
                    ],
                  ),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrokenImagePlaceholder(String message) {
    return Container(
      color: Colors.grey[900],
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.broken_image_outlined, color: Colors.amber, size: 64),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap) {
    return Column(
      children: [
        FloatingActionButton(
          heroTag: label,
          backgroundColor: Colors.black54,
          foregroundColor: Colors.white,
          onPressed: onTap,
          child: Icon(icon),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
