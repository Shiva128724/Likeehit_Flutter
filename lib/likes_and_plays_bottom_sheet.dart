import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'profile_screen.dart';
import 'public_profile_screen.dart';

class LikesAndPlaysBottomSheet extends StatefulWidget {
  final List<String> likedUserIds;
  final int viewCount;

  const LikesAndPlaysBottomSheet({
    super.key,
    required this.likedUserIds,
    required this.viewCount,
  });

  @override
  State<LikesAndPlaysBottomSheet> createState() =>
      _LikesAndPlaysBottomSheetState();
}

class _LikesAndPlaysBottomSheetState extends State<LikesAndPlaysBottomSheet> {
  final currentUserId = FirebaseAuth.instance.currentUser?.uid;

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  void _navigateToProfile(String uid) {
    Navigator.pop(context); // Close the bottom sheet
    if (uid == currentUserId) {
      // If I click on my own name, open my existing official main profile screen
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ProfileScreen()),
      );
    } else {
      // If I click on another creator's name, open the fully functional public profile screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PublicProfileScreen(userId: uid),
        ),
      );
    }
  }

  void _toggleFollow(String targetUid, bool isFollowing) async {
    if (currentUserId == null) return;

    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(targetUid)
        .collection('followers')
        .doc(currentUserId);

    if (isFollowing) {
      await docRef.delete();
    } else {
      await docRef.set({'timestamp': FieldValue.serverTimestamp()});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          // Stats Row Layout
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  const Icon(Icons.favorite, color: Colors.redAccent, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    _formatCount(widget.likedUserIds.length),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 32),
              Row(
                children: [
                  const Icon(Icons.visibility, color: Colors.white70, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    _formatCount(widget.viewCount),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white24, height: 1),
          Expanded(
            child: widget.likedUserIds.isEmpty
                ? const Center(
                    child: Text(
                      'No likes yet. Be the first!',
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                : ListView.builder(
                    itemCount: widget.likedUserIds.length,
                    itemBuilder: (context, index) {
                      final uid = widget.likedUserIds[index];
                      return StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .doc(uid)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.white12,
                                child: CupertinoActivityIndicator(
                                  color: Colors.white54,
                                ),
                              ),
                              title: SizedBox(
                                height: 12,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: Colors.white12,
                                  ),
                                ),
                              ),
                            );
                          }

                          if (!snapshot.hasData || !snapshot.data!.exists) {
                            return const SizedBox.shrink(); // Hide if user doesn't exist
                          }

                          final userData =
                              snapshot.data!.data() as Map<String, dynamic>? ??
                              {};
                          final String realName =
                              userData['name'] ??
                              userData['username'] ??
                              userData['displayName'] ??
                              'Likeehit Creator';
                          final String profileDpUrl =
                              userData['profileUrl'] ??
                              userData['photoUrl'] ??
                              userData['profileImage'] ??
                              '';

                          return StreamBuilder<DocumentSnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('users')
                                .doc(uid)
                                .collection('followers')
                                .doc(currentUserId ?? 'unknown')
                                .snapshots(),
                            builder: (context, followSnapshot) {
                              final isFollowing =
                                  followSnapshot.hasData &&
                                  followSnapshot.data!.exists;

                              return InkWell(
                                onTap: () => _navigateToProfile(uid),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.white12,
                                    backgroundImage: profileDpUrl.isNotEmpty
                                        ? NetworkImage(profileDpUrl)
                                        : null,
                                    child: profileDpUrl.isEmpty
                                        ? const Icon(
                                            Icons.person,
                                            color: Colors.white54,
                                          )
                                        : null,
                                  ),
                                  title: Text(
                                    realName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  trailing: uid == currentUserId
                                      ? const SizedBox.shrink()
                                      : ElevatedButton(
                                          onPressed: () =>
                                              _toggleFollow(uid, isFollowing),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: isFollowing
                                                ? Colors.white24
                                                : Colors.redAccent,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            minimumSize: const Size(80, 32),
                                          ),
                                          child: Text(
                                            isFollowing
                                                ? 'Following'
                                                : 'Follow',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
