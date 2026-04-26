import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/mood_engine.dart';

/// Provider that exposes the current [UserContext].
final moodProvider = NotifierProvider<MoodNotifier, UserContext>(() {
  return MoodNotifier();
});

class MoodNotifier extends Notifier<UserContext> {
  @override
  UserContext build() {
    return const UserContext();
  }

  void selectMood(UserMood mood) {
    state = state.copyWith(mood: mood);
  }

  Future<void> refresh() async {
    // No longer needs battery polling
  }
}
