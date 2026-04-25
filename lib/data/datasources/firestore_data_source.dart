import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/wallpaper_model.dart';

abstract class FirestoreDataSource {
  Future<List<WallpaperModel>> getWallpapers({required int page, required int limit, bool isPremium = false});
  Future<WallpaperModel> getWallpaperDetails(String id);
  Future<void> addWallpaper(WallpaperModel wallpaper);
  Future<void> deleteWallpaper(String id);
  Future<void> updateWallpaper(String id, {required String newTitle, required String newCategory, required bool isPremium, required int diamondCost, required List<String> tags});
  Future<void> renameCategory(String oldName, String newName);
  Future<String> getPaymentUpiId();
  Future<void> unlockPremiumWallpaper(String userId, String wallpaperId, [double amount = 0.0]);
  Future<bool> isWallpaperUnlocked(String userId, String wallpaperId);
  Future<void> submitPaymentRequest({
    required String userId,
    required String wallpaperId,
    required double amount,
    required String txnId,
    required String wallpaperTitle,
    String? screenshotUrl,
  });
  Future<void> submitSubscriptionRequest({
    required String userId,
    required int months,
    required double amount,
    required String txnId,
    String? screenshotUrl,
  });
  Future<bool> checkSubscriptionStatus(String userId);
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

  // ── Diamond System ─────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getDiamondData(String userId);
  Future<Map<String, dynamic>> claimDailyReward(String userId);
  Future<int> addAdReward(String userId);
  Future<int> spendDiamonds(String userId, String wallpaperId, int cost);
  /// Awards +5 diamonds for download/set-as (unified, per-wallpaper dedup + 80/day cap).
  /// Returns a map: { 'granted': bool, 'newBalance': int, 'reason': String? }
  Future<Map<String, dynamic>> addSmallReward(String userId, String wallpaperId);
}


class FirestoreDataSourceImpl implements FirestoreDataSource {
  final FirebaseFirestore firestore;

  FirestoreDataSourceImpl({required this.firestore});

