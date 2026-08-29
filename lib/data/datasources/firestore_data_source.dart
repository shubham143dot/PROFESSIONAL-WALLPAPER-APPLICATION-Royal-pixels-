import 'dart:async';

import 'package:async/async.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/wallpaper_model.dart';


abstract class FirestoreDataSource {
  Future<List<WallpaperModel>> getWallpapers(
      {required int page, required int limit, bool isPremium = false});
  Future<WallpaperModel> getWallpaperDetails(String id);
  Future<WallpaperModel?> getWallpaperById(String id);
  Future<String> addWallpaper(WallpaperModel wallpaper);
  Future<void> deleteWallpaper(String id);
  Future<void> updateWallpaper(String id,
      {required String newTitle,
      required String newCategory,
      required bool isPremium,
      required int diamondCost,
      required List<String> tags});
  Future<void> renameCategory(String oldName, String newName);
  Future<String> getPaymentUpiId();
  Future<void> unlockPremiumWallpaper(String userId, String wallpaperId,
      [double amount = 0.0]);
  Future<bool> isWallpaperUnlocked(String userId, String wallpaperId);
  Future<void> submitPaymentRequest({
    required String userId,
    required String wallpaperId,
    required double amount,
    required String txnId,
    required String wallpaperTitle,
    String? screenshotUrl,
  });

  Future<void> submitDiamondPackRequest({
    required String userId,
    required String packId,
    required String packLabel,
    required double amount,
    required int diamondsGranted,
    required String txnId,
    String? screenshotUrl,
  });
  Future<void> updateUserActivity(String userId);
  Future<bool> toggleLike(String userId, String wallpaperId,
      {bool isFavorite = true});
  Future<void> toggleLikeAnonymous(String wallpaperId, bool isAdding);

  // ── Diamond System ─────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getDiamondData(String userId);
  Future<Map<String, dynamic>> claimDailyReward(String userId);
  Future<int> spendDiamonds(String userId, String wallpaperId, int cost);

  /// Awards +5 diamonds for download/set-as (unified, per-wallpaper dedup + 20/day cap).
  /// Returns a map: { 'granted': bool, 'newBalance': int, 'reason': String? }
  Future<Map<String, dynamic>> addSmallReward(
      String userId, String wallpaperId);

  /// Atomically increments the view counter on a wallpaper document.
  /// Fire-and-forget — silently fails on offline/error.
  Future<void> incrementViewCount(String wallpaperId, {String? userId});
  Future<void> incrementShareCount(String wallpaperId);

  /// Fetches top trending wallpapers (sorted by view_count descending).
  Future<List<WallpaperModel>> getTrendingWallpapers({int limit = 30});

  /// Updates the user's subscription status.
  Future<void> updateSubscriptionStatus(String userId, bool isSubscribed);

  /// Awards [amount] diamonds to the user.
  Future<int> addDiamonds(String userId, int amount);

  /// Increments the daily rewarded ad count for the user.
  Future<int> incrementAdsWatchedToday(String userId);

  /// Streams the user document for real-time updates.
  Stream<Map<String, dynamic>> watchUser(String userId);

  /// Records this user/guest as active today, then streams
  /// the last [days] days of DAU counts (admin-only).
  /// Returns a list of [DauDayRecord] sorted oldest-first.
  Stream<List<DauDayRecord>> getDailyActiveUsersCounts({int days = 7});
}

/// Holds DAU data for a single calendar day.
class DauDayRecord {
  final String dateKey; // 'YYYY-MM-DD'
  final int count;

  const DauDayRecord({required this.dateKey, required this.count});

  /// Returns the day label: 'Mon', 'Tue', etc., or 'Today'.
  String get label {
    final now = DateTime.now();
    final todayKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    if (dateKey == todayKey) return 'Today';
    final parts = dateKey.split('-');
    final dt = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[dt.weekday - 1];
  }
}

class FirestoreDataSourceImpl implements FirestoreDataSource {
  final FirebaseFirestore firestore;

