import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'screens/live/host_center_screen.dart';

class CreatorToolsScreen extends StatefulWidget {
  const CreatorToolsScreen({super.key});

  @override
  State<CreatorToolsScreen> createState() => _CreatorToolsScreenState();
}

class _CreatorToolsScreenState extends State<CreatorToolsScreen> {
  int _tab = 0;
  int _liveSubTab = 0;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Sign in required')));
    }
    return Scaffold(
      backgroundColor: const Color(0xFF090A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF090A0F),
        title: const Text('Creator tools', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        actions: const [Padding(padding: EdgeInsets.only(right: 12), child: Icon(Icons.settings, color: Colors.white))],
      ),
      body: StreamBuilder<_CreatorStats>(
        stream: _watchCreatorStats(uid),
        builder: (context, snapshot) {
          final stats = snapshot.data ?? _CreatorStats.empty();
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 18),
            children: [
              _analyticsHeader(stats),
              const SizedBox(height: 12),
              _tabBar(),
              const SizedBox(height: 10),
              if (_tab == 0) _toolsTab(stats),
              if (_tab == 1) _liveTab(stats),
              if (_tab == 2) _growthTab(stats),
              if (_tab == 3) _monetizationTab(stats),
            ],
          );
        },
      ),
    );
  }

  Widget _analyticsHeader(_CreatorStats s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Analytics', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 22)),
            const Spacer(),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => _AnalyticsScreen(stats: s)),
              ),
              child: const Text('View all', style: TextStyle(color: Colors.white70)),
            ),
          ],
        ),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 4,
          childAspectRatio: 0.72,
          crossAxisSpacing: 8,
          children: [
            _kpi('Video views', _fmtNum(s.videoViews), Icons.bar_chart_rounded),
            _kpi('Profile views', _fmtNum(s.profileViews), Icons.person_outline_rounded),
            _kpi('Likes', _fmtNum(s.likes), Icons.favorite_border_rounded),
            _kpi('Comments', _fmtNum(s.comments), Icons.chat_bubble_outline_rounded),
          ],
        ),
      ],
    );
  }

  Widget _tabBar() {
    final items = ['Tools', 'LIVE', 'Growth', 'Monetization'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF171822),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: List.generate(items.length, (i) {
          final active = _tab == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _tab = i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: active ? const Color(0xFF2A2E45) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  items[i],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: active ? Colors.white : Colors.white70,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _toolsTab(_CreatorStats s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Your tools', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20)),
        const SizedBox(height: 10),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 4,
          childAspectRatio: 0.88,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          children: [
            _tool('Creator Portal', Icons.school_outlined, onTap: () => _openTool('creator_portal', 'Creator Portal', 'Manage profile growth tools and onboarding.')),
            _tool('Creator Next', Icons.auto_awesome_rounded, onTap: () => _openTool('creator_next', 'Creator Next', 'Partner and growth opportunities for creators.')),
            _tool('LIVE Center', Icons.live_tv_rounded, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HostCenterScreen()))),
            _tool('Subscription', Icons.star_border_rounded, onTap: () => _openTool('subscription', 'Subscription', 'Set monthly creator subscription plan.', initializeDefaults: true)),
            _tool('Video Gifts', Icons.card_giftcard_rounded, onTap: () => _openTool('video_gifts', 'Video Gifts', 'Accept gifts on videos and live.')),
            _tool('Work with Artists', Icons.music_note_rounded, onTap: () => _openTool('work_with_artists', 'Work with Artists', 'Collaborate with artists and labels.')),
            _tool('Series', Icons.video_collection_outlined, onTap: () => _openTool('series', 'Series', 'Build content series and track performance.')),
            _tool('TikTok Shop', Icons.storefront_rounded, onTap: () => _openTool('shop', 'Creator Shop', 'Product and affiliate monetization controls.')),
            _tool('Brand collabs', Icons.handshake_outlined, onTap: () => _openTool('brand_collabs', 'Brand Collaborations', 'Manage brand partnership offers.')),
            _tool('Effect Creator', Icons.auto_fix_high_rounded, onTap: () => _openTool('effect_creator', 'Effect Creator', 'Publish effects and track usage.')),
            _tool('Video maker', Icons.movie_creation_outlined, onTap: () => _openTool('video_maker', 'Video Maker', 'Templates and quick edit workflows.')),
            _tool('Add Yours', Icons.add_box_outlined, onTap: () => _openTool('add_yours', 'Add Yours', 'Community prompt tool controls.')),
          ],
        ),
        const SizedBox(height: 14),
        _promoCard(),
      ],
    );
  }

  Widget _liveTab(_CreatorStats s) {
    final subTabs = ['Data', 'Task', 'Top Fans'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFF171822),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: List.generate(subTabs.length, (i) {
              final active = _liveSubTab == i;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _liveSubTab = i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: active ? const Color(0xFF2A2E45) : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      subTabs[i],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: active ? Colors.white : Colors.white70,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 10),
        if (_liveSubTab == 0) ...[
          _miniMetric('Live sessions', '${s.liveSessions}', Icons.videocam_rounded),
          _miniMetric('Live diamonds', '${s.liveDiamonds}', Icons.diamond_rounded),
          _miniMetric('Valid live day', '${s.validLiveDay}', Icons.calendar_today_rounded),
        ],
        if (_liveSubTab == 1) ...[
          _taskItem('Go live 30 min', s.validLiveMinutes, 30),
          _taskItem('Get 1,000 stars', s.liveDiamonds, 1000),
          _taskItem('Get 10 comments', s.comments, 10),
        ],
        if (_liveSubTab == 2) ...[
          if (s.topFans.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text('No top fans yet', style: TextStyle(color: Colors.white70)),
              ),
            )
          else
            ...s.topFans.asMap().entries.map((entry) {
              final rank = entry.key + 1;
              final fan = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF171822),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: const Color(0xFF2D3150),
                      backgroundImage: fan.photoUrl.isNotEmpty ? NetworkImage(fan.photoUrl) : null,
                      child: fan.photoUrl.isEmpty ? const Icon(Icons.person, color: Colors.white70, size: 16) : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '#$rank ${fan.name}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text('${fan.stars}★', style: const TextStyle(color: Color(0xFFFFD66B), fontWeight: FontWeight.w800)),
                  ],
                ),
              );
            }),
        ],
      ],
    );
  }

  Widget _growthTab(_CreatorStats s) {
    return Column(
      children: [
        _miniMetric('Total followers', _fmtNum(s.followers), Icons.group_rounded),
        _miniMetric('Profile views', _fmtNum(s.profileViews), Icons.person_2_outlined),
        _miniMetric('Engagement rate', '${s.engagementRate.toStringAsFixed(2)}%', Icons.insights_rounded),
      ],
    );
  }

  Widget _monetizationTab(_CreatorStats s) {
    final tools = [
      ('LIVE Gifts', 'Get rewarded for your live videos'),
      ('Video Gifts', 'Get rewarded for your creativity'),
      ('Subscription', 'Create subscription for your viewers'),
      ('Series', 'Create series and earn'),
      ('Tips', 'Allow viewers to send tips'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: tools.map((t) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF171822),
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _openTool(
              t.$1.toLowerCase().replaceAll(' ', '_'),
              t.$1,
              t.$2,
              initializeDefaults: t.$1 == 'Subscription',
            ),
            child: Row(
            children: [
              const Icon(Icons.wallet_giftcard_rounded, color: Colors.white70),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.$1, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    Text(t.$2, style: const TextStyle(color: Colors.white60, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white38),
            ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _kpi(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF171822),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.white70),
          const SizedBox(height: 6),
          Text(title, style: const TextStyle(color: Colors.white60, fontSize: 11)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
        ],
      ),
    );
  }

  Widget _tool(String label, IconData icon, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF171822),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 21),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _promoCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF171822),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome_rounded, color: Colors.purpleAccent),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Creator Next\nJoin now and grow your audience',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF3A74)),
            child: const Text('Join', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _miniMetric(String title, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF171822),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: const TextStyle(color: Colors.white))),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _taskItem(String title, int value, int goal) {
    final progress = (value / goal).clamp(0.0, 1.0);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF171822),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
              Text('$value/$goal', style: const TextStyle(color: Colors.white70)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: const Color(0xFF2B2E45),
              valueColor: const AlwaysStoppedAnimation(Color(0xFFFF4FA0)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openTool(
    String toolKey,
    String title,
    String subtitle, {
    bool initializeDefaults = false,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('creatorTools')
        .doc(toolKey);

    if (initializeDefaults) {
      final doc = await ref.get();
      if (!doc.exists) {
        // Best beginner-friendly default: 99 stars per month.
        await ref.set({
          'enabled': true,
          'status': 'active',
          'subscriptionPlan': {
            'name': 'Starter Fan Club',
            'priceStarsMonthly': 99,
            'benefits': ['VIP badge', 'Priority reply', 'Exclusive posts'],
          },
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }

    if (!mounted) return;
    Widget screen;
    switch (toolKey) {
      case 'creator_portal':
        screen = _CreatorPortalScreen(uid: uid);
        break;
      case 'video_gifts':
        screen = _VideoGiftsScreen(uid: uid);
        break;
      case 'brand_collabs':
        screen = _BrandCollabsScreen(uid: uid);
        break;
      case 'shop':
        screen = _LikeehitShopScreen(uid: uid);
        break;
      default:
        screen = _CreatorToolDetailScreen(
          uid: uid,
          toolKey: toolKey,
          title: title,
          subtitle: subtitle,
        );
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => screen,
      ),
    );
  }
}

class _AnalyticsScreen extends StatelessWidget {
  const _AnalyticsScreen({required this.stats});
  final _CreatorStats stats;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF090A0F),
        title: const Text('Analytics', style: TextStyle(color: Colors.white)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _panel('Video views', _fmtNum(stats.videoViews)),
          _panel('Profile views', _fmtNum(stats.profileViews)),
          _panel('Likes', _fmtNum(stats.likes)),
          _panel('Comments', _fmtNum(stats.comments)),
          const SizedBox(height: 10),
          Container(
            height: 170,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF171822),
              borderRadius: BorderRadius.circular(12),
            ),
            child: CustomPaint(
              painter: _AnalyticsLinePainter(points: stats.last7DayTrend),
              child: const Align(
                alignment: Alignment.topLeft,
                child: Text('7-day trend', style: TextStyle(color: Colors.white70)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _panel(String title, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF171822),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(child: Text(title, style: const TextStyle(color: Colors.white70))),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 22)),
        ],
      ),
    );
  }
}

