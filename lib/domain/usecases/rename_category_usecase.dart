import 'package:dartz/dartz.dart';
import '../../core/error/failures.dart';
import '../repositories/wallpaper_repository.dart';

class RenameCategoryUseCase {
  final WallpaperRepository repository;

  RenameCategoryUseCase(this.repository);

  Future<Either<Failure, void>> call(String oldName, String newName) async {
    return await repository.renameCategory(oldName, newName);
  }
}
