import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';
import 'audio_track_profile_screen.dart';
import 'likes_and_plays_bottom_sheet.dart';
import 'comments_bottom_sheet.dart';
import 'public_profile_screen.dart';
import 'services/notification_service.dart';

class VideoFeedScreen extends StatefulWidget {
  const VideoFeedScreen({super.key});

  @override
  State<VideoFeedScreen> createState() => _VideoFeedScreenState();
}

class _VideoFeedScreenState extends State<VideoFeedScreen> {
  int _currentPageIndex = 0;
  bool _isForYou = true; // State for active top header tab
  late final Stream<QuerySnapshot> _postsStream;
  final PageController _pageController = PageController();
  List<QueryDocumentSnapshot> _playableDocs = const [];

  @override
  void initState() {
    super.initState();
    _postsStream = FirebaseFirestore.instance
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .snapshots();
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
      body: Stack(
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: _postsStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white54),
                );
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Text(
                    'No videos in feed',
                    style: TextStyle(color: Colors.white),
                  ),
                );
              }

              final docs = snapshot.data!.docs;
              final playableDocs = docs.where((doc) {
                final raw = doc.data() as Map<String, dynamic>;
                final url = _resolveVideoUrl(raw);
                return url.isNotEmpty;
              }).toList();
              _playableDocs = playableDocs;

              if (playableDocs.isEmpty) {
                return const Center(
                  child: Text(
                    'No playable videos found',
                    style: TextStyle(color: Colors.white),
                  ),
                );
              }

              return SizedBox(
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height,
                child: PageView.builder(
                  controller: _pageController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  scrollDirection: Axis.vertical,
                  itemCount: playableDocs.length,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPageIndex = index;
                    });
                  },
                  itemBuilder: (context, index) {
                    // DO NOT use docs[0]. Use the dynamic index loop variable:
                    final postDoc = playableDocs[index];
                    final post = postDoc.data() as Map<String, dynamic>;
                    final currentVideoUrl = _resolveVideoUrl(post);
                    final videoId = postDoc.id;

                    // Fallback for missing video URL
                    if (currentVideoUrl.isEmpty) {
                      return const Center(
                        child: Text(
                          'Invalid Video URL',
                          style: TextStyle(color: Colors.white),
                        ),
                      );
                    }

                    final currentUsername =
                        post['username'] ?? '@likeehit_creator';
                    final currentCaption = post['caption'] ?? '';

                    return TikTokFeedVideoItem(
                      key: ValueKey(videoId),
                      videoId: videoId,
                      videoUrl: currentVideoUrl,
                      isCurrentActivePage: index == _currentPageIndex,
                      username: currentUsername,
                      caption: currentCaption,
                      postUserId: post['userId'] ?? '',
                      onUnplayable: () => _goToNextPlayable(index),
                    );
                  },
                ),
              );
            },
          ),

          // Top Header Overlay
          Positioned(
            top: 40,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 8.0,
                vertical: 8.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Discover/Live Icon
                  IconButton(
                    icon: const Icon(
                      Icons.live_tv_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: () {},
                  ),

                  // Center Tabs (Followed | For You)
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _isForYou = false;
                          });
                        },
                        child: Text(
                          'Following',
                          style: TextStyle(
                            color: _isForYou
                                ? Colors.white.withValues(alpha: 0.7)
                                : Colors.white,
                            fontSize: 16,
                            fontWeight: _isForYou
                                ? FontWeight.w600
                                : FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _isForYou = true;
                          });
                        },
                        child: Text(
                          'For You',
                          style: TextStyle(
                            color: !_isForYou
                                ? Colors.white.withValues(alpha: 0.7)
                                : Colors.white,
                            fontSize: 17,
                            fontWeight: !_isForYou
                                ? FontWeight.w600
                                : FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Search Icon
                  IconButton(
                    icon: const Icon(
                      Icons.search,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: () {
                      showSearch(
                        context: context,
                        delegate: FeedSearchDelegate(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _resolveVideoUrl(Map<String, dynamic> post) {
    final candidates = <dynamic>[
      post['videoUrl'],
      post['videoURL'],
      post['video_url'],
      post['url'],
      post['mediaUrl'],
    ];
    for (final candidate in candidates) {
      final value = (candidate ?? '').toString().trim();
      if (value.isEmpty) continue;
      final uri = Uri.tryParse(value);
      if (uri != null && (uri.isScheme('https') || uri.isScheme('http'))) {
        return value;
      }
    }
    return '';
  }

  void _goToNextPlayable(int failedIndex) {
    if (!mounted) return;
    if (_playableDocs.isEmpty) return;
    if (failedIndex + 1 < _playableDocs.length) {
      _pageController.animateToPage(
        failedIndex + 1,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
      return;
    }
    if (failedIndex > 0) {
      _pageController.animateToPage(
        failedIndex - 1,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    }
  }
}

class FeedSearchDelegate extends SearchDelegate {
  @override
  ThemeData appBarTheme(BuildContext context) {
    return ThemeData.dark().copyWith(
      appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF1E1E1E)),
      inputDecorationTheme: const InputDecorationTheme(
        border: InputBorder.none,
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, color: Colors.white54, size: 60),
            const SizedBox(height: 16),
            Text(
              'No videos found for "$query"',
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try searching for something else.',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return Container(
      color: Colors.black,
      child: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.trending_up, color: Colors.white54),
            title: const Text(
              'Trending Reels',
              style: TextStyle(color: Colors.white),
            ),
            onTap: () {
              query = 'Trending Reels';
              showResults(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.music_note, color: Colors.white54),
            title: const Text(
              'Popular Audio',
              style: TextStyle(color: Colors.white),
            ),
            onTap: () {
              query = 'Popular Audio';
              showResults(context);
            },
          ),
        ],
      ),
    );
  }
}

class TikTokFeedVideoItem extends StatefulWidget {
  final String videoId;
  final String videoUrl;
  final bool isCurrentActivePage;
  final String username;
  final String caption;
  final String postUserId;
  final VoidCallback? onUnplayable;

  const TikTokFeedVideoItem({
    super.key,
    required this.videoId,
    required this.videoUrl,
    required this.isCurrentActivePage,
    this.username = '@likeehit_creator',
    this.caption = '',
    this.postUserId = '',
    this.onUnplayable,
  });

  @override
  State<TikTokFeedVideoItem> createState() => _TikTokFeedVideoItemState();
}

class _TikTokFeedVideoItemState extends State<TikTokFeedVideoItem>
    with TickerProviderStateMixin {
  static final Set<String> _countedViewsThisSession = <String>{};
  static final String _anonymousSessionId =
      'session_${DateTime.now().millisecondsSinceEpoch}';

  late VideoPlayerController _videoController;
  late AnimationController _animationController;
  late AnimationController _heartAnimationController;
  late AnimationController _playPauseAnimationController;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _videoStatsSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _followStatusSubscription;
  Timer? _viewTimer;
  bool _isPlaying = false;
  bool _viewCounted = false;

  // Interactive State
  bool _isLiked = false;
  int _likeCount = 0;
  int _viewCount = 0;
  List<String> _likedUserIds = [];
  bool _isFollowing = false;
  IconData _playPauseIcon = Icons.play_arrow;
  bool _showPlayPauseIcon = false;
  bool _showHeartIcon = false;
  String? _videoInitError;
  bool _resolvingVideoUrl = true;
  bool _retriedWithFreshUrl = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    _heartAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _playPauseAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _heartAnimationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _showHeartIcon = false);
        _heartAnimationController.reset();
      }
    });

    _playPauseAnimationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _showPlayPauseIcon = false);
        _playPauseAnimationController.reset();
      }
    });
    _videoController = VideoPlayerController.networkUrl(
      Uri.parse('https://example.com'),
    );
    unawaited(_initVideoController());

    // Initialize Real-time Listeners
    _listenToVideoStats();
    _listenToFollowStatus();
  }

  void _listenToVideoStats() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    _videoStatsSubscription = FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.videoId)
        .snapshots()
        .listen((snapshot) {
          if (snapshot.exists && mounted) {
            final data = snapshot.data();
            if (data != null) {
              final List<dynamic> likesList =
                  (data.containsKey('likes') && data['likes'] is List)
                  ? data['likes']
                  : [];
              final int views = data['viewsCount'] ?? data['views'] ?? 0;
              setState(() {
                _likedUserIds = List<String>.from(likesList);
                _likeCount = likesList.length;
                _isLiked = uid != null && likesList.contains(uid);
                _viewCount = views;
              });
            }
          }
        });
  }

  void _listenToFollowStatus() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || widget.postUserId.isEmpty || widget.postUserId == uid) {
      return;
    }
    _followStatusSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('following')
        .doc(widget.postUserId)
        .snapshots()
        .listen((snapshot) {
          if (mounted) {
            setState(() {
              _isFollowing = snapshot.exists;
            });
          }
        });
  }

  @override
  void didUpdateWidget(TikTokFeedVideoItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isCurrentActivePage != widget.isCurrentActivePage) {
      if (widget.isCurrentActivePage) {
        _videoController.play();
        _animationController.repeat();
        _isPlaying = true;
        _scheduleViewCount();
      } else {
        _viewTimer?.cancel();
        _videoController.pause();
        _animationController.stop();
        _isPlaying = false;
        _videoController.seekTo(Duration.zero); // Restart when scrolled off
      }
    }
  }

  Future<void> _initVideoController() async {
    try {
      final urlCandidates = await _buildUrlCandidates();
      if (!mounted) return;
      if (urlCandidates.isEmpty) {
        setState(() {
          _videoInitError = 'Video URL missing or invalid';
          _resolvingVideoUrl = false;
        });
        return;
      }

      final initialized = await _tryInitializeFromCandidates(urlCandidates);
      if (!mounted) return;
      if (!initialized) {
        setState(() {
          _videoInitError = 'Video failed to load';
          _resolvingVideoUrl = false;
        });
        unawaited(_markPostBroken());
        widget.onUnplayable?.call();
        return;
      }

      setState(() {
        _videoInitError = null;
        _resolvingVideoUrl = false;
      });
      _videoController.setLooping(true);
      if (widget.isCurrentActivePage) {
        _videoController.play();
        _animationController.repeat();
        _isPlaying = true;
        _scheduleViewCount();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _videoInitError = 'Video failed to load';
        _resolvingVideoUrl = false;
      });
      debugPrint(
        '[Likeehit Feed] Video init error for ${widget.videoId}: $error | rawUrl=${widget.videoUrl}',
      );
      unawaited(_markPostBroken());
      widget.onUnplayable?.call();
    }
  }

  Future<List<String>> _buildUrlCandidates() async {
    final candidates = <String>[];

    final direct = await _resolvePlaybackUrl(widget.videoUrl);
    if (direct != null && direct.isNotEmpty) {
      candidates.add(direct);
    }

    // If current field is Firebase Storage HTTPS URL, refresh tokenized URL.
    final refreshedFromFirebaseUrl = await _refreshFirebaseHttpsUrl(
      widget.videoUrl,
    );
    if (refreshedFromFirebaseUrl != null &&
        refreshedFromFirebaseUrl.isNotEmpty &&
        !candidates.contains(refreshedFromFirebaseUrl)) {
      candidates.insert(0, refreshedFromFirebaseUrl);
      await _updatePostVideoUrl(refreshedFromFirebaseUrl);
    }

    // Fetch latest post doc and try alternate keys as backup.
    final doc = await FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.videoId)
        .get();
    if (doc.exists) {
      final data = doc.data() ?? <String, dynamic>{};
      final extraRaw = <dynamic>[
        data['videoUrl'],
        data['videoURL'],
        data['video_url'],
        data['mediaUrl'],
        data['downloadUrl'],
        data['storagePath'],
      ];
      for (final raw in extraRaw) {
        final resolved = await _resolvePlaybackUrl((raw ?? '').toString());
        if (resolved != null &&
            resolved.isNotEmpty &&
            !candidates.contains(resolved)) {
          candidates.add(resolved);
        }
      }
    }

    return candidates;
  }

  Future<bool> _tryInitializeFromCandidates(List<String> candidates) async {
    for (final url in candidates) {
      try {
        _videoController.dispose();
        _videoController = VideoPlayerController.networkUrl(Uri.parse(url));
        await _videoController.initialize();
        return true;
      } catch (e) {
        debugPrint('[Likeehit Feed] Candidate failed: $url | error=$e');
      }
    }
    return false;
  }

  Future<String?> _resolvePlaybackUrl(String rawUrl) async {
    final candidate = rawUrl.trim();
    if (candidate.isEmpty) return null;
    final uri = Uri.tryParse(candidate);
    if (uri != null && (uri.isScheme('https') || uri.isScheme('http'))) {
      return candidate;
    }
    if (candidate.startsWith('gs://')) {
      final ref = FirebaseStorage.instance.refFromURL(candidate);
      return ref.getDownloadURL();
    }
    if (!candidate.contains('://')) {
      final ref = FirebaseStorage.instance.ref(candidate);
      return ref.getDownloadURL();
    }
    return null;
  }

  Future<String?> _refreshFirebaseHttpsUrl(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null) return null;
    if (uri.host != 'firebasestorage.googleapis.com') return null;
    final path = uri.path;
    final marker = '/o/';
    final idx = path.indexOf(marker);
    if (idx == -1) return null;
    final encodedObjectPath = path.substring(idx + marker.length);
    if (encodedObjectPath.isEmpty) return null;
    final objectPath = Uri.decodeComponent(encodedObjectPath);
    if (objectPath.isEmpty) return null;
    final ref = FirebaseStorage.instance.ref(objectPath);
    return ref.getDownloadURL();
  }

  Future<void> _updatePostVideoUrl(String url) async {
    try {
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.videoId)
          .set({'videoUrl': url, 'broken': false}, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> _markPostBroken() async {
    try {
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.videoId)
          .set({
            'broken': true,
            'brokenAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (_) {}
  }

  @override
  void dispose() {
    _animationController.dispose();
    _heartAnimationController.dispose();
    _playPauseAnimationController.dispose();
    _videoStatsSubscription?.cancel();
    _followStatusSubscription?.cancel();
    _viewTimer?.cancel();
    _videoController.pause();
    _videoController.dispose();
    super.dispose();
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    } else {
      return count.toString();
    }
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  void _togglePlay() {
    if (_videoInitError != null) return;
    setState(() {
      if (_isPlaying) {
        _videoController.pause();
        _animationController.stop();
        _playPauseIcon = Icons.pause;
      } else {
        _videoController.play();
        _animationController.repeat();
        _playPauseIcon = Icons.play_arrow;
      }
      _isPlaying = !_isPlaying;
      if (_isPlaying) {
        _scheduleViewCount();
      } else {
        _viewTimer?.cancel();
      }
      _showPlayPauseIcon = true;
    });
    _playPauseAnimationController.forward(from: 0.0);
  }

  void _scheduleViewCount() {
    if (_viewCounted || !widget.isCurrentActivePage) return;
    _viewTimer?.cancel();
    _viewTimer = Timer(const Duration(milliseconds: 2500), _recordViewIfValid);
  }

  Future<void> _recordViewIfValid() async {
    if (_viewCounted ||
        !mounted ||
        !widget.isCurrentActivePage ||
        !_videoController.value.isInitialized ||
        !_videoController.value.isPlaying) {
      return;
    }

    final viewerId =
        FirebaseAuth.instance.currentUser?.uid ?? _anonymousSessionId;
    final sessionKey = '${widget.videoId}:$viewerId';
    if (_countedViewsThisSession.contains(sessionKey)) {
      _viewCounted = true;
      return;
    }

    _countedViewsThisSession.add(sessionKey);
    _viewCounted = true;

    try {
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.videoId)
          .set({
            'viewsCount': FieldValue.increment(1),
            'views': FieldValue.increment(1),
            'lastViewedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (_) {
      _countedViewsThisSession.remove(sessionKey);
      _viewCounted = false;
    }
  }

  void _handleDoubleTap() {
    if (!_isLiked) {
      _toggleLike();
    }
    setState(() {
      _showHeartIcon = true;
    });
    _heartAnimationController.forward(from: 0.0);
  }

  void _showLikesSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: LikesAndPlaysBottomSheet(
            likedUserIds: _likedUserIds,
            viewCount: _viewCount,
          ),
        );
      },
    );
  }

  void _toggleLike() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final docRef = FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.videoId);

    // Optimistic local update
    setState(() {
      _isLiked = !_isLiked;
      _likeCount += _isLiked ? 1 : -1;
    });

    try {
      if (_isLiked) {
        await docRef.update({
          'likes': FieldValue.arrayUnion([uid]),
        });
        final postSnap = await docRef.get();
        final postData = postSnap.data() ?? const <String, dynamic>{};
        await AppNotificationService.send(
          ownerUid: widget.postUserId,
          category: 'like',
          type: 'video_like',
          title: 'New like',
          body: 'liked your video',
          postId: widget.videoId,
          postCaption: widget.caption,
          postVideoUrl: widget.videoUrl,
          postThumbnailUrl:
              postData['thumbnailUrl']?.toString() ??
              postData['thumbnail']?.toString() ??
              '',
          dedupeKey: 'like_${widget.videoId}_$uid',
        );
      } else {
        await docRef.update({
          'likes': FieldValue.arrayRemove([uid]),
        });
      }
    } catch (e) {
      // Revert if transaction fails
      if (mounted) {
        setState(() {
          _isLiked = !_isLiked;
          _likeCount += _isLiked ? 1 : -1;
        });
      }
    }
  }

  void _toggleFollow() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || widget.postUserId.isEmpty || widget.postUserId == uid) {
      return;
    }
    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('following')
        .doc(widget.postUserId);

    // Optimistic update
    setState(() {
      _isFollowing = true;
    });

    try {
      await docRef.set({
        'followedAt': FieldValue.serverTimestamp(),
        'userId': widget.postUserId,
      });
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'following': FieldValue.increment(1),
      }, SetOptions(merge: true));
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.postUserId)
          .set({'followers': FieldValue.increment(1)}, SetOptions(merge: true));
      await AppNotificationService.send(
        ownerUid: widget.postUserId,
        category: 'follow',
        type: 'user_follow',
        title: 'New follower',
        body: 'started following you',
        dedupeKey: 'follow_$uid',
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isFollowing = false;
        });
      }
    }
  }

  // --- UI Components for Sheets ---

  void _showCommentSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return CommentsBottomSheet(videoId: widget.videoId);
      },
    );
  }

  void _showGiftPanel(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        int selectedIndex = -1;
        final List<Map<String, dynamic>> gifts = [
          {
            'name': 'Rose',
            'icon': Icons.local_florist,
            'cost': 10,
            'color': Colors.red,
          },
          {
            'name': 'Heart',
            'icon': Icons.favorite,
            'cost': 50,
            'color': Colors.pink,
          },
          {
            'name': 'Diamond',
            'icon': Icons.diamond,
            'cost': 100,
            'color': Colors.blue,
          },
          {
            'name': 'Crown',
            'icon': Icons.workspace_premium,
            'cost': 300,
            'color': Colors.amber,
          },
          {
            'name': 'Sports Car',
            'icon': Icons.directions_car,
            'cost': 500,
            'color': Colors.orange,
          },
          {
            'name': 'Rocket',
            'icon': Icons.rocket_launch,
            'cost': 1000,
            'color': Colors.purple,
          },
        ];

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              height: 400,
              decoration: const BoxDecoration(
                color: Color(0xFF1E1E1E),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'Send a Gift',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Divider(color: Colors.white24, height: 1),
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.85,
                          ),
                      itemCount: gifts.length,
                      itemBuilder: (context, index) {
                        final gift = gifts[index];
                        final isSelected = selectedIndex == index;
                        return GestureDetector(
                          onTap: () {
                            setModalState(() {
                              selectedIndex = index;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.redAccent.withValues(alpha: 0.2)
                                  : Colors.white10,
                              border: Border.all(
                                color: isSelected
                                    ? Colors.redAccent
                                    : Colors.transparent,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  gift['icon'],
                                  color: gift['color'],
                                  size: 40,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  gift['name'],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.star,
                                      color: Colors.amber,
                                      size: 12,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${gift['cost']}',
                                      style: const TextStyle(
                                        color: Colors.amber,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: const BoxDecoration(
                      color: Color(0xFF121212),
                      border: Border(
                        top: BorderSide(color: Colors.white24, width: 1),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                          stream: FirebaseAuth.instance.currentUser?.uid == null
                              ? null
                              : FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(FirebaseAuth.instance.currentUser!.uid)
                                    .snapshots(),
                          builder: (context, snap) {
                            final stars = _toInt(
                              (snap.data?.data() ??
                                  const <String, dynamic>{})['stars'],
                            );
                            return Row(
                              children: [
                                const Icon(
                                  Icons.star,
                                  color: Colors.amber,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '$stars',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.arrow_forward_ios,
                                  color: Colors.white54,
                                  size: 12,
                                ),
                              ],
                            );
                          },
                        ),
                        ElevatedButton(
                          onPressed: selectedIndex != -1
                              ? () async {
                                  final gift = gifts[selectedIndex];
                                  try {
                                    await _sendVideoGift(
                                      giftName: gift['name'].toString(),
                                      stars: _toInt(gift['cost']),
                                      quantity: 1,
                                    );
                                    if (!context.mounted) return;
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Sent ${gift['name']} (${gift['cost']}★)!',
                                        ),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  } catch (e) {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          e.toString().replaceFirst(
                                            'Exception: ',
                                            '',
                                          ),
                                        ),
                                        backgroundColor: Colors.redAccent,
                                      ),
                                    );
                                  }
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            disabledBackgroundColor: Colors.redAccent
                                .withValues(alpha: 0.3),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                          child: const Text(
                            'Send Gift',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _sendVideoGift({
    required String giftName,
    required int stars,
    int quantity = 1,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Please sign in first.');
    }
    if (widget.postUserId.isEmpty) {
      throw Exception('Creator not found.');
    }

    final db = FirebaseFirestore.instance;
    final userRef = db.collection('users').doc(user.uid);
    final creatorRef = db.collection('users').doc(widget.postUserId);
    final postRef = db.collection('posts').doc(widget.videoId);
    final eventRef = postRef.collection('videoGiftEvents').doc();
    final toolRef = creatorRef.collection('creatorTools').doc('video_gifts');
    final totalStars = stars * quantity;

    await db.runTransaction((tx) async {
      final userSnap = await tx.get(userRef);
      final creatorSnap = await tx.get(creatorRef);
      final userData = userSnap.data() ?? <String, dynamic>{};
      final creatorData = creatorSnap.data() ?? <String, dynamic>{};
      final balance = _toInt(userData['stars']);
      if (balance < totalStars) {
        throw Exception('Not enough stars.');
      }

      final senderName = userData['name']?.toString().trim().isNotEmpty == true
          ? userData['name'].toString()
          : (user.displayName ?? 'Viewer');
      final creatorName = creatorData['name']?.toString() ?? 'Creator';

      tx.set(userRef, {
        'stars': balance - totalStars,
        'totalGiftedStars': FieldValue.increment(totalStars),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      tx.set(creatorRef, {
        'starsEarned': FieldValue.increment(totalStars),
        'totalReceivedGiftStars': FieldValue.increment(totalStars),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      tx.set(postRef, {
        'giftStars': FieldValue.increment(totalStars),
        'totalGiftCount': FieldValue.increment(quantity),
        'lastGiftAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      tx.set(eventRef, {
        'uid': user.uid,
        'name': senderName,
        'creatorId': widget.postUserId,
        'creatorName': creatorName,
        'postId': widget.videoId,
        'giftName': giftName,
        'stars': stars,
        'quantity': quantity,
        'totalStars': totalStars,
        'createdAt': FieldValue.serverTimestamp(),
      });

      tx.set(toolRef, {
        'enabled': true,
        'status': 'active',
        'stats': {
          'totalStars': FieldValue.increment(totalStars),
          'totalGifts': FieldValue.increment(quantity),
          'lastGiftAt': FieldValue.serverTimestamp(),
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });

    final postSnap = await postRef.get();
    final postData = postSnap.data() ?? const <String, dynamic>{};
    await AppNotificationService.send(
      ownerUid: widget.postUserId,
      category: 'gift',
      type: 'video_gift',
      title: 'New video gift',
      body: 'sent $giftName on your video',
      postId: widget.videoId,
      postCaption: widget.caption,
      postVideoUrl: widget.videoUrl,
      postThumbnailUrl:
          postData['thumbnailUrl']?.toString() ??
          postData['thumbnail']?.toString() ??
          '',
      giftName: giftName,
      giftStars: stars,
      giftCount: quantity,
      extra: {'totalStars': totalStars},
    );
  }

  void _showShareSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: 250,
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Share to',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Divider(color: Colors.white24, height: 1),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildShareIcon(
                      Icons.add_circle_outline,
                      Colors.blueAccent,
                      'Your story',
                      onTap: _shareCurrentVideoToStory,
                    ),
                    _buildShareIcon(Icons.message, Colors.green, 'WhatsApp'),
                    _buildShareIcon(Icons.facebook, Colors.blue, 'Facebook'),
                    _buildShareIcon(
                      Icons.camera_alt,
                      Colors.purpleAccent,
                      'Instagram',
                    ),
                    _buildShareIcon(Icons.link, Colors.grey, 'Copy Link'),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showMoreSheet(BuildContext context) {
    bool isPostOwner =
        widget.postUserId == FirebaseAuth.instance.currentUser?.uid;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.flag, color: Colors.white),
                title: const Text(
                  'Report',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.heart_broken, color: Colors.white),
                title: const Text(
                  'Not Interested',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.download, color: Colors.white),
                title: const Text(
                  'Save video',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.call_split, color: Colors.white),
                title: const Text(
                  'Duet',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(
                  Icons.storefront_rounded,
                  color: Colors.white,
                ),
                title: const Text(
                  'Likeehit Shop',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showCreatorShopSheet(context);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.receipt_long_rounded,
                  color: Colors.white,
                ),
                title: const Text(
                  'My Shop Orders',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showMyShopOrdersSheet(context);
                },
              ),
              if (isPostOwner)
                ListTile(
                  leading: const Icon(
                    Icons.delete_forever_outlined,
                    color: Colors.redAccent,
                  ),
                  title: const Text(
                    'Delete video',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                  onTap: () {
                    Navigator.pop(context); // Close bottom sheet
                    _showDeleteConfirmationDialog();
                  },
                ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Future<void> _shareCurrentVideoToStory() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    Navigator.pop(context);
    try {
      final db = FirebaseFirestore.instance;
      final userDoc = await db.collection('users').doc(uid).get();
      final userData = userDoc.data() ?? <String, dynamic>{};
      final postDoc = await db.collection('posts').doc(widget.videoId).get();
      final postData = postDoc.data() ?? <String, dynamic>{};
      final storyRef = db.collection('stories').doc();
      final thumbnail =
          postData['thumbnailUrl']?.toString() ??
          postData['thumbnail']?.toString() ??
          '';
      final duration = _videoController.value.isInitialized
          ? _videoController.value.duration.inSeconds.clamp(15, 60)
          : 15;
      await storyRef.set({
        'storyId': storyRef.id,
        'uid': uid,
        'userName':
            userData['name']?.toString() ??
            userData['username']?.toString() ??
            'Likeehit User',
        'userPhotoUrl':
            userData['photoURL']?.toString() ??
            userData['photoUrl']?.toString() ??
            '',
        'imageUrl': thumbnail,
        'mediaUrl': widget.videoUrl,
        'mediaType': 'video',
        'storyDurationSeconds': duration,
        'sourcePostId': widget.videoId,
        'sourceOwnerUid': widget.postUserId,
        'caption': widget.caption,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(hours: 24)),
        ),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Video added to your story')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  void _showCreatorShopSheet(BuildContext context) {
    if (widget.postUserId.isEmpty) return;
    final productsRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.postUserId)
        .collection('likeehitShopProducts')
        .snapshots();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.72,
          decoration: const BoxDecoration(
            color: Color(0xFF12131D),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Likeehit Shop',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseAuth.instance.currentUser?.uid == null
                    ? null
                    : FirebaseFirestore.instance
                          .collection('users')
                          .doc(FirebaseAuth.instance.currentUser!.uid)
                          .snapshots(),
                builder: (context, snap) {
                  final stars = _toInt(
                    (snap.data?.data() ?? const <String, dynamic>{})['stars'],
                  );
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          'My Stars: $stars',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: productsRef,
                  builder: (context, snap) {
                    final docs = snap.data?.docs ?? const [];
                    if (docs.isEmpty) {
                      return const Center(
                        child: Text(
                          'No products available.',
                          style: TextStyle(color: Colors.white70),
                        ),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final data = doc.data();
                        final title = data['title']?.toString() ?? 'Product';
                        final price = _toInt(data['priceStars']);
                        final stock = _toInt(data['stock']);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1C2B),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.shopping_bag_rounded,
                                color: Colors.white70,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      'Stock: $stock',
                                      style: const TextStyle(
                                        color: Colors.white60,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '$price★',
                                style: const TextStyle(
                                  color: Color(0xFFFFD66B),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: stock <= 0
                                    ? null
                                    : () async {
                                        try {
                                          await _buyCreatorProduct(
                                            creatorId: widget.postUserId,
                                            productId: doc.id,
                                            title: title,
                                            amountStars: price,
                                          );
                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Order placed: $title',
                                              ),
                                              backgroundColor: Colors.green,
                                            ),
                                          );
                                        } catch (e) {
                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                e.toString().replaceFirst(
                                                  'Exception: ',
                                                  '',
                                                ),
                                              ),
                                              backgroundColor: Colors.redAccent,
                                            ),
                                          );
                                        }
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFF3A74),
                                  disabledBackgroundColor: Colors.white12,
                                ),
                                child: const Text(
                                  'Buy',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _buyCreatorProduct({
    required String creatorId,
    required String productId,
    required String title,
    required int amountStars,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Please sign in first.');
    }
    if (amountStars <= 0) {
      throw Exception('Invalid product price.');
    }
    final db = FirebaseFirestore.instance;
    final buyerRef = db.collection('users').doc(user.uid);
    final creatorRef = db.collection('users').doc(creatorId);
    final productRef = creatorRef
        .collection('likeehitShopProducts')
        .doc(productId);
    final orderRef = creatorRef.collection('likeehitShopOrders').doc();

    await db.runTransaction((tx) async {
      final buyerSnap = await tx.get(buyerRef);
      final productSnap = await tx.get(productRef);
      final buyerData = buyerSnap.data() ?? const <String, dynamic>{};
      final productData = productSnap.data() ?? const <String, dynamic>{};
      final balance = _toInt(buyerData['stars']);
      final stock = _toInt(productData['stock']);
      if (balance < amountStars) {
        throw Exception('Not enough stars.');
      }
      if (stock <= 0) {
        throw Exception('Out of stock.');
      }

      tx.set(buyerRef, {
        'stars': balance - amountStars,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      tx.set(creatorRef, {
        'shopEarningsStars': FieldValue.increment(amountStars),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      tx.set(productRef, {
        'stock': stock - 1,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      tx.set(orderRef, {
        'productId': productId,
        'title': title,
        'amountStars': amountStars,
        'creatorId': creatorId,
        'buyerId': user.uid,
        'buyerName':
            buyerData['name']?.toString() ?? (user.displayName ?? 'Buyer'),
        'status': 'placed',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    await db
        .collection('users')
        .doc(creatorId)
        .collection('notifications')
        .add({
          'type': 'shop_order',
          'title': 'New Shop Order',
          'body': '$title ordered by ${user.displayName ?? 'a buyer'}',
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
  }

  void _showMyShopOrdersSheet(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return;
    final ordersRef = FirebaseFirestore.instance
        .collectionGroup('likeehitShopOrders')
        .where('buyerId', isEqualTo: currentUid)
        .orderBy('createdAt', descending: true)
        .snapshots();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.72,
          decoration: const BoxDecoration(
            color: Color(0xFF12131D),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'My Shop Orders',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: ordersRef,
                  builder: (context, snap) {
                    final docs = snap.data?.docs ?? const [];
                    if (docs.isEmpty) {
                      return const Center(
                        child: Text(
                          'No orders yet.',
                          style: TextStyle(color: Colors.white70),
                        ),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final d = docs[index].data();
                        final title = d['title']?.toString() ?? 'Order';
                        final amount = _toInt(d['amountStars']);
                        final status = d['status']?.toString() ?? 'placed';
                        final creatorId = d['creatorId']?.toString() ?? '';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1C2B),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.shopping_bag_rounded,
                                color: Colors.white70,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      'Amount: $amount★',
                                      style: const TextStyle(
                                        color: Color(0xFFFFD66B),
                                        fontSize: 12,
                                      ),
                                    ),
                                    if (creatorId.isNotEmpty)
                                      Text(
                                        'Creator: $creatorId',
                                        style: const TextStyle(
                                          color: Colors.white38,
                                          fontSize: 11,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              _orderStatusPill(status),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _orderStatusPill(String status) {
    Color bg;
    Color fg;
    switch (status) {
      case 'shipped':
        bg = const Color(0xFF1F314F);
        fg = const Color(0xFF7CB7FF);
        break;
      case 'completed':
        bg = const Color(0xFF203B2C);
        fg = const Color(0xFF7BD88F);
        break;
      case 'cancelled':
      case 'rejected':
        bg = const Color(0xFF3E2326);
        fg = const Color(0xFFFF8E8E);
        break;
      default:
        bg = const Color(0xFF343443);
        fg = const Color(0xFFC7C7D9);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 11),
      ),
    );
  }

  void _showDeleteConfirmationDialog() {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null || currentUid != widget.postUserId) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'Delete Video',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to delete this video?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              try {
                await _deleteCurrentVideo(currentUid);
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(
                      content: Text('Video deleted successfully.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(content: Text('Failed to delete video: $e')),
                  );
                }
              }
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCurrentVideo(String currentUid) async {
    final postRef = FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.videoId);
    final snapshot = await postRef.get();
    final data = snapshot.data();

    if (data == null) {
      return;
    }
    if (data['userId'] != currentUid) {
      throw StateError('Only the creator can delete this video.');
    }

    await _deleteStorageUrl(data['videoUrl']?.toString());
    await _deleteStorageUrl(data['thumbnailUrl']?.toString());
    await _deleteStorageUrl(data['thumbnail']?.toString());
    await postRef.delete();
  }

  Future<void> _deleteStorageUrl(String? url) async {
    if (url == null || url.isEmpty) return;
    try {
      await FirebaseStorage.instance.refFromURL(url).delete();
    } on FirebaseException catch (e) {
      if (e.code != 'object-not-found') {
        rethrow;
      }
    }
  }

  void _navigateToAudioProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AudioTrackProfileScreen(
          audioUrl: widget.videoUrl, // Use actual audio URL if available
          title: 'Original Audio - @${widget.username.replaceAll('@', '')}',
          artist: widget.username,
        ),
      ),
    );
  }

  Widget _buildShareIcon(
    IconData icon,
    Color color,
    String label, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap:
          onTap ??
          () {
            Clipboard.setData(
              ClipboardData(
                text:
                    'Check out this amazing short video on Likeehit! ${widget.videoUrl}',
              ),
            );
          },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: color.withValues(alpha: 0.2),
            child: Icon(icon, color: color, size: 30),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>>? get _creatorProfileStream {
    if (widget.postUserId.isEmpty) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(widget.postUserId)
        .snapshots();
  }

  String _creatorUsername(Map<String, dynamic>? data) {
    final raw =
        data?['username']?.toString() ??
        data?['name']?.toString() ??
        data?['displayName']?.toString() ??
        widget.username;
    if (raw.isEmpty) return '@likeehit_creator';
    return raw.startsWith('@') ? raw : '@$raw';
  }

  String _creatorPhotoUrl(Map<String, dynamic>? data) {
    return data?['photoURL']?.toString() ??
        data?['photoUrl']?.toString() ??
        data?['profileImage']?.toString() ??
        data?['profileUrl']?.toString() ??
        '';
  }

  void _openCreatorProfile() {
    if (widget.postUserId.isEmpty) return;
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 260),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (context, animation, secondaryAnimation) =>
            PublicProfileScreen(userId: widget.postUserId),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.04, 0),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  Widget _buildCreatorAvatar(String photoUrl) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _openCreatorProfile,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          image: photoUrl.isNotEmpty
              ? DecorationImage(
                  image: NetworkImage(photoUrl),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: photoUrl.isEmpty
            ? const Icon(Icons.person, color: Colors.white70, size: 28)
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_resolvingVideoUrl) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white54),
        ),
      );
    }
    if (_videoInitError != null) {
      if (!_retriedWithFreshUrl) {
        _retriedWithFreshUrl = true;
        Future<void>.delayed(const Duration(milliseconds: 250), () {
          if (!mounted) return;
          setState(() {
            _resolvingVideoUrl = true;
            _videoInitError = null;
          });
          unawaited(_initVideoController());
        });
      }
      return Container(
        color: Colors.black,
        child: const Center(
          child: Text(
            'Unable to play this video',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ),
      );
    }
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _creatorProfileStream,
      builder: (context, creatorSnapshot) {
        final creatorData = creatorSnapshot.data?.data();
        final creatorUsername = _creatorUsername(creatorData);
        final creatorPhotoUrl = _creatorPhotoUrl(creatorData);

        return GestureDetector(
          onTap: _togglePlay,
          onDoubleTap: _handleDoubleTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background Video
              if (_videoController.value.isInitialized)
                FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _videoController.value.size.width,
                    height: _videoController.value.size.height,
                    child: VideoPlayer(_videoController),
                  ),
                )
              else
                const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),

              // Play/Pause Icon Overlay
              if (_showPlayPauseIcon)
                Center(
                  child: AnimatedBuilder(
                    animation: _playPauseAnimationController,
                    builder: (context, child) {
                      final fade = 1.0 - _playPauseAnimationController.value;
                      final scale =
                          1.0 + (_playPauseAnimationController.value * 0.5);
                      return Opacity(
                        opacity: fade,
                        child: Transform.scale(
                          scale: scale,
                          child: Icon(
                            _playPauseIcon,
                            color: Colors.white70,
                            size: 80,
                          ),
                        ),
                      );
                    },
                  ),
                ),

              // Double Tap Heart Animation Overlay
              if (_showHeartIcon)
                Center(
                  child: AnimatedBuilder(
                    animation: _heartAnimationController,
                    builder: (context, child) {
                      double scale;
                      double opacity;
                      final progress = _heartAnimationController.value;
                      if (progress < 0.2) {
                        scale = progress * 5.0 * 1.2;
                        opacity = progress * 5.0;
                      } else {
                        scale = 1.2;
                        opacity = 1.0 - ((progress - 0.2) / 0.8);
                      }

                      return Opacity(
                        opacity: opacity.clamp(0.0, 1.0),
                        child: Transform.scale(
                          scale: scale.clamp(0.0, 1.2),
                          child: const Icon(
                            Icons.favorite,
                            color: Colors.redAccent,
                            size: 120,
                          ),
                        ),
                      );
                    },
                  ),
                ),

              // Right Side Action Buttons
              Positioned(
                right: 15,
                bottom: 100,
                child: Transform.translate(
                  offset: Offset(
                    0,
                    MediaQuery.sizeOf(context).height < 640 ? 40 : 52,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Profile Picture with Animated Follow Button
                      SizedBox(
                        width: 60,
                        height: 70,
                        child: Stack(
                          alignment: Alignment.topCenter,
                          children: [
                            _buildCreatorAvatar(creatorPhotoUrl),
                            Positioned(
                              bottom: 10,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                transitionBuilder:
                                    (
                                      Widget child,
                                      Animation<double> animation,
                                    ) {
                                      return ScaleTransition(
                                        scale: animation,
                                        child: child,
                                      );
                                    },
                                child: _isFollowing
                                    ? const SizedBox.shrink(
                                        key: ValueKey('followed'),
                                      )
                                    : GestureDetector(
                                        key: const ValueKey('unfollowed'),
                                        onTap: _toggleFollow,
                                        child: Container(
                                          decoration: const BoxDecoration(
                                            color: Colors.redAccent,
                                            shape: BoxShape.circle,
                                          ),
                                          padding: const EdgeInsets.all(2),
                                          child: const Icon(
                                            Icons.add,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 15),
                      // Like Button
                      GestureDetector(
                        onTap: _toggleLike,
                        child: Column(
                          children: [
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              transitionBuilder:
                                  (Widget child, Animation<double> animation) {
                                    return ScaleTransition(
                                      scale: animation,
                                      child: child,
                                    );
                                  },
                              child: Icon(
                                Icons.favorite,
                                key: ValueKey(_isLiked),
                                color: _isLiked
                                    ? Colors.redAccent
                                    : Colors.white,
                                size: 35,
                              ),
                            ),
                            const SizedBox(height: 4),
                            GestureDetector(
                              onTap: _showLikesSheet,
                              child: Text(
                                _formatCount(_likeCount),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 15),
                      // Comment Button
                      GestureDetector(
                        onTap: () => _showCommentSheet(context),
                        child: StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('posts')
                              .doc(widget.videoId)
                              .collection('comments')
                              .snapshots(),
                          builder: (context, snapshot) {
                            final count = snapshot.hasData
                                ? snapshot.data!.docs.length
                                : 0;
                            return _buildActionButton(
                              Icons.comment,
                              count > 0 ? _formatCount(count) : '0',
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 15),
                      // Share Button
                      GestureDetector(
                        onTap: () => _showShareSheet(context),
                        child: _buildActionButton(Icons.share, 'Share'),
                      ),
                      const SizedBox(height: 15),
                      // More Button
                      GestureDetector(
                        onTap: () => _showMoreSheet(context),
                        child: const Icon(
                          Icons.more_horiz,
                          color: Colors.white,
                          size: 35,
                        ),
                      ),
                      const SizedBox(height: 15),
                      // Gift Button
                      GestureDetector(
                        onTap: () => _showGiftPanel(context),
                        child: _buildActionButton(Icons.card_giftcard, 'Gift'),
                      ),
                      const SizedBox(height: 20),
                      // Audio Disc
                      GestureDetector(
                        onTap: _navigateToAudioProfile,
                        child: RotationTransition(
                          turns: _animationController,
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black,
                              border: Border.all(
                                color: Colors.white24,
                                width: 8,
                              ),
                            ),
                            child: const CircleAvatar(
                              backgroundImage: NetworkImage(
                                'https://picsum.photos/100?random=music',
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),

              // Bottom Left Text Details
              Positioned(
                bottom: 20,
                left: 15,
                right: 80, // Prevent overlapping with right action buttons
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _openCreatorProfile,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              creatorUsername,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        // Verified Badge
                        const Icon(
                          Icons.verified,
                          color: Colors.lightBlueAccent,
                          size: 16,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.caption.isNotEmpty
                          ? widget.caption
                          : 'Check out this amazing short video! 🔥 #trending #fyp #likeehit #viral',
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.visibility,
                          color: Colors.white70,
                          size: 16,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${_formatCount(_viewCount)} views',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: _navigateToAudioProfile,
                      child: Row(
                        children: [
                          const Icon(
                            Icons.music_note,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          // Scrolling music text effect
                          Expanded(
                            child: Text(
                              'Original Audio - ${widget.username} • Trending track',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 96,
                left: 12,
                right: 12,
                child: _buildShopStatusBanner(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionButton(IconData icon, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 35),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildShopStatusBanner() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .where('type', isEqualTo: 'shop_status')
          .where('read', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? const [];
        if (docs.isEmpty) return const SizedBox.shrink();
        final d = docs.first;
        final m = d.data();
        return GestureDetector(
          onTap: () async {
            await d.reference.set({'read': true}, SetOptions(merge: true));
            if (!mounted) return;
            _showMyShopOrdersSheet(this.context);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.local_shipping_rounded,
                  color: Color(0xFF7CB7FF),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    m['body']?.toString() ?? 'Order status updated',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: Colors.white70,
                  size: 18,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
