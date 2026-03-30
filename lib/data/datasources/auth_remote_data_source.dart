import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';

abstract class AuthRemoteDataSource {
  Future<UserModel> signInWithGoogle();
  Future<void> signOut();
  Future<UserModel?> getCurrentUser();
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
  Future<UserModel> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
    if (googleUser == null) {
      throw Exception('Google Sign-In was cancelled by the user');
    }

    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

    // idToken can be null if serverClientId is not configured in GoogleSignIn.
    // Ensure the service_locator.dart passes serverClientId to GoogleSignIn().
    if (googleAuth.idToken == null) {
      throw Exception(
        'Google Sign-In failed: idToken is null. '
        'Make sure serverClientId is set in GoogleSignIn().',
      );
    }

    final auth.OAuthCredential credential = auth.GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final auth.UserCredential userCredential = await firebaseAuth.signInWithCredential(credential);
    final auth.User? user = userCredential.user;

    if (user == null) {
      throw Exception('Failed to get Firebase user');
    }

    // Check if user exists in Firestore
    final userDoc = await firestore.collection('users').doc(user.uid).get();
    
    UserModel userModel;
    if (userDoc.exists) {
      // Update login history
      await firestore.collection('users').doc(user.uid).update({
        'login_history': FieldValue.serverTimestamp(),
      });
      userModel = UserModel.fromFirestore(userDoc.data()!, user.uid);
    } else {
      // Create new user
      userModel = UserModel(
        uid: user.uid,
        name: user.displayName ?? 'Unknown',
        email: user.email ?? '',
        phoneNo: user.phoneNumber,
        loginHistory: DateTime.now(),
        ownedWallpaperCount: 0,
      );
      await firestore.collection('users').doc(user.uid).set({
        ...userModel.toFirestore(),
        'login_history': FieldValue.serverTimestamp(),
      });
    }

    return userModel;
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
      }
    }
    return null;
  }
}
