import 'package:dartz/dartz.dart';
import '../../core/error/failures.dart';
import '../../domain/entities/wallpaper_entity.dart';
import '../../domain/repositories/wallpaper_repository.dart';
import '../datasources/firestore_data_source.dart';
import '../models/wallpaper_model.dart';

class WallpaperRepositoryImpl implements WallpaperRepository {
  final FirestoreDataSource remoteDataSource;

  WallpaperRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, List<WallpaperEntity>>> getWallpapers(
      {required int page, required int limit, bool isPremium = false}) async {
    try {
      final models = await remoteDataSource.getWallpapers(
          page: page, limit: limit, isPremium: isPremium);
      return Right(models);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, WallpaperEntity>> getWallpaperDetails(
      String id) async {
    try {
      final model = await remoteDataSource.getWallpaperDetails(id);
      return Right(model);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, String>> addWallpaper(
      WallpaperEntity wallpaper) async {
    try {
      final model = WallpaperModel(
        id: wallpaper.id,
        title: wallpaper.title,
        imageUrl: wallpaper.imageUrl,
        category: wallpaper.category,
        isPremium: wallpaper.isPremium,
        diamondCost: wallpaper.diamondCost,
        tags: wallpaper.tags,
      );
      final docId = await remoteDataSource.addWallpaper(model);
      return Right(docId);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteWallpaper(String id) async {
    try {
      await remoteDataSource.deleteWallpaper(id);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updateWallpaper(String id,
      {required String newTitle,
      required String newCategory,
      required bool isPremium,
      required int diamondCost,
      required List<String> tags}) async {
    try {
      await remoteDataSource.updateWallpaper(id,
          newTitle: newTitle,
          newCategory: newCategory,
          isPremium: isPremium,
          diamondCost: diamondCost,
          tags: tags);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> renameCategory(
      String oldName, String newName) async {
    try {
      await remoteDataSource.renameCategory(oldName, newName);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<void> incrementViewCount(String id, {String? userId}) async {
    await remoteDataSource.incrementViewCount(id, userId: userId);
  }

  @override
  Future<Either<Failure, bool>> toggleLike(String userId, String id,
      {bool isFavorite = true}) async {
    try {
      final isLiked =
          await remoteDataSource.toggleLike(userId, id, isFavorite: isFavorite);
      return Right(isLiked);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<void> toggleLikeAnonymous(String id, bool isAdding) async {
    await remoteDataSource.toggleLikeAnonymous(id, isAdding);
  }

  @override
  Future<void> incrementShareCount(String id) async {
    await remoteDataSource.incrementShareCount(id);
  }
}