class _AnalyticsLinePainter extends CustomPainter {
  const _AnalyticsLinePainter({required this.points});
  final List<int> points;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final maxY = points.reduce((a, b) => a > b ? a : b).toDouble().clamp(1.0, (1 << 30).toDouble());
    final path = Path();
    for (int i = 0; i < points.length; i++) {
      final x = size.width * i / (points.length - 1);
      final y = size.height - ((points[i] / maxY) * (size.height - 24)) - 8;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      canvas.drawCircle(Offset(x, y), 3.5, Paint()..color = const Color(0xFF5A8CFF));
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF5A8CFF)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _AnalyticsLinePainter oldDelegate) {
    return oldDelegate.points != points;
  }
}

Stream<_CreatorStats> _watchCreatorStats(String uid) {
  final db = FirebaseFirestore.instance;
  final rooms = db.collection('liveRooms').where('hostId', isEqualTo: uid).snapshots();

  return rooms.asyncMap((roomSnap) async {
    final postSnap = await db.collection('posts').where('userId', isEqualTo: uid).get();
    final userSnap = await db.collection('users').doc(uid).get();
    final giftSnap = await db.collectionGroup('giftEvents').where('hostId', isEqualTo: uid).get();

    int videoViews = 0;
    int likes = 0;
    int comments = 0;
    final trend = List<int>.filled(7, 0);
    final now = DateTime.now();
    for (final d in postSnap.docs) {
      final data = d.data();
      videoViews += _toInt(data['viewsCount'] ?? data['views']);
      final l = data['likes'];
      likes += l is List ? l.length : _toInt(data['likesCount']);
      comments += _toInt(data['comments']);
      final created = data['createdAt'] is Timestamp ? (data['createdAt'] as Timestamp).toDate() : null;
      if (created != null) {
        final diff = now.difference(DateTime(created.year, created.month, created.day)).inDays;
        if (diff >= 0 && diff < 7) {
          trend[6 - diff] += _toInt(data['viewsCount'] ?? data['views']);
        }
      }
    }

    int liveDiamonds = 0;
    int liveSessions = 0;
    final liveDays = <String>{};
    for (final d in roomSnap.docs) {
      final data = d.data();
      liveDiamonds += _toInt(data['totalGiftStars']);
      liveSessions += 1;
      final created = data['createdAt'] is Timestamp ? (data['createdAt'] as Timestamp).toDate() : null;
      if (created != null) {
        liveDays.add('${created.year}-${created.month}-${created.day}');
      }
    }

    final topFanMap = <String, _TopFan>{};
    for (final d in giftSnap.docs) {
      final data = d.data();
      final fanUid = data['uid']?.toString() ?? '';
      if (fanUid.isEmpty) continue;
      final current = topFanMap[fanUid];
      final stars = _toInt(data['totalStars']);
      topFanMap[fanUid] = _TopFan(
        uid: fanUid,
        name: data['name']?.toString() ?? current?.name ?? 'Fan',
        photoUrl: current?.photoUrl ?? '',
        stars: (current?.stars ?? 0) + stars,
      );
    }
    final topFans = topFanMap.values.toList()..sort((a, b) => b.stars.compareTo(a.stars));
    final usersToLoad = topFans.take(10).map((e) => e.uid).toList();
    for (final id in usersToLoad) {
      final idx = topFans.indexWhere((e) => e.uid == id);
      if (idx == -1) continue;
      final uDoc = await db.collection('users').doc(id).get();
      final uData = uDoc.data() ?? const <String, dynamic>{};
      topFans[idx] = _TopFan(
        uid: topFans[idx].uid,
        name: (uData['name']?.toString().isNotEmpty ?? false) ? uData['name'].toString() : topFans[idx].name,
        photoUrl: uData['photoUrl']?.toString() ?? '',
        stars: topFans[idx].stars,
      );
    }

    final userData = userSnap.data() ?? <String, dynamic>{};
    final profileViews = _toInt(userData['profileViews']);
    final followers = _toInt(userData['followers']);
    final double engagementRate = videoViews > 0 ? (likes / videoViews) * 100 : 0.0;
    final validLiveMinutes = _toInt(userData['validLiveMinutes']);

    return _CreatorStats(
      videoViews: videoViews,
      profileViews: profileViews,
      likes: likes,
      comments: comments,
      followers: followers,
      liveDiamonds: liveDiamonds,
      liveSessions: liveSessions,
      validLiveDay: liveDays.length,
      validLiveMinutes: validLiveMinutes,
      engagementRate: engagementRate,
      last7DayTrend: trend,
      topFans: topFans.take(10).toList(),
    );
  });
}

