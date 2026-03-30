import 'package:dartz/dartz.dart';
import '../../core/error/failures.dart';
import '../entities/wallpaper_entity.dart';

abstract class WallpaperRepository {
  Future<Either<Failure, List<WallpaperEntity>>> getWallpapers({required int page, required int limit, bool isPremium = false});
  Future<Either<Failure, WallpaperEntity>> getWallpaperDetails(String id);
}
