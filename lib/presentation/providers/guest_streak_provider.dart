import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// State for the guest streak system (stored fully in SharedPreferences — no Firestore)
class GuestStreakState {
  final int streak;
  final bool canClaimToday;
  final bool isLoading;

  const GuestStreakState({
    this.streak = 0,
    this.canClaimToday = false,
    this.isLoading = true,
  });

  GuestStreakState copyWith({
    int? streak,
    bool? canClaimToday,
    bool? isLoading,
  }) {
    return GuestStreakState(
      streak: streak ?? this.streak,
      canClaimToday: canClaimToday ?? this.canClaimToday,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

final guestStreakProvider =
    NotifierProvider<GuestStreakNotifier, GuestStreakState>(
        () => GuestStreakNotifier());

class GuestStreakNotifier extends Notifier<GuestStreakState> {
  static const _streakKey = 'guest_streak_count';
  static const _dateKey = 'guest_streak_date';

  @override
  GuestStreakState build() {
    // Load asynchronously during build
    Future.microtask(() => _loadStreak());
    return const GuestStreakState(isLoading: true);
  }

  Future<void> _loadStreak() async {
    final prefs = await SharedPreferences.getInstance();
    final streak = prefs.getInt(_streakKey) ?? 0;
    final lastDateStr = prefs.getString(_dateKey);

    final today = _todayStr();
    bool canClaim = false;

    if (lastDateStr == null) {
      // First time ever — they can claim day 1
      canClaim = true;
    } else if (lastDateStr == today) {
      // Already claimed today
      canClaim = false;
    } else {
      // Check if yesterday — continue streak; otherwise reset
      final lastDate = DateTime.parse(lastDateStr);
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final isYesterday = lastDate.year == yesterday.year &&
          lastDate.month == yesterday.month &&
          lastDate.day == yesterday.day;
      if (isYesterday) {
        canClaim = true; // Continue streak
      } else {
        // Missed a day — streak resets on next claim
        canClaim = true;
      }
    }

    state = GuestStreakState(
      streak: streak,
      canClaimToday: canClaim,
      isLoading: false,
    );
  }

  /// Claims the streak for today. Returns the new streak count.
  Future<int> claimStreak() async {
    if (!state.canClaimToday) return state.streak;

    final prefs = await SharedPreferences.getInstance();
    final lastDateStr = prefs.getString(_dateKey);
    final today = _todayStr();

    int newStreak;
    if (lastDateStr == null) {
      newStreak = 1;
    } else {
      final lastDate = DateTime.parse(lastDateStr);
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final isYesterday = lastDate.year == yesterday.year &&
          lastDate.month == yesterday.month &&
          lastDate.day == yesterday.day;
      if (isYesterday) {
        newStreak = state.streak + 1;
      } else {
        newStreak = 1; // Reset
      }
    }

    await prefs.setInt(_streakKey, newStreak);
    await prefs.setString(_dateKey, today);

    state = state.copyWith(streak: newStreak, canClaimToday: false);
    return newStreak;
  }

  String _todayStr() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }
}
