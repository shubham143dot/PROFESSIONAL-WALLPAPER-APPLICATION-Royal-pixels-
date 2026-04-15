import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/service_locator.dart';
import '../../domain/entities/diamond_data.dart';
import '../../domain/repositories/diamond_repository.dart';

// ── Diamond state ──────────────────────────────────────────────────────────────
class DiamondState {
  final int diamonds;
  final int streak;
  final int adsWatchedToday;
  final int smallRewardEarnedToday; // combined download+set-as, daily cap: 80
  final bool canClaimToday;
  final bool isLoading;
  final String? error;
  final DailyRewardResult? pendingReward; // non-null when popup should show

  const DiamondState({
    this.diamonds = 0,
    this.streak = 0,
    this.adsWatchedToday = 0,
    this.smallRewardEarnedToday = 0,
    this.canClaimToday = false,
    this.isLoading = false,
    this.error,
    this.pendingReward,
  });

  static const int dailyAdLimit        = 5;
  static const int dailySmallRewardCap = 80;

  bool get canWatchAd   => adsWatchedToday       < dailyAdLimit;
  bool get canEarnSmall => smallRewardEarnedToday < dailySmallRewardCap;

  int get remainingAdsToday    => dailyAdLimit        - adsWatchedToday;
  int get remainingSmallReward => dailySmallRewardCap - smallRewardEarnedToday;

  DiamondState copyWith({
    int? diamonds,
    int? streak,
    int? adsWatchedToday,
    int? smallRewardEarnedToday,
    bool? canClaimToday,
    bool? isLoading,
    String? error,
    DailyRewardResult? pendingReward,
    bool clearReward = false,
    bool clearError = false,
  }) {
    return DiamondState(
      diamonds:               diamonds               ?? this.diamonds,
      streak:                 streak                 ?? this.streak,
      adsWatchedToday:        adsWatchedToday        ?? this.adsWatchedToday,
      smallRewardEarnedToday: smallRewardEarnedToday ?? this.smallRewardEarnedToday,
      canClaimToday:          canClaimToday          ?? this.canClaimToday,
      isLoading:              isLoading              ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      pendingReward: clearReward ? null : (pendingReward ?? this.pendingReward),
    );
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────
final diamondProvider =
    NotifierProvider<DiamondNotifier, DiamondState>(() => DiamondNotifier());

class DiamondNotifier extends Notifier<DiamondState> {
  @override
  DiamondState build() => const DiamondState();

  DiamondRepository get _repo => sl<DiamondRepository>();

  // ── Load wallet data ──────────────────────────────────────────────────────
  Future<void> load(String userId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _repo.getDiamondData(userId);
    result.fold(
      (failure) => state = state.copyWith(
        isLoading: false,
        error: failure.message,
      ),
      (data) {
        DailyRewardResult? pending;
        if (data.canClaimToday) {
          final nextDay = (data.streak % 7) + 1;
          pending = DailyRewardResult(
            day: nextDay,
            diamonds: DailyRewardResult.rewardForDay(nextDay),
            isBonus: nextDay == 7,
          );
        }
        state = state.copyWith(
          diamonds:               data.diamonds,
          streak:                 data.streak,
          adsWatchedToday:        data.adsWatchedToday,
          smallRewardEarnedToday: data.smallRewardEarnedToday,
          canClaimToday:          data.canClaimToday,
          isLoading: false,
          pendingReward: pending,
        );
      },
    );
  }

  // ── Claim daily reward ────────────────────────────────────────────────────
  Future<DailyRewardResult?> claimDailyReward(String userId) async {
    final result = await _repo.claimDailyReward(userId);
    DailyRewardResult? claimed;
    result.fold(
      (failure) => state = state.copyWith(error: failure.message),
      (reward) {
        claimed = reward;
        state = state.copyWith(
          diamonds: state.diamonds + reward.diamonds,
          streak: reward.day,
          canClaimToday: false,
          clearReward: true,
        );
      },
    );
    return claimed;
  }

  // ── Watch ad reward ───────────────────────────────────────────────────────
  Future<bool> addAdReward(String userId) async {
    if (!state.canWatchAd) return false;
    final result = await _repo.addAdReward(userId);
    bool success = false;
    result.fold(
      (failure) => state = state.copyWith(error: failure.message),
      (newBalance) {
        success = true;
        state = state.copyWith(
          diamonds: newBalance,
          adsWatchedToday: state.adsWatchedToday + 1,
        );
      },
    );
    return success;
  }

  // ── Spend diamonds to unlock ──────────────────────────────────────────────
  Future<bool> spendDiamonds(
      String userId, String wallpaperId, int cost) async {
    if (state.diamonds < cost) return false;
    final result = await _repo.spendDiamonds(userId, wallpaperId, cost);
    bool success = false;
    result.fold(
      (failure) => state = state.copyWith(error: failure.message),
      (newBalance) {
        success = true;
        state = state.copyWith(diamonds: newBalance);
      },
    );
    return success;
  }

  // ── Small reward (download / set-as) — per-wallpaper dedup + 80/day cap ──
  /// Returns [SmallRewardResult] with granted=true and updated balance,
  /// or granted=false with the [SmallRewardDenyReason].
  Future<SmallRewardResult> addSmallReward(
      String userId, String wallpaperId) async {
    // Optimistic local check before hitting Firestore
    if (!state.canEarnSmall) {
      return const SmallRewardResult.denied(
          SmallRewardDenyReason.dailyCapReached);
    }
    final result = await _repo.addSmallReward(userId, wallpaperId);
    SmallRewardResult outcome = const SmallRewardResult.denied(
        SmallRewardDenyReason.dailyCapReached);
    result.fold(
      (failure) => state = state.copyWith(error: failure.message),
      (reward) {
        outcome = reward;
        if (reward.granted) {
          state = state.copyWith(
            diamonds: reward.newBalance,
            smallRewardEarnedToday:
                state.smallRewardEarnedToday + DiamondData.smallRewardAmount,
          );
        }
      },
    );
    return outcome;
  }

  // ── Dismiss popup without claiming ───────────────────────────────────────
  void dismissRewardPopup() {
    state = state.copyWith(clearReward: true, canClaimToday: false);
  }
}
