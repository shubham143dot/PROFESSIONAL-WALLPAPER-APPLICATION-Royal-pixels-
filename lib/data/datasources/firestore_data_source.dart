import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/wallpaper_model.dart';

abstract class FirestoreDataSource {
  Future<List<WallpaperModel>> getWallpapers({required int page, required int limit, bool isPremium = false});
  Future<WallpaperModel> getWallpaperDetails(String id);
  Future<String> getPaymentUpiId();
  Future<void> unlockPremiumWallpaper(String userId, String wallpaperId);
  Future<bool> isWallpaperUnlocked(String userId, String wallpaperId);
  Future<void> submitPaymentRequest({
    required String userId,
    required String wallpaperId,
    required double amount,
    required String txnId,
    required String wallpaperTitle,
    String? screenshotUrl,
  });
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
  Future<void> unlockPremiumWallpaper(String userId, String wallpaperId) async {
    final userRef = firestore.collection('users').doc(userId);
    
    await firestore.runTransaction((transaction) async {
      final userSnapshot = await transaction.get(userRef);
      if (!userSnapshot.exists) throw Exception('User not found');
      
      final currentCount = userSnapshot.data()?['owned_wallpaper'] ?? 0;
      
      transaction.update(userRef, {
        'owned_wallpaper': currentCount + 1,
        'unlocked_wallpapers': FieldValue.arrayUnion([wallpaperId])
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
    await unlockPremiumWallpaper(userId, wallpaperId);
  }
}
