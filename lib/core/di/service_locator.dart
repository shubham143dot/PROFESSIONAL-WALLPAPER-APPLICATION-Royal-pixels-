import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../data/datasources/auth_remote_data_source.dart';
import '../../data/datasources/firestore_data_source.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../data/repositories/payment_repository_impl.dart';
import '../../data/repositories/wallpaper_repository_impl.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/payment_repository.dart';
import '../../domain/repositories/wallpaper_repository.dart';
import '../../domain/usecases/buy_premium_wallpaper_usecase.dart';
import '../../domain/usecases/get_wallpapers_usecase.dart';
import '../../domain/usecases/login_usecase.dart';

final sl = GetIt.instance;

void setupLocator() {
  // --- External ---
  sl.registerLazySingleton(() => FirebaseAuth.instance);
  sl.registerLazySingleton(() => FirebaseFirestore.instance);
  sl.registerLazySingleton(() => FirebaseStorage.instance);
  // The serverClientId (web client ID) is required so that googleAuth.idToken
  // is always populated. Without it, Firebase credential creation will fail.
  sl.registerLazySingleton(() => GoogleSignIn(
    serverClientId: '871231257178-vtn84glpkom9qtrg075tt4hs7uhp0a6h.apps.googleusercontent.com',
  ));

  // --- Data Sources ---
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(
      firebaseAuth: sl(),
      googleSignIn: sl(),
      firestore: sl(),
    ),
  );
  sl.registerLazySingleton<FirestoreDataSource>(
    () => FirestoreDataSourceImpl(firestore: sl()),
  );

  // --- Repositories ---
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton<WallpaperRepository>(
    () => WallpaperRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton<PaymentRepository>(
    () => PaymentRepositoryImpl(remoteDataSource: sl(), storage: sl()),
  );

  // --- Use Cases ---
  sl.registerLazySingleton(() => LoginUseCase(sl()));
  sl.registerLazySingleton(() => GetWallpapersUseCase(sl()));
  sl.registerLazySingleton(() => BuyPremiumWallpaperUseCase(sl()));
}
