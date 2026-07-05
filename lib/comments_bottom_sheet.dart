import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'profile_screen.dart';
import 'public_profile_screen.dart';
import 'services/notification_service.dart';

class CommentsBottomSheet extends StatefulWidget {
  final String videoId;

  const CommentsBottomSheet({super.key, required this.videoId});

  @override
  State<CommentsBottomSheet> createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends State<CommentsBottomSheet> {
  final TextEditingController _commentController = TextEditingController();
  String? _replyToCommentId;
  String? _replyToUsername;

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    } else {
      return count.toString();
    }
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    final uid = currentUser.uid;
    String username =
        currentUser.displayName ??
        currentUser.phoneNumber ??
        'LikeeHit Creator';
    String profilePic = currentUser.photoURL ?? '';
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    final userData = userDoc.data();
    if (userData != null) {
      username =
          userData['username']?.toString() ??
          userData['name']?.toString() ??
          username;
      profilePic =
          userData['photoURL']?.toString() ??
          userData['photoUrl']?.toString() ??
          profilePic;
    }

    if (_replyToCommentId != null) {
      // Add as reply
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.videoId)
          .collection('comments')
          .doc(_replyToCommentId)
          .collection('replies')
          .add({
            'userId': uid,
            'username': username,
            'profilePic': profilePic,
            'text': text,
            'timestamp': FieldValue.serverTimestamp(),
            'comment_likes': [],
          });
    } else {
      // Add as main comment
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.videoId)
          .collection('comments')
          .add({
            'userId': uid,
            'username': username,
            'profilePic': profilePic,
            'text': text,
            'timestamp': FieldValue.serverTimestamp(),
            'comment_likes': [],
          });
    }

    final postDoc = await FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.videoId)
        .get();
    final postData = postDoc.data() ?? const <String, dynamic>{};
    final ownerUid = postData['userId']?.toString() ?? '';
    await AppNotificationService.send(
      ownerUid: ownerUid,
      category: 'comment',
      type: _replyToCommentId == null ? 'video_comment' : 'video_reply',
      title: 'New comment',
      body: 'commented on your video',
      postId: widget.videoId,
      postCaption: postData['caption']?.toString() ?? '',
      postVideoUrl: postData['videoUrl']?.toString() ?? '',
      postThumbnailUrl:
          postData['thumbnailUrl']?.toString() ??
          postData['thumbnail']?.toString() ??
          '',
      commentText: text,
    );

    _commentController.clear();
    if (!mounted) return;
    setState(() {
      _replyToCommentId = null;
      _replyToUsername = null;
    });
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('posts')
                  .doc(widget.videoId)
                  .collection('comments')
                  .snapshots(),
              builder: (context, snapshot) {
                final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                return Text(
                  '${_formatCount(count)} Comments',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
          ),
          const Divider(color: Colors.white24, height: 1),

          // Comments List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('posts')
                  .doc(widget.videoId)
                  .collection('comments')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text(
                      'Error loading comments',
                      style: TextStyle(color: Colors.white),
                    ),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.redAccent),
                  );
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'Be the first to comment!',
                      style: TextStyle(color: Colors.white54),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    return CommentTile(
                      videoId: widget.videoId,
                      commentDoc: docs[index],
                      onReplyTap: (commentId, username) {
                        setState(() {
                          _replyToCommentId = commentId;
                          _replyToUsername = username;
                        });
                        // Focus the text field (could add a FocusNode if needed)
                      },
                    );
                  },
                );
              },
            ),
          ),

          // Reply Indicator
          if (_replyToUsername != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.white10,
              child: Row(
                children: [
                  Text(
                    'Replying to @$_replyToUsername',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _replyToCommentId = null;
                        _replyToUsername = null;
                      });
                    },
                    child: const Icon(
                      Icons.close,
                      color: Colors.white70,
                      size: 16,
                    ),
                  ),
                ],
              ),
            ),

          // Bottom Text Input
          Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              left: 16,
              right: 16,
              top: 12,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF121212),
              border: Border(top: BorderSide(color: Colors.white24, width: 1)),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 18,
                  backgroundImage: NetworkImage('https://picsum.photos/100'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: _replyToUsername != null
                          ? 'Reply to @$_replyToUsername...'
                          : 'Add comment...',
                      hintStyle: const TextStyle(color: Colors.white54),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white12,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _submitComment,
                  child: const Icon(
                    Icons.send,
                    color: Colors.redAccent,
                    size: 28,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CommentTile extends StatelessWidget {
  final String videoId;
  final QueryDocumentSnapshot commentDoc;
  final Function(String, String) onReplyTap;
  final bool isReply;

  const CommentTile({
    super.key,
    required this.videoId,
    required this.commentDoc,
    required this.onReplyTap,
    this.isReply = false,
  });

  void _navigateToProfile(BuildContext context, String commentUserUid) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    Navigator.pop(context); // Dismiss the bottom sheet
    if (commentUserUid == currentUserId) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ProfileScreen()),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PublicProfileScreen(userId: commentUserUid),
        ),
      );
    }
  }

  void _toggleLike(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    final data = commentDoc.data() as Map<String, dynamic>;
    List<dynamic> likes = data.containsKey('comment_likes')
        ? data['comment_likes']
        : [];

    final docRef = isReply
        ? commentDoc
              .reference // For replies, commentDoc is the reply doc
        : FirebaseFirestore.instance
              .collection('posts')
              .doc(videoId)
              .collection('comments')
              .doc(commentDoc.id);

    if (likes.contains(currentUserId)) {
      docRef.update({
        'comment_likes': FieldValue.arrayRemove([currentUserId]),
      });
    } else {
      docRef.update({
        'comment_likes': FieldValue.arrayUnion([currentUserId]),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = commentDoc.data() as Map<String, dynamic>;
    final commentUserUid = data['userId'] ?? 'unknown';
    final username = data['username'] ?? 'User';
    final text = data['text'] ?? '';
    final profilePic = data.containsKey('profilePic')
        ? data['profilePic']
        : 'https://picsum.photos/100';

    List<dynamic> likes = data.containsKey('comment_likes')
        ? data['comment_likes']
        : [];
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isLiked = currentUserId != null && likes.contains(currentUserId);

    return Padding(
      padding: EdgeInsets.only(bottom: 20.0, left: isReply ? 40.0 : 0.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(commentUserUid)
                .snapshots(),
            builder: (context, userSnapshot) {
              String displayUsername = username;
              String displayProfilePic = profilePic;

              if (userSnapshot.hasData &&
                  userSnapshot.data != null &&
                  userSnapshot.data!.exists) {
                final userData =
                    userSnapshot.data!.data() as Map<String, dynamic>?;
                if (userData != null) {
                  displayProfilePic =
                      userData['profileUrl'] ?? userData['photoUrl'] ?? '';
                  displayUsername =
                      userData['username'] ??
                      userData['name'] ??
                      'Likeehit User';
                }
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => _navigateToProfile(context, commentUserUid),
                    child: CircleAvatar(
                      radius: isReply ? 14 : 18,
                      backgroundColor: Colors.grey[800],
                      backgroundImage: displayProfilePic.isNotEmpty
                          ? NetworkImage(displayProfilePic)
                          : null,
                      child: displayProfilePic.isEmpty
                          ? const Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 20,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () =>
                              _navigateToProfile(context, commentUserUid),
                          child: Text(
                            displayUsername,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          text,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Text(
                              'Just now',
                              style: TextStyle(
                                color: Colors.white38,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 16),
                            if (!isReply)
                              GestureDetector(
                                onTap: () =>
                                    onReplyTap(commentDoc.id, displayUsername),
                                child: const Text(
                                  'Reply',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      GestureDetector(
                        onTap: () => _toggleLike(context),
                        child: Icon(
                          isLiked ? Icons.favorite : Icons.favorite_border,
                          color: isLiked ? Colors.redAccent : Colors.white54,
                          size: 16,
                        ),
                      ),
                      if (likes.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            '${likes.length}',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
          // Fetch and display replies if this is a main comment
          if (!isReply)
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('posts')
                  .doc(videoId)
                  .collection('comments')
                  .doc(commentDoc.id)
                  .collection('replies')
                  .orderBy('timestamp', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const SizedBox.shrink();
                }

                final replies = snapshot.data!.docs;
                return Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Column(
                    children: replies.map((replyDoc) {
                      return CommentTile(
                        videoId: videoId,
                        commentDoc: replyDoc,
                        onReplyTap: onReplyTap,
                        isReply: true,
                      );
                    }).toList(),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
