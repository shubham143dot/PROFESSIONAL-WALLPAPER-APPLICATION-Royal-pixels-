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
import 'package:cached_network_image/cached_network_image.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../../providers/parallax_provider.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_colors.dart';
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

import '../../widgets/diamond_loader.dart';
import '../../../core/utils/image_filter_utils.dart';
import '../../providers/favorites_provider.dart';
import '../../../core/ads/ad_helper.dart';
import '../../providers/haptic_provider.dart';
import '../../providers/download_provider.dart';

import '../../../core/widgets/login_required_sheet.dart';
import '../../../core/utils/safe_tap.dart';

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

  final ValueNotifier<Offset> _tiltOffset = ValueNotifier(Offset.zero);
  StreamSubscription? _accelSub;

  @override
  void initState() {
    super.initState();
    
    // 1. Initial status check for parallax
    _initParallax();
    
    // Delay expensive render effects (like blur) until Hero transition completes
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _isHeroTransitionFinished = true);
    });
    // Real-time clock
    _clockTimer = Stream.periodic(const Duration(seconds: 1)).listen((_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    // For premium wallpapers, check if already unlocked
    if (widget.wallpaper.isPremium) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkIfAlreadyUnlocked();
      });
    }
    _extractColor();
  }

  Future<void> _initParallax() async {
    // 1. Check if hardware supports it
    final isSupported = await ref.read(parallaxSupportProvider.future);
    if (!isSupported) {
      if (kDebugMode) print('Parallax: Hardware not supported on this device.');
      return;
    }

    // 2. Check if user enabled it in settings
    final isEnabled = ref.read(parallaxProvider);
    if (!isEnabled) return;

    // 3. Start listening to sensors
    // We prioritize Accelerometer for absolute tilt as it's more stable for parallax
    try {
      _accelSub = accelerometerEventStream().listen(
        (event) {
          if (!mounted) return;
          // Normalize g-force to -1.0 to 1.0 range
          // x is horizontal tilt, y is vertical tilt
          final tx = (event.x / 9.8).clamp(-1.0, 1.0);
          final ty = (event.y / 9.8).clamp(-1.0, 1.0);
          _tiltOffset.value = Offset(tx, ty);
        },
        onError: (e) {
          if (kDebugMode) print('Parallax: Accelerometer Stream Error: $e');
        },
        cancelOnError: true,
      );
    } catch (e) {
      if (kDebugMode) print('Parallax: Failed to initialize sensors: $e');
    }
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    _accelSub?.cancel();
    _tiltOffset.dispose();
    super.dispose();
  }

  Future<void> _extractColor() async {
    try {
      final imageProvider = ResizeImage(
        CachedNetworkImageProvider(widget.wallpaper.optimizedUrl),
        width: 64, // Dramatically reduces extraction time and memory
      );
      final palette = await PaletteGeneratorMaster.fromImageProvider(
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

  Color get _primaryColor => _vibrantColor ?? _dominantColor ?? Colors.amber;

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
    // ── Local state for the dialog (StatefulBuilder) ──
    final titleController = TextEditingController(text: widget.wallpaper.title);
    final categoryController = TextEditingController(text: widget.wallpaper.category);
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
          backgroundColor: AppColors.bg1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
                  subtitle: 'Requires PRO subscription or 💎 to unlock',
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
                                  borderSide: const BorderSide(
                                      color: Colors.amber)),
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
                  onChanged: (v) =>
                      setDialogState(() => dialogIsEditorsChoice = v),
                ),

                const SizedBox(height: 24),

                // Actions
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textMuted,
                          side: const BorderSide(color: AppColors.glassBorder),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        child: const Text('Cancel'),
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
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Save',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
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
          .where((t) =>
              t != 'ultra_hd' &&
              t != 'editors_choice')
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
      final isFree = !widget.wallpaper.isPremium;
      final user = ref.read(authProvider).user;
      
      if (isFree) {
        final isPro = user?.isSubscribed ?? false;
        
        // 1. Increment click counter (only for free users)
        if (!isPro) {
          await AdHelper.incrementWallpaperActionClick();
        }
        
        // 2. Check if we should show an ad (Random clicks + 2 min gap)
        // Pass isPro to ensure ads are never shown for premium users
        final shouldShowAd = await AdHelper.shouldShowWallpaperActionAd(isPro: isPro);
        
        if (shouldShowAd) {
          if (mounted) {
            RoyalSnackBar.show(context, 'Loading Ad...', type: SnackBarType.info);
          }
          
          AdHelper.showWallpaperActionAd(onCompleted: (earnedReward) async {
            // Perform download regardless of ad skip
            await _performDownload();
            
            if (user != null) {
              if (earnedReward) {
                // Only grant diamond if ad was NOT skipped
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
              } else {
                if (mounted) {
                  RoyalSnackBar.show(context, 'Ad skipped – No diamonds earned. 💎 0', type: SnackBarType.info);
                }
              }
            }
          });
        } else {
          // No ad shown (either not enough clicks, on cooldown, or user is PRO)
          await _performDownload();
          if (user != null) {
            // Pro members and users who didn't get an ad still get the reward
            await ref
                .read(diamondProvider.notifier)
                .addSmallReward(user.uid, widget.wallpaper.id);
          }
        }
      } else {
        // Premium wallpaper (no ad required, cost already paid or sub active)
        await _performDownload();
        if (user != null) {
          await ref
              .read(diamondProvider.notifier)
              .addSmallReward(user.uid, widget.wallpaper.id);
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
      await ref.read(downloadProvider.notifier).addDownload(widget.wallpaper.id);

      if (mounted) {
        RoyalSnackBar.show(context, 'Saved to Gallery! 💎 +5');
        ref.read(notificationProvider.notifier).addNotification(
          title: 'Download Successful',
          message: '"${widget.wallpaper.title}" has been saved to your gallery.',
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

  Future<void> _setWallpaper([int choice = WallpaperManagerPlus.bothScreens]) async {
    SafeTap.run('wp_set', () async {
      if (!mounted) return;

    final isFree = !widget.wallpaper.isPremium;
    final user = ref.read(authProvider).user;
    if (isFree) {
      final isPro = user?.isSubscribed ?? false;

      // 1. Increment click counter (only for free users)
      if (!isPro) {
        await AdHelper.incrementWallpaperActionClick();
      }
      
      // 2. Check if we should show an ad (Random clicks + 2 min gap)
      final shouldShowAd = await AdHelper.shouldShowWallpaperActionAd(isPro: isPro);
      
      if (shouldShowAd) {
        if (mounted) {
          RoyalSnackBar.show(context, 'Loading Ad...', type: SnackBarType.info);
        }
        AdHelper.showWallpaperActionAd(onCompleted: (earnedReward) async {
          await _performSetWallpaper(choice);
          
          if (user != null) {
            if (earnedReward) {
              // Only grant diamond if ad was NOT skipped
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
            } else {
              if (mounted) {
                RoyalSnackBar.show(context, 'Ad skipped – No diamonds earned. 💎 0', type: SnackBarType.info);
              }
            }
          }
        });
      } else {
        // No ad shown (either not enough clicks, on cooldown, or user is PRO)
        await _performSetWallpaper(choice);
        if (user != null) {
          await ref
              .read(diamondProvider.notifier)
              .addSmallReward(user.uid, widget.wallpaper.id);
        }
      }
    } else {
      await _performSetWallpaper(choice);
      // +5 diamonds per unique wallpaper/day, 80 combined cap
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
    }
    });
  }

  Future<void> _performSetWallpaper(int choice) async {
    setState(() => _isSetting = true);
    try {
      if (mounted) {
        RoyalSnackBar.show(context, 'Setting wallpaper…', type: SnackBarType.info);
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
      final tempFile = File('${tempDir.path}/rp_wallpaper_${widget.wallpaper.id}.jpg');
      await tempFile.writeAsBytes(processedBytes);
      
      if (!mounted) return;
      // Instant Apply: bypass crop and let the OS handle center-cropping
      await WallpaperManagerPlus().setWallpaper(tempFile, choice);

      if (mounted) {
        RoyalSnackBar.show(context, 'Wallpaper set successfully!');
        ref.read(notificationProvider.notifier).addNotification(
          title: 'Wallpaper Applied',
          message: '"${widget.wallpaper.title}" is now your active wallpaper.',
          type: NotificationType.update, // Categorized as update
        );
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

  void _showSetWallpaperOptions() {
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
                  const Text('Set Wallpaper', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _dialogOption(ctx, Icons.home, 'Home Screen', WallpaperManagerPlus.homeScreen),
                  const SizedBox(height: 8),
                  _dialogOption(ctx, Icons.lock, 'Lock Screen', WallpaperManagerPlus.lockScreen),
                  const SizedBox(height: 8),
                  _dialogOption(ctx, Icons.phone_android, 'Both Screens', WallpaperManagerPlus.bothScreens),
                  const SizedBox(height: 20),
                ],
              ),
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
    final isPremiumAndLocked = widget.wallpaper.isPremium && !isPremiumUnlocked && !_isUnlocked;
    
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
            ref.read(hapticProvider.notifier).selectionClick();
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
          IconButton(
              icon: const Icon(Icons.auto_fix_high, color: Colors.white),
              onPressed: _showFilterBottomSheet,
            ),
            IconButton(
              icon: Icon(_showPreview ? Icons.visibility_off : Icons.visibility, color: Colors.white),
              onPressed: () {
                ref.read(hapticProvider.notifier).lightImpact();
                setState(() => _showPreview = !_showPreview);
              },
            ),
            IconButton(
              icon: Icon(
                isFavorite ? Icons.favorite : Icons.favorite_border,
                color: isFavorite ? Colors.redAccent : Colors.white,
              ),
              onPressed: () {
                ref.read(hapticProvider.notifier).lightImpact();
                final isGuest = ref.read(authProvider).isGuest;
                if (isGuest) {
                  showLoginRequiredSheet(context,
                      reason: LoginRequiredReason.favorites);
                  return;
                }
                ref
                    .read(favoritesProvider.notifier)
                    .toggleFavorite(widget.wallpaper.id);
                if (!isFavorite) {
                  RoyalSnackBar.show(context, 'Added to favorites!',
                      type: SnackBarType.info);
                }
              },
            ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onDoubleTap: () {
              ref.read(hapticProvider.notifier).lightImpact();
              final isGuest = ref.read(authProvider).isGuest;
              if (isGuest) {
                showLoginRequiredSheet(context,
                    reason: LoginRequiredReason.favorites);
                return;
              }
              final isFavorite = ref.read(favoritesProvider).contains(widget.wallpaper.id);
              ref.read(favoritesProvider.notifier).toggleFavorite(widget.wallpaper.id);
              if (!isFavorite) {
                RoyalSnackBar.show(context, 'Added to favorites!', type: SnackBarType.info);
              }
            },
            onLongPress: () {
              ref.read(hapticProvider.notifier).mediumImpact();
              _showSetWallpaperOptions();
            },
            child: Hero(
              tag: 'wallpaper_${widget.wallpaper.id}',
              child: ValueListenableBuilder<Offset>(
                valueListenable: _tiltOffset,
                builder: (context, tilt, child) {
                  final isParallaxEnabled = ref.watch(parallaxProvider);
                  final activeTilt = isParallaxEnabled ? tilt : Offset.zero;
                  return AnimatedScale(
                    scale: isParallaxEnabled ? 1.20 : 1.0,
                    duration: const Duration(milliseconds: 250),
                    child: AnimatedSlide(
                      offset: Offset(-activeTilt.dx * 0.09, activeTilt.dy * 0.09),
                      duration: const Duration(milliseconds: 150),
                      child: child!,
                    ),
                  );
                },
                child: widget.wallpaper.optimizedUrl.isEmpty
                    ? _buildBrokenImagePlaceholder('No image URL stored in database')
                    : ColorFiltered(
                    colorFilter: ColorFilter.matrix(
                      ImageFilterUtils.getMatrixForFilter(_currentFilter),
                    ),
                    child: CachedNetworkImage(
                      imageUrl: widget.wallpaper.optimizedUrl,
                      // Stable cache key — shared with grid card so the Hero transition
                      // reuses already-cached bytes and never shows a blank frame.
                      cacheKey: widget.wallpaper.cacheKey,
                      fit: BoxFit.cover,
                      memCacheHeight: 1600, // Limits maximum RAM allocation for 4k wallpapers
                      fadeInDuration: const Duration(milliseconds: 400),
                      fadeOutDuration: const Duration(milliseconds: 200),
                      placeholder: (context, url) => Container(
                        color: _dominantColor?.withAlpha(80) ?? Colors.grey[900],
                        child: Center(
                          child: DiamondLoader(size: 30, color: _primaryColor,),
                        ),
                      ),
                      errorWidget: (context, url, error) {
                        if (kDebugMode) {
                          debugPrint('Image load error for url: $url\nError: $error');
                        }
                        return _buildBrokenImagePlaceholder(
                          'Could not load image.\nCheck your internet connection\nor re-seed the wallpaper URL in Firestore.',
                        );
                      },
                    ),
                  ),
              ),
            ),
          ),
          
          // Blur if premium and not yet unlocked
          if (isPremiumAndLocked && _isHeroTransitionFinished)
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
                if (_isCheckingUnlock) ...[
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
                            

                            // 💎 Diamond unlock button (dynamic cost)
                            Builder(builder: (context) {
                              final cost = widget.wallpaper.diamondCost > 0
                                  ? widget.wallpaper.diamondCost
                                  : 100;
                              final diamonds = ref.watch(diamondProvider).diamonds;
                              final canAfford = diamonds >= cost;
                              return GestureDetector(
                                onTap: () async {
                                  final authState = ref.read(authProvider);
                                  if (authState.isGuest) {
                                    showLoginRequiredSheet(context,
                                        reason: LoginRequiredReason.diamonds);
                                    return;
                                  }

                                  if (canAfford) {
                                    final user = authState.user;
                                    if (user == null) return;
                                    final messenger =
                                        ScaffoldMessenger.of(context);
                                    final success = await ref
                                        .read(diamondProvider.notifier)
                                        .spendDiamonds(user.uid,
                                            widget.wallpaper.id, cost);
                                    if (success && mounted) {
                                      setState(() => _isUnlocked = true);
                                      RoyalSnackBar.showOnMessenger(messenger,
                                          '💎 Wallpaper unlocked!');
                                    }
                                  } else {
                                    RoyalSnackBar.show(
                                      context,
                                      'Need $cost 💎 — you have $diamonds',
                                      type: SnackBarType.info,
                                    );
                                  }
                                },
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 13),
                                  decoration: BoxDecoration(
                                    color: canAfford
                                        ? AppColors.goldMid.withAlpha(30)
                                        : AppColors.bg2,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: canAfford
                                          ? AppColors.goldMid.withAlpha(120)
                                          : AppColors.glassBorder,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Text('💎', style: TextStyle(fontSize: 18)),
                                      const SizedBox(width: 8),
                                      Text(
                                        canAfford
                                            ? 'Unlock with $cost Diamonds'
                                            : 'Need $cost 💎 (you have $diamonds)',
                                        style: TextStyle(
                                          color: canAfford
                                              ? AppColors.goldLight
                                              : AppColors.textMuted,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
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
                        Icons.wallpaper_rounded, 'Set', _showSetWallpaperOptions),
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
      ),
    );
  }

  Widget _buildPillButton(
      IconData icon, String label, VoidCallback onTap) {
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
    const days = ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[weekday];
  }

  String _monthName(int month) {
    const months = ['', 'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'];
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 10)),
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
