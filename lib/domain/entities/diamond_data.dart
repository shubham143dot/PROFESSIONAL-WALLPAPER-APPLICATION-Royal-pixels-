/// Represents the complete diamond wallet state of a user.
class DiamondData {
  final int diamonds;
  final int streak; // 1–7
  final int smallRewardEarnedToday; // combined download+set-as cap: max 80
  final bool canClaimToday;
  final String lastRewardDate; // "YYYY-MM-DD"
  final String lastSmallRewardDate; // date when smallRewardEarnedToday was set

  const DiamondData({
    required this.diamonds,
    required this.streak,
    this.smallRewardEarnedToday = 0,
    required this.canClaimToday,
    required this.lastRewardDate,
    this.lastSmallRewardDate = '',
  });

  static const int dailySmallRewardCap = 80; // combined cap for download+set-as
  static const int smallRewardAmount = 5;

  bool get canEarnSmall => smallRewardEarnedToday < dailySmallRewardCap;

  int get remainingSmallReward => dailySmallRewardCap - smallRewardEarnedToday;

  DiamondData copyWith({
    int? diamonds,
    int? streak,
    int? smallRewardEarnedToday,
    bool? canClaimToday,
    String? lastRewardDate,
    String? lastSmallRewardDate,
  }) {
    return DiamondData(
      diamonds: diamonds ?? this.diamonds,
      streak: streak ?? this.streak,
      smallRewardEarnedToday:
          smallRewardEarnedToday ?? this.smallRewardEarnedToday,
      canClaimToday: canClaimToday ?? this.canClaimToday,
      lastRewardDate: lastRewardDate ?? this.lastRewardDate,
      lastSmallRewardDate: lastSmallRewardDate ?? this.lastSmallRewardDate,
    );
  }
}

/// Result returned when a daily reward is claimed.
class DailyRewardResult {
  final int day; // 1–7
  final int diamonds; // diamonds awarded this claim
  final bool isBonus; // true on day 7

  const DailyRewardResult({
    required this.day,
    required this.diamonds,
    this.isBonus = false,
  });

  /// Diamond rewards per day (Day 1–7).
  static const List<int> rewardTable = [10, 15, 20, 25, 30, 40, 50];

  static int rewardForDay(int day) {
    final idx = (day - 1).clamp(0, 6);
    return rewardTable[idx];
  }
}

/// Reason a small reward was denied.
enum SmallRewardDenyReason { dailyCapReached, wallpaperAlreadyRewarded }

/// Result of attempting a small reward (download / set-as).
class SmallRewardResult {
  final bool granted;
  final int newBalance;
  final SmallRewardDenyReason? denyReason;

  const SmallRewardResult.granted(this.newBalance)
      : granted = true,
        denyReason = null;

  const SmallRewardResult.denied(this.denyReason)
      : granted = false,
        newBalance = 0;
}
