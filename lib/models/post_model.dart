import 'package:cloud_firestore/cloud_firestore.dart';

class PostModel {
  final String id;
  final String caption;
  final String videoUrl;
  final String userId;
  final String username;
  final String userPhotoUrl;
  final List<String> likes;
  final int comments;
  final int shares;
  final Timestamp? createdAt;

  const PostModel({
    required this.id,
    required this.caption,
    required this.videoUrl,
    required this.userId,
    required this.username,
    required this.userPhotoUrl,
    required this.likes,
    required this.comments,
    required this.shares,
    required this.createdAt,
  });

  factory PostModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return PostModel(
      id: doc.id,
      caption: data['caption']?.toString() ?? '',
      videoUrl: data['videoUrl']?.toString() ?? '',
      userId: data['userId']?.toString() ?? '',
      username: data['username']?.toString() ?? '@likeehit_creator',
      userPhotoUrl: data['userPhotoUrl']?.toString() ?? '',
      likes: (data['likes'] is List)
          ? List<String>.from(data['likes'].map((item) => item.toString()))
          : const [],
      comments: _asInt(data['comments']),
      shares: _asInt(data['shares']),
      createdAt: data['createdAt'] is Timestamp ? data['createdAt'] : null,
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }
}
