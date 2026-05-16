import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/di/service_locator.dart';
import '../../core/usecases/usecase.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../data/datasources/firestore_data_source.dart';
import '../../domain/repositories/auth_repository.dart';
import 'diamond_provider.dart';
import 'notification_provider.dart';
import '../../data/models/notification_model.dart';
import '../../core/services/notification_service.dart';
import 'dart:convert';
import '../../core/constants/app_constants.dart';
import '../../core/services/reward_ad_service.dart';
import '../../core/services/ad_service.dart';

final authProvider = NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});

class AuthState {
  final bool isLoading;
  final UserEntity? user;
  final String? error;

  /// True when user chose "Continue as Guest" — no Firebase Auth session
  final bool isGuest;

  AuthState({
    this.isLoading = false,
    this.user,
    this.error,
    this.isGuest = false,
  });

  bool get isAuthenticated => user != null && !isGuest;

  AuthState copyWith({
    bool? isLoading,
    UserEntity? user,
    String? error,
    bool? isGuest,
    bool clearError = false,
    bool clearUser = false,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      user: clearUser ? null : (user ?? this.user),
      error: clearError ? null : (error ?? this.error),
      isGuest: isGuest ?? this.isGuest,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  static const _guestKey = 'guest_mode';
  StreamSubscription? _userSubscription;

  @override
  AuthState build() {
    try {
      // Check if a real user is already signed in (Firebase persists this)
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        Future.microtask(() async {
          try {
            sl<FirestoreDataSource>().updateUserActivity(currentUser.uid);
            // Upload FCM token for testers and reliable notifications
            await NotificationService.uploadFCMToken(currentUser.uid);
            
            // Initial fetch to get the user data immediately
            final result = await sl<AuthRepository>().getCurrentUser();
            result.fold(
              (_) => null,
              (userData) {
                if (userData != null) {
                  state = state.copyWith(user: userData);
                  ref.read(diamondProvider.notifier).load(userData.uid);
                }
              },
            );

            // Start real-time listener
            _startUserListener(currentUser.uid);
            
            // Sync Ad Services with current user
            RewardAdService.instance.updateUserId(currentUser.uid);
            AdService.instance.updateUserId(currentUser.uid);
          } catch (_) {}
        });

        // Return a temporary state with ID so we don't flash "Not Logged In" if user exists
        return AuthState(
          user: UserEntity(
            uid: currentUser.uid,
            name: currentUser.displayName ?? 'User',
            email: currentUser.email ?? '',
            photoUrl: currentUser.photoURL,
            ownedWallpaperCount: 0,
            appVersion: AppConstants.appVersion,
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            'AuthNotifier build: Firebase Auth not initialized or failed: $e');
      }
    }

    // Check if user previously chose guest mode (persists across restarts)
    _restoreGuestMode();
    
    // Ensure we cancel any existing subscription on rebuild if user is null
    ref.onDispose(() => _userSubscription?.cancel());
    
    return AuthState();
  }

  void _startUserListener(String userId) {
    _userSubscription?.cancel();
    _userSubscription = sl<AuthRepository>().watchUser(userId).listen((result) {
      result.fold(
        (failure) {
          if (kDebugMode) debugPrint('User listener error: ${failure.message}');
        },
        (user) {
          if (user != null) {
            state = state.copyWith(user: user);
            // Also sync diamonds to diamondProvider if they changed
            // This ensures both providers see the real-time update
            ref.read(diamondProvider.notifier).updateFromUser(user);
          }
        },
      );
    });
  }

  /// Reads SharedPreferences asynchronously and sets guest mode if needed.
  Future<void> _restoreGuestMode() async {
    final prefs = await SharedPreferences.getInstance();
    final isGuest = prefs.getBool(_guestKey) ?? false;
    if (isGuest && state.user == null) {
      state = state.copyWith(isGuest: true);
    }
  }

  /// Allows the user to skip login and browse as a guest.
  Future<void> continueAsGuest() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_guestKey, true);
    state = state.copyWith(isGuest: true, clearError: true);
  }

  Future<void> loginWithGoogle() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final loginUseCase = sl<LoginUseCase>();
      final result = await loginUseCase(NoParams());

