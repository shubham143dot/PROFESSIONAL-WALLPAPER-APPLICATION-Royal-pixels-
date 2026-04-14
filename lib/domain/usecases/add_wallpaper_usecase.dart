import 'package:dartz/dartz.dart';
import '../../core/error/failures.dart';
import '../../domain/entities/wallpaper_entity.dart';
import '../../domain/repositories/wallpaper_repository.dart';

class AddWallpaperUseCase {
  final WallpaperRepository repository;

  AddWallpaperUseCase(this.repository);

  Future<Either<Failure, void>> call(WallpaperEntity wallpaper) async {
    return await repository.addWallpaper(wallpaper);
  }
}
