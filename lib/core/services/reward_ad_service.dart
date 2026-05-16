import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../di/service_locator.dart';
import '../../data/datasources/firestore_data_source.dart';

/// Royal Pixels – AdMob Rewarded Ad Service (Watch & Earn)
///
/// Logic:
///   • Each rewarded ad gives 20 diamonds.
///   • Max 5 ads per DAY = 100 diamonds/day (resets at midnight).
///   • After each ad there is a 15-second cooldown before the next can be watched.
///   • DATA IS PERSISTED PER-USER IN FIRESTORE (no device cap).
class RewardAdService {
  RewardAdService._();
  static final RewardAdService instance = RewardAdService._();

  // ─── Ad Unit IDs ─────────────────────────────────────────────────────────
  static const String _prodRewardedId =
      'ca-app-pub-7067800299420686/1740248221';
  static const String _testRewardedId =
      'ca-app-pub-3940256099942544/5224354917';

  static String get _rewardedId =>
      kDebugMode ? _testRewardedId : _prodRewardedId;

  // ─── Constants ────────────────────────────────────────────────────────────
  static const int diamondsPerAd = 20;
  static const int maxAdsPerDay = 5;
  static const int maxDiamondsPerDay = 100; // 5 × 20
  static const Duration cooldownDuration = Duration(seconds: 15);

  // ─── State ────────────────────────────────────────────────────────────────
  /// When true, ads are never loaded or shown.
  bool isPremium = false;

  String? _userId;
  int _adsWatchedToday = 0;
  bool _isCooldownActive = false;

  RewardedAd? _rewardedAd;
  bool _isLoadingAd = false;
  bool _adLoaded = false;

  Timer? _cooldownTimer;
  int _cooldownSecondsRemaining = 0;

  bool _initialized = false;

  // ─── Listeners ────────────────────────────────────────────────────────────
  final List<VoidCallback> _listeners = [];
  void addListener(VoidCallback l) => _listeners.add(l);
  void removeListener(VoidCallback l) => _listeners.remove(l);
  void _notify() {
    for (final l in _listeners) {
      l();
    }
  }

  // ─── Initialization ───────────────────────────────────────────────────────
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    // Initial load happens when user ID is updated
    _loadRewardedAd();
  }

  /// Syncs the service with the current user. Called from AuthProvider.
  Future<void> updateUserId(String? uid) async {
    if (_userId == uid) return;
    _userId = uid;
    
    if (_userId != null) {
      await _loadDailyCountFromFirestore();
    } else {
      _adsWatchedToday = 0;
      _notify();
    }
    
    // Refresh ad loading status
    if (_adLoaded && _adsWatchedToday >= maxAdsPerDay) {
       _rewardedAd?.dispose();
       _rewardedAd = null;
       _adLoaded = false;
    }
    _loadRewardedAd();
  }

  /// Reads daily count from Firestore.
  Future<void> _loadDailyCountFromFirestore() async {
    if (_userId == null) return;
    try {
      final ds = sl<FirestoreDataSource>();
      final data = await ds.getDiamondData(_userId!);
      _adsWatchedToday = data['adsWatchedToday'] as int? ?? 0;
      _notify();
    } catch (e) {
      debugPrint('[RewardAdService] Failed to load daily count: $e');
    }
  }

  Future<void> _incrementDailyCountInFirestore() async {
    if (_userId == null) return;
    try {
      final ds = sl<FirestoreDataSource>();
      _adsWatchedToday = await ds.incrementAdsWatchedToday(_userId!);
      _notify();
    } catch (e) {
      debugPrint('[RewardAdService] Failed to increment daily count: $e');
    }
  }

  // ─── Ad Loading ───────────────────────────────────────────────────────────
  void _loadRewardedAd() {
    if (isPremium) return;
    if (_isLoadingAd || _adLoaded) return;
    if (_adsWatchedToday >= maxAdsPerDay) return;

    _isLoadingAd = true;

    RewardedAd.load(
      adUnitId: _rewardedId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isLoadingAd = false;
          _adLoaded = true;
          debugPrint('[RewardAdService] Rewarded ad loaded ✓');
          _notify();
        },
        onAdFailedToLoad: (error) {
          _rewardedAd = null;
          _isLoadingAd = false;
          _adLoaded = false;
          debugPrint('[RewardAdService] Failed to load: ${error.message}');
          if (!isPremium) {
            Future.delayed(const Duration(seconds: 30), _loadRewardedAd);
          }
          _notify();
        },
      ),
    );
  }

  // ─── Public API ───────────────────────────────────────────────────────────

  /// Whether the user can watch another ad right now.
  bool get canWatchAd {
    if (isPremium) return false;
    return !_isCooldownActive &&
        _adsWatchedToday < maxAdsPerDay &&
        _adLoaded;
  }

  /// Whether the daily cap (100 diamonds) has been reached.
  bool get isDailyCapReached => _adsWatchedToday >= maxAdsPerDay;

  /// Diamonds earned today from ads (0–100).
  int get diamondsEarnedToday => _adsWatchedToday * diamondsPerAd;

  /// Number of ads watched today (0–5).
  int get adsWatchedToday => _adsWatchedToday;

  /// Ads remaining today.
  int get adsRemainingToday => (maxAdsPerDay - _adsWatchedToday).clamp(0, maxAdsPerDay);

  bool get isAdReady => _adLoaded;

  bool get isCooldownActive => _isCooldownActive;

  int get cooldownSecondsRemaining => _cooldownSecondsRemaining;

  /// Show a rewarded ad. [onRewarded] fires with diamonds earned on completion.
  void showRewardedAd({
    required void Function(int diamonds) onRewarded,
    VoidCallback? onFailed,
  }) {
    if (!canWatchAd) {
      onFailed?.call();
      return;
    }

    final ad = _rewardedAd;
    if (ad == null) {
      debugPrint('[RewardAdService] No ad ready');
      onFailed?.call();
      return;
    }

    _rewardedAd = null;
    _adLoaded = false;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) {
        debugPrint('[RewardAdService] Ad shown ✓');
      },
      onAdDismissedFullScreenContent: (dismissedAd) {
        debugPrint('[RewardAdService] Ad dismissed (no reward)');
        dismissedAd.dispose();
        if (_adsWatchedToday < maxAdsPerDay) _loadRewardedAd();
      },
      onAdFailedToShowFullScreenContent: (failedAd, error) {
        debugPrint('[RewardAdService] Failed to show: ${error.message}');
        failedAd.dispose();
        onFailed?.call();
        _loadRewardedAd();
        _notify();
      },
    );

    ad.show(
      onUserEarnedReward: (_, reward) {
        debugPrint('[RewardAdService] Reward earned → $diamondsPerAd 💎');
        _incrementDailyCountInFirestore();
        _startCooldown();

        onRewarded(diamondsPerAd);

        if (_adsWatchedToday < maxAdsPerDay) _loadRewardedAd();
        _notify();
      },
    );
  }

  // ─── Cooldown ─────────────────────────────────────────────────────────────
  void _startCooldown() {
    _cooldownTimer?.cancel();
    _isCooldownActive = true;
    _cooldownSecondsRemaining = cooldownDuration.inSeconds;
    _notify();

    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _cooldownSecondsRemaining--;
      if (_cooldownSecondsRemaining <= 0) {
        _isCooldownActive = false;
        _cooldownSecondsRemaining = 0;
        timer.cancel();
      }
      _notify();
    });
  }

  void dispose() {
    _cooldownTimer?.cancel();
    _rewardedAd?.dispose();
    _listeners.clear();
  }
}
