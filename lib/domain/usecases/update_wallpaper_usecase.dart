import 'package:dartz/dartz.dart';
import '../../core/error/failures.dart';
import '../repositories/wallpaper_repository.dart';

class UpdateWallpaperUseCase {
  final WallpaperRepository repository;

  UpdateWallpaperUseCase(this.repository);

  Future<Either<Failure, void>> call(
    String id, {
    required String newTitle,
    required String newCategory,
    required bool isPremium,
    required int diamondCost,
    required List<String> tags,
  }) async {
    return await repository.updateWallpaper(
      id,
      newTitle: newTitle,
      newCategory: newCategory,
      isPremium: isPremium,
      diamondCost: diamondCost,
      tags: tags,
    );
  }
}