class _CreatorStats {
  const _CreatorStats({
    required this.videoViews,
    required this.profileViews,
    required this.likes,
    required this.comments,
    required this.followers,
    required this.liveDiamonds,
    required this.liveSessions,
    required this.validLiveDay,
    required this.validLiveMinutes,
    required this.engagementRate,
    required this.last7DayTrend,
    required this.topFans,
  });

  final int videoViews;
  final int profileViews;
  final int likes;
  final int comments;
  final int followers;
  final int liveDiamonds;
  final int liveSessions;
  final int validLiveDay;
  final int validLiveMinutes;
  final double engagementRate;
  final List<int> last7DayTrend;
  final List<_TopFan> topFans;

  factory _CreatorStats.empty() {
    return const _CreatorStats(
      videoViews: 0,
      profileViews: 0,
      likes: 0,
      comments: 0,
      followers: 0,
      liveDiamonds: 0,
      liveSessions: 0,
      validLiveDay: 0,
      validLiveMinutes: 0,
      engagementRate: 0,
      last7DayTrend: [0, 0, 0, 0, 0, 0, 0],
      topFans: [],
    );
  }
}

class _TopFan {
  const _TopFan({
    required this.uid,
    required this.name,
    required this.photoUrl,
    required this.stars,
  });

  final String uid;
  final String name;
  final String photoUrl;
  final int stars;
}

