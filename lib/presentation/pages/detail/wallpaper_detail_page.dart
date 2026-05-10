import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:palette_generator_master/palette_generator_master.dart';
import 'package:wallpaper_manager_plus/wallpaper_manager_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/services/adaptive_performance.dart';
import 'package:go_router/go_router.dart';


import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/animations/liquid_rect_tween.dart';
import '../../../core/utils/royal_snack_bar.dart';
import '../../../domain/entities/diamond_data.dart';
import '../../../domain/entities/wallpaper_entity.dart';
import '../../../domain/repositories/payment_repository.dart';
import '../../../core/constants/app_constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/diamond_provider.dart';
import '../../providers/wallpaper_provider.dart';
import '../../providers/notification_provider.dart';
import '../../../domain/entities/notification_type.dart';
import '../../../data/datasources/firestore_data_source.dart';

import '../../widgets/diamond_loader.dart';
import '../../../core/utils/image_filter_utils.dart';
import '../../providers/likes_provider.dart';
import '../../providers/haptic_provider.dart';
import '../../providers/download_provider.dart';
import '../../../core/scroll/elite_scroll_physics.dart';
import '../../../core/widgets/premium_glass_container.dart';
import '../../../core/widgets/login_required_sheet.dart';
import '../../../core/utils/safe_tap.dart';

class WallpaperDetailPage extends ConsumerStatefulWidget {
  final WallpaperEntity wallpaper;

  const WallpaperDetailPage({super.key, required this.wallpaper});

  @override
  ConsumerState<WallpaperDetailPage> createState() =>
      _WallpaperDetailPageState();
}

class _WallpaperDetailPageState extends ConsumerState<WallpaperDetailPage> {
  bool _isSetting = false;
  bool _showPreview = false;
  bool _isHeroTransitionFinished = false;
  WallpaperFilter _currentFilter = WallpaperFilter.original;
  Color? _dominantColor;
  Color? _vibrantColor;
  // Real-time clock for preview
  late final StreamSubscription<dynamic> _clockTimer;
  DateTime _now = DateTime.now();

  bool _isUnlocked = false;
  bool _isLoadingUnlock = false;

  // Phase 4: Swipe-to-dismiss state
  final ValueNotifier<double> _dragOffset = ValueNotifier(0.0);
  bool _isDismissing = false;

  // Heart animations for double tap
  final List<Offset> _hearts = [];

