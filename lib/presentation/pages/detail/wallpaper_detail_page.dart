import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:palette_generator/palette_generator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallpaper_manager_plus/wallpaper_manager_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_cropper/image_cropper.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/royal_snack_bar.dart';
import '../../../domain/entities/wallpaper_entity.dart';
import '../../../domain/repositories/payment_repository.dart';
import '../../providers/auth_provider.dart';
import '../../providers/wallpaper_provider.dart';
import '../../widgets/diamond_loader.dart';
import '../payment/payment_bottom_sheet.dart';
import '../../../core/utils/image_filter_utils.dart';
import 'package:go_router/go_router.dart';
import '../../providers/favorites_provider.dart';
import '../../../core/ads/ad_helper.dart';

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
  bool _showPreview = false;
  bool _isHeroTransitionFinished = false;
  WallpaperFilter _currentFilter = WallpaperFilter.original;
  Color? _dominantColor;
  Color? _vibrantColor;
  // Real-time clock for preview
  late final StreamSubscription<dynamic> _clockTimer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Delay expensive render effects (like blur) until Hero transition completes
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _isHeroTransitionFinished = true);
    });
    // Real-time clock
    _clockTimer = Stream.periodic(const Duration(seconds: 1)).listen((_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    // For free wallpapers, skip the check
    if (widget.wallpaper.isSpecial) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkIfAlreadyUnlocked();
      });
    }
    _extractColor();
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    super.dispose();
  }

  Future<void> _extractColor() async {
    if (widget.wallpaper.isSpecial) return; // Special always golden
    try {
      final imageProvider = ResizeImage(
        CachedNetworkImageProvider(widget.wallpaper.optimizedUrl),
        width: 64, // Dramatically reduces extraction time and memory
      );
      final palette = await PaletteGenerator.fromImageProvider(
        imageProvider,
        size: const Size(64, 64),
        maximumColorCount: 5,
      );
      if (mounted) {
        setState(() {
          _dominantColor = palette.dominantColor?.color;
          _vibrantColor = palette.vibrantColor?.color ?? palette.lightVibrantColor?.color;
        });
      }
    } catch (e) {
      // Ignore errors
    }
  }

  Color get _primaryColor => widget.wallpaper.isSpecial 
      ? Colors.amber 
      : (_vibrantColor ?? _dominantColor ?? Colors.amber);

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
      RoyalSnackBar.show(context, 'Please login to unlock this wallpaper',
          type: SnackBarType.info);
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
      RoyalSnackBar.show(context, 'Payment confirmed! Wallpaper unlocked.');
      setState(() => _isUnlocked = true);
    }
  }

  Future<void> _deleteWallpaperAction() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bg2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Wallpaper',
            style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('Are you sure you want to delete this wallpaper?',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textMuted))),
          ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent.withAlpha(200)),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete',
                  style: TextStyle(color: Colors.white))),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await ref.read(wallpaperProvider.notifier).deleteWallpaper(widget.wallpaper.id);
      if (mounted) {
        RoyalSnackBar.show(context, 'Wallpaper deleted', type: SnackBarType.info);
        Navigator.pop(context);
      }
    }
  }

  Future<void> _editWallpaperAction() async {
    final titleController = TextEditingController(text: widget.wallpaper.title);
    final categoryController = TextEditingController(text: widget.wallpaper.category);

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bg2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit Wallpaper', style: TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Title',
                labelStyle: TextStyle(color: AppColors.textSecondary),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.glassBorder)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.amber)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: categoryController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Category',
                labelStyle: TextStyle(color: AppColors.textSecondary),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.glassBorder)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.amber)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.goldMid),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      final newTitle = titleController.text.trim();
      final newCategory = categoryController.text.trim();

      if (newTitle.isNotEmpty && newCategory.isNotEmpty) {
        await ref.read(wallpaperProvider.notifier).updateWallpaper(
              widget.wallpaper.id,
              newTitle,
              newCategory,
            );
        if (mounted) {
          RoyalSnackBar.show(context, 'Wallpaper updated successfully');
        }
      }
    }
  }

  Future<void> _downloadWallpaper() async {
    final isFree = !widget.wallpaper.isSpecial && !widget.wallpaper.isPremium;
    if (isFree) {
      if (mounted) {
        RoyalSnackBar.show(context, 'Loading Ad...', type: SnackBarType.info);
      }
      AdHelper.showRewardedAd(onCompleted: () async {
        await _performDownload();
      });
    } else {
      await _performDownload();
    }
  }

  Future<void> _performDownload() async {
    try {
      if (Platform.isAndroid) {
        final hasAccess = await Gal.hasAccess();
        if (!hasAccess) {
          final granted = await Gal.requestAccess();
          if (!granted) {
            if (mounted) {
              RoyalSnackBar.show(
                  context, 'Storage permission denied. Please allow in Settings.',
                  type: SnackBarType.error);
            }
            return;
          }
        }
      }

      if (mounted) {
        RoyalSnackBar.show(context, 'Downloading…', type: SnackBarType.info);
      }

      final response = await http.get(
        Uri.parse(widget.wallpaper.optimizedUrl),
        headers: {'User-Agent': 'RoyalPixels/1.0'},
      );

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final Uint8List bytes = response.bodyBytes;
      final processedBytes =
          await ImageFilterUtils.applyFilterToBytes(bytes, _currentFilter);
      await Gal.putImageBytes(processedBytes,
          name: 'royal_pixel_${widget.wallpaper.id}');

      final prefs = await SharedPreferences.getInstance();
      final ids = prefs.getStringList('downloaded_wallpaper_ids') ?? [];
      if (!ids.contains(widget.wallpaper.id)) {
        ids.add(widget.wallpaper.id);
        await prefs.setStringList('downloaded_wallpaper_ids', ids);
      }

      if (mounted) {
        RoyalSnackBar.show(context, 'Saved to Gallery!');
      }
    } catch (e) {
      if (mounted) {
        RoyalSnackBar.show(context, 'Download failed: ${e.toString()}',
            type: SnackBarType.error);
      }
    }
  }

  Future<void> _setWallpaper() async {
    final choice = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bg2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Set as Wallpaper',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
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

    final isFree = !widget.wallpaper.isSpecial && !widget.wallpaper.isPremium;
    if (isFree) {
      if (mounted) {
        RoyalSnackBar.show(context, 'Loading Ad...', type: SnackBarType.info);
      }
      AdHelper.showRewardedAd(onCompleted: () async {
        await _performSetWallpaper(choice);
      });
    } else {
      await _performSetWallpaper(choice);
    }
  }

  Future<void> _performSetWallpaper(int choice) async {
    setState(() => _isSetting = true);
    try {
      if (mounted) {
        RoyalSnackBar.show(context, 'Setting wallpaper…', type: SnackBarType.info);
      }

      final response = await http.get(
        Uri.parse(widget.wallpaper.optimizedUrl),
        headers: {'User-Agent': 'RoyalPixels/1.0'},
      );

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final Uint8List bytes = response.bodyBytes;
      final processedBytes =
          await ImageFilterUtils.applyFilterToBytes(bytes, _currentFilter);

      final tempDir = await getTemporaryDirectory();
      final tempFile =
          File('${tempDir.path}/rp_wallpaper_${widget.wallpaper.id}.jpg');
      await tempFile.writeAsBytes(processedBytes);
      
      final File? croppedFile = await _cropWallpaper(tempFile.path);
      if (croppedFile == null) {
        if (mounted) {
          RoyalSnackBar.show(context, 'Adjustment cancelled', type: SnackBarType.info);
        }
        return;
      }

      await WallpaperManagerPlus().setWallpaper(croppedFile, choice);

      if (mounted) {
        RoyalSnackBar.show(context, 'Wallpaper set successfully!');
      }
    } catch (e) {
      if (mounted) {
        RoyalSnackBar.show(
            context, 'Failed to set wallpaper: ${e.toString()}',
            type: SnackBarType.error);
      }
    } finally {
      if (mounted) setState(() => _isSetting = false);
    }
  }

  Future<File?> _cropWallpaper(String sourcePath) async {
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: sourcePath,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Adjust Wallpaper',
          toolbarColor: Colors.black,
          toolbarWidgetColor: Colors.amber,
          backgroundColor: Colors.black,
          activeControlsWidgetColor: Colors.amber,
          dimmedLayerColor: Colors.black54,
          // Start in free (original = no locked ratio) mode
          initAspectRatio: CropAspectRatioPreset.original,
          // Unlock aspect ratio so user can freely resize/scale
          lockAspectRatio: false,
          // Show all presets — "Original" is the freestyle freeform mode
          aspectRatioPresets: [
            CropAspectRatioPreset.original,
            CropAspectRatioPreset.square,
            CropAspectRatioPreset.ratio16x9,
            CropAspectRatioPreset.ratio4x3,
            CropAspectRatioPreset.ratio3x2,
          ],
          showCropGrid: true,
        ),
        IOSUiSettings(
          title: 'Adjust Wallpaper',
          cancelButtonTitle: 'Cancel',
          doneButtonTitle: 'Set',
          // Allow free resizing on iOS
          aspectRatioLockEnabled: false,
          resetAspectRatioEnabled: true,
          aspectRatioPresets: [
            CropAspectRatioPreset.original,
            CropAspectRatioPreset.square,
            CropAspectRatioPreset.ratio16x9,
            CropAspectRatioPreset.ratio4x3,
            CropAspectRatioPreset.ratio3x2,
          ],
        ),
      ],
    );
    if (croppedFile != null) {
      return File(croppedFile.path);
    }
    return null;
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
            Icon(icon, color: _primaryColor, size: 22),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 15)),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 14),
          ],
        ),
      ),
    );
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
            child: Container(
              color: const Color(0xFF1E1E1E).withAlpha(150),
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Remix Wallpaper', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _filterOption(WallpaperFilter.original, 'Original', Icons.image),
                    _filterOption(WallpaperFilter.amoledBlack, 'AMOLED Black', Icons.dark_mode),
                    _filterOption(WallpaperFilter.grayscale, 'Grayscale', Icons.tonality),
                    _filterOption(WallpaperFilter.highContrast, 'Contrast', Icons.contrast),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
            ),
          ),
        );
      },
    );
  }

  Widget _filterOption(WallpaperFilter filter, String label, IconData icon) {
    final isSelected = _currentFilter == filter;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _currentFilter = filter);
        Navigator.pop(context);
      },
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? _primaryColor : Colors.white12,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? _primaryColor : Colors.transparent),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? Colors.black : Colors.white, size: 28),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: isSelected ? Colors.black : Colors.white, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
          ],
        ),
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final isPremiumUnlocked = user?.isSubscribed ?? false;
    final isPremiumAndLocked = widget.wallpaper.isPremium && !widget.wallpaper.isSpecial && !isPremiumUnlocked;
    
    final favorites = ref.watch(favoritesProvider);
    final isFavorite = favorites.contains(widget.wallpaper.id);

    return Scaffold(
      backgroundColor: _dominantColor?.withAlpha(40) ?? Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            HapticFeedback.selectionClick();
            Navigator.of(context).pop();
          },
        ),
        actions: [
          if (ref.watch(authProvider).user?.email == 'subhamsoudeep@gmail.com') ...[
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.white),
              onPressed: _editWallpaperAction,
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.white),
              onPressed: _deleteWallpaperAction,
            ),
          ],
          if (!widget.wallpaper.isSpecial || _isUnlocked) ...[
            IconButton(
              icon: const Icon(Icons.auto_fix_high, color: Colors.white),
              onPressed: _showFilterBottomSheet,
            ),
            IconButton(
              icon: Icon(_showPreview ? Icons.visibility_off : Icons.visibility, color: Colors.white),
              onPressed: () {
                HapticFeedback.lightImpact();
                setState(() => _showPreview = !_showPreview);
              },
            ),
            IconButton(
              icon: Icon(
                isFavorite ? Icons.favorite : Icons.favorite_border,
                color: isFavorite ? Colors.redAccent : Colors.white,
              ),
              onPressed: () {
                HapticFeedback.lightImpact();
                ref.read(favoritesProvider.notifier).toggleFavorite(widget.wallpaper.id);
                if (!isFavorite) {
                  RoyalSnackBar.show(context, 'Added to favorites!', type: SnackBarType.info);
                }
              },
            ),
          ],
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Hero(
            tag: 'wallpaper_${widget.wallpaper.id}',
            child: widget.wallpaper.optimizedUrl.isEmpty
                ? _buildBrokenImagePlaceholder('No image URL stored in database')
                : ColorFiltered(
                    colorFilter: ColorFilter.matrix(
                      ImageFilterUtils.getMatrixForFilter(_currentFilter),
                    ),
                    child: CachedNetworkImage(
                      imageUrl: widget.wallpaper.optimizedUrl,
                      fit: BoxFit.cover,
                      memCacheHeight: 1600, // Limits maximum RAM allocation for 4k wallpapers
                      placeholder: (context, url) => Container(
                        color: _dominantColor?.withAlpha(80) ?? Colors.grey[900],
                        child: Center(
                          child: DiamondLoader(size: 30, color: _primaryColor,),
                        ),
                      ),
                      errorWidget: (context, url, error) {
                        debugPrint('Image load error for url: $url\nError: $error');
                        return _buildBrokenImagePlaceholder(
                          'Could not load image.\nCheck your internet connection\nor re-seed the wallpaper URL in Firestore.',
                        );
                      },
                    ),
                  ),
          ),
          
          // Blur if special and not yet unlocked OR premium and not yet unlocked
          if ((widget.wallpaper.isSpecial && !_isUnlocked && !_isCheckingUnlock && _isHeroTransitionFinished) ||
              (isPremiumAndLocked && _isHeroTransitionFinished))
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 300),
              builder: (context, value, child) {
                return BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10.0 * value, sigmaY: 10.0 * value),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.3 * value),
                  ),
                );
              },
            ),

          // Bottom gradient (no blur — cheaper, same visual effect)
          Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 250,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.black.withAlpha(210),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            
          // Lock Screen Preview Overlay
          if (_showPreview)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.only(top: 100, bottom: 60),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Clock & Date
                      Column(
                        children: [
                          Text(
                            '${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 84,
                              fontWeight: FontWeight.w200,
                              shadows: [Shadow(color: Colors.black45, blurRadius: 10)],
                            ),
                          ),
                          Text(
                            '${_weekdayName(_now.weekday)}, ${_monthName(_now.month)} ${_now.day}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              shadows: [Shadow(color: Colors.black45, blurRadius: 10)],
                            ),
                          ),
                        ],
                      ),
                      // Mock bottom icons
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                              child: Icon(Icons.flashlight_on, color: _primaryColor, size: 28),
                            ),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                              child: Icon(Icons.camera_alt, color: _primaryColor, size: 28),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
          // Bottom Actions
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Column(
              children: [
                if (widget.wallpaper.isSpecial && _isCheckingUnlock) ...[
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
                ] else if (widget.wallpaper.isSpecial && !_isUnlocked) ...[
                  // ── Premium gate ────────────────────────────────────
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                        decoration: BoxDecoration(
                          color: AppColors.bg0.withAlpha(180),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AppColors.glassBorder),
                        ),
                        child: Column(
                          children: [
                            ShaderMask(
                              shaderCallback: (b) =>
                                  AppColors.goldGradient.createShader(b),
                              child: const Icon(Icons.lock_rounded,
                                  color: Colors.white, size: 40),
                            ),
                            const SizedBox(height: 10),
                            const Text('Special Wallpaper',
                                style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            ShaderMask(
                              shaderCallback: (b) =>
                                  AppColors.goldGradient.createShader(b),
                              child: Text(
                                '₹${widget.wallpaper.price.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900),
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Subscription button removed from Special Gate because Special Wallpapers
                            // are not unlocked by subscription.
                            
                            // Individual purchase button
                            GestureDetector(
                              onTap: _buyPremium,
                              child: Container(
                                width: double.infinity,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  border: Border.all(color: Colors.white24),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.qr_code,
                                        color: Colors.white, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Unlock for ₹${widget.wallpaper.price.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ] else if (isPremiumAndLocked) ...[
                  // ── Premium gate ────────────────────────────────────
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                        decoration: BoxDecoration(
                          color: AppColors.bg0.withAlpha(180),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AppColors.glassBorder),
                        ),
                        child: Column(
                          children: [
                            ShaderMask(
                              shaderCallback: (b) =>
                                  AppColors.goldGradient.createShader(b),
                              child: const Icon(Icons.workspace_premium,
                                  color: Colors.white, size: 40),
                            ),
                            const SizedBox(height: 10),
                            const Text('Premium Wallpaper',
                                style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 16),
                            
                            // Subscription button
                            GestureDetector(
                              onTap: () {
                                context.push('/subscription');
                              },
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  gradient: AppColors.goldGradient,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFFF8C00).withValues(alpha: 0.3),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.workspace_premium, color: Colors.black, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'Subscribe to Unlock',
                                      style: TextStyle(
                                          color: Colors.black,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ] else if (!_showPreview) ...[
                  // ── Action button row ───────────────────────────────
                  _buildActionRow(),
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
      color: _dominantColor?.withAlpha(80) ?? Colors.grey[900],
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image_outlined, color: _primaryColor, size: 64),
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

  /// Glassmorphic pill button row: Download + Set Wallpaper
  Widget _buildActionRow() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.glassFill,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildPillButton(
                    Icons.download_rounded, 'Save', _downloadWallpaper),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _isSetting
                    ? Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.bg3,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            DiamondLoader(size: 20, color: _primaryColor),
                            const SizedBox(width: 8),
                            const Text('Setting…',
                                style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      )
                    : _buildPillButton(
                        Icons.wallpaper_rounded, 'Set', _setWallpaper),
              ),
              const SizedBox(width: 10),
              // Filter icon button
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _showFilterBottomSheet();
                },
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: _currentFilter != WallpaperFilter.original
                        ? _primaryColor.withAlpha(60)
                        : AppColors.bg2,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _currentFilter != WallpaperFilter.original
                          ? _primaryColor.withAlpha(120)
                          : AppColors.glassBorder,
                    ),
                  ),
                  child: Icon(
                    Icons.auto_fix_high_rounded,
                    color: _currentFilter != WallpaperFilter.original
                        ? _primaryColor
                        : AppColors.textSecondary,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPillButton(
      IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: AppColors.goldGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.goldMid.withAlpha(60),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.black, size: 18),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  String _weekdayName(int weekday) {
    const days = ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[weekday];
  }

  String _monthName(int month) {
    const months = ['', 'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'];
    return months[month];
  }
}