  @override
  Future<List<WallpaperModel>> getWallpapers({required int page, required int limit, bool isPremium = false}) async {
    try {
      // 1. Attempt server-side sorting (Preferred for performance)
      // IMPORTANT: Requires a composite index (is_premium, created_at) in Firestore
      final querySnapshot = await firestore
          .collection('wallpapers')
          .where('is_premium', isEqualTo: isPremium)
          .orderBy('created_at', descending: true)
          .limit(limit)
          .get();

      return querySnapshot.docs.expand((doc) {
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
      if (errorMsg.contains('failed-precondition') || errorMsg.contains('requires an index')) {
        if (kDebugMode) {
          debugPrint('Firestore: Missing composite index for wallpapers. Falling back to client-side sorting.');
        }
        
        // Use a simpler query that only filters (no ordering) to bypass index requirement
        final querySnapshot = await firestore
            .collection('wallpapers')
            .where('is_premium', isEqualTo: isPremium)
            .limit(limit * 2) // Fetch a bit more to improve sorting quality
            .get();

        final list = querySnapshot.docs.expand((doc) {
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
        return list.take(limit).toList();
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
  Future<String> getPaymentUpiId() async {
    // ── UPI System Removed ──────────────────────────────────────────────────
    // Manual UPI payments are being replaced by Google Play Billing.
    throw Exception('Manual UPI payments are currently disabled. Please use Diamonds to unlock content.');
    
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
  Future<void> unlockPremiumWallpaper(String userId, String wallpaperId, [double amount = 0.0]) async {
    final userRef = firestore.collection('users').doc(userId);
    
    await firestore.runTransaction((transaction) async {
      final userSnapshot = await transaction.get(userRef);
      if (!userSnapshot.exists) throw Exception('User not found');
      
      final currentCount = userSnapshot.data()?['owned_wallpaper'] ?? 0;
      final currentSpent = (userSnapshot.data()?['total_spent'] ?? 0.0).toDouble();
      
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
    throw Exception('Manual payments are currently disabled. Please use the Diamond system or wait for the upcoming Google Play Billing update.');
  }

  @override
  Future<void> submitSubscriptionRequest({
    required String userId,
    required int months,
    required double amount,
    required String txnId,
    String? screenshotUrl,
  }) async {
    // ── Disabled for Play Store Safety ──────────────────────────────────────
    throw Exception('Manual subscriptions are currently disabled. Official Google Play Subscriptions are coming soon!');
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
    throw Exception('Manual diamond purchases are currently disabled. Please use the Ad rewards to earn more diamonds!');
  }

  @override
  Future<bool> checkSubscriptionStatus(String userId) async {
    final doc = await firestore.collection('users').doc(userId).get();
    if (!doc.exists) return false;
    final data = doc.data();
    final isSubscribed = data?['is_subscribed'] ?? false;
    final expiry = (data?['subscription_expiry'] as Timestamp?)?.toDate();
    final planType = data?['plan_type'] as String? ?? '';

    // Lifetime plan — never expires
    if (isSubscribed && planType == 'lifetime') return true;

    if (isSubscribed && expiry != null && expiry.isAfter(DateTime.now())) {
      return true;
    }
    // Automatically revert if expired (only for non-lifetime plans)
    if (isSubscribed &&
        expiry != null &&
        expiry.isBefore(DateTime.now()) &&
        planType != 'lifetime') {
      await firestore.collection('users').doc(userId).update({
        'is_subscribed': false,
      });
    }
    return false;
  }


  @override
  Future<void> updateUserActivity(String userId) async {
    final userRef = firestore.collection('users').doc(userId);
    
    await firestore.runTransaction((transaction) async {
      final userSnapshot = await transaction.get(userRef);
      if (!userSnapshot.exists) return; // Do nothing if user document doesn't exist yet
      
      final data = userSnapshot.data();
      final currentScore = data?['activity_score'] ?? 0;
      final Timestamp? lastLoginTs = data?['login_history'] as Timestamp?;
      
      final now = DateTime.now();
      bool isNewDay = true;
      
      if (lastLoginTs != null) {
        final lastLoginDate = lastLoginTs.toDate();
        if (lastLoginDate.year == now.year && 
            lastLoginDate.month == now.month && 
            lastLoginDate.day == now.day) {
          isNewDay = false;
        }
      }
      
      Map<String, dynamic> updates = {};
      
      // Initialize new fields for backward compatibility
      if (data?['activity_score'] == null) {
        updates['activity_score'] = currentScore;
      }
      if (data?['total_spent'] == null) {
        updates['total_spent'] = 0.0;
      }
      
      if (isNewDay) {
        updates['activity_score'] = currentScore + 10;
        updates['login_history'] = FieldValue.serverTimestamp();
      }
      
      if (updates.isNotEmpty) {
        transaction.update(userRef, updates);
      }
    });
  }

  // ── DIAMOND SYSTEM ──────────────────────────────────────────────────────

  String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  Future<Map<String, dynamic>> getDiamondData(String userId) async {
    final doc = await firestore.collection('users').doc(userId).get();
    final data = doc.data() ?? {};
    final today = _todayString();
    final lastRewardDate      = data['lastRewardDate']      as String? ?? '';
    final lastAdDate          = data['lastAdDate']          as String? ?? '';
    final lastSmallRewardDate = data['lastSmallRewardDate'] as String? ?? '';

    // Reset counters when the date changes
    final adsWatchedToday        = (lastAdDate          == today)
        ? (data['adsWatchedToday']        as int? ?? 0) : 0;
    final smallRewardEarnedToday = (lastSmallRewardDate == today)
        ? (data['smallRewardEarnedToday'] as int? ?? 0) : 0;

    return {
      'diamonds':               data['diamonds'] as int? ?? 0,
      'streak':                 data['streak']   as int? ?? 0,
      'adsWatchedToday':        adsWatchedToday,
      'smallRewardEarnedToday': smallRewardEarnedToday,
      'lastRewardDate':         lastRewardDate,
      'lastAdDate':             lastAdDate,
      'lastSmallRewardDate':    lastSmallRewardDate,
      'canClaimToday':          lastRewardDate != today,
    };
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
  Future<int> addAdReward(String userId) async {
    final userRef = firestore.collection('users').doc(userId);
    late int newBalance;

    await firestore.runTransaction((transaction) async {
      final snap = await transaction.get(userRef);
      if (!snap.exists) throw Exception('User not found');

      final data = snap.data()!;
      final today = _todayString();
      final lastAdDate = data['lastAdDate'] as String? ?? '';
      final adsWatchedToday = (lastAdDate == today)
          ? (data['adsWatchedToday'] as int? ?? 0)
          : 0;

      if (adsWatchedToday >= 5) {
        throw Exception('Daily ad limit reached (5/day)');
      }

      final currentDiamonds = data['diamonds'] as int? ?? 0;
      newBalance = currentDiamonds + 10;

      transaction.update(userRef, {
        'diamonds': newBalance,
        'adsWatchedToday': adsWatchedToday + 1,
        'lastAdDate': today,
      });
    });

    return newBalance;
  }

  @override
  Future<int> spendDiamonds(
      String userId, String wallpaperId, int cost) async {
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
      final smallRewardEarnedToday = isNewDay
          ? 0
          : (data['smallRewardEarnedToday'] as int? ?? 0);
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
  Future<void> addWallpaper(WallpaperModel wallpaper) async {
    Map<String, dynamic> data = wallpaper.toFirestore();
    data['created_at'] = FieldValue.serverTimestamp();
    
    if (wallpaper.id.isEmpty) {
      await firestore.collection('wallpapers').add(data);
    } else {
      await firestore.collection('wallpapers').doc(wallpaper.id).set(data);
    }
  }

  @override
  Future<void> deleteWallpaper(String id) async {
    await firestore.collection('wallpapers').doc(id).delete();
  }

  @override
  Future<void> updateWallpaper(String id, {required String newTitle, required String newCategory, required bool isPremium, required int diamondCost, required List<String> tags}) async {
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
    final oldCoverRef = firestore.collection('category_covers').doc(oldCategoryLower);
    final oldCoverDoc = await oldCoverRef.get();
    
    if (oldCoverDoc.exists) {
      final newCoverRef = firestore.collection('category_covers').doc(newCategoryLower);
      batch.set(newCoverRef, oldCoverDoc.data()!);
      batch.delete(oldCoverRef);
    }

    await batch.commit();
  }
}