  void _handleDoubleTap() {
    // 1. Trigger Haptics
    ref.read(hapticProvider.notifier).mediumImpact();

    // 2. Perform Like Logic (ensure it's liked)
    final isLiked = ref.read(likesProvider).contains(widget.wallpaper.id);
    if (!isLiked) {
      ref.read(likesNotifierProvider.notifier).toggleLike(widget.wallpaper.id);
      RoyalSnackBar.show(context, 'Added to favorites!', type: SnackBarType.info);
    }

    // 3. Add Heart Animation Instance
    setState(() {
      _hearts.add(Offset.zero);
    });

    // 4. Cleanup
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted && _hearts.isNotEmpty) {
        setState(() {
          _hearts.removeAt(0);
        });
      }
    });
  }




  @override
  void initState() {
    super.initState();



    // Phase 7: Faster detail page activation on budget devices
    // We reduce the "Hero" wait time since we might disable Hero transitions entirely.
    final heroDuration = AdaptivePerformance.enableHeroTransitions ? 400 : 50;
    Future.delayed(Duration(milliseconds: heroDuration), () {
      if (mounted) setState(() => _isHeroTransitionFinished = true);
    });
    // Real-time clock
    _clockTimer = Stream.periodic(const Duration(seconds: 1)).listen((_) {
      if (mounted) setState(() => _now = DateTime.now());
    });

    _checkUnlockStatus();

    _extractColor();
    // Fire-and-forget: increment view count after hero transition completes
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      final userId = ref.read(authProvider).user?.uid;
      sl<FirestoreDataSource>()
          .incrementViewCount(widget.wallpaper.id, userId: userId);
    });
  }



  @override
  void dispose() {
    _clockTimer.cancel();

    _dragOffset.dispose();
    super.dispose();
  }

  Future<void> _extractColor() async {
    try {
      // Use thumbnailUrl (150px) for palette extraction — tiny bitmap,
      // extracts almost instantly with no GPU pressure.
      final imageProvider = ResizeImage(
        CachedNetworkImageProvider(widget.wallpaper.thumbnailUrl),
        width: 64,
      );
      final palette = await PaletteGeneratorMaster.fromImageProvider(
        imageProvider,
        size: const Size(64, 64),
        maximumColorCount: 5,
      );
      if (mounted) {
        setState(() {
          _dominantColor = palette.dominantColor?.color;
          _vibrantColor =
              palette.vibrantColor?.color ?? palette.lightVibrantColor?.color;
        });
      }
    } catch (e) {
      // Ignore errors
    }
  }

  Color get _primaryColor => _vibrantColor ?? _dominantColor ?? Colors.amber;

  Future<void> _checkUnlockStatus() async {
    if (!widget.wallpaper.isPremium) {
      if (mounted) setState(() => _isUnlocked = true);
      return;
    }

    final authState = ref.read(authProvider);
    if (authState.user != null && authState.user?.isSubscribed == true) {
      if (mounted) setState(() => _isUnlocked = true);
      return;
    }

    if (authState.user != null) {
      try {
        final paymentRepo = sl<PaymentRepository>();
        final result = await paymentRepo.checkUnlockStatus(
          authState.user!.uid,
          widget.wallpaper.id,
        );
        result.fold(
          (failure) => debugPrint('Error checking unlock status: $failure'),
          (isUnlocked) {
            if (mounted) setState(() => _isUnlocked = isUnlocked);
          },
        );
      } catch (e) {
        debugPrint('Error checking unlock status: $e');
      }
    }
  }

  Future<void> _unlockWallpaper() async {
    SafeTap.run('unlock_wallpaper', () async {
      final authState = ref.read(authProvider);
      if (!authState.isAuthenticated) {
        showLoginRequiredSheet(context, reason: LoginRequiredReason.diamonds);
        return;
      }

      setState(() => _isLoadingUnlock = true);
      
      try {
        final success = await ref.read(diamondProvider.notifier).spendDiamonds(
          authState.user!.uid,
          widget.wallpaper.id,
          widget.wallpaper.diamondCost,
        );

        if (success && mounted) {
          setState(() => _isUnlocked = true);
          RoyalSnackBar.show(context, 'Wallpaper unlocked successfully!', type: SnackBarType.success);
        } else if (mounted) {
          RoyalSnackBar.show(context, 'Insufficient diamonds. Get more in the store.', type: SnackBarType.error);
        }
      } catch (e) {
        if (mounted) RoyalSnackBar.show(context, 'Failed to unlock: $e', type: SnackBarType.error);
      } finally {
        if (mounted) setState(() => _isLoadingUnlock = false);
      }
    });
  }

  /// Silently checks Firestore to see if user has already paid for this wallpaper.
  /// If yes, automatically removes the blur & lock UI.


  Future<void> _deleteWallpaperAction() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: AdaptivePerformance.enableBackdropBlur
          ? BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.bg2.withAlpha(13),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.glassBorder.withAlpha(50)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Delete Wallpaper',
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  const Text('Are you sure you want to delete this wallpaper?',
                      style: TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel',
                              style: TextStyle(color: AppColors.textMuted))),
                      const SizedBox(width: 8),
                      ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent.withAlpha(200)),
                          onPressed: () => Navigator.pop(ctx, true),
                          child:
                              const Text('Delete', style: TextStyle(color: Colors.white))),
                    ],
                  ),
                ],
              ),
            ),
          )
          : Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.bg2.withAlpha(240),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.glassBorder.withAlpha(50)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Delete Wallpaper',
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  const Text('Are you sure you want to delete this wallpaper?',
                      style: TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel',
                              style: TextStyle(color: AppColors.textMuted))),
                      const SizedBox(width: 8),
                      ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent.withAlpha(200)),
                          onPressed: () => Navigator.pop(ctx, true),
                          child:
                              const Text('Delete', style: TextStyle(color: Colors.white))),
                    ],
                  ),
                ],
              ),
            ),
        ),
      ),
    );

    if (confirm == true && mounted) {
      await ref
          .read(wallpaperProvider.notifier)
          .deleteWallpaper(widget.wallpaper.id);
      if (mounted) {
        RoyalSnackBar.show(context, 'Wallpaper deleted',
            type: SnackBarType.info);
        Navigator.pop(context);
      }
    }
  }

  Future<void> _editWallpaperAction() async {
    // ── Local state for the dialog (StatefulBuilder) ──
    final titleController = TextEditingController(text: widget.wallpaper.title);
    final categoryController =
        TextEditingController(text: widget.wallpaper.category);
    final diamondCostController = TextEditingController(
      text: widget.wallpaper.diamondCost > 0
          ? widget.wallpaper.diamondCost.toString()
          : '100',
    );
    bool dialogIsPremium = widget.wallpaper.isPremium;
    bool dialogIsUltraHD = widget.wallpaper.isUltraHD;
    bool dialogIsEditorsChoice = widget.wallpaper.isEditorsChoice;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Builder(
              builder: (ctx) {
                final dialogContent = Container(
                  decoration: BoxDecoration(
                    color: AdaptivePerformance.enableBackdropBlur ? AppColors.bg1.withAlpha(13) : AppColors.bg1.withAlpha(240),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.glassBorder.withAlpha(50)),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    const Icon(Icons.admin_panel_settings_rounded,
                        color: AppColors.goldMid, size: 22),
                    const SizedBox(width: 10),
                    const Text('Edit Wallpaper',
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 20),

                // Title
                _EditField(
                  controller: titleController,
                  label: 'Title',
                  icon: Icons.title_rounded,
                ),
                const SizedBox(height: 12),

                // Category
                _EditField(
                  controller: categoryController,
                  label: 'Category',
                  icon: Icons.category_rounded,
                ),
                const SizedBox(height: 20),

                // Section: Content Type
                _sectionLabel('Content Type'),
                const SizedBox(height: 8),

                // Premium toggle
                _DialogSwitch(
                  icon: Icons.workspace_premium,
                  iconColor: AppColors.goldMid,
                  label: 'Premium',
                  subtitle: 'Premium badge for exclusive wallpapers',
                  value: dialogIsPremium,
                  activeColor: AppColors.goldMid,
                  onChanged: (v) => setDialogState(() {
                    dialogIsPremium = v;
                    if (!v) {
                      // Reset cost when un-premiuming
                      diamondCostController.text = '0';
                    } else {
                      if (diamondCostController.text == '0') {
                        diamondCostController.text = '100';
                      }
                    }
                  }),
                ),

                // Diamond cost — only when premium is on
                if (dialogIsPremium) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withAlpha(15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.withAlpha(60)),
                    ),
                    child: Row(
                      children: [
                        const Text('💎', style: TextStyle(fontSize: 20)),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Diamond Cost',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600)),
                              Text('How many 💎 required to unlock',
                                  style: TextStyle(
                                      color: Colors.white38, fontSize: 11)),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 70,
                          child: TextField(
                            controller: diamondCostController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.amber,
                                fontWeight: FontWeight.w800,
                                fontSize: 18),
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 8),
                              filled: true,
                              fillColor: Colors.amber.withAlpha(20),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide:
                                      const BorderSide(color: Colors.amber)),
                              enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                      color: Colors.amber, width: 0.8)),
                              focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                      color: Colors.amber, width: 2)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),
                _sectionLabel('Tags'),
                const SizedBox(height: 8),

                // Ultra HD toggle
                _DialogSwitch(
                  icon: Icons.hd_rounded,
                  iconColor: const Color(0xFF22D3EE),
                  label: 'Ultra HD / 4K',
                  subtitle: 'Shows cyan 4K badge on card',
                  value: dialogIsUltraHD,
                  activeColor: const Color(0xFF22D3EE),
                  onChanged: (v) => setDialogState(() => dialogIsUltraHD = v),
                ),
                const SizedBox(height: 8),

                // Editor's Choice toggle
                _DialogSwitch(
                  icon: Icons.star_rounded,
                  iconColor: const Color(0xFFFBBF24),
                  label: "Editor's Choice",
                  subtitle: 'Shows amber ★ PICK badge on card',
                  value: dialogIsEditorsChoice,
                  activeColor: const Color(0xFFFBBF24),
                  onChanged: (v) => setDialogState(() => dialogIsEditorsChoice = v),
                ),
                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel',
                            style: TextStyle(color: AppColors.textMuted)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.goldMid,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Save Changes',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    ],
                  ),
                ],
                    ),
                  ),
                );

            return AdaptivePerformance.enableBackdropBlur
                ? BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: dialogContent,
                  )
                : dialogContent;
          },
        ),
      ),
    ),
  ),
);


    if (result == true && mounted) {
      final newTitle = titleController.text.trim();
      final newCategory = categoryController.text.trim();
      final newDiamondCost =
          int.tryParse(diamondCostController.text.trim()) ?? 100;

      // Rebuild tags: keep non-meta tags, then add fresh meta tags
      final baseTags = widget.wallpaper.tags
          .where((t) => t != 'ultra_hd' && t != 'editors_choice')
          .toList();
      if (dialogIsUltraHD) baseTags.add('ultra_hd');
      if (dialogIsEditorsChoice) baseTags.add('editors_choice');

      if (newTitle.isNotEmpty && newCategory.isNotEmpty) {
        await ref.read(wallpaperProvider.notifier).updateWallpaper(
              widget.wallpaper.id,
              newTitle: newTitle,
              newCategory: newCategory,
              isPremium: dialogIsPremium,
              diamondCost: dialogIsPremium ? newDiamondCost : 0,
              tags: baseTags,
            );
        if (mounted) {
          RoyalSnackBar.show(context, 'Wallpaper updated ✅');
        }
      }
    }
  }



  Future<void> _downloadWallpaper() async {
    SafeTap.run('wp_download', () async {
      final user = ref.read(authProvider).user;

      await _performDownload();

      if (user != null) {
        final result = await ref
            .read(diamondProvider.notifier)
            .addSmallReward(user.uid, widget.wallpaper.id);

        if (mounted && !result.granted) {
          final msg = result.denyReason ==
                  SmallRewardDenyReason.wallpaperAlreadyRewarded
              ? 'Already earned reward for this wallpaper today'
              : 'Daily reward cap reached (80/day). Come back tomorrow!';
          RoyalSnackBar.show(context, msg, type: SnackBarType.info);
        }
      }
    });
  }

  Future<void> _performDownload() async {
    try {
      if (Platform.isAndroid) {
        final hasAccess = await Gal.hasAccess();
        if (!hasAccess) {
          final granted = await Gal.requestAccess();
          if (!granted) {
            if (mounted) {
              RoyalSnackBar.show(context,
                  'Storage permission denied. Please allow in Settings.',
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
        Uri.parse(widget.wallpaper.fullQualityUrl),
        headers: {'User-Agent': 'RoyalPixels/1.0'},
      );

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final Uint8List bytes = response.bodyBytes;
      final processedBytes =
          await ImageFilterUtils.applyFilterToBytes(bytes, _currentFilter);

      // Write bytes to a temp file first, then save via path.
      // Gal.putImageBytes() fails with GalException/UNEXPECTED on many
      // Android devices; using a temp file + Gal.putImage() is reliable.
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(
          '${tempDir.path}/rp_download_${widget.wallpaper.id}_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(processedBytes);
      await Gal.putImage(tempFile.path, album: AppConstants.appName);
      // Clean up the temp file after saving
      tempFile.deleteSync();

      // Save to global state and SharedPreferences
      await ref
          .read(downloadProvider.notifier)
          .addDownload(widget.wallpaper.id);

      if (mounted) {
        RoyalSnackBar.show(context, 'Saved to Gallery! 💎 +5');
        ref.read(notificationProvider.notifier).addNotification(
              title: 'Download Successful',
              message:
                  '"${widget.wallpaper.title}" has been saved to your gallery.',
              type: NotificationType.download,
            );
      }
    } catch (e) {
      if (mounted) {
        RoyalSnackBar.show(context, 'Download failed: ${e.toString()}',
            type: SnackBarType.error);
      }
    }
  }

  Future<void> _setWallpaper(
      [int choice = WallpaperManagerPlus.bothScreens]) async {
    SafeTap.run('wp_set', () async {
      if (!mounted) return;

      final user = ref.read(authProvider).user;

      await _performSetWallpaper(choice);

      if (user != null) {
        final result = await ref
            .read(diamondProvider.notifier)
            .addSmallReward(user.uid, widget.wallpaper.id);

        if (mounted && !result.granted) {
          final msg = result.denyReason ==
                  SmallRewardDenyReason.wallpaperAlreadyRewarded
              ? 'Already earned reward for this wallpaper today'
              : 'Daily reward cap reached (80/day). Come back tomorrow!';
          RoyalSnackBar.show(context, msg, type: SnackBarType.info);
        }
      }
    });
  }

  Future<void> _performSetWallpaper(int choice) async {
    setState(() => _isSetting = true);
    try {
      if (mounted) {
        RoyalSnackBar.show(context, 'Setting wallpaper…',
            type: SnackBarType.info);
      }

      final response = await http.get(
        Uri.parse(widget.wallpaper.fullQualityUrl),
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

      if (!mounted) return;
      // Instant Apply: bypass crop and let the OS handle center-cropping
      await WallpaperManagerPlus().setWallpaper(tempFile, choice);

      if (mounted) {
        RoyalSnackBar.show(context, 'Wallpaper set successfully!');
        ref.read(notificationProvider.notifier).addNotification(
              title: 'Wallpaper Applied',
              message:
                  '"${widget.wallpaper.title}" is now your active wallpaper.',
              type: NotificationType.update, // Categorized as update
            );
      }
    } catch (e) {
      if (mounted) {
        RoyalSnackBar.show(context, 'Failed to set wallpaper: ${e.toString()}',
            type: SnackBarType.error);
      }
    } finally {
      if (mounted) setState(() => _isSetting = false);
    }
  }

  Widget _dialogOption(
      BuildContext ctx, IconData icon, String label, int value) {
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
            Text(label,
                style: const TextStyle(color: Colors.white, fontSize: 15)),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios,
                color: Colors.white38, size: 14),
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
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: AdaptivePerformance.enableBackdropBlur
              ? BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
                  child: Container(
                    color: const Color(0xFF1E1E1E).withAlpha(13),
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Remix Wallpaper',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const EliteScrollPhysics(),
                          child: Row(
                            children: [
                              _filterOption(
                                  WallpaperFilter.original, 'Original', Icons.image),
                              _filterOption(WallpaperFilter.amoledBlack,
                                  'AMOLED Black', Icons.dark_mode),
                              _filterOption(WallpaperFilter.grayscale, 'Grayscale',
                                  Icons.tonality),
                              _filterOption(WallpaperFilter.highContrast, 'Contrast',
                                  Icons.contrast),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                )
              : Container(
                  color: const Color(0xFF1E1E1E).withAlpha(240),
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Remix Wallpaper',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const EliteScrollPhysics(),
                        child: Row(
                          children: [
                            _filterOption(
                                WallpaperFilter.original, 'Original', Icons.image),
                            _filterOption(WallpaperFilter.amoledBlack,
                                'AMOLED Black', Icons.dark_mode),
                            _filterOption(WallpaperFilter.grayscale, 'Grayscale',
                                Icons.tonality),
                            _filterOption(WallpaperFilter.highContrast, 'Contrast',
                                Icons.contrast),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
        );
      },
    );
  }

  void _showSetWallpaperOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: AdaptivePerformance.enableBackdropBlur
              ? BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
                  child: Container(
                    color: const Color(0xFF1E1E1E).withAlpha(13),
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Set Wallpaper',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        _dialogOption(ctx, Icons.home, 'Home Screen',
                            WallpaperManagerPlus.homeScreen),
                        const SizedBox(height: 8),
                        _dialogOption(ctx, Icons.lock, 'Lock Screen',
                            WallpaperManagerPlus.lockScreen),
                        const SizedBox(height: 8),
                        _dialogOption(ctx, Icons.phone_android, 'Both Screens',
                            WallpaperManagerPlus.bothScreens),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                )
              : Container(
                  color: const Color(0xFF1E1E1E).withAlpha(240),
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Set Wallpaper',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      _dialogOption(ctx, Icons.home, 'Home Screen',
                          WallpaperManagerPlus.homeScreen),
                      const SizedBox(height: 8),
                      _dialogOption(ctx, Icons.lock, 'Lock Screen',
                          WallpaperManagerPlus.lockScreen),
                      const SizedBox(height: 8),
                      _dialogOption(ctx, Icons.phone_android, 'Both Screens',
                          WallpaperManagerPlus.bothScreens),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
        );
      },
    ).then((value) {
      if (value != null && value is int) {
        _setWallpaper(value);
      }
    });
  }

  Widget _filterOption(WallpaperFilter filter, String label, IconData icon) {
    final isSelected = _currentFilter == filter;
    return GestureDetector(
      onTap: () {
        ref.read(hapticProvider.notifier).selectionClick();
        setState(() => _currentFilter = filter);
        Navigator.pop(context);
      },
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? _primaryColor : Colors.white12,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isSelected ? _primaryColor : Colors.transparent),
        ),
        child: Column(
          children: [
            Icon(icon,
                color: isSelected ? Colors.black : Colors.white, size: 28),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(
                    color: isSelected ? Colors.black : Colors.white,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final likedIds = ref.watch(likesProvider);
    final isLiked = likedIds.contains(widget.wallpaper.id);

    return ValueListenableBuilder<double>(
      valueListenable: _dragOffset,
      builder: (context, offset, child) {
        // Opacity fades as user drags down (full at 0, 0.5 at 40% screen)
        final screenH = MediaQuery.sizeOf(context).height;
        final dragFraction = (offset / screenH).clamp(0.0, 1.0);
        final opacity = (1.0 - dragFraction * 1.5).clamp(0.4, 1.0);
        final scale = 1.0 - (dragFraction * 0.08);

        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, offset),
            child: Transform.scale(
              scale: scale,
              child: child,
            ),
          ),
        );
      },
      child: GestureDetector(
        // Phase 4: Swipe down to dismiss
        onVerticalDragUpdate: (details) {
          if (_isDismissing) return;
          // Only allow downward drag (positive dy)
          final newOffset = (_dragOffset.value + details.delta.dy).clamp(0.0, double.infinity);
          _dragOffset.value = newOffset;
        },
        onVerticalDragEnd: (details) {
          if (_isDismissing) return;
          final screenH = MediaQuery.sizeOf(context).height;
          final velocity = details.primaryVelocity ?? 0;
          final fraction = _dragOffset.value / screenH;

          if (EliteScrollPhysics.shouldDismiss(
            dragFraction: fraction,
            velocity: velocity.clamp(0, double.infinity),
          )) {
            // Dismiss!
            _isDismissing = true;
            ref.read(hapticProvider.notifier).lightImpact();
            // Animate to off-screen then pop
            final target = screenH * 1.2;
            final animDuration = Duration(
              milliseconds: (150 + (target - _dragOffset.value) / 8).clamp(150, 350).toInt(),
            );
            final navigator = Navigator.of(context);
            Future.delayed(animDuration, () {
              navigator.pop();
            });
            // Move to off-screen in animDuration
            Future.microtask(() async {
              const steps = 16;
              final stepSize = (target - _dragOffset.value) / steps;
              for (int i = 0; i < steps; i++) {
                await Future.delayed(Duration(milliseconds: animDuration.inMilliseconds ~/ steps));
                if (!mounted) break;
                _dragOffset.value = (_dragOffset.value + stepSize).clamp(0, target);
              }
            });
          } else {
            // Snap back
            _snapBack();
          }
        },
        onVerticalDragCancel: _snapBack,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: AnimatedOpacity(
          opacity: _isHeroTransitionFinished ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            flexibleSpace: PremiumGlassContainer(
              color: AppColors.bg0.withAlpha(120),
              glowColor: _primaryColor,
              glowIntensity: 0.5,
              glowOffset: const Offset(0, 10),
              border: const Border(
                bottom: BorderSide(color: AppColors.glassBorder, width: 0.8),
              ),
              child: const SizedBox.expand(),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () {
                ref.read(hapticProvider.notifier).selectionClick();
                Navigator.of(context).pop();
              },
            ),
            actions: [
              if (ref.watch(authProvider).user?.email ==
                  'subhamsoudeep@gmail.com') ...[
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.white),
                  onPressed: _editWallpaperAction,
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.white),
                  onPressed: _deleteWallpaperAction,
                ),
              ],
              IconButton(
                icon: const Icon(Icons.auto_fix_high, color: Colors.white),
                onPressed: _showFilterBottomSheet,
              ),
              IconButton(
                icon: Icon(_showPreview ? Icons.visibility_off : Icons.visibility,
                    color: Colors.white),
                onPressed: () {
                  ref.read(hapticProvider.notifier).lightImpact();
                  setState(() => _showPreview = !_showPreview);
                },
              ),
              IconButton(
                icon: Icon(
                  isLiked ? Icons.favorite : Icons.favorite_border,
                  color: isLiked ? Colors.redAccent : Colors.white,
                ),
                onPressed: () {
                  ref.read(hapticProvider.notifier).lightImpact();
                  // Allow guests to like locally.
                  ref
                      .read(likesNotifierProvider.notifier)
                      .toggleLike(widget.wallpaper.id);
                  if (!isLiked) {
                    RoyalSnackBar.show(context, 'Added to favorites!',
                        type: SnackBarType.info);
                  }
                },
              ),
            ],
          ),
        ),
      ),
      body: RepaintBoundary(
        child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onDoubleTap: _handleDoubleTap,
            onLongPress: () {
              ref.read(hapticProvider.notifier).mediumImpact();
              _showSetWallpaperOptions();
            },
            child: _buildMainImage(context),
          ),

          // Heart Popups Overlay
          if (AdaptivePerformance.enableAnimations)
            ..._hearts.map((_) => Center(
              child: Icon(
                Icons.favorite_rounded,
                color: Colors.redAccent.withValues(alpha: 0.9),
                size: 140,
              ).animate()
               .scale(
                 begin: const Offset(0.3, 0.3),
                 end: const Offset(1.2, 1.2),
                 duration: 400.ms,
                 curve: Curves.elasticOut,
               )
               .fadeOut(delay: 400.ms, duration: 300.ms)
               .moveY(begin: 0, end: -100, delay: 400.ms, duration: 400.ms, curve: Curves.easeOut),
            )),




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
                              shadows: [
                                Shadow(color: Colors.black45, blurRadius: 10)
                              ],
                            ),
                          ),
                          Text(
                            '${_weekdayName(_now.weekday)}, ${_monthName(_now.month)} ${_now.day}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              shadows: [
                                Shadow(color: Colors.black45, blurRadius: 10)
                              ],
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
                              decoration: const BoxDecoration(
                                  color: Colors.black45,
                                  shape: BoxShape.circle),
                              child: Icon(Icons.flashlight_on,
                                  color: _primaryColor, size: 28),
                            ),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: const BoxDecoration(
                                  color: Colors.black45,
                                  shape: BoxShape.circle),
                              child: Icon(Icons.camera_alt,
                                  color: _primaryColor, size: 28),
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
            child: AnimatedOpacity(
              opacity: _isHeroTransitionFinished ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOut,
              child: Column(
                children: [
                  if (!_showPreview) ...[
                    // ── Quality Note ───────────────────────────────────
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(100),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withAlpha(20)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.info_outline_rounded,
                              color: AppColors.goldLight, size: 14),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'This is a preview. High-quality original image is provided when you download or set as wallpaper.',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // ── Action button row ───────────────────────────────
                    RepaintBoundary(
                      child: _buildActionRow(),
                    ),
                  ]
                ],
              ),
            ),
          ),
        ], // closes Stack.children
      ), // closes Stack
    ), // closes RepaintBoundary
    ), // closes Scaffold
    ), // closes GestureDetector
    ); // closes ValueListenableBuilder
  }

  Widget _buildMainImage(BuildContext context) {
    final imageStack = widget.wallpaper.optimizedUrl.isEmpty
        ? _buildBrokenImagePlaceholder('No image URL stored in database')
        : ColorFiltered(
            colorFilter: ColorFilter.matrix(
              ImageFilterUtils.getMatrixForFilter(_currentFilter),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Layer 1: Grid-res (400px) — already cached from grid.
                CachedNetworkImage(
                  imageUrl: widget.wallpaper.mediumUrl.isNotEmpty
                      ? widget.wallpaper.mediumUrl
                      : widget.wallpaper.optimizedUrl,
                  fit: BoxFit.cover,
                  memCacheWidth: 400,
                  memCacheHeight: 800,
                  fadeInDuration: Duration.zero,
                  fadeOutDuration: Duration.zero,
                  placeholder: (_, __) => const SizedBox.shrink(),
                  errorWidget: (_, __, ___) => CachedNetworkImage(
                    imageUrl: widget.wallpaper.thumbnailUrl,
                    fit: BoxFit.cover,
                    memCacheWidth: 400,
                    memCacheHeight: 800,
                  ),
                ),
                // Layer 2: Full-HD (1080px) — loads on top after Hero transition.
                if (_isHeroTransitionFinished)
                  CachedNetworkImage(
                    imageUrl: widget.wallpaper.getAdaptiveOptimizedUrl(AdaptivePerformance.tier),
                    fit: BoxFit.cover,
                    fadeInDuration: const Duration(milliseconds: 250),
                    fadeOutDuration: Duration.zero,
                    memCacheWidth: (MediaQuery.of(context).size.width *
                            MediaQuery.of(context).devicePixelRatio)
                        .round(),
                    placeholder: (_, __) => const SizedBox.shrink(),
                    errorWidget: (context, url, error) => const SizedBox.shrink(),
                  ),
              ],
            ),
          );

    if (!AdaptivePerformance.enableHeroTransitions) {
      return imageStack;
    }

    return Hero(
      tag: 'wallpaper_${widget.wallpaper.id}',
      createRectTween: (begin, end) =>
          LiquidSpringRectTween(begin: begin, end: end),
      child: imageStack,
    );
  }

  Widget _buildBrokenImagePlaceholder(String message) {
    return Container(
      color: AppColors.bg0,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.broken_image_rounded, color: Colors.white24, size: 64),
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

  Widget _buildActionRow() {
    if (!_isUnlocked) {
      return PremiumGlassContainer(
        borderRadius: BorderRadius.circular(24),
        color: AppColors.bg0.withAlpha(100),
        glowColor: AppColors.goldMid,
        glowIntensity: 0.6,
        glowOffset: const Offset(0, -10),
        border: Border.all(color: AppColors.goldMid.withAlpha(180), width: 1.5),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: _isLoadingUnlock
                    ? Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.bg3,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            DiamondLoader(size: 20, color: AppColors.goldMid),
                            const SizedBox(width: 8),
                            const Text('Unlocking…',
                                style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      )
                    : GestureDetector(
                        onTap: _unlockWallpaper,
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
                              const Icon(Icons.lock_open_rounded, color: Colors.black, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Unlock for ${widget.wallpaper.diamondCost} 💎',
                                style: const TextStyle(
                                    color: Colors.black, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () {
                  ref.read(hapticProvider.notifier).lightImpact();
                  context.pushNamed('subscription');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.bg2,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: const Center(
                    child: Text(
                      'Get PRO',
                      style: TextStyle(
                        color: AppColors.goldLight,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return PremiumGlassContainer(
      borderRadius: BorderRadius.circular(24),
      color: AppColors.bg0.withAlpha(100),
      glowColor: _primaryColor,
      glowIntensity: 0.6,
      glowOffset: const Offset(0, -10),
      border: Border.all(color: AppColors.glassBorder.withAlpha(180), width: 1.5),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                  : _buildPillButton(Icons.wallpaper_rounded, 'Set',
                      _showSetWallpaperOptions),
            ),
            const SizedBox(width: 10),
            // Filter icon button
            GestureDetector(
              onTap: () {
                ref.read(hapticProvider.notifier).lightImpact();
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
    );
  }

  /// Elastic spring-back animation when swipe dismiss is rejected.
  void _snapBack() {
    if (!mounted || _isDismissing) return;
    // Animate offset back to 0 with exponential ease
    final startOffset = _dragOffset.value;
    if (startOffset <= 0.5) {
      _dragOffset.value = 0.0;
      return;
    }
    const steps = 12;
    const totalMs = 250;
    for (int i = 1; i <= steps; i++) {
      Future.delayed(Duration(milliseconds: (totalMs * i / steps).toInt()), () {
        if (!mounted) return;
        final t = i / steps;
        // Exponential ease-out
        final ease = 1.0 - (1.0 - t) * (1.0 - t) * (1.0 - t);
        _dragOffset.value = startOffset * (1.0 - ease);
      });
    }
  }

  Widget _buildPillButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        ref.read(hapticProvider.notifier).mediumImpact();
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
    const days = [
      '',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    return days[weekday];
  }

  String _monthName(int month) {
    const months = [
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return months[month];
  }



}


// ─── Helper: section label ────────────────────────────────────────────────────
Widget _sectionLabel(String text) => Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
    );

// ─── Helper: styled text field for the edit dialog ───────────────────────────
class _EditField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;

  const _EditField({
    required this.controller,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        prefixIcon: Icon(icon, color: AppColors.textMuted, size: 18),
        filled: true,
        fillColor: AppColors.bg2,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.glassBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.glassBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.goldMid, width: 1.5),
        ),
      ),
    );
  }
}

// ─── Helper: compact animated switch row for the edit dialog ─────────────────
class _DialogSwitch extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String subtitle;
  final bool value;
  final Color activeColor;
  final ValueChanged<bool> onChanged;

  const _DialogSwitch({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.activeColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: value ? activeColor.withAlpha(18) : AppColors.bg2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value ? activeColor.withAlpha(70) : AppColors.glassBorder,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconColor.withAlpha(28),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                Text(subtitle,
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 10)),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: activeColor,
            onChanged: onChanged,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool isOutlined;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.isOutlined = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isOutlined ? Colors.transparent : color.withAlpha(40),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isOutlined ? color.withAlpha(80) : color.withAlpha(120),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

