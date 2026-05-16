import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Royal Pixels – AdMob Interstitial Ad Service
///
/// Logic:
///   • Every 3 taps on "Set as Wallpaper" OR "Download" (combined) the user
///     sees an interstitial ad AFTER the action completes.
///   • After the ad is shown a 1-minute cooldown begins. During this window
///     clicks are counted but NO ads are shown.
///   • When the cooldown expires the counter resets and the 3-click cycle
///     restarts from zero.
class AdService {
  AdService._();
  static final AdService instance = AdService._();

  // ─── Ad Unit IDs ────────────────────────────────────────────────────────────
  /// Production interstitial unit – ca-app-pub-7067800299420686/5163269329
  /// Test unit used automatically in debug builds.
  static const String _prodInterstitialId =
      'ca-app-pub-7067800299420686/5163269329';
  static const String _testInterstitialId =
      'ca-app-pub-3940256099942544/1033173712';

  static String get _interstitialId =>
      kDebugMode ? _testInterstitialId : _prodInterstitialId;

  // ─── Thresholds ─────────────────────────────────────────────────────────────
  static const int _clicksBeforeAd = 3; // show ad after this many taps
  static const Duration _adCooldown = Duration(minutes: 1);

  // ─── State ──────────────────────────────────────────────────────────────────
  /// When true, ads are never loaded or shown.
  bool isPremium = false;

  int _clickCount = 0;
  DateTime? _lastAdShownAt;
  bool _isInCooldown = false;

  InterstitialAd? _interstitialAd;
  bool _isLoadingAd = false;

  // ─── Initialization ─────────────────────────────────────────────────────────

  /// Must be called once after [MobileAds.instance.initialize()].
  Future<void> initialize() async {
    _loadInterstitialAd();
  }

  void _loadInterstitialAd() {
    if (isPremium) return;
    if (_isLoadingAd) return;
    _isLoadingAd = true;

    InterstitialAd.load(
      adUnitId: _interstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isLoadingAd = false;
          debugPrint('[AdService] Interstitial ad loaded ✓');
        },
        onAdFailedToLoad: (error) {
          _interstitialAd = null;
          _isLoadingAd = false;
          debugPrint('[AdService] Failed to load interstitial: ${error.message}');
          // Retry after a short delay if not premium
          if (!isPremium) {
            Future.delayed(const Duration(seconds: 30), _loadInterstitialAd);
          }
        },
      ),
    );
  }

  // ─── Public API ─────────────────────────────────────────────────────────────

  /// Call this every time the user taps "Set as Wallpaper" or "Download".
  ///
  /// Pass [onAdDismissed] to execute code AFTER the ad closes (or
  /// immediately if no ad is shown).
  ///
  /// Returns true if an ad was triggered.
  bool recordActionAndMaybeShowAd({VoidCallback? onAdDismissed}) {
    if (isPremium) {
      onAdDismissed?.call();
      return false;
    }

    _refreshCooldownState();

    _clickCount++;
    debugPrint(
        '[AdService] Action click #$_clickCount | cooldown: $_isInCooldown');

    if (!_isInCooldown && _clickCount >= _clicksBeforeAd) {
      // ── Time to show an ad ──────────────────────────────────────────────────
      _clickCount = 0;
      _lastAdShownAt = DateTime.now();
      _isInCooldown = true;

      _showInterstitialAd(onAdDismissed: onAdDismissed);
      return true;
    }

    // No ad – fire callback immediately so caller can proceed
    onAdDismissed?.call();
    return false;
  }

  /// Current click count (for debug / UI purposes).
  int get clickCount => _clickCount;

  /// Whether the 1-minute cooldown is still active.
  bool get isInCooldown => _isInCooldown;

  /// Seconds remaining in cooldown (0 when inactive).
  int get cooldownSecondsRemaining {
    if (_lastAdShownAt == null || !_isInCooldown) return 0;
    final elapsed = DateTime.now().difference(_lastAdShownAt!);
    final remaining = _adCooldown - elapsed;
    return remaining.isNegative ? 0 : remaining.inSeconds;
  }

  /// Syncs the service with the current user.
  void updateUserId(String? uid) {
    // Reset counters when user switches accounts
    _clickCount = 0;
    _isInCooldown = false;
    _lastAdShownAt = null;
    debugPrint('[AdService] Account switched - counter reset');
  }

  // ─── Private helpers ────────────────────────────────────────────────────────

  /// Checks if the cooldown has expired and resets state accordingly.
  void _refreshCooldownState() {
    if (!_isInCooldown || _lastAdShownAt == null) return;
    final elapsed = DateTime.now().difference(_lastAdShownAt!);
    if (elapsed >= _adCooldown) {
      _isInCooldown = false;
      _clickCount = 0; // fresh cycle after cooldown
      debugPrint('[AdService] Cooldown expired – counter reset');
    }
  }

  void _showInterstitialAd({VoidCallback? onAdDismissed}) {
    if (isPremium) {
      onAdDismissed?.call();
      return;
    }

    final ad = _interstitialAd;
    if (ad == null) {
      debugPrint('[AdService] No ad ready – skipping');
      onAdDismissed?.call();
      // Preload next ad
      _loadInterstitialAd();
      return;
    }

    _interstitialAd = null; // prevent double-show

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) {
        debugPrint('[AdService] Ad shown ✓');
      },
      onAdDismissedFullScreenContent: (dismissedAd) {
        debugPrint('[AdService] Ad dismissed');
        dismissedAd.dispose();
        onAdDismissed?.call();
        // Pre-load the next ad
        _loadInterstitialAd();
      },
      onAdFailedToShowFullScreenContent: (failedAd, error) {
        debugPrint('[AdService] Ad failed to show: ${error.message}');
        failedAd.dispose();
        onAdDismissed?.call();
        _loadInterstitialAd();
      },
    );

    ad.show();
  }
}
