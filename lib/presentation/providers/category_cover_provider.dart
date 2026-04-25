import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Provides a map of lowercase categoryName to its coverUrl
final categoryCoverProvider = StreamProvider<Map<String, String>>((ref) {
  return FirebaseFirestore.instance
      .collection('category_covers')
      .snapshots()
      .map((snapshot) {
    final Map<String, String> covers = {};
    for (var doc in snapshot.docs) {
      if (doc.data().containsKey('coverUrl')) {
        covers[doc.id] = doc.data()['coverUrl'] as String;
      }
    }
    return covers;
  }).handleError((error) {
    // Silently catch permission-denied or other Firestore errors
    // so it doesn't crash the widget tree.
    return <String, String>{};
  });
});
