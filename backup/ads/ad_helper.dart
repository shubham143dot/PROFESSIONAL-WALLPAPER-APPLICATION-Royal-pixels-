import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdHelper {
  static const String _keyClickCount = 'wallpaper_action_click_count';
  static const String _keyLastAdTime = 'last_wallpaper_interstitial_time';
  static const String _keyNextAdThreshold = 'next_wallpaper_ad_threshold';
  static const String _keyLastRewardedTime = 'last_rewarded_ad_time';

  /// Increments the click counter for wallpaper actions (download/set).
  static Future<int> incrementWallpaperActionClick() async {
    final prefs = await SharedPreferences.getInstance();
    int current = prefs.getInt(_keyClickCount) ?? 0;
    current++;
    await prefs.setInt(_keyClickCount, current);
    return current;
  }

  /// Checks if an interstitial ad should be shown based on random threshold and 2-minute gap.
  /// Always returns false for Pro members.
  static Future<bool> shouldShowWallpaperActionAd({bool isPro = false}) async {
    if (isPro) return false;

    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getInt(_keyClickCount) ?? 0;
    final threshold =
        prefs.getInt(_keyNextAdThreshold) ?? 4; // Default to 4 on first run

    // Rule 1: Show after reaching random threshold
    if (count < threshold) return false;

    // Rule 2: 2-minute gap between ads
    final lastTimeMillis = prefs.getInt(_keyLastAdTime) ?? 0;
    final lastTime = DateTime.fromMillisecondsSinceEpoch(lastTimeMillis);
    final diff = DateTime.now().difference(lastTime);

    return diff.inMinutes >= 2;
  }

  /// Updates the last shown timestamp for interstitial ads and resets counter with new random threshold.
  static Future<void> recordInterstitialAdShow() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    await prefs.setInt(_keyLastAdTime, now.millisecondsSinceEpoch);
    await prefs.setInt(_keyClickCount, 0); // Reset click counter

    // Set next random threshold (between 3 and 15)
    final randomThreshold = 3 + Random().nextInt(13); // 3 to 15
    await prefs.setInt(_keyNextAdThreshold, randomThreshold);
  }

  /// Returns the number of seconds remaining for the rewarded ad cooldown (60 sec).
  static Future<int> getRemainingRewardedCooldownSeconds() async {
    final prefs = await SharedPreferences.getInstance();
    final lastTimeMillis = prefs.getInt(_keyLastRewardedTime) ?? 0;
    if (lastTimeMillis == 0) return 0;

    final lastTime = DateTime.fromMillisecondsSinceEpoch(lastTimeMillis);
    final diff = DateTime.now().difference(lastTime);
    final remaining = 60 - diff.inSeconds;

    return remaining > 0 ? remaining : 0;
  }

  /// Updates the last shown timestamp for rewarded ads.
  static Future<void> recordRewardedAdShow() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
        _keyLastRewardedTime, DateTime.now().millisecondsSinceEpoch);
  }

  static String get rewardedAdUnitId {
    if (kReleaseMode) {
      final id = defaultTargetPlatform == TargetPlatform.android
          ? 'ca-app-pub-################/##########' // REPLACE WITH REAL ANDROID REWARDED ID
          : 'ca-app-pub-################/##########'; // REPLACE WITH REAL IOS REWARDED ID

      if (id.contains('########')) {
        debugPrint(
            '⚠️ WARNING: AdMob Rewarded ID is still a placeholder in Release Mode!');
      }
      return id;
    }
    // Test IDs
    return defaultTargetPlatform == TargetPlatform.iOS
        ? 'ca-app-pub-3940256099942544/1712485313'
        : 'ca-app-pub-3940256099942544/5224354917';
  }

  static String get interstitialAdUnitId {
    if (kReleaseMode) {
      final id = defaultTargetPlatform == TargetPlatform.android
          ? 'ca-app-pub-################/##########' // REPLACE WITH REAL ANDROID INTERSTITIAL ID
          : 'ca-app-pub-################/##########'; // REPLACE WITH REAL IOS INTERSTITIAL ID

      if (id.contains('########')) {
        debugPrint(
            '⚠️ WARNING: AdMob Interstitial ID is still a placeholder in Release Mode!');
      }
      return id;
    }
    // Test IDs
    return defaultTargetPlatform == TargetPlatform.iOS
        ? 'ca-app-pub-3940256099942544/4411468910'
        : 'ca-app-pub-3940256099942544/1033173712';
  }

  /// Shows a rewarded ad.
  /// [onCompleted] is called with true if the user earned the reward, false otherwise.
  static void showRewardedAd({
    required Function(bool rewardEarned) onCompleted,
  }) {
    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          bool isRewarded = false;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              onCompleted(isRewarded);
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              onCompleted(false);
            },
          );
          ad.show(onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
            isRewarded = true;
          });
        },
        onAdFailedToLoad: (err) {
          debugPrint('Failed to load a rewarded ad: ${err.message}');
          onCompleted(false);
        },
      ),
    );
  }

  /// Shows an interstitial ad.
  static void showInterstitialAd({VoidCallback? onDismissed}) {
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              recordInterstitialAdShow();
              if (onDismissed != null) onDismissed();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              if (onDismissed != null) onDismissed();
            },
          );
          ad.show();
        },
        onAdFailedToLoad: (err) {
          debugPrint('Failed to load an interstitial ad: ${err.message}');
          if (onDismissed != null) onDismissed();
        },
      ),
    );
  }

  /// Specific helper for wallpaper actions.
  /// Although the user sees an "interstitial" like experience,
  /// we use RewardedAd internally to detect if they skipped (to fulfill the "no skip, no diamond" rule).
  static void showWallpaperActionAd(
      {required Function(bool rewardEarned) onCompleted}) {
    showRewardedAd(onCompleted: (earned) {
      if (earned) {
        recordInterstitialAdShow();
      }
      onCompleted(earned);
    });
  }
}
