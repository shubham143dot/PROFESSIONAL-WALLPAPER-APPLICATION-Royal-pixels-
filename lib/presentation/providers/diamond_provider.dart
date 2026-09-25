
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/service_locator.dart';
import '../../domain/entities/diamond_data.dart';
import '../../domain/repositories/diamond_repository.dart';
import '../../domain/entities/notification_type.dart';
import '../../domain/entities/user_entity.dart';
import 'notification_provider.dart';

// ── Diamond state ──────────────────────────────────────────────────────────────
class DiamondState {
  final int diamonds;
  final int streak;
  final int smallRewardEarnedToday; // combined download+set-as, daily cap: 20
  final bool canClaimToday;
  final bool isLoading;
  final String? error;
  final DailyRewardResult? pendingReward; // non-null when popup should show
  final int adsWatchedToday;

  const DiamondState({
    this.diamonds = 0,
    this.streak = 0,
    this.smallRewardEarnedToday = 0,
    this.canClaimToday = false,
    this.isLoading = false,
    this.error,
    this.pendingReward,
    this.adsWatchedToday = 0,
  });


  static const int dailySmallRewardCap = 20;


  bool get canEarnSmall => smallRewardEarnedToday < dailySmallRewardCap;


  int get remainingSmallReward => dailySmallRewardCap - smallRewardEarnedToday;

  DiamondState copyWith({
    int? diamonds,
    int? streak,
    int? smallRewardEarnedToday,
    bool? canClaimToday,
    bool? isLoading,
    String? error,
    DailyRewardResult? pendingReward,
    int? adsWatchedToday,
    bool clearReward = false,
    bool clearError = false,
  }) {
    return DiamondState(
      diamonds: diamonds ?? this.diamonds,
      streak: streak ?? this.streak,
      smallRewardEarnedToday:
          smallRewardEarnedToday ?? this.smallRewardEarnedToday,
      canClaimToday: canClaimToday ?? this.canClaimToday,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      pendingReward: clearReward ? null : (pendingReward ?? this.pendingReward),
      adsWatchedToday: adsWatchedToday ?? this.adsWatchedToday,
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
          diamonds: data.diamonds,
          streak: data.streak,
          smallRewardEarnedToday: data.smallRewardEarnedToday,
          canClaimToday: data.canClaimToday,
          adsWatchedToday: data.adsWatchedToday,
          isLoading: false,
          pendingReward: pending,
        );
      },
    );
  }

  /// Updates local state from a [UserEntity] received via real-time stream.
  void updateFromUser(UserEntity user) {
    if (state.diamonds != user.diamonds ||
        state.streak != user.streak ||
        state.smallRewardEarnedToday != user.smallRewardEarnedToday ||
        state.adsWatchedToday != user.adsWatchedToday) {
      state = state.copyWith(
        diamonds: user.diamonds,
        streak: user.streak,
        smallRewardEarnedToday: user.smallRewardEarnedToday,
        adsWatchedToday: user.adsWatchedToday,
      );
    }
  }

  /// Alias for [load] — used after diamond pack purchase to refresh balance.
  Future<void> loadDiamonds(String userId) => load(userId);

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
        ref.read(notificationProvider.notifier).addNotification(
              title: 'Daily Reward Claimed!',
              message:
                  'You\'ve received ${reward.diamonds} diamonds for Day ${reward.day}. Keep the streak going!',
              type: NotificationType.reward,
            );
      },
    );
    return claimed;
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
        ref.read(notificationProvider.notifier).addNotification(
              title: 'Wallpaper Unlocked!',
              message:
                  'Successfully spent $cost diamonds to unlock a premium wallpaper.',
              type: NotificationType.purchase,
            );
      },
    );
    return success;
  }

  // ── Small reward (download / set-as) — per-wallpaper dedup + 20/day cap ──
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
    SmallRewardResult outcome =
        const SmallRewardResult.denied(SmallRewardDenyReason.dailyCapReached);
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
          ref.read(notificationProvider.notifier).addNotification(
                title: 'Gems Collected!',
                message:
                    'You received 5 bonus diamonds for downloading/setting a wallpaper. (Max 20/day)',
                type: NotificationType.reward,
              );
        }
      },
    );
    return outcome;
  }

  // ── Purchase diamonds ───────────────────────────────────────────────────
  Future<bool> addDiamonds(String userId, int amount) async {
    final result = await _repo.addDiamonds(userId, amount);
    bool success = false;
    result.fold(
      (failure) => state = state.copyWith(error: failure.message),
      (newBalance) {
        success = true;
        state = state.copyWith(diamonds: newBalance);
        ref.read(notificationProvider.notifier).addNotification(
              title: 'Purchase Successful!',
              message: 'Successfully added $amount diamonds to your wallet.',
              type: NotificationType.purchase,
            );
      },
    );
    return success;
  }

  // ── Dismiss popup without claiming ───────────────────────────────────────
  void dismissRewardPopup() {
    state = state.copyWith(clearReward: true, canClaimToday: false);
  }
}
