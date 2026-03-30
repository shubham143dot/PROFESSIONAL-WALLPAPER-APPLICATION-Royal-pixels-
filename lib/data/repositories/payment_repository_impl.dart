import 'dart:io';
import 'package:dartz/dartz.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/error/failures.dart';
import '../../domain/repositories/payment_repository.dart';
import '../datasources/firestore_data_source.dart';

class PaymentRepositoryImpl implements PaymentRepository {
  final FirestoreDataSource remoteDataSource;
  final FirebaseStorage storage;

  PaymentRepositoryImpl({
    required this.remoteDataSource,
    required this.storage,
  });

  @override
  Future<Either<Failure, String>> getUpiId() async {
    try {
      final upiId = await remoteDataSource.getPaymentUpiId();
      return Right(upiId);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> initiateUpiPayment(
      String upiId, double amount, String wallpaperId) async {
    try {
      const String trName = 'Premium Wallpaper Unlock';
      const String mc = '8999';
      final String uri =
          'upi://pay?pa=$upiId&pn=Royal%20Pixels&am=${amount.toStringAsFixed(2)}&cu=INR&tn=$trName&mc=$mc';

      final parseUrl = Uri.parse(uri);
      bool isLaunched =
          await launchUrl(parseUrl, mode: LaunchMode.externalApplication);

      if (!isLaunched) {
        return const Left(ServerFailure('No UPI app installed'));
      }

      await Future.delayed(const Duration(seconds: 3));
      return const Right(true);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> unlockWallpaper(
      String userId, String wallpaperId) async {
    try {
      await remoteDataSource.unlockPremiumWallpaper(userId, wallpaperId);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> checkUnlockStatus(
      String userId, String wallpaperId) async {
    try {
      final isUnlocked =
          await remoteDataSource.isWallpaperUnlocked(userId, wallpaperId);
      return Right(isUnlocked);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, String>> uploadPaymentScreenshot({
    required String userId,
    required String wallpaperId,
    required String localFilePath,
  }) async {
    try {
      final file = File(localFilePath);
      final fileName =
          'payment_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = storage
          .ref()
          .child('payment_screenshots')
          .child(userId)
          .child(wallpaperId)
          .child(fileName);

      final uploadTask = await ref.putFile(
        file,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return Right(downloadUrl);
    } catch (e) {
      return Left(ServerFailure('Failed to upload screenshot: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> submitManualPayment({
    required String userId,
    required String wallpaperId,
    required double amount,
    required String txnId,
    required String wallpaperTitle,
    String? screenshotUrl,
  }) async {
    try {
      await remoteDataSource.submitPaymentRequest(
        userId: userId,
        wallpaperId: wallpaperId,
        amount: amount,
        txnId: txnId,
        wallpaperTitle: wallpaperTitle,
        screenshotUrl: screenshotUrl,
      );
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
