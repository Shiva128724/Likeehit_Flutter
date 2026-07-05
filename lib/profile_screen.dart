import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'settings_screen.dart';
import 'video_feed_screen.dart';
import 'edit_profile_screen.dart';
import 'inbox_screen.dart';
import 'creator_tools_screen.dart';
import 'my_level_page.dart';
import 'svip_screen.dart';
import 'wallet_screen.dart';
import 'services/level_service.dart';
import 'screens/live/host_center_screen.dart';
import 'widgets/svip_badge.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  void _openHostCenter() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HostCenterScreen()),
    );
  }

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
    return 0;
  }

  int _activeSvipTierFromData(Map<String, dynamic> data) {
    final until = data['svipUntil'];
    if (until is Timestamp && !until.toDate().isAfter(DateTime.now())) {
      return 0;
    }

    final tier = _toInt(data['svipTier']);
    if (tier > 0) return tier.clamp(1, 3);

    final plan = data['svipPlan']?.toString().toLowerCase() ?? '';
    if (plan == 'royal') return 3;
    if (plan == 'pro') return 2;
    if (plan == 'lite') return 1;

    final level = _toInt(data['svipLevel']);
    if (level >= 7) return 3;
    if (level >= 3) return 2;
    if (level >= 1) return 1;
    return 0;
  }

  Uri? _normalisePublicLink(String rawLink) {
    final value = rawLink.trim();
    if (value.isEmpty) return null;
    final withScheme = value.startsWith(RegExp(r'https?://'))
        ? value
        : 'https://$value';
    return Uri.tryParse(withScheme);
  }

  Future<void> _openPublicLink(String rawLink) async {
    final uri = _normalisePublicLink(rawLink);
    if (uri == null) return;

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open this link.'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            'Sign in to view your profile.',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, snapshot) {
        String displayName = 'LikeeHit Creator';
        String bio = '';
        String website = '';
        String publicId = uid;
        String? photoUrl;
        int followersCount = 0;
        int followingCount = 0;
        int svipTier = 0;
        UserLevelState levelState = LevelService.userLevelFromExp(0);

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          displayName = data['name'] ?? data['displayName'] ?? displayName;
          publicId = _profileIdFrom(data, uid);
          bio = data['bio']?.toString() ?? bio;
          website = data['website']?.toString().trim() ?? '';
          photoUrl =
              data['photoURL']?.toString() ?? data['photoUrl']?.toString();
          followersCount = _toInt(data['followers']);
          followingCount = _toInt(data['following']);
          levelState = LevelService.userLevelFromUserData(data);
          svipTier = _activeSvipTierFromData(data);
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('posts')
              .where('userId', isEqualTo: uid)
              .snapshots(),
          builder: (context, postsSnapshot) {
            final analytics = _ProfileAnalytics.fromDocs(
              postsSnapshot.data?.docs ?? const [],
              followersCount: followersCount,
              followingCount: followingCount,
            );

            return Scaffold(
              backgroundColor: Colors.black,
              appBar: AppBar(
                backgroundColor: Colors.black,
                title: const Text(
                  'Profile',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
                centerTitle: true,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.menu, color: Colors.white, size: 28),
                    onPressed: _showProfileMenuBottomSheet,
                  ),
                ],
              ),
              body: DefaultTabController(
                length: 5,
                child: NestedScrollView(
                  headerSliverBuilder: (context, _) {
                    return [
                      SliverToBoxAdapter(
                        child: _buildProfileHeader(
                          uid,
                          displayName,
                          bio,
                          website,
                          publicId,
                          levelState,
                          svipTier,
                          photoUrl,
                          analytics,
                        ),
                      ),
                      SliverPersistentHeader(
                        delegate: _SliverAppBarDelegate(
                          TabBar(
                            indicatorColor: Colors.redAccent,
                            indicatorWeight: 2,
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
      },
    );
  }

  Widget _buildProfileHeader(
    String uid,
    String displayName,
    String bio,
    String website,
    String publicId,
    UserLevelState levelState,
    int svipTier,
    String? photoUrl,
    _ProfileAnalytics analytics,
  ) {
    return Column(
      children: [
        const SizedBox(height: 20),
        Hero(
          tag: 'profile-avatar-$uid',
          child: Container(
            width: 104,
            height: 104,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Colors.redAccent, Color(0xFFFF7A45)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.redAccent.withValues(alpha: 0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: CircleAvatar(
              backgroundColor: const Color(0xFF19191F),
              backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                  ? NetworkImage(photoUrl)
                  : null,
              child: photoUrl == null || photoUrl.isEmpty
                  ? const Icon(Icons.person, color: Colors.white54, size: 52)
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          displayName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        _buildIdentityRow(
          uid: uid,
          displayName: displayName,
          photoUrl: photoUrl ?? '',
          publicId: publicId,
          levelState: levelState,
          svipTier: svipTier,
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            bio,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.35,
            ),
          ),
        ),
        if (website.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          _buildPublicLink(website),
        ],
        const SizedBox(height: 16),
        // Stats
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildStatColumn(
              _formatNumber(analytics.followingCount),
              'Following',
            ),
            _buildStatDivider(),
            _buildStatColumn(
              _formatNumber(analytics.followersCount),
              'Followers',
            ),
            _buildStatDivider(),
            _buildStatColumn(_formatNumber(analytics.totalLikes), 'Likes'),
          ],
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF161821),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _ProfileQuickIcon(
                    label: 'Live',
                    icon: Icons.mic_rounded,
                    colors: [Color(0xFFB4A8FF), Color(0xFF9C8BFF)],
                    onTap: _openHostCenter,
                  ),
                  SizedBox(width: 14),
                  _ProfileQuickIcon(
                    label: 'Creator',
                    icon: Icons.spa_rounded,
                    colors: [Color(0xFFFFD18A), Color(0xFFFFB06A)],
                    onTap: () => _showCreatorDashboardSheet(analytics),
                  ),
                  SizedBox(width: 14),
                  _ProfileQuickIcon(
                    label: 'Family',
                    icon: Icons.groups_rounded,
                    colors: [Color(0xFFFFB59D), Color(0xFFFF8A66)],
                  ),
                  SizedBox(width: 14),
                  _ProfileQuickIcon(
                    label: 'Store',
                    icon: Icons.storefront_rounded,
                    colors: [Color(0xFFF5A3FF), Color(0xFFDD6DFF)],
                  ),
                  SizedBox(width: 14),
                  _ProfileQuickIcon(
                    label: 'SVIP',
                    icon: Icons.auto_awesome_rounded,
                    colors: [Color(0xFFDFA7FF), Color(0xFFB072FF)],
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SvipScreen()),
                      );
                    },
                  ),
                  SizedBox(width: 14),
                  _ProfileQuickIcon(
                    label: 'Wallet',
                    icon: Icons.account_balance_wallet_rounded,
                    colors: [Color(0xFFFFB5C7), Color(0xFFFF6A8A)],
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const WalletScreen()),
                      );
                    },
                  ),
                  SizedBox(width: 14),
                  _ProfileQuickIcon(
                    label: 'Task',
                    icon: Icons.assignment_rounded,
                    colors: [Color(0xFFB6B7FF), Color(0xFF7E80E8)],
                  ),
                  SizedBox(width: 14),
                  _ProfileQuickIcon(
                    label: 'My Bag',
                    icon: Icons.backpack_rounded,
                    colors: [Color(0xFF96E9FF), Color(0xFF5DC7E9)],
                  ),
                  SizedBox(width: 14),
                  _ProfileQuickIcon(
                    label: 'Withdrawal',
                    icon: Icons.account_balance_rounded,
                    colors: [Color(0xFF8DFFCD), Color(0xFF2BCB8A)],
                  ),
                  SizedBox(width: 14),
                  _ProfileQuickIcon(
                    label: 'KYC',
                    icon: Icons.verified_user_rounded,
                    colors: [Color(0xFF9BB6FF), Color(0xFF5A78E8)],
                  ),
                  SizedBox(width: 14),
                  _ProfileQuickIcon(
                    label: 'Bonus',
                    icon: Icons.card_giftcard_rounded,
                    colors: [Color(0xFFFFD29B), Color(0xFFFF9B57)],
                  ),
                  SizedBox(width: 14),
                  _ProfileQuickIcon(
                    label: 'Analytics',
                    icon: Icons.analytics_rounded,
                    colors: [Color(0xFFFFA8CC), Color(0xFFE95F9A)],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Action Buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OutlinedButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditProfileScreen(
                      initialDisplayName: displayName,
                      initialBio: bio,
                      initialPhotoUrl: photoUrl,
                    ),
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: const Text(
                'Edit Profile',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final text =
                    'Follow $displayName on LikeeHit: https://likeehit.com/@$uid';
                await Clipboard.setData(ClipboardData(text: text));
                messenger.showSnackBar(
                  const SnackBar(content: Text('Profile link copied')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: const Text(
                'Share Profile',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildHighlightsSection(uid),
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
    required int svipTier,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
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
              fontSize: 14,
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
          SvipBadge(
            tier: svipTier,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (_) => const SvipScreen()),
              );
            },
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

  Widget _buildPublicLink(String website) {
    final uri = _normalisePublicLink(website);
    final displayLink = website.trim();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: InkWell(
        onTap: uri == null ? null : () => _openPublicLink(website),
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1287FF).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: const Color(0xFF1287FF).withValues(alpha: 0.20),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.link_rounded,
                color: Color(0xFF57A7FF),
                size: 16,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  displayLink,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF57A7FF),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreatorDashboardCard(_ProfileAnalytics analytics) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 10 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF160B11), Color(0xFF101014), Color(0xFF050506)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.redAccent.withValues(alpha: 0.14),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
            BoxShadow(
              color: const Color(0xFFFF2D75).withValues(alpha: 0.08),
              blurRadius: 30,
              offset: const Offset(14, -12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.insights_rounded,
                  color: Colors.redAccent,
                  size: 18,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Creator Dashboard',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF2D55).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.redAccent.withValues(alpha: 0.28),
                    ),
                  ),
                  child: Text(
                    '${analytics.engagementRate.toStringAsFixed(1)}% ER',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _buildDashboardMetric(
                    label: 'Videos',
                    value: _formatNumber(analytics.totalVideos),
                    icon: Icons.video_library_rounded,
                  ),
                  _buildDashboardMetric(
                    label: 'Likes',
                    value: _formatNumber(analytics.totalLikes),
                    icon: Icons.favorite_rounded,
                  ),
                  _buildDashboardMetric(
                    label: 'Views',
                    value: _formatNumber(analytics.totalViews),
                    icon: Icons.visibility_rounded,
                  ),
                  _buildDashboardMetric(
                    label: 'Followers',
                    value: _formatNumber(analytics.followersCount),
                    icon: Icons.group_rounded,
                  ),
                  _buildDashboardMetric(
                    label: 'Following',
                    value: _formatNumber(analytics.followingCount),
                    icon: Icons.person_add_alt_1_rounded,
                    isLast: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCreatorDashboardSheet(_ProfileAnalytics analytics) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF101014),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 18),
                _buildCreatorDashboardCard(analytics),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CreatorToolsScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.spa_rounded),
                    label: const Text('Open creator tools'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHighlightsSection(String uid) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('highlights')
          .orderBy('highlightedAt', descending: true)
          .limit(20)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = (snapshot.data?.docs ?? const []).where((doc) {
          final data = doc.data();
          final isHighlight = data['isHighlight'] == true;
          final storyId = data['storyId']?.toString() ?? '';
          final mediaUrl =
              data['mediaUrl']?.toString() ??
              data['imageUrl']?.toString() ??
              data['thumbnailUrl']?.toString() ??
              '';
          return isHighlight && storyId.isNotEmpty && mediaUrl.isNotEmpty;
        }).toList();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Highlights',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 128,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: docs.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(width: 14),
                  itemBuilder: (context, index) {
                    if (index == 0) return const _NewHighlightTile();
                    final doc = docs[index - 1];
                    final data = doc.data();
                    return _HighlightTile(
                      data: data,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => StoryViewerScreen(
                              ownerUid: uid,
                              initialStoryId:
                                  data['storyId']?.toString() ?? doc.id,
                              highlightsOnly: true,
                            ),
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

  Widget _buildDashboardMetric({
    required String label,
    required String value,
    required IconData icon,
    bool isLast = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(right: isLast ? 0 : 8),
      child: Container(
        width: 86,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.055),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.075)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 12,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white70, size: 16),
            const SizedBox(height: 6),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
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
          padding: const EdgeInsets.all(4),
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 5,
            mainAxisSpacing: 5,
            childAspectRatio: 9 / 16,
          ),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final post = docs[index].data() as Map<String, dynamic>;
            final viewsCount = _toInt(post['viewsCount'] ?? post['views']);
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
                viewsCount,
                icon: Icons.visibility_rounded,
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
          padding: const EdgeInsets.all(4),
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 5,
            mainAxisSpacing: 5,
            childAspectRatio: 9 / 16,
          ),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final post = docs[index].data() as Map<String, dynamic>;
            final viewsCount = _toInt(post['viewsCount'] ?? post['views']);
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
                viewsCount,
                icon: Icons.visibility_rounded,
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
          padding: const EdgeInsets.all(4),
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 5,
            mainAxisSpacing: 5,
            childAspectRatio: 9 / 16,
          ),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final post = docs[index].data() as Map<String, dynamic>;
            final viewsCount = _toInt(post['viewsCount'] ?? post['views']);
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
                viewsCount,
                icon: Icons.visibility_rounded,
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
          padding: const EdgeInsets.all(4),
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 5,
            mainAxisSpacing: 5,
            childAspectRatio: 9 / 16,
          ),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final post = docs[index].data() as Map<String, dynamic>;
            final viewsCount = _toInt(post['viewsCount'] ?? post['views']);
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
                viewsCount,
                icon: Icons.visibility_rounded,
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
    final thumbnailUrl =
        post['thumbnailUrl']?.toString() ??
        post['thumbnail']?.toString() ??
        post['coverUrl']?.toString() ??
        '';
    final videoUrl = post['videoUrl']?.toString() ?? '';

    return _HoverLift(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.34),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: const Color(0xFFFF2D55).withValues(alpha: 0.10),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (thumbnailUrl.isNotEmpty)
                Image.network(
                  thumbnailUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const _ThumbnailSkeleton();
                  },
                  errorBuilder: (context, error, stackTrace) =>
                      videoUrl.isNotEmpty
                      ? _VideoFrameThumbnail(videoUrl: videoUrl)
                      : const _ThumbnailSkeleton(),
                )
              else if (videoUrl.isNotEmpty)
                _VideoFrameThumbnail(videoUrl: videoUrl)
              else
                const _ThumbnailSkeleton(),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFFF2D55).withValues(alpha: 0.10),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.78),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0, 0.45, 1],
                  ),
                ),
              ),
              Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.30),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.22),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
              if (post['privacy'] == 'Private')
                const Positioned(
                  top: 7,
                  right: 7,
                  child: Icon(
                    Icons.lock_rounded,
                    color: Colors.white70,
                    size: 15,
                  ),
                ),
              if (caption.isNotEmpty)
                Positioned(
                  left: 8,
                  right: 8,
                  top: 8,
                  child: Text(
                    caption,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      height: 1.15,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.32),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.10),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          _formatNumber(metricCount),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showProfileMenuBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8, bottom: 16),
                height: 4,
                width: 40,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              _buildMenuOption(
                icon: Icons.storefront,
                title: 'Creator tools',
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              _buildMenuOption(
                icon: Icons.account_balance_wallet,
                title: 'Balance',
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              _buildMenuOption(
                icon: Icons.qr_code_scanner,
                title: 'QR code',
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              _buildMenuOption(
                icon: Icons.settings,
                title: 'Settings and privacy',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMenuOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.white, size: 28),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
      onTap: onTap,
    );
  }
}

