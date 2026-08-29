import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:royal_pixels/core/di/service_locator.dart';
import 'package:royal_pixels/data/datasources/firestore_data_source.dart';

/// Streams the last 7 days of Daily Active User counts.
/// Intended for admin-only display - guard the UI with the isAdmin check.
final dauProvider = StreamProvider.autoDispose<List<DauDayRecord>>((ref) {
  return sl<FirestoreDataSource>().getDailyActiveUsersCounts(days: 7);
});