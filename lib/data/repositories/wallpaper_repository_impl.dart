import 'package:dartz/dartz.dart';
import '../../core/error/failures.dart';
import '../../domain/entities/wallpaper_entity.dart';
import '../../domain/repositories/wallpaper_repository.dart';
import '../datasources/firestore_data_source.dart';

class WallpaperRepositoryImpl implements WallpaperRepository {
  final FirestoreDataSource remoteDataSource;

  WallpaperRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, List<WallpaperEntity>>> getWallpapers({required int page, required int limit, bool isPremium = false}) async {
    try {
      final models = await remoteDataSource.getWallpapers(page: page, limit: limit, isPremium: isPremium);
      return Right(models);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, WallpaperEntity>> getWallpaperDetails(String id) async {
    try {
      final model = await remoteDataSource.getWallpaperDetails(id);
      return Right(model);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
