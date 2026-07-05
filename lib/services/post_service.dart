import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/app_user.dart';
import '../models/post_model.dart';
import 'notification_service.dart';

class PostService {
  PostService._();

  static final PostService instance = PostService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Stream<List<PostModel>> feed() {
    return _firestore
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(PostModel.fromDoc).toList());
  }

  Stream<List<PostModel>> postsForUser(String uid) {
    return _firestore
        .collection('posts')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(PostModel.fromDoc).toList());
  }

  Future<void> uploadVideo({
    required File file,
    required String caption,
    String privacy = 'Everyone',
    String location = '',
    String? attachedLink,
    List<String> taggedUsers = const [],
    bool allowComments = true,
    bool isHighQuality = true,
    void Function(double progress)? onProgress,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('You must be signed in to post a video.');
    }

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final appUser = userDoc.exists
        ? AppUser.fromDoc(userDoc)
        : AppUser.fromAuth(user);

    final postRef = _firestore.collection('posts').doc();
    final storageRef = _storage.ref('videos/${user.uid}/${postRef.id}.mp4');
    final uploadTask = storageRef.putFile(
      file,
      SettableMetadata(contentType: 'video/mp4'),
    );

    uploadTask.snapshotEvents.listen((snapshot) {
      if (snapshot.totalBytes > 0) {
        onProgress?.call(snapshot.bytesTransferred / snapshot.totalBytes);
      }
    });

    final snapshot = await uploadTask;
    final downloadUrl = await snapshot.ref.getDownloadURL();

    await postRef.set({
      'caption': caption,
      'videoUrl': downloadUrl,
      'likes': <String>[],
      'comments': 0,
      'shares': 0,
      'views': 0,
      'viewsCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'userId': user.uid,
      'username': '@${appUser.username}',
      'userPhotoUrl': appUser.photoUrl,
      'privacy': privacy,
      'location': location,
      'attachedLink': attachedLink,
      'taggedUsers': taggedUsers,
      'allowComments': allowComments,
      'isHighQuality': isHighQuality,
    });

    await AppNotificationService.sendPostMentionNotifications(
      taggedUsers: taggedUsers,
      postId: postRef.id,
      postCaption: caption,
      postVideoUrl: downloadUrl,
    );
  }
}
