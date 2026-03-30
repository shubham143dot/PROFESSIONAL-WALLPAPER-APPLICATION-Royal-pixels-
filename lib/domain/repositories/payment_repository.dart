import 'package:dartz/dartz.dart';
import '../../core/error/failures.dart';

abstract class PaymentRepository {
  Future<Either<Failure, String>> getUpiId();
  Future<Either<Failure, bool>> initiateUpiPayment(String upiId, double amount, String wallpaperId);
  Future<Either<Failure, void>> unlockWallpaper(String userId, String wallpaperId);
  Future<Either<Failure, bool>> checkUnlockStatus(String userId, String wallpaperId);
  Future<Either<Failure, void>> submitManualPayment({
    required String userId,
    required String wallpaperId,
    required double amount,
    required String txnId,
    required String wallpaperTitle,
    String? screenshotUrl,
  });

  /// Uploads a payment screenshot to Firebase Storage and returns its download URL.
  Future<Either<Failure, String>> uploadPaymentScreenshot({
    required String userId,
    required String wallpaperId,
    required String localFilePath,
  });
}
