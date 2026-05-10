import 'package:dartz/dartz.dart';
import '../../core/error/failures.dart';
import '../../core/usecases/usecase.dart';
import '../entities/wallpaper_entity.dart';
import '../repositories/wallpaper_repository.dart';

class GetWallpapersParams {
  final int page;
  final int limit;
  final bool isPremium;

  GetWallpapersParams(
      {required this.page, required this.limit, this.isPremium = false});
}

class GetWallpapersUseCase
    implements UseCase<List<WallpaperEntity>, GetWallpapersParams> {
  final WallpaperRepository repository;

  GetWallpapersUseCase(this.repository);

  @override
  Future<Either<Failure, List<WallpaperEntity>>> call(
      GetWallpapersParams params) async {
    return await repository.getWallpapers(
        page: params.page, limit: params.limit, isPremium: params.isPremium);
  }
}