  FirestoreDataSourceImpl({required this.firestore});

  @override
  Stream<Map<String, dynamic>> watchUser(String userId) {
    return firestore.collection('users').doc(userId).snapshots().map((doc) => doc.data() ?? {});
  }

  @override
  Future<List<WallpaperModel>> getWallpapers(
      {required int page, required int limit, bool isPremium = false}) async {
    try {
      // 1. Attempt server-side sorting (Preferred for performance)
      // IMPORTANT: Requires a composite index (is_premium, created_at) in Firestore
      // When limit <= 0, fetch ALL wallpapers (no cap).
      Query<Map<String, dynamic>> query = firestore
          .collection('wallpapers')
          .where('is_premium', isEqualTo: isPremium)
          .orderBy('created_at', descending: true);
      if (limit > 0) {
        query = query.limit(page * limit);
      }
      final querySnapshot = await query.get();

      final allDocs = querySnapshot.docs;
      final start = (page - 1) * limit;
      final pageDocs = (limit > 0 && allDocs.length > start)
          ? allDocs.sublist(start)
          : allDocs;

      return pageDocs.expand((doc) {
        try {
          return [WallpaperModel.fromFirestore(doc.data(), doc.id)];
        } catch (e) {
          if (kDebugMode) {
            debugPrint('Error parsing wallpaper ${doc.id}: $e');
          }
          return <WallpaperModel>[];
        }
      }).toList();
    } catch (e) {
      final errorMsg = e.toString();

      // 2. Identify missing index error (failed-precondition)
      if (errorMsg.contains('failed-precondition') ||
          errorMsg.contains('requires an index')) {
        if (kDebugMode) {
          debugPrint(
              'Firestore: Missing composite index for wallpapers. Falling back to client-side sorting.');
        }

        // Use a simpler query that only filters (no ordering) to bypass index requirement
        Query<Map<String, dynamic>> fallbackQuery = firestore
            .collection('wallpapers')
            .where('is_premium', isEqualTo: isPremium);
        if (limit > 0) {
          fallbackQuery = fallbackQuery.limit(page * limit);
        }
        final querySnapshot = await fallbackQuery.get();

        final allDocs = querySnapshot.docs;
        final start = (page - 1) * limit;
        final list = (limit > 0 && allDocs.length > start)
            ? allDocs.sublist(start).expand((doc) {
                try {
                  return [WallpaperModel.fromFirestore(doc.data(), doc.id)];
                } catch (err) {
                  return <WallpaperModel>[];
                }
              }).toList()
            : allDocs.expand((doc) {
                try {
                  return [WallpaperModel.fromFirestore(doc.data(), doc.id)];
                } catch (err) {
                  return <WallpaperModel>[];
                }
              }).toList();

        // 3. Apply client-side sorting as a fallback
        list.sort((a, b) {
          final dateA = a.createdAt ?? DateTime(2000);
          final dateB = b.createdAt ?? DateTime(2000);
          return dateB.compareTo(dateA); // Descending (newest first)
        });

        // 4. Respect the original limit after sorting
        return limit > 0 ? list.take(limit).toList() : list;
      }

      if (kDebugMode) {
        debugPrint('❌ Firestore getWallpapers Error: $e');
      }
      // If it's a different error, rethrow it
      rethrow;
    }
  }

  @override
  Future<WallpaperModel> getWallpaperDetails(String id) async {
    final doc = await firestore.collection('wallpapers').doc(id).get();
    if (doc.exists) {
      return WallpaperModel.fromFirestore(doc.data()!, doc.id);
    } else {
      throw Exception('Wallpaper not found');
    }
  }