class _HoverLift extends StatefulWidget {
  const _HoverLift({required this.child});

  final Widget child;

  @override
  State<_HoverLift> createState() => _HoverLiftState();
}

class _ProfileQuickIcon extends StatelessWidget {
  const _ProfileQuickIcon({
    required this.label,
    required this.icon,
    required this.colors,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: colors,
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.last.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _HoverLiftState extends State<_HoverLift> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedScale(
        scale: _hovering ? 1.025 : 1,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: _hovering ? 0.94 : 1,
          duration: const Duration(milliseconds: 160),
          child: widget.child,
        ),
      ),
    );
  }
}

class _VideoFrameThumbnail extends StatefulWidget {
  const _VideoFrameThumbnail({required this.videoUrl});

  final String videoUrl;

  @override
  State<_VideoFrameThumbnail> createState() => _VideoFrameThumbnailState();
}

class _VideoFrameThumbnailState extends State<_VideoFrameThumbnail> {
  late final VideoPlayerController _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    _controller
        .initialize()
        .then((_) async {
          await _controller.setVolume(0);
          await _controller.pause();
          if (_controller.value.duration > const Duration(milliseconds: 160)) {
            await _controller.seekTo(const Duration(milliseconds: 120));
          }
          if (mounted) {
            setState(() => _ready = true);
          }
        })
        .catchError((_) {
          if (mounted) {
            setState(() => _ready = false);
          }
        });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready || !_controller.value.isInitialized) {
      return const _ThumbnailSkeleton();
    }

    final size = _controller.value.size;
    if (size.width <= 0 || size.height <= 0) {
      return const _ThumbnailSkeleton();
    }

    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: VideoPlayer(_controller),
        ),
      ),
    );
  }
}

