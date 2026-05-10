import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Event recorded when a user interacts with a wallpaper.
class ViewEvent {
  final String wallpaperId;
  final List<String> tags;
  final String category;
  final Duration timeSpent;
  final bool downloaded;
  final bool setAs;
  final DateTime timestamp;

  ViewEvent({
    required this.wallpaperId,
    required this.tags,
    required this.category,
    required this.timeSpent,
    required this.downloaded,
    required this.setAs,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'wallpaperId': wallpaperId,
        'tags': tags,
        'category': category,
        'timeSpentMs': timeSpent.inMilliseconds,
        'downloaded': downloaded,
        'setAs': setAs,
        'timestamp': FieldValue.serverTimestamp(),
      };
}

/// Engine that calculates preference scores based on user history.
class PreferenceEngine {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Tracks a view event in Firestore.
  Future<void> trackEvent(ViewEvent event) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('view_history')
        .doc(event.wallpaperId)
        .set(event.toJson());

    // Also update tag scores for "For You" personalization
    await _updateTagScores(user.uid, event);
  }

  Future<void> _updateTagScores(String uid, ViewEvent event) async {
    int points = 0;
    if (event.setAs) {
      points += 10;
    } else if (event.downloaded) {
      points += 5;
    } else if (event.timeSpent.inSeconds > 5) {
      points += 2;
    } else {
      points -= 1; // Dismissed quickly
    }

    final batch = _firestore.batch();
    final prefDoc =
        _firestore.collection('users').doc(uid).collection('preferences');

    for (final tag in event.tags) {
      batch.set(
        prefDoc.doc(tag),
        {'score': FieldValue.increment(points), 'tag': tag},
        SetOptions(merge: true),
      );
    }

    // Also score the category
    batch.set(
      prefDoc.doc('cat_${event.category}'),
      {'score': FieldValue.increment(points), 'category': event.category},
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  /// Gets the user's top tags to use for "For You" filtering.
  Future<List<String>> getTopTags() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    final snapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('preferences')
        .orderBy('score', descending: true)
        .limit(25)
        .get();

    return snapshot.docs
        .where((doc) => doc.data().containsKey('tag'))
        .map((doc) => doc.data()['tag'] as String)
        .toList();
  }
}
