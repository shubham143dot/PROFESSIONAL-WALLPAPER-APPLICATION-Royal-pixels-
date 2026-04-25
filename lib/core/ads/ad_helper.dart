import 'package:flutter/foundation.dart';

class AdHelper {
  /// Increments the click counter for wallpaper actions (download/set).
  static Future<int> incrementWallpaperActionClick() async {
    return 0; // Stub
  }

  /// Checks if an interstitial ad should be shown based on random threshold and 2-minute gap.
  /// Always returns false for Pro members.
  static Future<bool> shouldShowWallpaperActionAd({bool isPro = false}) async {
    return false; // Stub - never show ads
  }

  /// Updates the last shown timestamp for interstitial ads and resets counter with new random threshold.
  static Future<void> recordInterstitialAdShow() async {
    // Stub
  }

  /// Returns the number of seconds remaining for the rewarded ad cooldown (60 sec).
  static Future<int> getRemainingRewardedCooldownSeconds() async {
    return 0; // Stub
  }

  /// Updates the last shown timestamp for rewarded ads.
  static Future<void> recordRewardedAdShow() async {
    // Stub
  }

  static String get rewardedAdUnitId {
    return ''; // Stub
  }

  static String get interstitialAdUnitId {
    return ''; // Stub
  }

  /// Shows a rewarded ad.
  /// [onCompleted] is called with true if the user earned the reward, false otherwise.
  static void showRewardedAd({
    required Function(bool rewardEarned) onCompleted,
  }) {
    // Stub: Instead of showing an ad, immediately return false to not give rewards for non-existent ads.
    // However, if the user requested to keep getting rewards, we can pass true/false depending on usage.
    // For diamond store Watch & Earn, it will fail silently (no reward), which is correct for removing ads.
    onCompleted(false);
  }

  /// Shows an interstitial ad.
  static void showInterstitialAd({VoidCallback? onDismissed}) {
    if (onDismissed != null) onDismissed(); // Stub
  }

  /// Specific helper for wallpaper actions. 
  /// Although the user sees an "interstitial" like experience, 
  /// we use RewardedAd internally to detect if they skipped (to fulfill the "no skip, no diamond" rule).
  static void showWallpaperActionAd({required Function(bool rewardEarned) onCompleted}) {
    // Stub: Never show ad. But if it accidentally reaches here, just proceed immediately and don't give "ad" reward
    // The main reward is still given in wallpaper_detail_page.dart because shouldShowWallpaperActionAd is false.
    onCompleted(false);
  }
}
