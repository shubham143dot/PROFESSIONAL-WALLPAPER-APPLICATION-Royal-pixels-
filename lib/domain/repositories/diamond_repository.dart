import 'package:dartz/dartz.dart';
import '../../core/error/failures.dart';
import '../entities/diamond_data.dart';

abstract class DiamondRepository {
  /// Fetches the current diamond wallet state for [userId].
  Future<Either<Failure, DiamondData>> getDiamondData(String userId);

  /// Claims the daily streak reward.
  Future<Either<Failure, DailyRewardResult>> claimDailyReward(String userId);

  /// Deducts [cost] diamonds and unlocks [wallpaperId].
  /// Returns the new diamond balance.
  Future<Either<Failure, int>> spendDiamonds(
    String userId,
    String wallpaperId,
    int cost,
  );

  /// Awards +💎5 for downloading OR setting a wallpaper (unified).
  ///
  /// Rules (enforced atomically in Firestore):
  ///  1. Each [wallpaperId] can only reward once per day (dedup).
  ///  2. Combined daily cap of 80💎 for all small rewards.
  ///
  /// Returns [SmallRewardResult] indicating success or the denial reason.
  Future<Either<Failure, SmallRewardResult>> addSmallReward(
    String userId,
    String wallpaperId,
  );
  /// Awards [amount] diamonds to the user.
  Future<Either<Failure, int>> addDiamonds(String userId, int amount);
}
