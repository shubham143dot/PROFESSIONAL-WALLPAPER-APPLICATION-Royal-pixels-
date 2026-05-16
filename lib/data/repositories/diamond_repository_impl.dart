import 'package:dartz/dartz.dart';
import '../../core/error/failures.dart';
import '../../data/datasources/firestore_data_source.dart';
import '../../domain/entities/diamond_data.dart';
import '../../domain/repositories/diamond_repository.dart';

class DiamondRepositoryImpl implements DiamondRepository {
  final FirestoreDataSource dataSource;

  DiamondRepositoryImpl({required this.dataSource});

  @override
  Future<Either<Failure, DiamondData>> getDiamondData(String userId) async {
    try {
      final data = await dataSource.getDiamondData(userId);
      return Right(DiamondData(
        diamonds: data['diamonds'] as int,
        streak: data['streak'] as int,
        smallRewardEarnedToday: data['smallRewardEarnedToday'] as int? ?? 0,
        canClaimToday: data['canClaimToday'] as bool,
        lastRewardDate: data['lastRewardDate'] as String,
        lastSmallRewardDate: data['lastSmallRewardDate'] as String? ?? '',
        adsWatchedToday: data['adsWatchedToday'] as int? ?? 0,
        lastAdRewardDate: data['lastAdRewardDate'] as String? ?? '',
      ));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, int>> incrementAdsWatchedToday(String userId) async {
    try {
      final newCount = await dataSource.incrementAdsWatchedToday(userId);
      return Right(newCount);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, DailyRewardResult>> claimDailyReward(
      String userId) async {
    try {
      final data = await dataSource.claimDailyReward(userId);
      return Right(DailyRewardResult(
        day: data['day'] as int,
        diamonds: data['diamonds'] as int,
        isBonus: data['isBonus'] as bool,
      ));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, int>> spendDiamonds(
      String userId, String wallpaperId, int cost) async {
    try {
      final newBalance =
          await dataSource.spendDiamonds(userId, wallpaperId, cost);
      return Right(newBalance);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, SmallRewardResult>> addSmallReward(
      String userId, String wallpaperId) async {
    try {
      final map = await dataSource.addSmallReward(userId, wallpaperId);
      final granted = map['granted'] as bool;
      if (granted) {
        return Right(SmallRewardResult.granted(map['newBalance'] as int));
      }
      final reason = map['reason'] as String?;
      final denyReason = reason == 'wallpaperAlreadyRewarded'
          ? SmallRewardDenyReason.wallpaperAlreadyRewarded
          : SmallRewardDenyReason.dailyCapReached;
      return Right(SmallRewardResult.denied(denyReason));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, int>> addDiamonds(String userId, int amount) async {
    try {
      final newBalance = await dataSource.addDiamonds(userId, amount);
      return Right(newBalance);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
