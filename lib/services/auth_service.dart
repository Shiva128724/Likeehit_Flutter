import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../firebase_options.dart';
import '../models/app_user.dart';

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _googleInitialized = false;

  static const String _defaultWebClientId =
      '82314281320-agnul0gorugou8dofolpa2ir1d943rsn.apps.googleusercontent.com';

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  String get _webClientId =>
      dotenv.env['GOOGLE_WEB_CLIENT_ID']?.trim().isNotEmpty == true
          ? dotenv.env['GOOGLE_WEB_CLIENT_ID']!.trim()
          : _defaultWebClientId;

  String get _iosClientId =>
      dotenv.env['GOOGLE_IOS_CLIENT_ID']?.trim().isNotEmpty == true
          ? dotenv.env['GOOGLE_IOS_CLIENT_ID']!.trim()
          : DefaultFirebaseOptions.ios.iosClientId!;

  String? get _serverClientId {
    final configured = dotenv.env['GOOGLE_SERVER_CLIENT_ID']?.trim();
    if (configured != null && configured.isNotEmpty) {
      return configured;
    }
    return _defaultWebClientId;
  }

  Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) return;

    if (kIsWeb) {
      await GoogleSignIn.instance.initialize(
        clientId: _webClientId,
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      await GoogleSignIn.instance.initialize(
        clientId: _iosClientId,
        serverClientId: _serverClientId,
      );
    } else {
      await GoogleSignIn.instance.initialize(
        serverClientId: _serverClientId,
      );
    }

    _googleInitialized = true;
  }

  Future<UserCredential> signInWithGoogle() async {
    await _ensureGoogleInitialized();
    final account = await GoogleSignIn.instance.authenticate();
    final auth = account.authentication;
    final credential = GoogleAuthProvider.credential(idToken: auth.idToken);
    final userCredential = await _auth.signInWithCredential(credential);
    await ensureUserProfile(userCredential.user);
    return userCredential;
  }

  Future<void> startPhoneVerification({
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken) codeSent,
    required void Function(String message) failed,
    void Function(UserCredential credential)? completed,
  }) {
    return _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (credential) async {
        final userCredential = await _auth.signInWithCredential(credential);
        await ensureUserProfile(userCredential.user);
        completed?.call(userCredential);
      },
      verificationFailed: (error) {
        failed(error.message ?? error.code);
      },
      codeSent: codeSent,
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  Future<UserCredential> verifyPhoneOtp({
    required String verificationId,
    required String smsCode,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    final userCredential = await _auth.signInWithCredential(credential);
    await ensureUserProfile(userCredential.user);
    return userCredential;
  }

  Future<void> ensureUserProfile(User? user) async {
    if (user == null) return;
    final docRef = _firestore.collection('users').doc(user.uid);
    final doc = await docRef.get();
    final profile = AppUser.fromAuth(user);

    if (!doc.exists) {
      await docRef.set(profile.toCreateMap());
      return;
    }

    await docRef.set({
      'uid': user.uid,
      'name': user.displayName ?? doc.data()?['name'] ?? profile.name,
      'displayName':
          user.displayName ?? doc.data()?['displayName'] ?? profile.name,
      'username': doc.data()?['username'] ?? profile.username,
      'email': user.email ?? doc.data()?['email'] ?? '',
      'phoneNumber': user.phoneNumber ?? doc.data()?['phoneNumber'] ?? '',
      'photoURL': user.photoURL ?? doc.data()?['photoURL'] ?? '',
      'photoUrl': user.photoURL ?? doc.data()?['photoUrl'] ?? '',
      'followers': doc.data()?['followers'] ?? 0,
      'following': doc.data()?['following'] ?? 0,
      'likes': doc.data()?['likes'] ?? 0,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> signOut() async {
    await _ensureGoogleInitialized();
    await GoogleSignIn.instance.signOut();
    await _auth.signOut();
  }
}
