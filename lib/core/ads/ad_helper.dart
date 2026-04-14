import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdHelper {
  // Test Rewarded Ad Unit ID from Android
  static const String rewardedAdUnitId = 'ca-app-pub-3940256099942544/5224354917';

  static void showRewardedAd({required VoidCallback onCompleted}) {
    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              onCompleted();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              onCompleted();
            },
          );
          ad.show(onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
            // Reward earned
          });
        },
        onAdFailedToLoad: (err) {
          debugPrint('Failed to load a rewarded ad: ${err.message}');
          onCompleted();
        },
      ),
    );
  }
}
