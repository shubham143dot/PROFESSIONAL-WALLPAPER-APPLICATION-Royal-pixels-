import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';
import '../../core/constants/app_constants.dart';

abstract class AuthRemoteDataSource {
  Future<UserModel> signInWithGoogle();
  Future<void> signOut();
  Future<UserModel?> getCurrentUser();
  Stream<UserModel?> watchUser(String userId);
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final auth.FirebaseAuth firebaseAuth;
  final GoogleSignIn googleSignIn;
  final FirebaseFirestore firestore;

  AuthRemoteDataSourceImpl({
    required this.firebaseAuth,
    required this.googleSignIn,
    required this.firestore,
  });

  @override
  Stream<UserModel?> watchUser(String userId) {
    return firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) => doc.exists ? UserModel.fromFirestore(doc.data()!, doc.id) : null);
  }

  @override
  Future<UserModel> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser;
    try {
      googleUser = await googleSignIn.signIn();
    } catch (e) {
      throw Exception('Google Sign-In failed to open: $e');
    }

    if (googleUser == null) {
      throw Exception('Google Sign-In was cancelled by the user');
    }

    final GoogleSignInAuthentication googleAuth;
    try {
      googleAuth = await googleUser.authentication;
    } catch (e) {
      throw Exception('Failed to get Google Authentication: $e');
    }

    // idToken can be null if serverClientId is not configured in GoogleSignIn.
    // Ensure the service_locator.dart passes serverClientId to GoogleSignIn().
    if (googleAuth.idToken == null) {
      throw Exception(
        'Google Sign-In failed: idToken is null. '
        'This usually means the SHA-1 fingerprint of your app is not registered in the Firebase Console, '
        'or the serverClientId is incorrect.',
      );
    }

    final auth.OAuthCredential credential = auth.GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
      accessToken: googleAuth.accessToken,
    );

    final auth.UserCredential userCredential;
    try {
      userCredential = await firebaseAuth.signInWithCredential(credential);
    } catch (e) {
      throw Exception('Firebase authentication failed: $e');
    }

    final auth.User? user = userCredential.user;

    if (user == null) {
      throw Exception('Failed to get Firebase user');
    }

    try {
      // Check if user exists in Firestore
      final userDoc = await firestore.collection('users').doc(user.uid).get();

    UserModel userModel;
    if (userDoc.exists) {
      // Update login history, version, and profile info
      await firestore.collection('users').doc(user.uid).update({
        'login_history': FieldValue.serverTimestamp(),
        'app_version': AppConstants.appVersion,
        if (user.displayName != null) 'name': user.displayName,
        if (user.photoURL != null) 'photo_url': user.photoURL,
      });
      userModel = UserModel.fromFirestore(userDoc.data()!, user.uid);
    } else {
      // Create new user
      userModel = UserModel(
        uid: user.uid,
        name: user.displayName ?? 'Unknown',
        email: user.email ?? '',
        photoUrl: user.photoURL,
        phoneNo: user.phoneNumber,
        loginHistory: DateTime.now(),
        ownedWallpaperCount: 0,
        appVersion: AppConstants.appVersion,
      );
      await firestore.collection('users').doc(user.uid).set({
        ...userModel.toFirestore(),
        'liked_wallpapers': [],
        'login_history': FieldValue.serverTimestamp(),
        'app_version': AppConstants.appVersion,
      });
    }

      return userModel;
    } catch (e) {
      if (e.toString().contains('permission-denied') || e.toString().contains('app-check')) {
        throw Exception(
          'Firestore access denied. This is likely due to Firebase App Check. '
          'Please ensure the app is registered in Play Integrity and the SHA-256 fingerprint is added to the Google Play Console.',
        );
      }
      throw Exception('Failed to sync user data with Firestore: $e');
    }
  }

  @override
  Future<void> signOut() async {
    await googleSignIn.signOut();
    await firebaseAuth.signOut();
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    final user = firebaseAuth.currentUser;
    if (user != null) {
      final userDoc = await firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        return UserModel.fromFirestore(userDoc.data()!, user.uid);
      } else {
        // Critical Fix: If user exists in Auth but document is missing in Firestore,
        // create it now. This fixes the "Likes not working for non-admins" issue
        // where users were missing their profile documents.
        final userModel = UserModel(
          uid: user.uid,
          name: user.displayName ?? 'User',
          email: user.email ?? '',
          photoUrl: user.photoURL,
          phoneNo: user.phoneNumber,
          loginHistory: DateTime.now(),
          ownedWallpaperCount: 0,
          appVersion: AppConstants.appVersion,
        );

        await firestore.collection('users').doc(user.uid).set({
          ...userModel.toFirestore(),
          'liked_wallpapers': [],
          'login_history': FieldValue.serverTimestamp(),
          'app_version': AppConstants.appVersion,
        });

        return userModel;
      }
    }
    return null;
  }
}
