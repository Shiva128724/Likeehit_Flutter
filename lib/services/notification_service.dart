import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AppNotificationService {
  AppNotificationService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Future<void> send({
    required String ownerUid,
    required String category,
    required String type,
    required String title,
    required String body,
    String? dedupeKey,
    String postId = '',
    String postCaption = '',
    String postThumbnailUrl = '',
    String postVideoUrl = '',
    String commentText = '',
    String giftName = '',
    int giftStars = 0,
    int giftCount = 1,
    Map<String, dynamic> extra = const <String, dynamic>{},
  }) async {
    final actor = FirebaseAuth.instance.currentUser;
    if (actor == null || ownerUid.isEmpty) return;

    final actorData = await _userData(actor.uid);
    final actorName =
        _firstText(actorData, const ['name', 'username', 'displayName']) ??
        actor.displayName ??
        actor.phoneNumber ??
        'Likeehit User';
    final actorPhotoUrl =
        _firstText(actorData, const ['photoURL', 'photoUrl', 'profilePic']) ??
        actor.photoURL ??
        '';

    final notificationsRef = _db
        .collection('users')
        .doc(ownerUid)
        .collection('notifications');
    final ref = dedupeKey?.isNotEmpty == true
        ? notificationsRef.doc(dedupeKey)
        : notificationsRef.doc();

    await ref.set({
      'category': category,
      'type': type,
      'title': title,
      'body': body,
      'actorUid': actor.uid,
      'actorName': actorName,
      'actorPhotoUrl': actorPhotoUrl,
      'ownerUid': ownerUid,
      'postId': postId,
      'postCaption': postCaption,
      'postThumbnailUrl': postThumbnailUrl,
      'postVideoUrl': postVideoUrl,
      'commentText': commentText,
      'giftName': giftName,
      'giftStars': giftStars,
      'giftCount': giftCount,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      ...extra,
    }, SetOptions(merge: true));
  }

  static Future<void> sendPostMentionNotifications({
    required List<String> taggedUsers,
    required String postId,
    required String postCaption,
    required String postVideoUrl,
    String postThumbnailUrl = '',
  }) async {
    final seen = <String>{};
    for (final rawTag in taggedUsers) {
      final uid = await _resolveTaggedUserUid(rawTag);
      if (uid == null || !seen.add(uid)) continue;
      await send(
        ownerUid: uid,
        category: 'mention',
        type: 'reel_mention',
        title: 'Mentioned you in a reel',
        body: 'tagged you in a video',
        postId: postId,
        postCaption: postCaption,
        postVideoUrl: postVideoUrl,
        postThumbnailUrl: postThumbnailUrl,
        dedupeKey: 'mention_${postId}_$uid',
      );
    }
  }

  static Future<Map<String, dynamic>> _userData(String uid) async {
    final snap = await _db.collection('users').doc(uid).get();
    return snap.data() ?? const <String, dynamic>{};
  }

  static String? _firstText(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  static Future<String?> _resolveTaggedUserUid(String rawTag) async {
    final tag = rawTag.trim().replaceFirst(RegExp('^@+'), '');
    if (tag.isEmpty) return null;

    final direct = await _db.collection('users').doc(tag).get();
    if (direct.exists) return direct.id;

    for (final field in const ['username', 'name', 'displayName']) {
      final snap = await _db
          .collection('users')
          .where(field, isEqualTo: tag)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) return snap.docs.first.id;

      final atSnap = await _db
          .collection('users')
          .where(field, isEqualTo: '@$tag')
          .limit(1)
          .get();
      if (atSnap.docs.isNotEmpty) return atSnap.docs.first.id;
    }
    return null;
  }
}