      await result.fold(
        (failure) async =>
            state = state.copyWith(isLoading: false, error: failure.message),
        (user) async {
          // If we were in guest mode, merge guest data before clearing
          final wasGuest = state.isGuest;
          if (wasGuest) {
            await _mergeGuestDataToAccount(user);
          }
          sl<FirestoreDataSource>().updateUserActivity(user.uid);
          // Upload FCM token upon login
          await NotificationService.uploadFCMToken(user.uid);
          
          // Sync Ad Services with current user
          await RewardAdService.instance.updateUserId(user.uid);
          AdService.instance.updateUserId(user.uid);
          
          state = AuthState(user: user); // clear guest flag
          
          // Start real-time listener
          _startUserListener(user.uid);
          
          ref.read(diamondProvider.notifier).load(user.uid);
        },
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Copies guest-stored data (favorites, streak) into the real user account.
  Future<void> _mergeGuestDataToAccount(UserEntity user) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // --- 1. Merge favorites ---
      final guestFavs = prefs.getStringList('favorite_wallpaper_ids') ?? [];
      if (guestFavs.isNotEmpty) {
        final firestore = sl<FirebaseFirestore>();
        final batch = firestore.batch();

        // Write to user doc
        batch.set(
          firestore.collection('users').doc(user.uid),
          {'liked_wallpapers': FieldValue.arrayUnion(guestFavs)},
          SetOptions(merge: true),
        );

        // Also update the global like_count for each wallpaper in the batch
        for (var id in guestFavs) {
          batch.update(
            firestore.collection('wallpapers').doc(id),
            {'like_count': FieldValue.increment(1)},
          );
        }

        await batch.commit();
      }

      // --- 2. Merge streak —  use the higher value ---
      final guestStreak = prefs.getInt('guest_streak_count') ?? 0;
      if (guestStreak > 0) {
        // Only update if guest streak is higher than what Firestore has
        final firestore = sl<FirebaseFirestore>();
        final doc = await firestore.collection('users').doc(user.uid).get();
        final firestoreStreak = (doc.data()?['streak'] as int?) ?? 0;
        if (guestStreak > firestoreStreak) {
          await firestore.collection('users').doc(user.uid).set(
            {'streak': guestStreak},
            SetOptions(merge: true),
          );
        }
      }

      // --- 3. Clear guest keys ---
      await prefs.remove(_guestKey);
      await prefs.remove('guest_streak_count');
      await prefs.remove('guest_streak_date');

      // --- 4. Merge notifications ---
      final localNotifsJson = prefs.getString('local_notifications');
      if (localNotifsJson != null) {
        final List<dynamic> jsonList = json.decode(localNotifsJson);
        final firestore = sl<FirebaseFirestore>();
        final batch = firestore.batch();

        for (var item in jsonList) {
          final model = NotificationModel.fromJson(item);
          final ref = firestore
              .collection('users')
              .doc(user.uid)
              .collection('notifications')
              .doc(model.id);
          batch.set(ref, model.toFirestore());
        }
        await batch.commit();
        await prefs.remove('local_notifications');

        // Refresh notifications to show migrated ones
        ref.invalidate(notificationProvider);
      }
    } catch (e) {
      // Non-fatal: if merge fails, continue login normally
      if (kDebugMode) {
        debugPrint('Guest data merge failed: $e');
      }
    }
  }

  /// Re-fetches the current user document from Firestore and updates state.
  Future<void> refreshUser() async {
    final result = await sl<AuthRepository>().getCurrentUser();
    result.fold(
      (_) => null,
      (userData) {
        if (userData != null) {
          state = state.copyWith(user: userData);
          ref.read(diamondProvider.notifier).updateFromUser(userData);
        }
      },
    );
  }

  Future<void> logout() async {
    _userSubscription?.cancel();
    _userSubscription = null;
    
    try {
      final googleSignIn = sl<GoogleSignIn>();
      await googleSignIn.signOut();
    } catch (_) {}
    // Also clear guest mode flag
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_guestKey);

    // Clear Ad Services state
    RewardAdService.instance.updateUserId(null);
    AdService.instance.updateUserId(null);

    state = AuthState(); // Clear all state
  }
}
