import 'package:dartz/dartz.dart';
import '../../core/error/failures.dart';
import '../entities/wallpaper_entity.dart';

abstract class WallpaperRepository {
  Future<Either<Failure, List<WallpaperEntity>>> getWallpapers(
      {required int page, required int limit, bool isPremium = false});
  Future<Either<Failure, WallpaperEntity>> getWallpaperDetails(String id);
  Future<Either<Failure, String>> addWallpaper(WallpaperEntity wallpaper);
  Future<Either<Failure, void>> deleteWallpaper(String id);
  Future<Either<Failure, void>> updateWallpaper(String id,
      {required String newTitle,
      required String newCategory,
      required bool isPremium,
      required int diamondCost,
      required List<String> tags});
  Future<Either<Failure, void>> renameCategory(String oldName, String newName);
  Future<void> incrementViewCount(String id, {String? userId});
  Future<Either<Failure, bool>> toggleLike(String userId, String id,
      {bool isFavorite = true});
  Future<void> toggleLikeAnonymous(String id, bool isAdding);
  Future<void> incrementShareCount(String id);
}
