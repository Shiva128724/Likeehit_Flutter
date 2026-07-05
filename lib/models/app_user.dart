import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AppUser {
  final String uid;
  final String name;
  final String username;
  final String email;
  final String phoneNumber;
  final String photoUrl;
  final String bio;
  final int followers;
  final int following;
  final int likes;
  final Timestamp? createdAt;

  const AppUser({
    required this.uid,
    required this.name,
    required this.username,
    required this.email,
    required this.phoneNumber,
    required this.photoUrl,
    required this.bio,
    required this.followers,
    required this.following,
    required this.likes,
    required this.createdAt,
  });

  factory AppUser.fromAuth(User user) {
    final fallbackName = user.displayName?.trim().isNotEmpty == true
        ? user.displayName!.trim()
        : user.phoneNumber ?? 'LikeeHit Creator';
    return AppUser(
      uid: user.uid,
      name: fallbackName,
      username: _usernameFrom(fallbackName, user.uid),
      email: user.email ?? '',
      phoneNumber: user.phoneNumber ?? '',
      photoUrl: user.photoURL ?? '',
      bio: '',
      followers: 0,
      following: 0,
      likes: 0,
      createdAt: null,
    );
  }

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return AppUser(
      uid: data['uid']?.toString() ?? doc.id,
      name:
          data['name']?.toString() ??
          data['displayName']?.toString() ??
          'LikeeHit Creator',
      username:
          data['username']?.toString() ??
          data['bio']?.toString().replaceFirst('@', '') ??
          _usernameFrom(doc.id, doc.id),
      email: data['email']?.toString() ?? '',
      phoneNumber: data['phoneNumber']?.toString() ?? '',
      photoUrl:
          data['photoURL']?.toString() ?? data['photoUrl']?.toString() ?? '',
      bio: data['bio']?.toString() ?? '',
      followers: _asInt(data['followers']),
      following: _asInt(data['following']),
      likes: _asInt(data['likes']),
      createdAt: data['createdAt'] is Timestamp ? data['createdAt'] : null,
    );
  }

  Map<String, dynamic> toCreateMap() {
    return {
      'uid': uid,
      'name': name,
      'displayName': name,
      'username': username,
      'email': email,
      'phoneNumber': phoneNumber,
      'photoURL': photoUrl,
      'photoUrl': photoUrl,
      'bio': bio,
      'followers': followers,
      'following': following,
      'likes': likes,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  static String _usernameFrom(String source, String uid) {
    final cleaned = source
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    final prefix = cleaned.isEmpty ? 'creator' : cleaned;
    return '${prefix}_${uid.substring(0, uid.length < 5 ? uid.length : 5)}';
  }
}
