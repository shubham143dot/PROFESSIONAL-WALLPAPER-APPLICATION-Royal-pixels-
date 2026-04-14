import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/wallpaper_model.dart';
import '../models/user_model.dart';

abstract class FirestoreDataSource {
  Future<List<WallpaperModel>> getWallpapers({required int page, required int limit, bool isPremium = false});
  Future<WallpaperModel> getWallpaperDetails(String id);
  Future<void> addWallpaper(WallpaperModel wallpaper);
  Future<void> deleteWallpaper(String id);
  Future<void> updateWallpaper(String id, String newTitle, String newCategory);
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
  Future<void> updateUserActivity(String userId);
  Future<List<UserModel>> getLeaderboard(String category, {int limit = 20});
}

class FirestoreDataSourceImpl implements FirestoreDataSource {
  final FirebaseFirestore firestore;

  FirestoreDataSourceImpl({required this.firestore});

  @override
  Future<List<WallpaperModel>> getWallpapers({required int page, required int limit, bool isPremium = false}) async {
    // Basic pagination (for a real app, use cursor/startAfterDocument)
    // Here we just fetch ordered by ID or a timestamp, with limit
    final querySnapshot = await firestore
        .collection('wallpapers')
        .where('is_premium', isEqualTo: isPremium)
        .limit(limit)
        .get();

    return querySnapshot.docs
        .map((doc) => WallpaperModel.fromFirestore(doc.data(), doc.id))
        .toList();
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
    final snapshot = await firestore.collection('payment_methods').limit(1).get();
    if (snapshot.docs.isNotEmpty) {
      // Matching the exact firestore field from requirements: 'upi id' vs 'upi_id'
      // Taking a guess it might be 'upi_id' based on standard conventions, but user image showed 'upi id : "user@upi"'.
      // We will look for keys. Let's use 'upi id' or 'upi_id'
      final data = snapshot.docs.first.data();
      return data['upi id'] ?? data['upi_id'] ?? (throw Exception('UPI ID not configured in database'));
    }
    throw Exception('Payment methods collection is empty');
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
    final cleanTxnId = txnId.trim().toUpperCase();

    // ── Duplicate UTR check ─────────────────────────────────────────────────
    // Query pending_purchases to see if this UTR was already submitted
    final existing = await firestore
        .collection('pending_purchases')
        .where('txnId', isEqualTo: cleanTxnId)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      throw Exception(
        'This UTR/Transaction ID has already been used. '  
        'Please enter a valid, unique Transaction ID from your UPI app.',
      );
    }

    // ── Save pending purchase record for manual verification ────────────────
    await firestore.collection('pending_purchases').add({
      'userId': userId,
      'wallpaperId': wallpaperId,
      'wallpaperTitle': wallpaperTitle,
      'amount': amount,
      'txnId': cleanTxnId,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      if (screenshotUrl != null) 'screenshotUrl': screenshotUrl,
    });

    // ── Optimistically unlock the wallpaper for the user ────────────────────
    await unlockPremiumWallpaper(userId, wallpaperId, amount);
  }

  @override
  Future<void> submitSubscriptionRequest({
    required String userId,
    required int months,
    required double amount,
    required String txnId,
    String? screenshotUrl,
  }) async {
    final cleanTxnId = txnId.trim().toUpperCase();

    final existing = await firestore
        .collection('pending_purchases')
        .where('txnId', isEqualTo: cleanTxnId)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      throw Exception(
        'This UTR/Transaction ID has already been used. '  
        'Please enter a valid, unique Transaction ID from your UPI app.',
      );
    }

    await firestore.collection('pending_purchases').add({
      'userId': userId,
      'type': 'subscription',
      'months': months,
      'amount': amount,
      'txnId': cleanTxnId,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      if (screenshotUrl != null) 'screenshotUrl': screenshotUrl,
    });

    final userRef = firestore.collection('users').doc(userId);
    await firestore.runTransaction((transaction) async {
      final userSnapshot = await transaction.get(userRef);
      if (!userSnapshot.exists) throw Exception('User not found');
      
      final currentSpent = (userSnapshot.data()?['total_spent'] ?? 0.0).toDouble();
      
      final now = DateTime.now();
      // Calculate expiry date
      final oldExpiry = (userSnapshot.data()?['subscription_expiry'] as Timestamp?)?.toDate();
      final baseDate = (oldExpiry != null && oldExpiry.isAfter(now)) ? oldExpiry : now;
      final newExpiry = DateTime(baseDate.year, baseDate.month + months, baseDate.day);
      
      transaction.update(userRef, {
        'total_spent': currentSpent + amount,
        'is_subscribed': true,
        'subscription_expiry': Timestamp.fromDate(newExpiry),
      });
    });
  }

  @override
  Future<bool> checkSubscriptionStatus(String userId) async {
    final doc = await firestore.collection('users').doc(userId).get();
    if (!doc.exists) return false;
    final data = doc.data();
    final isSubscribed = data?['is_subscribed'] ?? false;
    final expiry = (data?['subscription_expiry'] as Timestamp?)?.toDate();
    if (isSubscribed && expiry != null && expiry.isAfter(DateTime.now())) {
      return true;
    }
    // Automatically revert if expired
    if (isSubscribed && expiry != null && expiry.isBefore(DateTime.now())) {
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
      
      // Initialize new fields for backward compatibility so older users appear on leaderboards
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

  @override
  Future<List<UserModel>> getLeaderboard(String category, {int limit = 20}) async {
    String orderByField;
    switch (category) {
      case 'collectors':
        orderByField = 'owned_wallpaper';
        break;
      case 'supporters':
        orderByField = 'total_spent';
        break;
      case 'active':
        orderByField = 'activity_score';
        break;
      default:
        orderByField = 'owned_wallpaper';
    }

    final querySnapshot = await firestore
        .collection('users')
        .orderBy(orderByField, descending: true)
        .limit(limit)
        .get();

    return querySnapshot.docs
        .map((doc) => UserModel.fromFirestore(doc.data(), doc.id))
        .toList();
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
  Future<void> updateWallpaper(String id, String newTitle, String newCategory) async {
    await firestore.collection('wallpapers').doc(id).update({
      'title': newTitle,
      'category': newCategory,
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
