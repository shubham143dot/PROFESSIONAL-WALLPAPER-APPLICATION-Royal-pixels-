import 'package:dartz/dartz.dart';
import '../../core/error/failures.dart';
import '../entities/wallpaper_entity.dart';

abstract class WallpaperRepository {
  Future<Either<Failure, List<WallpaperEntity>>> getWallpapers({required int page, required int limit, bool isPremium = false});
  Future<Either<Failure, WallpaperEntity>> getWallpaperDetails(String id);
  Future<Either<Failure, void>> addWallpaper(WallpaperEntity wallpaper);
  Future<Either<Failure, void>> deleteWallpaper(String id);
  Future<Either<Failure, void>> updateWallpaper(String id, String newTitle, String newCategory);
  Future<Either<Failure, void>> renameCategory(String oldName, String newName);
}
