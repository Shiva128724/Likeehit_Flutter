import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/app_user.dart';

class UserService {
  UserService._();

  static final UserService instance = UserService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Stream<AppUser> currentUserProfile() {
    final user = _auth.currentUser;
    if (user == null) {
      return const Stream.empty();
    }
    return _firestore
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .map(AppUser.fromDoc);
  }

  Stream<AppUser> userProfile(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .map(AppUser.fromDoc);
  }

  Future<Map<String, dynamic>> currentUserProfileData() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('You must be signed in to edit your profile.');
    }
    final snapshot = await _firestore.collection('users').doc(uid).get();
    return snapshot.data() ?? <String, dynamic>{};
  }

  Future<void> updateProfile({
    required String name,
    required String username,
    required String bio,
    String? website,
    String? category,
    String? gender,
    DateTime? birthday,
    String? photoUrl,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('You must be signed in to edit your profile.');
    }
    final updates = <String, dynamic>{
      'name': name,
      'displayName': name,
      'username': username,
      'bio': bio,
      'website': website ?? '',
      'category': category ?? '',
      'gender': gender ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (birthday != null) {
      updates['birthday'] = Timestamp.fromDate(birthday);
    }
    if (photoUrl != null) {
      updates['photoURL'] = photoUrl;
      updates['photoUrl'] = photoUrl;
    }
    await _firestore
        .collection('users')
        .doc(uid)
        .set(updates, SetOptions(merge: true));
  }

  Future<String> uploadProfileImage(File file) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('You must be signed in to upload a profile image.');
    }
    final ref = _storage.ref('users/$uid/profile.jpg');
    final snapshot = await ref.putFile(file);
    final url = await snapshot.ref.getDownloadURL();
    return url;
  }

  Future<String> uploadProfileImageBytes(Uint8List bytes) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('You must be signed in to upload a profile image.');
    }
    final ref = _storage.ref('users/$uid/profile.jpg');
    final snapshot = await ref.putData(
      bytes,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return snapshot.ref.getDownloadURL();
  }
}