class _CreatorToolDetailScreen extends StatelessWidget {
  const _CreatorToolDetailScreen({
    required this.uid,
    required this.toolKey,
    required this.title,
    required this.subtitle,
  });

  final String uid;
  final String toolKey;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('creatorTools')
        .doc(toolKey);

    return Scaffold(
      backgroundColor: const Color(0xFF090A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF090A0F),
        title: Text(title, style: const TextStyle(color: Colors.white)),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: ref.snapshots(),
        builder: (context, snap) {
          final data = snap.data?.data() ?? <String, dynamic>{};
          final enabled = data['enabled'] == true;
          final status = data['status']?.toString() ?? 'inactive';
          final stats = (data['stats'] as Map<String, dynamic>?) ?? <String, dynamic>{};
          final subscription = (data['subscriptionPlan'] as Map<String, dynamic>?) ?? <String, dynamic>{};

          return ListView(
            padding: const EdgeInsets.all(14),
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF171822),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(subtitle, style: const TextStyle(color: Colors.white70)),
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                tileColor: const Color(0xFF171822),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                title: const Text('Tool Enabled', style: TextStyle(color: Colors.white)),
                subtitle: Text('Status: $status', style: const TextStyle(color: Colors.white70)),
                value: enabled,
                onChanged: (v) async {
                  await ref.set({
                    'enabled': v,
                    'status': v ? 'active' : 'inactive',
                    'updatedAt': FieldValue.serverTimestamp(),
                  }, SetOptions(merge: true));
                },
              ),
              const SizedBox(height: 10),
              if (toolKey == 'subscription') _subscriptionCard(ref, subscription),
              if (stats.isNotEmpty)
                ...stats.entries.map((e) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF171822),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              e.key,
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ),
                          Text(
                            '${e.value}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    )),
              if (stats.isEmpty) const SizedBox(height: 2),
            ],
          );
        },
      ),
    );
  }

  Widget _subscriptionCard(
    DocumentReference<Map<String, dynamic>> ref,
    Map<String, dynamic> subscription,
  ) {
    final price = _toInt(subscription['priceStarsMonthly']);
    final name = subscription['name']?.toString() ?? 'Starter Fan Club';
    final effectivePrice = price > 0 ? price : 99;
    return Builder(
      builder: (context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF171822),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('$effectivePrice stars / month', style: const TextStyle(color: Color(0xFFFFD66B), fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text('Recommended starter pricing: 99 stars (best for early creator growth).', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () async {
                await ref.set({
                  'subscriptionPlan': {
                    'name': 'Starter Fan Club',
                    'priceStarsMonthly': 99,
                    'benefits': ['VIP badge', 'Priority reply', 'Exclusive posts'],
                  },
                  'status': 'active',
                  'enabled': true,
                  'updatedAt': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Starter subscription plan applied (99 stars/month).')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF3A74)),
              child: const Text('Apply Starter Plan', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreatorPortalScreen extends StatelessWidget {
  const _CreatorPortalScreen({required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context) {
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
    final postsRef = FirebaseFirestore.instance.collection('posts').where('userId', isEqualTo: uid);
    return Scaffold(
      backgroundColor: const Color(0xFF090A0F),
      appBar: AppBar(backgroundColor: const Color(0xFF090A0F), title: const Text('Creator Portal', style: TextStyle(color: Colors.white))),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: userRef.snapshots(),
        builder: (context, userSnap) {
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: postsRef.snapshots(),
            builder: (context, postSnap) {
              final user = userSnap.data?.data() ?? const <String, dynamic>{};
              final posts = postSnap.data?.docs ?? const [];
              final hasPhoto = (user['photoUrl']?.toString().isNotEmpty ?? false) || (user['photoURL']?.toString().isNotEmpty ?? false);
              final hasBio = user['bio']?.toString().trim().isNotEmpty ?? false;
              final hasName = user['name']?.toString().trim().isNotEmpty ?? false;
              final hasFirstPost = posts.isNotEmpty;
              final followers = _toInt(user['followers']);
              final done = [hasPhoto, hasBio, hasName, hasFirstPost, followers >= 10].where((e) => e).length;
              final percent = done / 5;
              return ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  _bigStatCard('Profile Strength', '${(percent * 100).toStringAsFixed(0)}%', subtitle: '$done/5 completed'),
                  const SizedBox(height: 10),
                  _checkItem('Profile photo', hasPhoto),
                  _checkItem('Display name', hasName),
                  _checkItem('Bio added', hasBio),
                  _checkItem('First post uploaded', hasFirstPost),
                  _checkItem('10+ followers', followers >= 10),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _VideoGiftsScreen extends StatelessWidget {
  const _VideoGiftsScreen({required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context) {
    final postsRef = FirebaseFirestore.instance.collection('posts').where('userId', isEqualTo: uid).snapshots();
    final giftsRef = FirebaseFirestore.instance.collectionGroup('videoGiftEvents').where('creatorId', isEqualTo: uid).snapshots();
    return Scaffold(
      backgroundColor: const Color(0xFF090A0F),
      appBar: AppBar(backgroundColor: const Color(0xFF090A0F), title: const Text('Video Gifts', style: TextStyle(color: Colors.white))),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: postsRef,
        builder: (context, postsSnap) {
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: giftsRef,
            builder: (context, giftsSnap) {
              final posts = postsSnap.data?.docs ?? const [];
              final giftMap = <String, int>{};
              for (final g in giftsSnap.data?.docs ?? const []) {
                final d = g.data();
                final postId = d['postId']?.toString() ?? '';
                if (postId.isEmpty) continue;
                giftMap[postId] = (giftMap[postId] ?? 0) + _toInt(d['stars']) * (_toInt(d['quantity']) == 0 ? 1 : _toInt(d['quantity']));
              }

              int totalStars = 0;
              final rows = posts.map((p) {
                final d = p.data();
                final postId = p.id;
                final stars = giftMap[postId] ?? _toInt(d['giftStars']);
                totalStars += stars;
                return _VideoGiftRow(
                  postId: postId,
                  thumbnail: d['thumbnailUrl']?.toString() ?? '',
                  caption: d['caption']?.toString() ?? 'My video',
                  stars: stars,
                );
              }).toList()
                ..sort((a, b) => b.stars.compareTo(a.stars));

              return ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  _bigStatCard(
                    'Total Video Gift Stars',
                    '$totalStars stars',
                    subtitle: '${rows.length} videos',
                  ),
                  const SizedBox(height: 10),
                  if (rows.isEmpty)
                    const Text('No video gift data yet.', style: TextStyle(color: Colors.white70))
                  else
                    ...rows,
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _BrandCollabsScreen extends StatelessWidget {
  const _BrandCollabsScreen({required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('brandCollabs')
        .orderBy('createdAt', descending: true);
    return Scaffold(
      backgroundColor: const Color(0xFF090A0F),
      appBar: AppBar(backgroundColor: const Color(0xFF090A0F), title: const Text('Brand Collaborations', style: TextStyle(color: Colors.white))),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFFF3A74),
        onPressed: () async {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('brandCollabs')
              .add({
            'brandName': 'Demo Brand',
            'campaign': 'Summer Creator Campaign',
            'offerStars': 2500,
            'status': 'pending',
            'createdAt': FieldValue.serverTimestamp(),
          });
        },
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Collab', style: TextStyle(color: Colors.white)),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: ref.snapshots(),
        builder: (context, snap) {
          final docs = snap.data?.docs ?? const [];
          int pending = 0, active = 0, completed = 0;
          for (final d in docs) {
            final status = d.data()['status']?.toString() ?? 'pending';
            if (status == 'active') {
              active++;
            } else if (status == 'completed') {
              completed++;
            } else {
              pending++;
            }
          }
          return ListView(
            padding: const EdgeInsets.all(14),
            children: [
              Row(children: [
                Expanded(child: _smallStat('Pending', '$pending')),
                const SizedBox(width: 8),
                Expanded(child: _smallStat('Active', '$active')),
                const SizedBox(width: 8),
                Expanded(child: _smallStat('Completed', '$completed')),
              ]),
              const SizedBox(height: 10),
              if (docs.isEmpty)
                const Text('No collaboration offers yet.', style: TextStyle(color: Colors.white70))
              else
                ...docs.map((d) {
                  final m = d.data();
                  final status = m['status']?.toString() ?? 'pending';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF171822),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.handshake_outlined, color: Colors.white70),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    m['brandName']?.toString() ?? 'Brand',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                                  ),
                                  Text(
                                    m['campaign']?.toString() ?? '',
                                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${_toInt(m['offerStars'])}★',
                              style: const TextStyle(color: Color(0xFFFFD66B), fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _statusPill(status),
                            const Spacer(),
                            if (status == 'pending')
                              TextButton(
                                onPressed: () => d.reference.set({
                                  'status': 'active',
                                  'updatedAt': FieldValue.serverTimestamp(),
                                }, SetOptions(merge: true)),
                                child: const Text('Accept', style: TextStyle(color: Color(0xFF7BD88F))),
                              ),
                            if (status == 'active')
                              TextButton(
                                onPressed: () => d.reference.set({
                                  'status': 'completed',
                                  'completedAt': FieldValue.serverTimestamp(),
                                  'updatedAt': FieldValue.serverTimestamp(),
                                }, SetOptions(merge: true)),
                                child: const Text('Complete', style: TextStyle(color: Color(0xFF7CB7FF))),
                              ),
                            if (status != 'completed')
                              TextButton(
                                onPressed: () => d.reference.set({
                                  'status': 'rejected',
                                  'updatedAt': FieldValue.serverTimestamp(),
                                }, SetOptions(merge: true)),
                                child: const Text('Reject', style: TextStyle(color: Color(0xFFFF8E8E))),
                              ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}

class _LikeehitShopScreen extends StatelessWidget {
  const _LikeehitShopScreen({required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context) {
    final productsRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('likeehitShopProducts')
        .snapshots();
    final ordersRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('likeehitShopOrders')
        .orderBy('createdAt', descending: true)
        .snapshots();
    return Scaffold(
      backgroundColor: const Color(0xFF090A0F),
      appBar: AppBar(backgroundColor: const Color(0xFF090A0F), title: const Text('Likeehit Shop', style: TextStyle(color: Colors.white))),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFFF3A74),
        onPressed: () async {
          await FirebaseFirestore.instance.collection('users').doc(uid).collection('likeehitShopProducts').add({
            'title': 'Creator Product',
            'priceStars': 299,
            'stock': 25,
            'createdAt': FieldValue.serverTimestamp(),
          });
        },
        icon: const Icon(Icons.add_business, color: Colors.white),
        label: const Text('Add Product', style: TextStyle(color: Colors.white)),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: productsRef,
        builder: (context, pSnap) {
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: ordersRef,
            builder: (context, oSnap) {
              final products = pSnap.data?.docs ?? const [];
              final orders = oSnap.data?.docs ?? const [];
              int revenue = 0;
              for (final o in orders) {
                revenue += _toInt(o.data()['amountStars']);
              }
              return ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  Row(children: [
                    Expanded(child: _smallStat('Products', '${products.length}')),
                    const SizedBox(width: 8),
                    Expanded(child: _smallStat('Orders', '${orders.length}')),
                    const SizedBox(width: 8),
                    Expanded(child: _smallStat('Revenue', '$revenue★')),
                  ]),
                  const SizedBox(height: 10),
                  ...products.map((p) {
                    final d = p.data();
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0xFF171822), borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          const Icon(Icons.storefront_rounded, color: Colors.white70),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(d['title']?.toString() ?? 'Product', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                              Text('Stock: ${_toInt(d['stock'])}', style: const TextStyle(color: Colors.white60, fontSize: 12)),
                            ]),
                          ),
                          Text('${_toInt(d['priceStars'])}★', style: const TextStyle(color: Color(0xFFFFD66B), fontWeight: FontWeight.w800)),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () async {
                              await _createTestOrder(
                                uid: uid,
                                productId: p.id,
                                title: d['title']?.toString() ?? 'Product',
                                amountStars: _toInt(d['priceStars']),
                              );
                            },
                            icon: const Icon(Icons.shopping_cart_checkout_rounded, color: Color(0xFF7CB7FF)),
                          ),
                        ],
                      ),
                    );
                  }),
                  if (orders.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text('Recent Orders', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    ...orders.take(10).map((o) {
                      final od = o.data();
                      final status = od['status']?.toString() ?? 'placed';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF171822),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(od['title']?.toString() ?? 'Order', style: const TextStyle(color: Colors.white)),
                                  Text('${_toInt(od['amountStars'])}★', style: const TextStyle(color: Color(0xFFFFD66B))),
                                ],
                              ),
                            ),
                            _statusPill(status),
                            const SizedBox(width: 8),
                            if (status == 'placed')
                              TextButton(
                                onPressed: () => _setOrderStatusWithNotification(
                                  orderRef: o.reference,
                                  status: 'shipped',
                                  buyerId: od['buyerId']?.toString() ?? '',
                                  title: od['title']?.toString() ?? 'Order',
                                ),
                                child: const Text('Ship', style: TextStyle(color: Color(0xFF7CB7FF))),
                              ),
                            if (status == 'shipped')
                              TextButton(
                                onPressed: () => _setOrderStatusWithNotification(
                                  orderRef: o.reference,
                                  status: 'completed',
                                  buyerId: od['buyerId']?.toString() ?? '',
                                  title: od['title']?.toString() ?? 'Order',
                                ),
                                child: const Text('Complete', style: TextStyle(color: Color(0xFF7BD88F))),
                              ),
                            if (status == 'placed' || status == 'shipped')
                              TextButton(
                                onPressed: () => _cancelAndRefundOrder(
                                  creatorId: uid,
                                  orderRef: o.reference,
                                  orderData: od,
                                ),
                                child: const Text('Refund', style: TextStyle(color: Color(0xFFFF8E8E))),
                              ),
                          ],
                        ),
                      );
                    }),
                  ],
                  if (products.isEmpty) const Text('No products yet. Add your first product.', style: TextStyle(color: Colors.white70)),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _VideoGiftRow extends StatelessWidget {
  const _VideoGiftRow({
    required this.postId,
    required this.thumbnail,
    required this.caption,
    required this.stars,
  });
  final String postId;
  final String thumbnail;
  final String caption;
  final int stars;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xFF171822), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 54,
              height: 54,
              color: const Color(0xFF26293D),
              child: thumbnail.isEmpty ? const Icon(Icons.play_arrow, color: Colors.white70) : Image.network(thumbnail, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(caption, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              Text(postId, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white38, fontSize: 11)),
            ]),
          ),
          Text('$stars★', style: const TextStyle(color: Color(0xFFFFD66B), fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

Future<void> _createTestOrder({
  required String uid,
  required String productId,
  required String title,
  required int amountStars,
}) async {
  final db = FirebaseFirestore.instance;
  final orderRef = db.collection('users').doc(uid).collection('likeehitShopOrders').doc();
  final productRef = db.collection('users').doc(uid).collection('likeehitShopProducts').doc(productId);

  await db.runTransaction((tx) async {
    final productSnap = await tx.get(productRef);
    final product = productSnap.data() ?? const <String, dynamic>{};
    final stock = _toInt(product['stock']);
    if (stock <= 0) {
      throw Exception('Out of stock');
    }
    tx.set(productRef, {
      'stock': stock - 1,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    tx.set(orderRef, {
      'productId': productId,
      'title': title,
      'amountStars': amountStars,
      'status': 'placed',
      'buyerId': 'demo-buyer',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  });
}

Future<void> _setOrderStatusWithNotification({
  required DocumentReference<Map<String, dynamic>> orderRef,
  required String status,
  required String buyerId,
  required String title,
}) async {
  await orderRef.set({
    'status': status,
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));

  if (buyerId.isNotEmpty) {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(buyerId)
        .collection('notifications')
        .add({
      'type': 'shop_status',
      'title': 'Order Update',
      'body': '$title is now ${status.toUpperCase()}',
      'status': status,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}

Future<void> _cancelAndRefundOrder({
  required String creatorId,
  required DocumentReference<Map<String, dynamic>> orderRef,
  required Map<String, dynamic> orderData,
}) async {
  final buyerId = orderData['buyerId']?.toString() ?? '';
  final amountStars = _toInt(orderData['amountStars']);
  final productId = orderData['productId']?.toString() ?? '';
  final currentStatus = orderData['status']?.toString() ?? 'placed';
  if (buyerId.isEmpty || amountStars <= 0) return;
  if (currentStatus == 'completed' || currentStatus == 'cancelled_refunded') return;

  final db = FirebaseFirestore.instance;
  final buyerRef = db.collection('users').doc(buyerId);
  final creatorRef = db.collection('users').doc(creatorId);
  final productRef = creatorRef.collection('likeehitShopProducts').doc(productId);

  await db.runTransaction((tx) async {
    final buyerSnap = await tx.get(buyerRef);
    final productSnap = await tx.get(productRef);
    final buyerData = buyerSnap.data() ?? const <String, dynamic>{};
    final productData = productSnap.data() ?? const <String, dynamic>{};
    final buyerStars = _toInt(buyerData['stars']);
    final stock = _toInt(productData['stock']);

    tx.set(buyerRef, {
      'stars': buyerStars + amountStars,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    tx.set(creatorRef, {
      'shopEarningsStars': FieldValue.increment(-amountStars),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (productId.isNotEmpty) {
      tx.set(productRef, {
        'stock': stock + 1,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    tx.set(orderRef, {
      'status': 'cancelled_refunded',
      'refundedStars': amountStars,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  });

  await FirebaseFirestore.instance
      .collection('users')
      .doc(buyerId)
      .collection('notifications')
      .add({
    'type': 'shop_status',
    'title': 'Order Refunded',
    'body': '${orderData['title']?.toString() ?? 'Order'} refunded. $amountStars stars returned.',
    'status': 'cancelled_refunded',
    'read': false,
    'createdAt': FieldValue.serverTimestamp(),
  });
}

Widget _statusPill(String status) {
  Color bg;
  Color fg;
  switch (status) {
    case 'active':
    case 'shipped':
      bg = const Color(0xFF1F314F);
      fg = const Color(0xFF7CB7FF);
      break;
    case 'completed':
      bg = const Color(0xFF203B2C);
      fg = const Color(0xFF7BD88F);
      break;
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
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
    child: Text(
      status.toUpperCase(),
      style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 11),
    ),
  );
}

Widget _bigStatCard(String title, String value, {String? subtitle}) {
  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: const Color(0xFF171822), borderRadius: BorderRadius.circular(12)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(color: Colors.white70)),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 26)),
      if (subtitle != null) ...[
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: Colors.white60)),
      ],
    ]),
  );
}

Widget _smallStat(String title, String value) {
  return Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: const Color(0xFF171822), borderRadius: BorderRadius.circular(12)),
    child: Column(children: [
      Text(title, style: const TextStyle(color: Colors.white60, fontSize: 12)),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
    ]),
  );
}

Widget _checkItem(String title, bool done) {
  return Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: const Color(0xFF171822), borderRadius: BorderRadius.circular(12)),
    child: Row(
      children: [
        Icon(done ? Icons.check_circle : Icons.radio_button_unchecked, color: done ? const Color(0xFF32D583) : Colors.white38),
        const SizedBox(width: 10),
        Expanded(child: Text(title, style: const TextStyle(color: Colors.white))),
      ],
    ),
  );
}

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is List) return value.length;
  return 0;
}

String _fmtNum(int number) {
  if (number >= 1000000) return '${(number / 1000000).toStringAsFixed(1)}M';
  if (number >= 1000) return '${(number / 1000).toStringAsFixed(1)}K';
  return '$number';
}
