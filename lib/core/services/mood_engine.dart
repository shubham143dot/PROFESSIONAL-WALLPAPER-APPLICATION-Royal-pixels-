import 'package:flutter/material.dart';

/// The five moods a user can explicitly pick.
enum UserMood { all, calm, energetic, focus, dark, festival }

/// Snapshot of the user's current context used for AI personalization.
class UserContext {
  final UserMood mood;

  const UserContext({
    this.mood = UserMood.all,
  });

  UserContext copyWith({
    UserMood? mood,
  }) {
    return UserContext(
      mood: mood ?? this.mood,
    );
  }
}

/// Maps a [UserContext] to a prioritised list of wallpaper tags.
/// These tags are used to score and re-rank the wallpaper feed.
class MoodEngine {
  MoodEngine._();

  // ── Scoring weights ───────────────────────────────────────────────────────
  /// Points added to a wallpaper's score per matching tag.
  static const int _tagMatchScore = 10;

  /// Tags derived from device context (time) at fixed weight.
  static const int _contextTagScore = 5;

  /// Returns an ordered list of preferred tags for the given [context].
  static List<String> tagsForContext(UserContext context) {
    final tags = <String>[];

    // ── Time of day overlay ─────────────────────────────────────────────────
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      tags.addAll(['sunrise', 'nature', 'bright', 'minimal', 'morning']);
    } else if (hour >= 12 && hour < 18) {
      tags.addAll(['vibrant', 'colorful', 'energy', 'abstract']);
    } else if (hour >= 18 && hour < 21) {
      tags.addAll(['sunset', 'warm', 'golden', 'landscape']);
    } else {
      tags.addAll(['dark', 'amoled', 'neon', 'space', 'night']);
    }

    // ── Explicit mood overlay ───────────────────────────────────────────────
    switch (context.mood) {
      case UserMood.calm:
        tags.addAll(['nature', 'ocean', 'soft', 'pastel', 'forest', 'minimal']);
      case UserMood.energetic:
        tags.addAll(['cyberpunk', 'neon', 'cars', 'vibrant', 'fire', 'electric']);
      case UserMood.focus:
        tags.addAll(['minimal', 'abstract', 'gradient', 'clean', 'geometry']);
      case UserMood.dark:
        tags.addAll(['dark', 'amoled', 'space', 'black', 'night', 'horror']);
      case UserMood.festival:
        tags.addAll(['diwali', 'festival', 'lights', 'golden', 'colorful', 'holi']);
      case UserMood.all:
        break; // no tag bias
    }

    return tags;
  }

  /// Scores a list of wallpaper tags against the context tags.
  /// Higher score = better match.
  static int scoreWallpaper({
    required List<String> wallpaperTags,
    required String wallpaperCategory,
    required UserContext context,
  }) {
    int score = 0;
    final contextTags = tagsForContext(context);
    final wpTagsLower = wallpaperTags.map((t) => t.toLowerCase()).toSet();
    final catLower = wallpaperCategory.toLowerCase();

    for (final ctxTag in contextTags) {
      if (wpTagsLower.contains(ctxTag)) {
        score += _tagMatchScore;
      }
      if (catLower.contains(ctxTag)) {
        score += _contextTagScore;
      }
    }
    return score;
  }

  // ── Mood metadata (UI labels + icons) ────────────────────────────────────

  static String labelForMood(UserMood mood) {
    switch (mood) {
      case UserMood.all: return 'All';
      case UserMood.calm: return 'Calm';
      case UserMood.energetic: return 'Energy';
      case UserMood.focus: return 'Focus';
      case UserMood.dark: return 'Dark';
      case UserMood.festival: return 'Festival';
    }
  }

  static String emojiForMood(UserMood mood) {
    switch (mood) {
      case UserMood.all: return '✨';
      case UserMood.calm: return '🌿';
      case UserMood.energetic: return '⚡';
      case UserMood.focus: return '🧘';
      case UserMood.dark: return '🌌';
      case UserMood.festival: return '🎉';
    }
  }

  static Color accentForMood(UserMood mood) {
    switch (mood) {
      case UserMood.all: return const Color(0xFFD4A017);
      case UserMood.calm: return const Color(0xFF34D399);
      case UserMood.energetic: return const Color(0xFFEF4444);
      case UserMood.focus: return const Color(0xFF818CF8);
      case UserMood.dark: return const Color(0xFF6366F1);
      case UserMood.festival: return const Color(0xFFF59E0B);
    }
  }
}