class _ThumbnailSkeleton extends StatefulWidget {
  const _ThumbnailSkeleton();

  @override
  State<_ThumbnailSkeleton> createState() => _ThumbnailSkeletonState();
}

class _ThumbnailSkeletonState extends State<_ThumbnailSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: const [
                Color(0xFF13090E),
                Color(0xFF2A1720),
                Color(0xFF0A0A0D),
              ],
              begin: Alignment(-1 + (_controller.value * 2), -1),
              end: Alignment(1 + (_controller.value * 2), 1),
            ),
          ),
        );
      },
    );
  }
}

class _ProfileAnalytics {
  const _ProfileAnalytics({
    required this.totalVideos,
    required this.totalLikes,
    required this.totalViews,
    required this.followersCount,
    required this.followingCount,
  });

  final int totalVideos;
  final int totalLikes;
  final int totalViews;
  final int followersCount;
  final int followingCount;

  double get engagementRate {
    if (totalViews <= 0) return 0;
    return (totalLikes / totalViews) * 100;
  }

  factory _ProfileAnalytics.fromDocs(
    List<QueryDocumentSnapshot> docs, {
    required int followersCount,
    required int followingCount,
  }) {
    var totalLikes = 0;
    var totalViews = 0;

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final likes = data['likes'];
      totalLikes += likes is List ? likes.length : _asInt(data['likesCount']);
      totalViews += _asInt(data['viewsCount'] ?? data['views']);
    }

    return _ProfileAnalytics(
      totalVideos: docs.length,
      totalLikes: totalLikes,
      totalViews: totalViews,
      followersCount: followersCount,
      followingCount: followingCount,
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is List) return value.length;
    return 0;
  }
}

class _NewHighlightTile extends StatelessWidget {
  const _NewHighlightTile();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      child: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: Icon(Icons.add_rounded, color: Colors.white70, size: 34),
              ),
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'New',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _HighlightTile extends StatelessWidget {
  const _HighlightTile({required this.data, required this.onTap});

  final Map<String, dynamic> data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final imageUrl =
        data['imageUrl']?.toString() ??
        data['thumbnailUrl']?.toString() ??
        data['mediaUrl']?.toString() ??
        '';
    final title = data['highlightTitle']?.toString() ?? 'Collection';
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: SizedBox(
        width: 92,
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  color: Colors.white10,
                  child: imageUrl.isEmpty
                      ? const Icon(Icons.image_rounded, color: Colors.white70)
                      : Image.network(
                          imageUrl,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                        ),
                ),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
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
