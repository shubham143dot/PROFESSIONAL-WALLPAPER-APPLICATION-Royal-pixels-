import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../core/di/service_locator.dart';
import '../../core/usecases/usecase.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../data/datasources/firestore_data_source.dart';
import '../../domain/repositories/auth_repository.dart';
import 'diamond_provider.dart';

final authProvider = NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});

class AuthState {
  final bool isLoading;
  final UserEntity? user;
  final String? error;

  AuthState({
    this.isLoading = false,
    this.user,
    this.error,
  });

  AuthState copyWith({
    bool? isLoading,
    UserEntity? user,
    String? error,
    bool clearError = false,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      user: user ?? this.user,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    // Check if a user is already signed in (persists between restarts)
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      // Hydrate with proper Firestore user data shortly after build
      Future.microtask(() async {
        sl<FirestoreDataSource>().updateUserActivity(currentUser.uid);
        final result = await sl<AuthRepository>().getCurrentUser();
        result.fold(
          (_) => null,
          (userData) {
            if (userData != null) {
              state = state.copyWith(user: userData);
              // Load diamond wallet for restored session
              ref.read(diamondProvider.notifier).load(userData.uid);
            }
          },
        );
      });
      return AuthState(
        user: UserEntity(
          uid: currentUser.uid,
          name: currentUser.displayName ?? 'User',
          email: currentUser.email ?? '',
          ownedWallpaperCount: 0,
        ),
      );
    }
    return AuthState();
  }

  Future<void> loginWithGoogle() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final loginUseCase = sl<LoginUseCase>();
      final result = await loginUseCase(NoParams());

      result.fold(
        (failure) => state = state.copyWith(isLoading: false, error: failure.message),
        (user) {
          sl<FirestoreDataSource>().updateUserActivity(user.uid);
          state = state.copyWith(isLoading: false, user: user);
          // Load diamond wallet after Google login
          ref.read(diamondProvider.notifier).load(user.uid);
        },
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Re-fetches the current user document from Firestore and updates state.
  /// Call this after a subscription payment to reflect isSubscribed immediately.
  Future<void> refreshUser() async {
    final result = await sl<AuthRepository>().getCurrentUser();
    result.fold(
      (_) => null,
      (userData) {
        if (userData != null) {
          state = state.copyWith(user: userData);
        }
      },
    );
  }

  Future<void> logout() async {
    try {
      // Sign out from GoogleSignIn first so the account picker shows on next login
      final googleSignIn = sl<GoogleSignIn>();
      await googleSignIn.signOut();
    } catch (_) {
      // Ignore GoogleSignIn errors during logout
    }
    await FirebaseAuth.instance.signOut();
    state = AuthState(); // Clear user state
  }
}
