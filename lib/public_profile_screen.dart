import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'my_level_page.dart';
import 'services/level_service.dart';
import 'video_feed_screen.dart';

class PublicProfileScreen extends StatefulWidget {
  final String userId;
  const PublicProfileScreen({super.key, required this.userId});

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is List) return value.length;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _profileIdFrom(Map<String, dynamic> data, String uid) {
    final username = data['username']?.toString().trim();
    if (username != null && username.isNotEmpty) return username;
    final publicId = data['publicId']?.toString().trim();
    if (publicId != null && publicId.isNotEmpty) return publicId;
    return uid.length > 10 ? uid.substring(0, 10) : uid;
  }

  Future<void> _copyProfileId(String publicId) async {
    await Clipboard.setData(ClipboardData(text: publicId));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Profile ID copied')));
  }

  @override
  Widget build(BuildContext context) {
    final uid = widget.userId;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, snapshot) {
        String displayName = 'Guest User';
        String bio = '@guest';
        String? photoUrl;
        String stars = '0';
        String followers = '0';
        String following = '0';
        String publicId = uid;
        UserLevelState levelState = LevelService.userLevelFromExp(0);

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          displayName = data['name'] ?? data['displayName'] ?? displayName;
          bio = data['bio'] ?? bio;
          photoUrl =
              data['photoURL']?.toString() ?? data['photoUrl']?.toString();
          publicId = _profileIdFrom(data, uid);
          levelState = LevelService.userLevelFromUserData(data);

          stars = _formatNumber(
            _toInt(data['starsEarned'] ?? data['totalGiftedStars']),
          );
          followers = _formatNumber(
            _toInt(data['followersCount'] ?? data['followers']),
          );
          following = _formatNumber(
            _toInt(data['followingCount'] ?? data['following']),
          );
        }

        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            title: Text(
              displayName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: DefaultTabController(
            length: 5,
            child: NestedScrollView(
              headerSliverBuilder: (context, _) {
                return [
                  SliverToBoxAdapter(
                    child: _buildProfileHeader(
                      displayName,
                      bio,
                      photoUrl,
                      publicId,
                      levelState,
                      stars,
                      followers,
                      following,
                    ),
                  ),
                  SliverPersistentHeader(
                    delegate: _SliverAppBarDelegate(
                      TabBar(
                        indicatorColor: Colors.white,
                        indicatorWeight: 1.5,
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.grey.shade600,
                        tabs: const [
                          Tab(icon: Icon(Icons.grid_on)),
                          Tab(icon: Icon(Icons.shopping_bag_outlined)),
                          Tab(icon: Icon(Icons.lock_outline)),
                          Tab(icon: Icon(Icons.bookmark_border)),
                          Tab(icon: Icon(Icons.favorite_border)),
                        ],
                      ),
                    ),
                    pinned: true,
                  ),
                ];
              },
              body: TabBarView(
                children: [
                  _buildVideosGrid(uid),
                  const Center(
                    child: Text(
                      'No products showcased yet',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
                  _buildPrivateGrid(uid),
                  _buildSavedGrid(uid),
                  _buildLikedGrid(uid),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileHeader(
    String displayName,
    String bio,
    String? photoUrl,
    String publicId,
    UserLevelState levelState,
    String stars,
    String followers,
    String following,
  ) {
    return Column(
      children: [
        const SizedBox(height: 20),
        // Avatar
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF1E1E1E),
            border: Border.all(color: Colors.redAccent, width: 2),
            image: photoUrl != null
                ? DecorationImage(
                    image: NetworkImage(photoUrl),
                    fit: BoxFit.cover,
                  )
                : const DecorationImage(
                    image: NetworkImage('https://picsum.photos/200'),
                    fit: BoxFit.cover,
                  ),
          ),
        ),
        const SizedBox(height: 12),
        // Name
        Text(
          displayName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        _buildIdentityRow(
          uid: widget.userId,
          displayName: displayName,
          photoUrl: photoUrl ?? '',
          publicId: publicId,
          levelState: levelState,
        ),
        const SizedBox(height: 6),
        Text(bio, style: const TextStyle(color: Colors.white70, fontSize: 14)),
        const SizedBox(height: 16),
        // Stats
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildStatColumn(following, 'Following'),
            _buildStatDivider(),
            _buildStatColumn(followers, 'Followers'),
            _buildStatDivider(),
            _buildStatColumn(stars, 'Stars'),
          ],
        ),
        const SizedBox(height: 24),
        // Action Buttons
        // Action Buttons
        StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(widget.userId)
              .collection('followers')
              .doc(FirebaseAuth.instance.currentUser?.uid ?? 'guest')
              .snapshots(),
          builder: (context, followSnapshot) {
            final isFollowing =
                followSnapshot.hasData && followSnapshot.data!.exists;
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () async {
                    final currentUid = FirebaseAuth.instance.currentUser?.uid;
                    if (currentUid == null) return;
                    final docRef = FirebaseFirestore.instance
                        .collection('users')
                        .doc(widget.userId)
                        .collection('followers')
                        .doc(currentUid);
                    if (isFollowing) {
                      await docRef.delete();
                    } else {
                      await docRef.set({
                        'timestamp': FieldValue.serverTimestamp(),
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isFollowing
                        ? Colors.white24
                        : Colors.redAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 48,
                      vertical: 12,
                    ),
                  ),
                  child: Text(
                    isFollowing ? 'Following' : 'Follow',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        // Teen Patti Mini-Game Banner (FITTED BOX FOR FULL RESPONSIVENESS)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF8E2DE2),
                  Color(0xFF4A00E0),
                ], // Vibrant purple gradient
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4A00E0).withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Teen Patti Mini-Game Arena',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Play & Win Stars!',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF4A00E0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    child: const Text(
                      'Play Now',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildIdentityRow({
    required String uid,
    required String displayName,
    required String photoUrl,
    required String publicId,
    required UserLevelState levelState,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          Text(
            'ID $publicId',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              fontStyle: FontStyle.italic,
            ),
          ),
          InkWell(
            onTap: () => _copyProfileId(publicId),
            borderRadius: BorderRadius.circular(8),
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: Icon(Icons.copy_rounded, color: Colors.white70, size: 17),
            ),
          ),
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => MyLevelPage(
                    uid: uid,
                    displayName: displayName,
                    photoUrl: photoUrl,
                  ),
                ),
              );
            },
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF5F79FF), Color(0xFFC493FF)],
                ),
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF9073FF).withValues(alpha: 0.35),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.workspace_premium_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Lv.${levelState.level}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(
      height: 24,
      width: 1,
      color: Colors.white24,
      margin: const EdgeInsets.symmetric(horizontal: 16),
    );
  }

  Widget _buildVideosGrid(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .where('userId', isEqualTo: uid)
          .where('privacy', isEqualTo: 'Everyone')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white54),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              'No videos yet',
              style: TextStyle(color: Colors.white54),
            ),
          );
        }

        final docs = snapshot.data!.docs;

        return GridView.builder(
          padding: const EdgeInsets.all(2),
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
            childAspectRatio: 0.7,
          ),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final post = docs[index].data() as Map<String, dynamic>;
            final likesList = post['likes'] is List ? post['likes'] : [];
            final likesCount = likesList.length;
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfileVideoPlaybackScreen(
                      initialIndex: index,
                      docs: docs,
                    ),
                  ),
                );
              },
              child: _buildThumbnailCard(
                post,
                likesCount,
                icon: Icons.favorite,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLikedGrid(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .where('likes', arrayContains: uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white54),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              'No liked videos',
              style: TextStyle(color: Colors.white54),
            ),
          );
        }

        final docs = snapshot.data!.docs;

        return GridView.builder(
          padding: const EdgeInsets.all(2),
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
            childAspectRatio: 0.7,
          ),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final post = docs[index].data() as Map<String, dynamic>;
            final likesList = post['likes'] is List ? post['likes'] : [];
            final likesCount = likesList.length;
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfileVideoPlaybackScreen(
                      initialIndex: index,
                      docs: docs,
                    ),
                  ),
                );
              },
              child: _buildThumbnailCard(
                post,
                likesCount,
                icon: Icons.favorite,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPrivateGrid(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .where('userId', isEqualTo: uid)
          .where('privacy', whereIn: ['Friends', 'Private'])
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white54),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              'No private videos',
              style: TextStyle(color: Colors.white54),
            ),
          );
        }

        final docs = snapshot.data!.docs;

        return GridView.builder(
          padding: const EdgeInsets.all(2),
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
            childAspectRatio: 0.7,
          ),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final post = docs[index].data() as Map<String, dynamic>;
            final likesList = post['likes'] is List ? post['likes'] : [];
            final likesCount = likesList.length;
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfileVideoPlaybackScreen(
                      initialIndex: index,
                      docs: docs,
                    ),
                  ),
                );
              },
              child: _buildThumbnailCard(
                post,
                likesCount,
                icon: Icons.favorite,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSavedGrid(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('saved_tracks')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white54),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              'No saved collections yet',
              style: TextStyle(color: Colors.white54),
            ),
          );
        }

        final docs = snapshot.data!.docs;

        return GridView.builder(
          padding: const EdgeInsets.all(2),
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
            childAspectRatio: 0.7,
          ),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final post = docs[index].data() as Map<String, dynamic>;
            final likesList = post['likes'] is List ? post['likes'] : [];
            final likesCount = likesList.length;
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfileVideoPlaybackScreen(
                      initialIndex: index,
                      docs: docs,
                    ),
                  ),
                );
              },
              child: _buildThumbnailCard(
                post,
                likesCount,
                icon: Icons.favorite,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildThumbnailCard(
    Map<String, dynamic> post,
    int metricCount, {
    IconData icon = Icons.play_arrow_outlined,
  }) {
    final caption = post['caption']?.toString() ?? '';
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.grey.shade900, Colors.black87],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Play Icon in the center representing video
          const Center(
            child: Icon(
              Icons.play_circle_outline,
              color: Colors.white24,
              size: 40,
            ),
          ),
          // Top Left: Privacy or other markers if needed
          if (post['privacy'] == 'Private')
            const Positioned(
              top: 4,
              right: 4,
              child: Icon(Icons.lock, color: Colors.white70, size: 14),
            ),
          // Center Text: Caption preview
          if (caption.isNotEmpty)
            Positioned(
              left: 4,
              right: 4,
              top: 4,
              child: Text(
                caption,
                style: const TextStyle(color: Colors.white54, fontSize: 10),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          // Bottom Left: View/Like Count
          Positioned(
            bottom: 4,
            left: 4,
            child: Row(
              children: [
                Icon(icon, color: Colors.white, size: 16),
                const SizedBox(width: 2),
                Text(
                  _formatNumber(metricCount),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
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

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: Colors.black, child: _tabBar);
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}

class ProfileVideoPlaybackScreen extends StatefulWidget {
  final int initialIndex;
  final List<QueryDocumentSnapshot> docs;

  const ProfileVideoPlaybackScreen({
    super.key,
    required this.initialIndex,
    required this.docs,
  });

  @override
  State<ProfileVideoPlaybackScreen> createState() =>
      _ProfileVideoPlaybackScreenState();
}

class _ProfileVideoPlaybackScreenState
    extends State<ProfileVideoPlaybackScreen> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white, size: 30),
      ),
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: widget.docs.length,
        onPageChanged: (index) {
          setState(() {
            _currentPage = index;
          });
        },
        itemBuilder: (context, index) {
          // DO NOT use docs[0]. Use the dynamic index loop variable:
          final postDoc = widget.docs[index];
          final post = postDoc.data() as Map<String, dynamic>;
          final currentVideoUrl = post['videoUrl'] ?? '';
          final videoId = postDoc.id;

          if (currentVideoUrl.isEmpty) {
            return const Center(
              child: Text(
                'Invalid Video URL',
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          final currentUsername = post['username'] ?? '@likeehit_creator';
          final currentCaption = post['caption'] ?? '';

          return TikTokFeedVideoItem(
            key: ValueKey(videoId),
            videoId: videoId,
            videoUrl: currentVideoUrl,
            isCurrentActivePage: index == _currentPage,
            username: currentUsername,
            caption: currentCaption,
            postUserId: post['userId'] ?? '',
          );
        },
      ),
    );
  }
}
