import 'package:dartz/dartz.dart';
import '../../core/error/failures.dart';
import '../repositories/wallpaper_repository.dart';

class UpdateWallpaperUseCase {
  final WallpaperRepository repository;

  UpdateWallpaperUseCase(this.repository);

  Future<Either<Failure, void>> call(String id, String newTitle, String newCategory) async {
    return await repository.updateWallpaper(id, newTitle, newCategory);
  }
}
