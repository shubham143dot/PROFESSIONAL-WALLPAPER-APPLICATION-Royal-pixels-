import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';


import '../../data/datasources/auth_remote_data_source.dart';
import '../../data/datasources/firestore_data_source.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../data/repositories/diamond_repository_impl.dart';
import '../../data/repositories/payment_repository_impl.dart';
import '../../data/repositories/wallpaper_repository_impl.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/diamond_repository.dart';
import '../../domain/repositories/payment_repository.dart';
import '../../domain/repositories/wallpaper_repository.dart';
import '../../domain/usecases/buy_premium_wallpaper_usecase.dart';
import '../../domain/usecases/get_wallpapers_usecase.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/add_wallpaper_usecase.dart';
import '../../domain/usecases/delete_wallpaper_usecase.dart';
import '../../domain/usecases/update_wallpaper_usecase.dart';
import '../../domain/usecases/rename_category_usecase.dart';
import '../../domain/repositories/notification_repository.dart';
import '../../data/repositories/notification_repository_impl.dart';



final sl = GetIt.instance;

Future<void> setupLocator() async {
  // --- External ---
  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerLazySingleton(() => sharedPreferences);

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
  sl.registerLazySingleton<DiamondRepository>(
    () => DiamondRepositoryImpl(dataSource: sl()),
  );

  sl.registerLazySingleton<NotificationRepository>(
    () => NotificationRepositoryImpl(
      firestore: sl(),
      prefs: sl(),
    ),
  );


  // --- Use Cases ---
  sl.registerLazySingleton(() => LoginUseCase(sl()));
  sl.registerLazySingleton(() => GetWallpapersUseCase(sl()));
  sl.registerLazySingleton(() => BuyPremiumWallpaperUseCase(sl()));
  sl.registerLazySingleton(() => AddWallpaperUseCase(sl()));
  sl.registerLazySingleton(() => DeleteWallpaperUseCase(sl()));
  sl.registerLazySingleton(() => UpdateWallpaperUseCase(sl()));
  sl.registerLazySingleton(() => RenameCategoryUseCase(sl()));
}
