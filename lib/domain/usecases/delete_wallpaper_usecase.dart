import 'package:dartz/dartz.dart';
import '../../core/error/failures.dart';
import '../../core/usecases/usecase.dart';
import '../repositories/wallpaper_repository.dart';

class DeleteWallpaperUseCase implements UseCase<void, String> {
  final WallpaperRepository repository;

  DeleteWallpaperUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(String id) async {
    return await repository.deleteWallpaper(id);
  }
}
