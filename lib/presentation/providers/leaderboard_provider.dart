import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/service_locator.dart';
import '../../data/datasources/firestore_data_source.dart';
import '../../domain/entities/user_entity.dart';

// Provides the Top Collectors (by owned_wallpaper)
final topCollectorsProvider = FutureProvider<List<UserEntity>>((ref) async {
  final dataSource = sl<FirestoreDataSource>();
  return dataSource.getLeaderboard('collectors', limit: 20);
});

// Provides the Top Supporters (by total_spent)
final topSupportersProvider = FutureProvider<List<UserEntity>>((ref) async {
  final dataSource = sl<FirestoreDataSource>();
  return dataSource.getLeaderboard('supporters', limit: 20);
});

// Provides the Active Users (by activity_score)
final activeUsersProvider = FutureProvider<List<UserEntity>>((ref) async {
  final dataSource = sl<FirestoreDataSource>();
  return dataSource.getLeaderboard('active', limit: 20);
});
