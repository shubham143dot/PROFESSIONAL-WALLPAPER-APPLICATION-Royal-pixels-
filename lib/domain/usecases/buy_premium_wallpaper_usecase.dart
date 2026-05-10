import 'package:dartz/dartz.dart';
import '../../core/error/failures.dart';
import '../../core/usecases/usecase.dart';
import '../repositories/payment_repository.dart';

class BuyPremiumParams {
  final String userId;
  final String wallpaperId;
  final double amount;

  BuyPremiumParams(
      {required this.userId, required this.wallpaperId, required this.amount});
}

class BuyPremiumWallpaperUseCase implements UseCase<bool, BuyPremiumParams> {
  final PaymentRepository repository;

  BuyPremiumWallpaperUseCase(this.repository);

  @override
  Future<Either<Failure, bool>> call(BuyPremiumParams params) async {
    // 1. Get UPI ID
    final upiIdEither = await repository.getUpiId();
    return upiIdEither.fold((failure) => Left(failure), (upiId) async {
      // 2. Initiate Payment
      final paymentEither = await repository.initiateUpiPayment(
          upiId, params.amount, params.wallpaperId);
      return paymentEither.fold((failure) => Left(failure), (success) async {
        if (success) {
          // 3. Unlock wallpaper
          final unlockEither = await repository.unlockWallpaper(
              params.userId, params.wallpaperId);
          return unlockEither.fold(
              (failure) => Left(failure), (_) => const Right(true));
        } else {
          return const Left(
              ServerFailure('Payment fell through or was cancelled'));
        }
      });
    });
  }
}
