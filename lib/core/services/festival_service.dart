import 'package:cloud_firestore/cloud_firestore.dart';

class Festival {
  final String name;
  final DateTime date;
  final List<String> tags;
  final String country;

  Festival({
    required this.name,
    required this.date,
    required this.tags,
    required this.country,
  });

  factory Festival.fromJson(Map<String, dynamic> json) {
    return Festival(
      name: json['name'] as String,
      date: (json['date'] as Timestamp).toDate(),
      tags: List<String>.from(json['tags'] as List),
      country: json['country'] as String,
    );
  }
}

class FestivalService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Festival?> getTodayFestival(String country) async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    final snapshot = await _firestore
        .collection('festivals')
        .where('country', isEqualTo: country)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
        .where('date', isLessThan: Timestamp.fromDate(todayEnd))
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      return Festival.fromJson(snapshot.docs.first.data());
    }

    // Hardcoded fallback for common Indian festivals in 2026 if Firestore is empty
    return _getHardcodedFestival(country, todayStart);
  }

  Festival? _getHardcodedFestival(String country, DateTime date) {
    if (country != 'IN') return null;

    final calendar = {
      '2026-03-03': Festival(name: 'Holi', date: DateTime(2026, 3, 3), tags: ['vibrant', 'colors', 'festival', 'abstract'], country: 'IN'),
      '2026-04-10': Festival(name: 'Ramadan', date: DateTime(2026, 4, 10), tags: ['moon', 'spiritual', 'night', 'dark'], country: 'IN'),
      '2026-08-15': Festival(name: 'Independence Day', date: DateTime(2026, 8, 15), tags: ['india', 'tricolored', 'proud', 'flag'], country: 'IN'),
      '2026-10-20': Festival(name: 'Diwali', date: DateTime(2026, 10, 20), tags: ['diwali', 'lights', 'golden', 'festival'], country: 'IN'),
    };

    final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return calendar[dateKey];
  }
}