  @override
  Future<WallpaperModel?> getWallpaperById(String id) async {
    try {
      final doc = await firestore.collection('wallpapers').doc(id).get();
      if (doc.exists) {
        return WallpaperModel.fromFirestore(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error fetching wallpaper by ID: $e');
      }
      return null;
    }
  }

  @override
  Future<String> getPaymentUpiId() async {
    // ── UPI System Removed ──────────────────────────────────────────────────
    // Manual UPI payments are being replaced by Google Play Billing.
    throw Exception(
        'Manual UPI payments are currently disabled. Please use Diamonds to unlock content.');

    /*
    final snapshot = await firestore.collection('payment_methods').limit(1).get();
    if (snapshot.docs.isNotEmpty) {
      final data = snapshot.docs.first.data();
      return data['upi id'] ?? data['upi_id'] ?? (throw Exception('UPI ID not configured in database'));
    }
    throw Exception('Payment methods collection is empty');
    */
  }

  @override
  Future<void> unlockPremiumWallpaper(String userId, String wallpaperId,
      [double amount = 0.0]) async {
    final userRef = firestore.collection('users').doc(userId);

    await firestore.runTransaction((transaction) async {
      final userSnapshot = await transaction.get(userRef);
      if (!userSnapshot.exists) throw Exception('User not found');

      final currentCount = userSnapshot.data()?['owned_wallpaper'] ?? 0;
      final currentSpent =
          (userSnapshot.data()?['total_spent'] ?? 0.0).toDouble();

      transaction.update(userRef, {
        'owned_wallpaper': currentCount + 1,
        'unlocked_wallpapers': FieldValue.arrayUnion([wallpaperId]),
        if (amount > 0) 'total_spent': currentSpent + amount,
      });
    });
  }

  @override
  Future<bool> isWallpaperUnlocked(String userId, String wallpaperId) async {
    final doc = await firestore.collection('users').doc(userId).get();
    if (!doc.exists) return false;
    final data = doc.data();
    final List<dynamic> unlocked = data?['unlocked_wallpapers'] ?? [];
    return unlocked.contains(wallpaperId);
  }

  @override
  Future<void> submitPaymentRequest({
    required String userId,
    required String wallpaperId,
    required double amount,
    required String txnId,
    required String wallpaperTitle,
    String? screenshotUrl,
  }) async {
    // ── Disabled for Play Store Safety ──────────────────────────────────────
    throw Exception(
        'Manual payments are currently disabled. Please use the Diamond system or wait for the upcoming Google Play Billing update.');
  }



  @override
  Future<void> submitDiamondPackRequest({
    required String userId,
    required String packId,
    required String packLabel,
    required double amount,
    required int diamondsGranted,
    required String txnId,
    String? screenshotUrl,
  }) async {
    // ── Disabled for Play Store Safety ──────────────────────────────────────
    throw Exception(
        'Manual diamond purchases are currently disabled. Please use the Ad rewards to earn more diamonds!');
  }

  @override
  Future<void> updateUserActivity(String userId) async {
    final userRef = firestore.collection('users').doc(userId);
    final today = _dauDateKey(DateTime.now());

    await firestore.runTransaction((transaction) async {
      final userSnapshot = await transaction.get(userRef);
      Map<String, dynamic> updates = {};
      final now = DateTime.now();
      bool isNewDay = true;

      if (!userSnapshot.exists) {
        // Create user document if it doesn't exist
        updates = {
          'activity_score': 10,
          'login_history': FieldValue.serverTimestamp(),
          'total_spent': 0.0,
          'owned_wallpaper': 0,
          'diamonds': 0,
          'streak': 0,
        };
        transaction.set(userRef, updates);
        // Record as first-time active today
        final dauRef = firestore.collection('daily_active_users').doc(today);
        transaction.set(
          dauRef,
          {
            'count': FieldValue.increment(1),
            'uids': {userId: true},
          },
          SetOptions(merge: true),
        );
        return;
      }

      final data = userSnapshot.data()!;
      final currentScore = data['activity_score'] ?? 0;
      final Timestamp? lastLoginTs = data['login_history'] as Timestamp?;

      if (lastLoginTs != null) {
        final lastLoginDate = lastLoginTs.toDate();
        if (lastLoginDate.year == now.year &&
            lastLoginDate.month == now.month &&
            lastLoginDate.day == now.day) {
          isNewDay = false;
        }
      }

      // Initialize new fields for backward compatibility
      if (data['activity_score'] == null) {
        updates['activity_score'] = currentScore;
      }
      if (data['total_spent'] == null) {
        updates['total_spent'] = 0.0;
      }

      if (isNewDay) {
        updates['activity_score'] =
            (updates['activity_score'] ?? currentScore) + 10;
        updates['login_history'] = FieldValue.serverTimestamp();
      }

      if (updates.isNotEmpty) {
        transaction.update(userRef, updates);
      }

      // ── DAU: record this uid as active today (idempotent via merge) ──
      // We always try to record the UID. The Firestore document uses a
      // map {uid: true} so duplicate writes are harmless.
      final dauRef = firestore.collection('daily_active_users').doc(today);
      final dauKey = 'uids.$userId';
      // Only increment count if uid is NOT already recorded today
      final dauSnap = await transaction.get(dauRef);
      final alreadyCounted = dauSnap.exists &&
          (dauSnap.data()?['uids'] as Map<String, dynamic>? ?? {})
              .containsKey(userId);
      if (!alreadyCounted) {
        transaction.set(
          dauRef,
          {
            'count': FieldValue.increment(1),
            'uids': {userId: true},
          },
          SetOptions(merge: true),
        );
      } else {
        // Still mark uid present (no-op if already set)
        transaction.set(
          dauRef,
          {'uids': {userId: true}},
          SetOptions(merge: true),
        );
      }
      // Suppress unused variable warning
      // ignore: unused_local_variable
      final _ = dauKey;
    });
  }

  // ── DIAMOND SYSTEM ──────────────────────────────────────────────────────

  String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  static String _dauDateKey(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  @override
  Stream<List<DauDayRecord>> getDailyActiveUsersCounts({int days = 7}) {
    // Build list of date keys for the last [days] days
    final now = DateTime.now();
    final dateKeys = List.generate(
      days,
      (i) => _dauDateKey(now.subtract(Duration(days: days - 1 - i))),
    );

    // Stream each day's document and combine them
    final streams = dateKeys
        .map((key) => firestore
            .collection('daily_active_users')
            .doc(key)
            .snapshots()
            .map((snap) => DauDayRecord(
                  dateKey: key,
                  count: snap.exists ? (snap.data()?['count'] as int? ?? 0) : 0,
                )))
        .toList();

    // Zip all per-day streams into one combined list stream
    return _zipDauStreams(streams);
  }

  /// Combines N independent streams into one stream that emits
  /// a complete list every time any source emits.
  Stream<List<DauDayRecord>> _zipDauStreams(
    List<Stream<DauDayRecord>> streams,
  ) async* {
    final latest = List<DauDayRecord?>.filled(streams.length, null);
    final controllers =
        List.generate(streams.length, (_) => StreamController<DauDayRecord>());
    final subs = <StreamSubscription>[];

    for (var i = 0; i < streams.length; i++) {
      final idx = i;
      subs.add(streams[idx].listen((record) {
        latest[idx] = record;
        controllers[idx].add(record);
      }));
    }

    // Emit whenever any controller fires
    final merged = StreamGroup.merge(controllers.map((c) => c.stream).toList());
    await for (final _ in merged) {
      if (latest.every((r) => r != null)) {
        yield latest.map((r) => r!).toList();
      }
    }

    for (final sub in subs) {
      await sub.cancel();
    }
    for (final c in controllers) {
      await c.close();
    }
  }

  @override
  Future<Map<String, dynamic>> getDiamondData(String userId) async {
    final doc = await firestore.collection('users').doc(userId).get();
    final data = doc.data() ?? {};
    final today = _todayString();
    final lastRewardDate = data['lastRewardDate'] as String? ?? '';
    final lastSmallRewardDate = data['lastSmallRewardDate'] as String? ?? '';
    final lastAdRewardDate = data['lastAdRewardDate'] as String? ?? '';

    // Reset counters when the date changes
    final smallRewardEarnedToday = (lastSmallRewardDate == today)
        ? (data['smallRewardEarnedToday'] as int? ?? 0)
        : 0;

    final adsWatchedToday = (lastAdRewardDate == today)
        ? (data['adsWatchedToday'] as int? ?? 0)
        : 0;

    int streak = data['streak'] as int? ?? 0;
    bool canClaimToday = lastRewardDate != today;

    // Check if streak is broken (missed more than 1 day)
    if (lastRewardDate.isNotEmpty && lastRewardDate != today) {
      try {
        final lastParts = lastRewardDate.split('-');
        final lastDate = DateTime(
          int.parse(lastParts[0]),
          int.parse(lastParts[1]),
          int.parse(lastParts[2]),
        );
        final now = DateTime.now();
        final yesterday = DateTime(now.year, now.month, now.day - 1);

        bool isYesterday = lastDate.year == yesterday.year &&
            lastDate.month == yesterday.month &&
            lastDate.day == yesterday.day;

        if (!isYesterday) {
          streak = 0; // Streak is broken
        }
      } catch (_) {
        streak = 0;
      }
    }

    return {
      'diamonds': data['diamonds'] as int? ?? 0,
      'streak': streak,
      'smallRewardEarnedToday': smallRewardEarnedToday,
      'lastRewardDate': lastRewardDate,
      'lastSmallRewardDate': lastSmallRewardDate,
      'canClaimToday': canClaimToday,
      'adsWatchedToday': adsWatchedToday,
      'lastAdRewardDate': lastAdRewardDate,
    };
  }

  @override
  Future<int> incrementAdsWatchedToday(String userId) async {
    final userRef = firestore.collection('users').doc(userId);
    late int newCount;

    await firestore.runTransaction((transaction) async {
      final snap = await transaction.get(userRef);
      if (!snap.exists) throw Exception('User not found');

      final data = snap.data()!;
      final today = _todayString();
      final lastAdRewardDate = data['lastAdRewardDate'] as String? ?? '';
      final isNewDay = lastAdRewardDate != today;

      final currentCount = isNewDay ? 0 : (data['adsWatchedToday'] as int? ?? 0);
      newCount = currentCount + 1;

      transaction.update(userRef, {
        'adsWatchedToday': newCount,
        'lastAdRewardDate': today,
      });
    });

    return newCount;
  }

  @override
  Future<Map<String, dynamic>> claimDailyReward(String userId) async {
    final userRef = firestore.collection('users').doc(userId);
    late Map<String, dynamic> result;

    await firestore.runTransaction((transaction) async {
      final snap = await transaction.get(userRef);
      if (!snap.exists) throw Exception('User not found');

      final data = snap.data()!;
      final today = _todayString();
      final lastRewardDate = data['lastRewardDate'] as String? ?? '';

      // Guard: already claimed today
      if (lastRewardDate == today) {
        throw Exception('Already claimed today');
      }

      final currentDiamonds = data['diamonds'] as int? ?? 0;
      int currentStreak = data['streak'] as int? ?? 0;

      // Check if streak is still valid (claimed yesterday or first time)
      bool streakContinues = false;
      if (lastRewardDate.isNotEmpty) {
        try {
          final lastParts = lastRewardDate.split('-');
          final lastDate = DateTime(
            int.parse(lastParts[0]),
            int.parse(lastParts[1]),
            int.parse(lastParts[2]),
          );
          final now = DateTime.now();
          final yesterday = DateTime(now.year, now.month, now.day - 1);
          if (lastDate.year == yesterday.year &&
              lastDate.month == yesterday.month &&
              lastDate.day == yesterday.day) {
            streakContinues = true;
          }
        } catch (_) {}
      }

      if (!streakContinues) {
        currentStreak = 0; // Reset to 0, will become 1 below
      }

      // Advance streak (wraps 7 -> 1)
      final newStreak = (currentStreak % 7) + 1;
      final reward = _rewardForDay(newStreak);
      final isBonus = newStreak == 7;
      final newDiamonds = currentDiamonds + reward;

      transaction.update(userRef, {
        'diamonds': newDiamonds,
        'streak': newStreak,
        'lastRewardDate': today,
      });

      result = {
        'day': newStreak,
        'diamonds': reward,
        'newTotal': newDiamonds,
        'isBonus': isBonus,
      };
    });

    return result;
  }

  int _rewardForDay(int day) {
    const rewards = [10, 15, 20, 25, 30, 40, 50];
    return rewards[(day - 1).clamp(0, 6)];
  }



  @override
  Future<int> spendDiamonds(String userId, String wallpaperId, int cost) async {
    final userRef = firestore.collection('users').doc(userId);
    late int newBalance;

    await firestore.runTransaction((transaction) async {
      final snap = await transaction.get(userRef);
      if (!snap.exists) throw Exception('User not found');

      final data = snap.data()!;
      final currentDiamonds = data['diamonds'] as int? ?? 0;

      if (currentDiamonds < cost) {
        throw Exception('Insufficient diamonds');
      }

      newBalance = currentDiamonds - cost;

      transaction.update(userRef, {
        'diamonds': newBalance,
        'unlocked_wallpapers': FieldValue.arrayUnion([wallpaperId]),
        'owned_wallpaper': FieldValue.increment(1),
      });
    });

    return newBalance;
  }

  @override
  Future<Map<String, dynamic>> addSmallReward(
      String userId, String wallpaperId) async {
    final userRef = firestore.collection('users').doc(userId);
    late Map<String, dynamic> result;

    await firestore.runTransaction((transaction) async {
      final snap = await transaction.get(userRef);
      if (!snap.exists) throw Exception('User not found');

      final data = snap.data()!;
      final today = _todayString();
      final lastSmallRewardDate = data['lastSmallRewardDate'] as String? ?? '';
      final isNewDay = lastSmallRewardDate != today;

      // Reset daily tracking on new day
      final smallRewardEarnedToday =
          isNewDay ? 0 : (data['smallRewardEarnedToday'] as int? ?? 0);
      final rewardedWallpapers = isNewDay
          ? <String>[]
          : List<String>.from(
              (data['rewardedWallpapersToday'] as List<dynamic>?) ?? []);

      // Rule 1: per-wallpaper dedup — each wallpaper can only earn once/day
      if (rewardedWallpapers.contains(wallpaperId)) {
        result = {
          'granted': false,
          'newBalance': data['diamonds'] as int? ?? 0,
          'reason': 'wallpaperAlreadyRewarded',
        };
        return; // no Firestore update
      }

      // Rule 2: 80-diamond combined daily cap for all download/set-as actions
      const int dailyCap = 80;
      if (smallRewardEarnedToday >= dailyCap) {
        result = {
          'granted': false,
          'newBalance': data['diamonds'] as int? ?? 0,
          'reason': 'dailyCapReached',
        };
        return;
      }

      const int rewardAmount = 5;
      final currentDiamonds = data['diamonds'] as int? ?? 0;
      final newBalance = currentDiamonds + rewardAmount;
      rewardedWallpapers.add(wallpaperId);

      transaction.update(userRef, {
        'diamonds': newBalance,
        'smallRewardEarnedToday': smallRewardEarnedToday + rewardAmount,
        'rewardedWallpapersToday': rewardedWallpapers,
        'lastSmallRewardDate': today,
      });

      result = {
        'granted': true,
        'newBalance': newBalance,
        'reason': null,
      };
    });

    return result;
  }

  @override
  Future<String> addWallpaper(WallpaperModel wallpaper) async {
    // ── Duplicate guard: reject if this exact image URL already exists ──
    if (wallpaper.imageUrl.isNotEmpty) {
      final existing = await firestore
          .collection('wallpapers')
          .where('image_url', isEqualTo: wallpaper.imageUrl)
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) {
        throw Exception('Duplicate: This image has already been uploaded.');
      }
    }

    Map<String, dynamic> data = wallpaper.toFirestore();
    data['created_at'] = FieldValue.serverTimestamp();

    // Ensure we don't save an empty ID field inside the document,
    // as it's redundant and can cause deduplication issues.
    if (data['id'] == null ||
        (data['id'] is String && (data['id'] as String).isEmpty)) {
      data.remove('id');
    }

    if (wallpaper.id.isEmpty) {
      final docRef = await firestore.collection('wallpapers').add(data);
      return docRef.id;
    } else {
      await firestore.collection('wallpapers').doc(wallpaper.id).set(data);
      return wallpaper.id;
    }
  }

  @override
  Future<void> deleteWallpaper(String id) async {
    await firestore.collection('wallpapers').doc(id).delete();
  }

  @override
  Future<void> updateWallpaper(String id,
      {required String newTitle,
      required String newCategory,
      required bool isPremium,
      required int diamondCost,
      required List<String> tags}) async {
    await firestore.collection('wallpapers').doc(id).update({
      'title': newTitle,
      'category': newCategory,
      'is_premium': isPremium,
      'diamond_cost': diamondCost,
      'tags': tags,
    });
  }

  @override
  Future<void> renameCategory(String oldName, String newName) async {
    final oldCategoryLower = oldName.toLowerCase();
    final newCategoryLower = newName.toLowerCase();

    // 1. Update wallpapers
    final wallpapersSnap = await firestore
        .collection('wallpapers')
        .where('category', isEqualTo: oldName)
        .get();

    final batch = firestore.batch();

    for (var doc in wallpapersSnap.docs) {
      final data = doc.data();
      List<dynamic> tags = data['tags'] ?? [];

      // Update tags
      tags = tags.map((t) {
        if (t == oldCategoryLower) return newCategoryLower;
        return t;
      }).toList();

      if (!tags.contains(newCategoryLower)) {
        tags.add(newCategoryLower); // Fallback to ensure new tag exists
      }

      batch.update(doc.reference, {
        'category': newName,
        'tags': tags,
      });
    }

    // 2. Update category_covers
    final oldCoverRef =
        firestore.collection('category_covers').doc(oldCategoryLower);
    final oldCoverDoc = await oldCoverRef.get();

    if (oldCoverDoc.exists) {
      final newCoverRef =
          firestore.collection('category_covers').doc(newCategoryLower);
      batch.set(newCoverRef, oldCoverDoc.data()!);
      batch.delete(oldCoverRef);
    }

    await batch.commit();
  }

  // ── Trending / View Count ──────────────────────────────────────────────────

  @override
  Future<void> incrementViewCount(String wallpaperId, {String? userId}) async {
    try {
      if (userId == null) {
        // Anonymous user: just increment (fallback) or skip to stay strictly accurate
        // Here we increment to still show some growth for non-logged users
        await firestore
            .collection('wallpapers')
            .doc(wallpaperId)
            .update({'view_count': FieldValue.increment(1)});
        return;
      }

      // Logged-in user: use a subcollection for exact deduplication
      final viewerRef = firestore
          .collection('wallpapers')
          .doc(wallpaperId)
          .collection('viewers')
          .doc(userId);

      // Check if this user has already viewed this wallpaper
      final viewerDoc = await viewerRef.get();
      if (viewerDoc.exists) {
        return; // Already counted
      }

      // Atomic update: Record the view AND increment the count
      final batch = firestore.batch();
      batch.set(viewerRef, {
        'viewed_at': FieldValue.serverTimestamp(),
      });
      batch.update(firestore.collection('wallpapers').doc(wallpaperId), {
        'view_count': FieldValue.increment(1),
      });

      await batch.commit();
    } catch (_) {
      // Fire-and-forget
    }
  }

  @override
  Future<bool> toggleLike(String userId, String wallpaperId,
      {bool isFavorite = true}) async {
    final wallpaperRef = firestore.collection('wallpapers').doc(wallpaperId);
    final userRef = firestore.collection('users').doc(userId);
    final fieldName = isFavorite ? 'liked_wallpapers' : 'feed_likes';

    try {
      final userSnapshot = await userRef.get();
      bool newlyLiked = false;

      if (!userSnapshot.exists) {
        // Create user document if it doesn't exist
        await userRef.set({
          'liked_wallpapers': isFavorite ? [wallpaperId] : [],
          'feed_likes': !isFavorite ? [wallpaperId] : [],
          'owned_wallpaper': 0,
          'activity_score': 0,
          'diamonds': 0,
          'total_spent': 0.0,
          'streak': 0,
          'login_history': FieldValue.serverTimestamp(),
        });
        newlyLiked = true;
      } else {
        final userData = userSnapshot.data() ?? {};
        final List<dynamic> likedList = userData[fieldName] ?? [];
        final wasLiked = likedList.contains(wallpaperId);

        if (wasLiked) {
          await userRef.update({
            fieldName: FieldValue.arrayRemove([wallpaperId])
          });
          newlyLiked = false;
        } else {
          await userRef.update({
            fieldName: FieldValue.arrayUnion([wallpaperId])
          });
          newlyLiked = true;
        }
      }

      // Best effort update for wallpaper like count
      // This is separated from user doc update to ensure likes "work" (in favorites/state)
      // even if the global wallpaper doc update fails due to Firestore Rules.
      try {
        await wallpaperRef
            .update({'like_count': FieldValue.increment(newlyLiked ? 1 : -1)});
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Wallpaper count update failed (likely permission): $e');
        }
      }

      return newlyLiked;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error toggling like: $e');
      }
      return false;
    }
  }

  @override
  Future<void> toggleLikeAnonymous(String wallpaperId, bool isAdding) async {
    final wallpaperRef = firestore.collection('wallpapers').doc(wallpaperId);
    try {
      await wallpaperRef
          .update({'like_count': FieldValue.increment(isAdding ? 1 : -1)});
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error toggling anonymous like: $e');
      }
    }
  }

  @override
  Future<void> incrementShareCount(String wallpaperId) async {
    try {
      await firestore
          .collection('wallpapers')
          .doc(wallpaperId)
          .update({'share_count': FieldValue.increment(1)});
    } catch (_) {
      // Fire-and-forget
    }
  }

  @override
  Future<List<WallpaperModel>> getTrendingWallpapers({int limit = 30}) async {
    try {
      // Primary: fetch wallpapers flagged as trending
      final flaggedSnap = await firestore
          .collection('wallpapers')
          .where('is_trending', isEqualTo: true)
          .limit(limit)
          .get();

      final flagged = flaggedSnap.docs.expand((doc) {
        try {
          return [WallpaperModel.fromFirestore(doc.data(), doc.id)];
        } catch (_) {
          return <WallpaperModel>[];
        }
      }).toList();

      // If flagged set is big enough, return it
      if (flagged.length >= 5) return flagged;

      // Fallback: top by view_count (requires index on view_count desc)
      final topSnap = await firestore
          .collection('wallpapers')
          .orderBy('view_count', descending: true)
          .limit(limit)
          .get();

      return topSnap.docs.expand((doc) {
        try {
          return [WallpaperModel.fromFirestore(doc.data(), doc.id)];
        } catch (_) {
          return <WallpaperModel>[];
        }
      }).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error fetching trending wallpapers: $e');
      }
      return [];
    }
  }

  @override
  Future<void> updateSubscriptionStatus(String userId, bool isSubscribed) async {
    await firestore.collection('users').doc(userId).update({
      'is_subscribed': isSubscribed,
      'premium_since': isSubscribed ? FieldValue.serverTimestamp() : null,
    });
  }

  @override
  Future<int> addDiamonds(String userId, int amount) async {
    final userRef = firestore.collection('users').doc(userId);
    return await firestore.runTransaction((transaction) async {
      final snap = await transaction.get(userRef);
      if (!snap.exists) {
        transaction.set(userRef, {'diamonds': amount});
        return amount;
      }
      final current = (snap.data()?['diamonds'] as int?) ?? 0;
      final newValue = current + amount;
      transaction.update(userRef, {'diamonds': newValue});
      return newValue;
    });
  }
}
