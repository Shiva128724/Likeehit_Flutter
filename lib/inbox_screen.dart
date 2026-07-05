import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:photo_manager/photo_manager.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import 'story_create_screen.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  int _sectionIndex = 0;
  int _informationIndex = 0;
  Timer? _storyExpiryTimer;

  @override
  void initState() {
    super.initState();
    _cleanupExpiredStories();
    _storyExpiryTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      setState(() {});
      _cleanupExpiredStories();
    });
  }

  @override
  void dispose() {
    _storyExpiryTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      backgroundColor: const Color(0xFF14131D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF14131D),
        elevation: 0,
        title: const Text(
          'Messages',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 28,
          ),
        ),
        centerTitle: true,
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 14),
            child: Icon(Icons.settings_rounded, color: Colors.white),
          ),
        ],
      ),
      body: uid == null
          ? const Center(
              child: Text(
                'Sign in required',
                style: TextStyle(color: Colors.white70),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(0, 4, 0, 24),
              children: [
                _storyRail(uid),
                const SizedBox(height: 22),
                _sectionTabs(),
                const SizedBox(height: 10),
                _sectionIndex == 0 ? _officialList(uid) : _informationPanel(),
              ],
            ),
    );
  }

  Widget _storyRail(String uid) {
    return SizedBox(
      height: 156,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('stories')
            .where('expiresAt', isGreaterThan: Timestamp.now())
            .limit(80)
            .snapshots(),
        builder: (context, snapshot) {
          final docs = _activeLatestStoryDocs(
            snapshot.data?.docs ?? const [],
            uid,
          );
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: docs.length + 1,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              if (index == 0) return _createStoryCard(uid);
              return _storyCard(docs[index - 1], uid);
            },
          );
        },
      ),
    );
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _activeLatestStoryDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    String uid,
  ) {
    final now = DateTime.now();
    final latestByUser =
        <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    for (final doc in docs) {
      final data = doc.data();
      final expiresAt = _timestampToDate(data['expiresAt']);
      if (expiresAt != null && !expiresAt.isAfter(now)) continue;
      final ownerUid = data['uid']?.toString() ?? doc.id;
      final existing = latestByUser[ownerUid];
      if (existing == null ||
          _storyCreatedAt(doc).isAfter(_storyCreatedAt(existing))) {
        latestByUser[ownerUid] = doc;
      }
    }
    final stories = latestByUser.values.toList();
    stories.sort((a, b) {
      final aUid = a.data()['uid']?.toString();
      final bUid = b.data()['uid']?.toString();
      if (aUid == uid && bUid != uid) return -1;
      if (bUid == uid && aUid != uid) return 1;
      return _storyCreatedAt(b).compareTo(_storyCreatedAt(a));
    });
    return stories;
  }

  DateTime _storyCreatedAt(DocumentSnapshot<Map<String, dynamic>> doc) {
    return _timestampToDate(doc.data()?['createdAt']) ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  DateTime? _timestampToDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  Future<void> _cleanupExpiredStories() async {
    try {
      final expired = await FirebaseFirestore.instance
          .collection('stories')
          .where('expiresAt', isLessThanOrEqualTo: Timestamp.now())
          .limit(25)
          .get();
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in expired.docs) {
        batch.delete(doc.reference);
      }
      if (expired.docs.isNotEmpty) await batch.commit();
    } catch (_) {
      // Story rail still hides expired stories even when cleanup is blocked.
    }
  }

  Widget _createStoryCard(String uid) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const StoryCreateScreen()),
        );
      },
      child: SizedBox(
        width: 104,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFFFD8EA), Color(0xFFE8F3FF)],
                  ),
                ),
              ),
              Positioned.fill(
                bottom: 42,
                child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(uid)
                      .snapshots(),
                  builder: (context, snapshot) {
                    final data = snapshot.data?.data() ?? <String, dynamic>{};
                    final photo =
                        data['photoURL']?.toString() ??
                        data['photoUrl']?.toString() ??
                        '';
                    return photo.isEmpty
                        ? const Icon(
                            Icons.person_rounded,
                            color: Color(0xFF656B7F),
                            size: 46,
                          )
                        : Image.network(photo, fit: BoxFit.cover);
                  },
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 54,
                child: Container(color: const Color(0xFF262A35)),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 38,
                child: Center(
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2377FF),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ),
              ),
              const Positioned(
                left: 8,
                right: 8,
                bottom: 10,
                child: Text(
                  'Create story',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _storyCard(DocumentSnapshot<Map<String, dynamic>> doc, String uid) {
    final data = doc.data() ?? <String, dynamic>{};
    final imageUrl = data['imageUrl']?.toString() ?? '';
    final ownerUid = data['uid']?.toString() ?? '';
    final name = ownerUid == uid
        ? 'Your story'
        : data['userName']?.toString() ?? 'Story';
    final avatar = data['userPhotoUrl']?.toString() ?? '';
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                StoryViewerScreen(ownerUid: ownerUid, initialStoryId: doc.id),
          ),
        );
      },
      child: SizedBox(
        width: 104,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (imageUrl.isNotEmpty)
                Image.network(imageUrl, fit: BoxFit.cover)
              else
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF8B4DFF), Color(0xFFFF4E8D)],
                    ),
                  ),
                ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.12),
                      Colors.black.withValues(alpha: 0.62),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFF287CFF), Color(0xFFFF3F8E)],
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.white,
                    backgroundImage: avatar.isNotEmpty
                        ? NetworkImage(avatar)
                        : null,
                    child: avatar.isEmpty
                        ? const Icon(
                            Icons.person,
                            color: Color(0xFF656B7F),
                            size: 18,
                          )
                        : null,
                  ),
                ),
              ),
              Positioned(
                left: 8,
                right: 8,
                bottom: 10,
                child: Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _sectionTab('Official', 0),
          const SizedBox(width: 24),
          _sectionTab('Information', 1),
          const Spacer(),
          IconButton(
            onPressed: () => _toast('Inbox cleared view refreshed'),
            icon: const Icon(
              Icons.cleaning_services_outlined,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTab(String label, int index) {
    final active = _sectionIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _sectionIndex = index),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: active ? Colors.white : const Color(0xFF8D8A9B),
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: active ? 34 : 0,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFFF3E78),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ],
      ),
    );
  }

  Widget _officialList(String uid) {
    final notifRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(40);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: notifRef.snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? const [];
        return Column(
          children: [
            _officialCard(
              icon: Icons.notifications_active_rounded,
              color: const Color(0xFFF07B7B),
              title: 'System',
              subtitle: 'Likeehit updates and announcements',
              badge: docs.where((doc) => doc.data()['read'] != true).length,
            ),
            _officialCard(
              icon: Icons.local_activity_rounded,
              color: const Color(0xFFF8A767),
              title: 'Activity Center',
              subtitle: 'Tasks, rewards and live events',
            ),
            _officialCard(
              icon: Icons.play_circle_fill_rounded,
              color: const Color(0xFFB064FF),
              title: 'Friends Video',
              subtitle: 'Moments from people you follow',
            ),
            _officialCard(
              icon: Icons.shield_rounded,
              color: const Color(0xFFF3C74E),
              title: 'Safety Notification',
              subtitle: 'Trust, privacy and account alerts',
            ),
            if (docs.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 26),
                child: Text(
                  'No notifications yet',
                  style: TextStyle(color: Colors.white54),
                ),
              )
            else
              ...docs.map((doc) => _notificationTile(doc)),
          ],
        );
      },
    );
  }

  Widget _informationPanel() {
    final items = [
      _InfoItem(
        'like',
        'Likes',
        Icons.favorite_border_rounded,
        const Color(0xFFD72AA0),
      ),
      _InfoItem(
        'mention',
        'Mentions',
        Icons.alternate_email_rounded,
        const Color(0xFF2260AF),
      ),
      _InfoItem(
        'follow',
        'Followers',
        Icons.person_add_alt_1_rounded,
        const Color(0xFF16875B),
      ),
      _InfoItem(
        'comment',
        'Comments',
        Icons.chat_bubble_outline_rounded,
        const Color(0xFF8E3FD1),
      ),
      _InfoItem(
        'gift',
        'Gift',
        Icons.card_giftcard_rounded,
        const Color(0xFFE27926),
      ),
    ];
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 24),
      child: Column(
        children: [
          Row(
            children: [
              for (int index = 0; index < items.length; index++)
                Expanded(
                  child: _informationTile(
                    items[index],
                    selected: index == _informationIndex,
                    onTap: () => _openInformationPage(items[index], index),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Container(height: 1, color: const Color(0xFF2B2938)),
          const SizedBox(height: 18),
          _directChatList(uid),
        ],
      ),
    );
  }

  void _openInformationPage(_InfoItem item, int index) {
    setState(() => _informationIndex = index);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _InformationNotificationsPage(item: item),
      ),
    );
  }

  Widget _informationTile(
    _InfoItem item, {
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: selected
                  ? Border.all(
                      color: Colors.white.withValues(alpha: 0.78),
                      width: 1.4,
                    )
                  : null,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [item.color.withValues(alpha: 0.72), item.color],
              ),
            ),
            child: Icon(item.icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 7),
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFFD8D5E3),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  String notificationBody(Map<String, dynamic> data) {
    final category = data['category']?.toString() ?? '';
    final caption = _text(data['postCaption'], '');
    final comment = _text(data['commentText'], '');
    final giftName = _text(data['giftName'], 'Gift');
    final giftStars = _infoInt(data['giftStars']);
    final giftCount = _infoInt(data['giftCount']);
    final videoLabel = caption.isEmpty ? 'your video' : '"$caption"';
    switch (category) {
      case 'like':
        return 'liked $videoLabel';
      case 'mention':
        return 'mentioned you in $videoLabel';
      case 'follow':
        return 'started following you';
      case 'comment':
        return comment.isEmpty
            ? 'commented on $videoLabel'
            : 'commented: $comment';
      case 'gift':
        final countText = giftCount > 1 ? ' x$giftCount' : '';
        final starsText = giftStars > 0 ? ' ($giftStars★)' : '';
        return 'sent $giftName$countText$starsText on $videoLabel';
      default:
        return _text(data['body'], 'New notification');
    }
  }

  String _timeAgo(dynamic value) {
    DateTime? time;
    if (value is Timestamp) time = value.toDate();
    if (time == null) return 'Just now';
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} h ago';
    return '${diff.inDays} d ago';
  }

  String _text(dynamic value, String fallback) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? fallback : text;
  }

  int _infoInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  Widget _directChatList(String? uid) {
    if (uid == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Text(
              'Chats',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            Spacer(),
            Icon(Icons.bolt_rounded, color: Color(0xFFFF3D8B), size: 20),
            SizedBox(width: 4),
            Text(
              'Realtime',
              style: TextStyle(
                color: Color(0xFFFF6FAB),
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('chats')
              .where('participants', arrayContains: uid)
              .snapshots(),
          builder: (context, snapshot) {
            final chats = [...(snapshot.data?.docs ?? const [])];
            chats.sort((a, b) {
              final aTime = _timestampMillis(a.data()['updatedAt']);
              final bTime = _timestampMillis(b.data()['updatedAt']);
              return bTime.compareTo(aTime);
            });
            if (chats.isEmpty) return _friendChatSuggestions(uid);
            return ListView.separated(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (context, index) => _chatRow(uid, chats[index]),
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemCount: chats.length,
            );
          },
        ),
      ],
    );
  }

  Widget _chatRow(String uid, QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final participants = (data['participants'] as List?)?.cast<dynamic>() ?? [];
    final peerUid = participants
        .map((value) => value.toString())
        .firstWhere((value) => value != uid, orElse: () => '');
    if (peerUid.isEmpty) return const SizedBox.shrink();
    final names = Map<String, dynamic>.from(data['participantNames'] ?? {});
    final photos = Map<String, dynamic>.from(data['participantPhotos'] ?? {});
    return _chatListTile(
      name: _text(names[peerUid], 'Likeehit User'),
      photoUrl: _text(photos[peerUid], ''),
      subtitle: _text(data['lastMessage'], 'Say hello'),
      trailing: _timeAgo(data['updatedAt']),
      onTap: () => _openDirectChat(
        peerUid,
        _text(names[peerUid], 'Likeehit User'),
        _text(photos[peerUid], ''),
      ),
    );
  }

  Widget _friendChatSuggestions(String uid) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('following')
          .limit(20)
          .snapshots(),
      builder: (context, snapshot) {
        final friends = snapshot.data?.docs ?? const [];
        if (friends.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 18),
            decoration: BoxDecoration(
              color: const Color(0xFF201C2A),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF302A3C)),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: Color(0xFFFF4E93),
                  size: 42,
                ),
                SizedBox(height: 10),
                Text(
                  'No chats yet',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Follow friends, then start realtime chatting here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFA9A6B8),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          );
        }
        return Column(
          children: [
            for (final friend in friends)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .doc(friend.id)
                      .get(),
                  builder: (context, userSnapshot) {
                    final data = userSnapshot.data?.data() ?? friend.data();
                    final name = _text(
                      data['name'] ?? data['username'] ?? data['displayName'],
                      'Likeehit User',
                    );
                    final photo = _text(
                      data['photoUrl'] ??
                          data['photoURL'] ??
                          data['avatarUrl'] ??
                          data['profileImageUrl'],
                      '',
                    );
                    return _chatListTile(
                      name: name,
                      photoUrl: photo,
                      subtitle: 'Tap to start chat',
                      trailing: 'New',
                      onTap: () => _openDirectChat(friend.id, name, photo),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _chatListTile({
    required String name,
    required String photoUrl,
    required String subtitle,
    required String trailing,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF242030),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF332E43)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: const Color(0xFF3A324B),
                backgroundImage: photoUrl.isNotEmpty
                    ? NetworkImage(photoUrl)
                    : null,
                child: photoUrl.isEmpty
                    ? const Icon(Icons.person_rounded, color: Colors.white70)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFA9A6B8),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                trailing,
                style: const TextStyle(
                  color: Color(0xFF7F7890),
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openDirectChat(String peerUid, String peerName, String peerPhotoUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _DirectChatPage(
          peerUid: peerUid,
          peerName: peerName,
          peerPhotoUrl: peerPhotoUrl,
        ),
      ),
    );
  }

  int _timestampMillis(dynamic value) {
    if (value is Timestamp) return value.millisecondsSinceEpoch;
    if (value is DateTime) return value.millisecondsSinceEpoch;
    return 0;
  }

  Widget _officialCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    int badge = 0,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF242233),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: color.withValues(alpha: 0.2),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _officialBadge(),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFA9A6B8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (badge > 0) _countBadge(badge),
          ],
        ),
      ),
    );
  }

  Widget _notificationTile(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final title = data['title']?.toString() ?? 'Notification';
    final body = data['body']?.toString() ?? 'New update available';
    final unread = data['read'] != true;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        tileColor: const Color(0xFF242233),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF353247),
          child: Icon(
            _iconForType(data['type']?.toString() ?? ''),
            color: const Color(0xFFD8D5E3),
          ),
        ),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text(
          body,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Color(0xFFA9A6B8)),
        ),
        trailing: unread
            ? Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Color(0xFFFF3E78),
                  shape: BoxShape.circle,
                ),
              )
            : null,
        onTap: () => doc.reference.set({'read': true}, SetOptions(merge: true)),
      ),
    );
  }

  Widget _officialBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFCE8F1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'Official',
        style: TextStyle(
          color: Color(0xFFED6D9F),
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _countBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFF3E78),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  IconData _iconForType(String type) {
    if (type.contains('gift')) return Icons.card_giftcard_rounded;
    if (type.contains('shop')) return Icons.shopping_bag_rounded;
    if (type.contains('comment')) return Icons.chat_bubble_outline_rounded;
    if (type.contains('friend') || type.contains('follow')) {
      return Icons.person_add_alt_1_rounded;
    }
    if (type.contains('live')) return Icons.live_tv_rounded;
    return Icons.notifications_none_rounded;
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }
}

class StoryViewerScreen extends StatefulWidget {
  const StoryViewerScreen({
    super.key,
    required this.ownerUid,
    required this.initialStoryId,
    this.highlightsOnly = false,
  });

  final String ownerUid;
  final String initialStoryId;
  final bool highlightsOnly;

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen> {
  Timer? _progressTimer;
  final AudioPlayer _storyAudioPlayer = AudioPlayer();
  int _index = 0;
  double _progress = 0;
  String? _activeStoryId;
  String? _activeAudioUrl;
  final Set<String> _readyVideoStoryIds = <String>{};

  @override
  void dispose() {
    _progressTimer?.cancel();
    _storyAudioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: widget.highlightsOnly
            ? FirebaseFirestore.instance
                  .collection('users')
                  .doc(widget.ownerUid)
                  .collection('highlights')
                  .orderBy('highlightedAt', descending: false)
                  .limit(80)
                  .snapshots()
            : FirebaseFirestore.instance
                  .collection('stories')
                  .where('uid', isEqualTo: widget.ownerUid)
                  .limit(80)
                  .snapshots(),
        builder: (context, snapshot) {
          final stories = _activeStories(snapshot.data?.docs ?? const []);
          if (stories.isEmpty) {
            unawaited(_stopStoryAudio());
            return _emptyStory();
          }
          if (_activeStoryId == null) {
            final initial = stories.indexWhere(
              (doc) => doc.id == widget.initialStoryId,
            );
            _index = initial == -1 ? 0 : initial;
            _activateStory(stories[_index], stories);
          } else if (_index >= stories.length) {
            _index = stories.length - 1;
            _activateStory(stories[_index], stories);
          } else if (_activeStoryId != stories[_index].id) {
            _activateStory(stories[_index], stories);
          }
          final doc = stories[_index];
          final data = doc.data();
          final stickers =
              (data['stickers'] as List?)
                  ?.whereType<Map>()
                  .map((item) => Map<String, dynamic>.from(item))
                  .toList() ??
              const <Map<String, dynamic>>[];
          return SafeArea(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) {
                final width = MediaQuery.sizeOf(context).width;
                if (details.localPosition.dx < width * 0.38) {
                  _previous(stories);
                } else if (details.localPosition.dx > width * 0.62) {
                  _next(stories);
                }
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _StoryMediaView(
                    data: data,
                    onVideoReady: () {
                      if (!_readyVideoStoryIds.add(doc.id)) return;
                      if (_activeStoryId == doc.id) {
                        _startProgress(doc, stories, recordView: false);
                      }
                    },
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.36),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.34),
                        ],
                      ),
                    ),
                  ),
                  ...stickers.map(
                    (sticker) =>
                        _StoryViewerSticker(storyId: doc.id, sticker: sticker),
                  ),
                  _progressBars(stories.length),
                  _header(data),
                  _bottomActions(doc, data),
                  _closeButton(context),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _activeStories(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final now = DateTime.now();
    final stories = docs.where((doc) {
      if (widget.highlightsOnly) return doc.data()['isHighlight'] == true;
      final expiresAt = _date(doc.data()['expiresAt']);
      return expiresAt == null || expiresAt.isAfter(now);
    }).toList();
    stories.sort((a, b) {
      if (widget.highlightsOnly) {
        return _highlightedAt(a).compareTo(_highlightedAt(b));
      }
      return _createdAt(a).compareTo(_createdAt(b));
    });
    return stories;
  }

  void _activateStory(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> stories,
  ) {
    final data = doc.data();
    _progressTimer?.cancel();
    _activeStoryId = doc.id;
    _progress = 0;
    unawaited(_recordStoryView(doc));
    if (_isVideoStory(data) && !_readyVideoStoryIds.contains(doc.id)) {
      unawaited(_stopStoryAudio());
      return;
    }
    _startProgress(doc, stories, recordView: false);
  }

  bool _isVideoStory(Map<String, dynamic> data) {
    return data['mediaType']?.toString() == 'video' &&
        (data['mediaUrl']?.toString().trim().isNotEmpty ?? false);
  }

  void _startProgress(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> stories, {
    bool recordView = true,
  }) {
    _progressTimer?.cancel();
    _activeStoryId = doc.id;
    _progress = 0;
    unawaited(_playStoryAudio(doc.data()));
    if (recordView) unawaited(_recordStoryView(doc));
    final seconds = _storySeconds(doc.data());
    _progressTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      setState(() {
        _progress += 0.1 / seconds;
        if (_progress >= 1) {
          _progress = 1;
          _progressTimer?.cancel();
        }
      });
      if (_progress >= 1 && mounted) _next(stories);
    });
  }

  Future<void> _playStoryAudio(Map<String, dynamic> data) async {
    final url = data['audioUrl']?.toString().trim() ?? '';
    if (url.isEmpty) {
      await _stopStoryAudio();
      return;
    }
    if (_activeAudioUrl == url) return;
    _activeAudioUrl = url;
    try {
      await _storyAudioPlayer.setReleaseMode(ReleaseMode.loop);
      await _storyAudioPlayer.setVolume(0.75);
      await _storyAudioPlayer.play(UrlSource(url));
    } catch (_) {
      _activeAudioUrl = null;
    }
  }

  Future<void> _stopStoryAudio() async {
    if (_activeAudioUrl == null) return;
    _activeAudioUrl = null;
    await _storyAudioPlayer.stop();
  }

  void _next(List<QueryDocumentSnapshot<Map<String, dynamic>>> stories) {
    if (_index >= stories.length - 1) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _index++;
      _activateStory(stories[_index], stories);
    });
  }

  void _previous(List<QueryDocumentSnapshot<Map<String, dynamic>>> stories) {
    if (_index <= 0) {
      setState(() => _progress = 0);
      _activateStory(stories[_index], stories);
      return;
    }
    setState(() {
      _index--;
      _activateStory(stories[_index], stories);
    });
  }

  Widget _progressBars(int count) {
    return Positioned(
      left: 10,
      right: 10,
      top: 8,
      child: Row(
        children: List.generate(count, (i) {
          final value = i < _index ? 1.0 : (i == _index ? _progress : 0.0);
          return Expanded(
            child: Container(
              height: 3,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: Colors.white30,
                borderRadius: BorderRadius.circular(99),
              ),
              clipBehavior: Clip.antiAlias,
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: value.clamp(0, 1),
                  child: Container(color: Colors.white),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _header(Map<String, dynamic> data) {
    final name = data['userName']?.toString() ?? 'Story';
    final avatar = data['userPhotoUrl']?.toString() ?? '';
    final createdAt = _date(data['createdAt']);
    return Positioned(
      left: 16,
      right: 70,
      top: 22,
      child: Row(
        children: [
          CircleAvatar(
            radius: 21,
            backgroundColor: Colors.white24,
            backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
            child: avatar.isEmpty
                ? const Icon(Icons.person_rounded, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                children: [
                  TextSpan(
                    text: name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  TextSpan(
                    text: '  ${_timeAgo(createdAt)}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
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

  Widget _bottomActions(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    Map<String, dynamic> data,
  ) {
    return Positioned(
      left: 18,
      right: 18,
      bottom: MediaQuery.paddingOf(context).bottom + 24,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _StoryBottomAction(
            Icons.groups_rounded,
            'Activity',
            onTap: () => _showActivitySheet(doc, data),
          ),
          _StoryBottomAction(
            Icons.ios_share_rounded,
            'Share on...',
            onTap: () => _showShareSheet(doc, data),
          ),
          _StoryBottomAction(
            Icons.send_rounded,
            'Send',
            onTap: () => _showSendSheet(doc, data),
          ),
          _StoryBottomAction(
            Icons.alternate_email_rounded,
            'Mention',
            onTap: () => _showMentionSheet(doc, data),
          ),
          _StoryBottomAction(
            Icons.more_vert_rounded,
            'More',
            onTap: () => _showMoreSheet(doc, data),
          ),
        ],
      ),
    );
  }

  Future<void> _recordStoryView(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final viewRef = doc.reference.collection('views').doc(uid);
    final snap = await viewRef.get();
    if (snap.exists) return;
    final userData =
        (await FirebaseFirestore.instance.collection('users').doc(uid).get())
            .data() ??
        <String, dynamic>{};
    await viewRef.set({
      'uid': uid,
      'name':
          userData['name']?.toString() ??
          userData['username']?.toString() ??
          FirebaseAuth.instance.currentUser?.displayName ??
          'Likeehit User',
      'photoUrl':
          userData['photoURL']?.toString() ??
          userData['photoUrl']?.toString() ??
          FirebaseAuth.instance.currentUser?.photoURL ??
          '',
      'liked': false,
      'viewedAt': FieldValue.serverTimestamp(),
    });
    await doc.reference.set({
      'viewsCount': FieldValue.increment(1),
    }, SetOptions(merge: true));
  }

  Future<void> _showActivitySheet(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    Map<String, dynamic> data,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0D1116),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) => _StoryActivitySheet(storyId: doc.id, data: data),
    );
  }

  Future<void> _showShareSheet(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    Map<String, dynamic> data,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF15191D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) => _StoryShareSheet(
        storyId: doc.id,
        title: data['userName']?.toString() ?? 'Likeehit story',
        onShare: (platform) => _shareStory(doc, data, platform),
      ),
    );
  }

  Future<void> _showSendSheet(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    Map<String, dynamic> data,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF15191D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) => _StorySendSheet(
        storyId: doc.id,
        storyData: data,
        onExternalShare: (platform) => _shareStory(doc, data, platform),
      ),
    );
  }

  Future<void> _showMentionSheet(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    Map<String, dynamic> data,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF15191D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) => _StoryMentionSheet(storyRef: doc.reference),
    );
  }

  Future<void> _showMoreSheet(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    Map<String, dynamic> data,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF15191D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _StoryMoreSheet(
        storyId: doc.id,
        storyRef: doc.reference,
        storyData: data,
        onShare: () => _showShareSheet(doc, data),
        onDeleted: () {
          Navigator.pop(context);
          if (Navigator.canPop(context)) Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _shareStory(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    Map<String, dynamic> data,
    String platform,
  ) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    await doc.reference.collection('shares').add({
      'platform': platform,
      'uid': uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await doc.reference.set({
      'sharesCount': FieldValue.increment(1),
    }, SetOptions(merge: true));
    final text = 'Likeehit story: ${_storyLink(doc.id, data)}';
    Uri? uri;
    switch (platform) {
      case 'whatsapp':
        uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}');
        break;
      case 'facebook':
        uri = Uri.parse(
          'https://www.facebook.com/sharer/sharer.php?u=${Uri.encodeComponent(_storyLink(doc.id, data))}',
        );
        break;
      case 'instagram':
        uri = Uri.parse('instagram://camera');
        break;
      case 'copy':
        await Clipboard.setData(ClipboardData(text: _storyLink(doc.id, data)));
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Story link copied')));
        return;
      default:
        uri = Uri.parse(_storyLink(doc.id, data));
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && platform == 'instagram') {
      await launchUrl(
        Uri.parse('https://www.instagram.com/'),
        mode: LaunchMode.externalApplication,
      );
    }
  }

  String _storyLink(String storyId, Map<String, dynamic> data) {
    final mediaUrl = data['mediaUrl']?.toString() ?? '';
    if (mediaUrl.startsWith('http')) return mediaUrl;
    return 'https://likeehit.com/story/$storyId';
  }

  Widget _emptyStory() {
    return Stack(
      children: [
        const Center(
          child: Text(
            'Story not available',
            style: TextStyle(color: Colors.white70),
          ),
        ),
        _closeButton(context),
      ],
    );
  }

  Widget _closeButton(BuildContext context) {
    return Positioned(
      right: 14,
      top: MediaQuery.paddingOf(context).top + 18,
      child: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.close_rounded, color: Colors.white, size: 34),
      ),
    );
  }

  int _storySeconds(Map<String, dynamic> data) {
    final raw = data['storyDurationSeconds'];
    final seconds = raw is num ? raw.toInt() : int.tryParse('$raw') ?? 15;
    return seconds.clamp(5, 60);
  }

  DateTime _createdAt(DocumentSnapshot<Map<String, dynamic>> doc) {
    return _date(doc.data()?['createdAt']) ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  DateTime _highlightedAt(DocumentSnapshot<Map<String, dynamic>> doc) {
    return _date(doc.data()?['highlightedAt']) ?? _createdAt(doc);
  }

  DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  String _timeAgo(DateTime? date) {
    if (date == null) return 'Just now';
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    return '${diff.inHours}h';
  }
}

class _StoryMediaView extends StatelessWidget {
  const _StoryMediaView({required this.data, this.onVideoReady});

  final Map<String, dynamic> data;
  final VoidCallback? onVideoReady;

  @override
  Widget build(BuildContext context) {
    final mediaType = data['mediaType']?.toString() ?? 'image';
    final mediaUrl = data['mediaUrl']?.toString() ?? '';
    final effectKey = data['effectKey']?.toString() ?? 'none';
    final imageUrl =
        data['imageUrl']?.toString() ??
        data['thumbnailUrl']?.toString() ??
        mediaUrl;
    if (mediaType == 'video' && mediaUrl.isNotEmpty) {
      return ColorFiltered(
        colorFilter: ColorFilter.matrix(_storyEffectMatrix(effectKey)),
        child: _StoryVideoPlayer(
          url: mediaUrl,
          fallbackUrl: imageUrl,
          onReady: onVideoReady,
        ),
      );
    }
    if (imageUrl.isNotEmpty) {
      return ColorFiltered(
        colorFilter: ColorFilter.matrix(_storyEffectMatrix(effectKey)),
        child: Image.network(imageUrl, fit: BoxFit.cover),
      );
    }
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF242044), Color(0xFF111018)],
        ),
      ),
    );
  }
}

class _StoryVideoPlayer extends StatefulWidget {
  const _StoryVideoPlayer({
    required this.url,
    required this.fallbackUrl,
    this.onReady,
  });

  final String url;
  final String fallbackUrl;
  final VoidCallback? onReady;

  @override
  State<_StoryVideoPlayer> createState() => _StoryVideoPlayerState();
}

class _StoryVideoPlayerState extends State<_StoryVideoPlayer> {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _StoryVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) _load();
  }

  Future<void> _load() async {
    final old = _controller;
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    await old?.dispose();
    try {
      await _controller!.initialize();
      await _controller!.setLooping(true);
      await _controller!.play();
      widget.onReady?.call();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller != null && controller.value.isInitialized) {
      return FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: controller.value.size.width,
          height: controller.value.size.height,
          child: VideoPlayer(controller),
        ),
      );
    }
    if (widget.fallbackUrl.isNotEmpty) {
      return Image.network(widget.fallbackUrl, fit: BoxFit.cover);
    }
    return const Center(child: CircularProgressIndicator(color: Colors.white));
  }
}

List<double> _storyEffectMatrix(String key) {
  switch (key) {
    case 'beautiful':
    case 'blush':
      return _viewerColorMatrix(saturation: 1.18, brightness: 10, red: 1.08);
    case 'funny':
    case 'pop':
    case 'party':
      return _viewerColorMatrix(saturation: 1.55, brightness: 8);
    case 'glow':
    case 'bright':
      return _viewerColorMatrix(saturation: 1.12, brightness: 24);
    case 'cinema':
    case 'dramatic':
      return _viewerColorMatrix(
        saturation: 1.18,
        brightness: -16,
        contrast: 1.18,
      );
    case 'vintage':
      return const [
        0.9,
        0.18,
        0.08,
        0,
        12,
        0.08,
        0.82,
        0.08,
        0,
        6,
        0.06,
        0.12,
        0.68,
        0,
        -4,
        0,
        0,
        0,
        1,
        0,
      ];
    case 'cool':
    case 'aqua':
    case 'ice':
      return _viewerColorMatrix(saturation: 1.08, brightness: 4, blue: 1.18);
    case 'warm':
    case 'sunset':
      return _viewerColorMatrix(saturation: 1.22, brightness: 6, red: 1.14);
    case 'soft':
    case 'dream':
    case 'fairy':
      return _viewerColorMatrix(saturation: 0.88, brightness: 18);
    case 'noir':
    case 'mono':
      return const [
        0.2126,
        0.7152,
        0.0722,
        0,
        0,
        0.2126,
        0.7152,
        0.0722,
        0,
        0,
        0.2126,
        0.7152,
        0.0722,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
      ];
    case '8k':
      return _viewerColorMatrix(
        saturation: 1.35,
        brightness: 5,
        contrast: 1.22,
      );
    case 'gold':
      return _viewerColorMatrix(
        saturation: 1.15,
        brightness: 10,
        red: 1.16,
        green: 1.08,
      );
    case 'rose':
    case 'love':
      return _viewerColorMatrix(
        saturation: 1.18,
        brightness: 5,
        red: 1.2,
        blue: 0.92,
      );
    case 'neon':
      return _viewerColorMatrix(
        saturation: 1.7,
        brightness: 10,
        contrast: 1.12,
      );
    case 'glitch':
      return _viewerColorMatrix(
        saturation: 1.45,
        brightness: -4,
        red: 1.22,
        blue: 1.18,
      );
    case 'shadow':
      return _viewerColorMatrix(
        saturation: 1.0,
        brightness: -28,
        contrast: 1.2,
      );
    case 'forest':
    case 'fresh':
      return _viewerColorMatrix(saturation: 1.2, brightness: 4, green: 1.18);
    default:
      return const [1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0];
  }
}

List<double> _viewerColorMatrix({
  double saturation = 1,
  double brightness = 0,
  double contrast = 1,
  double red = 1,
  double green = 1,
  double blue = 1,
}) {
  final inv = 1 - saturation;
  final r = 0.213 * inv;
  final g = 0.715 * inv;
  final b = 0.072 * inv;
  final translate = 128 * (1 - contrast) + brightness;
  return [
    (r + saturation) * contrast * red,
    g * contrast * red,
    b * contrast * red,
    0,
    translate,
    r * contrast * green,
    (g + saturation) * contrast * green,
    b * contrast * green,
    0,
    translate,
    r * contrast * blue,
    g * contrast * blue,
    (b + saturation) * contrast * blue,
    0,
    translate,
    0,
    0,
    0,
    1,
    0,
  ];
}

class _StoryActivitySheet extends StatelessWidget {
  const _StoryActivitySheet({required this.storyId, required this.data});

  final String storyId;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.72,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('stories')
            .doc(storyId)
            .collection('views')
            .orderBy('viewedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          final views = snapshot.data?.docs ?? const [];
          final liked = views
              .where((doc) => doc.data()['liked'] == true)
              .length;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(child: _SheetHandle()),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 88,
                    child: Row(
                      children: [
                        _MiniStoryPreview(data: data),
                        const SizedBox(width: 18),
                        _ActivityCount(
                          icon: Icons.visibility_rounded,
                          value: views.length,
                          label: 'Viewed',
                        ),
                        const SizedBox(width: 12),
                        _ActivityCount(
                          icon: Icons.favorite_rounded,
                          value: liked,
                          label: 'Likes',
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.white12, height: 34),
                  const Text(
                    'Who viewed your story',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: views.isEmpty
                        ? const Center(
                            child: Text(
                              'No viewers yet',
                              style: TextStyle(
                                color: Colors.white54,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                        : ListView.separated(
                            itemCount: views.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final item = views[index].data();
                              final photo = item['photoUrl']?.toString() ?? '';
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  radius: 24,
                                  backgroundColor: Colors.white12,
                                  backgroundImage: photo.isNotEmpty
                                      ? NetworkImage(photo)
                                      : null,
                                  child: photo.isEmpty
                                      ? const Icon(
                                          Icons.person_rounded,
                                          color: Colors.white,
                                        )
                                      : null,
                                ),
                                title: Text(
                                  item['name']?.toString() ?? 'Likeehit User',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (item['liked'] == true)
                                      const Icon(
                                        Icons.favorite_rounded,
                                        color: Color(0xFFFF3F86),
                                      ),
                                    const SizedBox(width: 16),
                                    const Icon(
                                      Icons.send_rounded,
                                      color: Colors.white,
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StoryShareSheet extends StatelessWidget {
  const _StoryShareSheet({
    required this.storyId,
    required this.title,
    required this.onShare,
  });

  final String storyId;
  final String title;
  final Future<void> Function(String platform) onShare;

  @override
  Widget build(BuildContext context) {
    final items = [
      _ShareChoice('whatsapp', 'WhatsApp', Icons.chat_rounded, Colors.green),
      _ShareChoice('copy', 'Copy link', Icons.link_rounded, Colors.white70),
      _ShareChoice('share', 'Share all', Icons.share_rounded, Colors.white70),
      _ShareChoice('facebook', 'Facebook', Icons.facebook_rounded, Colors.blue),
      _ShareChoice(
        'instagram',
        'Instagram',
        Icons.camera_alt_rounded,
        Colors.pinkAccent,
      ),
    ];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _SheetHandle(),
            const SizedBox(height: 18),
            Text(
              'Share story',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 20),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: items.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 18),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(40),
                      onTap: () async {
                        Navigator.pop(context);
                        await onShare(item.platform);
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 32,
                            backgroundColor: item.color.withValues(alpha: 0.18),
                            child: Icon(item.icon, color: item.color, size: 32),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            item.label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StorySendSheet extends StatelessWidget {
  const _StorySendSheet({
    required this.storyId,
    required this.storyData,
    required this.onExternalShare,
  });

  final String storyId;
  final Map<String, dynamic> storyData;
  final Future<void> Function(String platform) onExternalShare;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.62,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            const _SheetHandle(),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search',
                  hintStyle: const TextStyle(color: Colors.white54),
                  prefixIcon: const Icon(Icons.search, color: Colors.white54),
                  filled: true,
                  fillColor: Colors.white10,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: uid == null
                  ? const Center(child: Text('Login required'))
                  : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(uid)
                          .collection('friends')
                          .limit(40)
                          .snapshots(),
                      builder: (context, snapshot) {
                        final friends = snapshot.data?.docs ?? const [];
                        if (friends.isEmpty) {
                          return const Center(
                            child: Text(
                              'No friends yet',
                              style: TextStyle(color: Colors.white54),
                            ),
                          );
                        }
                        return GridView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                mainAxisExtent: 116,
                                crossAxisSpacing: 10,
                              ),
                          itemCount: friends.length,
                          itemBuilder: (context, index) {
                            final friend = friends[index];
                            final data = friend.data();
                            return _FriendBubble(
                              data: data,
                              onTap: () =>
                                  _sendToFriend(context, friend.id, data),
                            );
                          },
                        );
                      },
                    ),
            ),
            const Divider(color: Colors.white12, height: 1),
            SizedBox(
              height: 104,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ExternalSendButton(
                    'WhatsApp',
                    Icons.chat_rounded,
                    Colors.green,
                    () => onExternalShare('whatsapp'),
                  ),
                  _ExternalSendButton(
                    'Facebook',
                    Icons.facebook_rounded,
                    Colors.blue,
                    () => onExternalShare('facebook'),
                  ),
                  _ExternalSendButton(
                    'Instagram',
                    Icons.camera_alt_rounded,
                    Colors.pinkAccent,
                    () => onExternalShare('instagram'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendToFriend(
    BuildContext context,
    String friendUid,
    Map<String, dynamic> friendData,
  ) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(friendUid)
        .collection('inbox')
        .add({
          'type': 'story',
          'storyId': storyId,
          'fromUid': currentUser.uid,
          'fromName': currentUser.displayName ?? 'Likeehit User',
          'imageUrl':
              storyData['imageUrl']?.toString() ??
              storyData['thumbnailUrl']?.toString() ??
              storyData['mediaUrl']?.toString() ??
              '',
          'createdAt': FieldValue.serverTimestamp(),
          'read': false,
        });
    await FirebaseFirestore.instance.collection('stories').doc(storyId).set({
      'sendCount': FieldValue.increment(1),
    }, SetOptions(merge: true));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sent to ${friendData['name'] ?? 'friend'}')),
      );
    }
  }
}

class _InformationNotificationsPage extends StatelessWidget {
  const _InformationNotificationsPage({required this.item});

  final _InfoItem item;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      backgroundColor: const Color(0xFF11101A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF11101A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          item.label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: uid == null
          ? _InformationEmptyState(item: item)
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .collection('notifications')
                  .orderBy('createdAt', descending: true)
                  .limit(120)
                  .snapshots(),
              builder: (context, snapshot) {
                final docs = (snapshot.data?.docs ?? const [])
                    .where((doc) => _matchesInfoNotification(doc.data(), item))
                    .toList();
                if (docs.isEmpty) return _InformationEmptyState(item: item);
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
                  itemBuilder: (context, index) => _InformationNotificationTile(
                    doc: docs[index],
                    item: item,
                  ),
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemCount: docs.length,
                );
              },
            ),
    );
  }
}

class _InformationEmptyState extends StatelessWidget {
  const _InformationEmptyState({required this.item});

  final _InfoItem item;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 136,
              height: 136,
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(68),
                boxShadow: [
                  BoxShadow(
                    color: item.color.withValues(alpha: 0.14),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Icon(item.icon, color: item.color, size: 76),
            ),
            const SizedBox(height: 18),
            const Text(
              'Sorry, No Content Here.',
              style: TextStyle(
                color: Color(0xFFA9A6B8),
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InformationNotificationTile extends StatelessWidget {
  const _InformationNotificationTile({required this.doc, required this.item});

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final _InfoItem item;

  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    final actorUid = _infoPageText(data['actorUid'], '');
    final actorName = _infoPageText(data['actorName'], 'Likeehit User');
    final actorPhoto = _infoPageText(data['actorPhotoUrl'], '');
    final thumbnail = _infoPageText(data['postThumbnailUrl'], '');
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: actorUid.isEmpty
            ? null
            : () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => _DirectChatPage(
                      peerUid: actorUid,
                      peerName: actorName,
                      peerPhotoUrl: actorPhoto,
                    ),
                  ),
                );
              },
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF242030),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF332E43)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: item.color.withValues(alpha: 0.22),
                backgroundImage: actorPhoto.isNotEmpty
                    ? NetworkImage(actorPhoto)
                    : null,
                child: actorPhoto.isEmpty
                    ? Icon(item.icon, color: item.color)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      actorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _infoNotificationBody(data),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFB7B2C5),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _infoTimeAgo(data['createdAt']),
                      style: const TextStyle(
                        color: Color(0xFF807B8E),
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (thumbnail.isNotEmpty) ...[
                const SizedBox(width: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    thumbnail,
                    width: 50,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 50,
                      height: 60,
                      color: const Color(0xFF181520),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white54,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DirectChatPage extends StatefulWidget {
  const _DirectChatPage({
    required this.peerUid,
    required this.peerName,
    required this.peerPhotoUrl,
  });

  final String peerUid;
  final String peerName;
  final String peerPhotoUrl;

  @override
  State<_DirectChatPage> createState() => _DirectChatPageState();
}

class _DirectChatPageState extends State<_DirectChatPage> {
  final TextEditingController _messageController = TextEditingController();
  bool _sending = false;

  String get _chatId {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final ids = [currentUid, widget.peerUid]..sort();
    return ids.join('_');
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return Scaffold(
      backgroundColor: const Color(0xFF11101A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF11101A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF332E43),
              backgroundImage: widget.peerPhotoUrl.isNotEmpty
                  ? NetworkImage(widget.peerPhotoUrl)
                  : null,
              child: widget.peerPhotoUrl.isEmpty
                  ? const Icon(Icons.person_rounded, color: Colors.white70)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.peerName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: currentUid.isEmpty
                ? const Center(
                    child: Text(
                      'Login required',
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('chats')
                        .doc(_chatId)
                        .collection('messages')
                        .orderBy('createdAt', descending: true)
                        .limit(100)
                        .snapshots(),
                    builder: (context, snapshot) {
                      final messages = snapshot.data?.docs ?? const [];
                      if (messages.isEmpty) {
                        return const Center(
                          child: Text(
                            'Say hello to start chatting.',
                            style: TextStyle(
                              color: Color(0xFFA9A6B8),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                      }
                      return ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final data = messages[index].data();
                          final mine = data['senderId'] == currentUid;
                          return Align(
                            alignment: mine
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.sizeOf(context).width * 0.74,
                              ),
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: mine
                                    ? const Color(0xFFFF3D8B)
                                    : const Color(0xFF252131),
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(18),
                                  topRight: const Radius.circular(18),
                                  bottomLeft: Radius.circular(mine ? 18 : 5),
                                  bottomRight: Radius.circular(mine ? 5 : 18),
                                ),
                              ),
                              child: Text(
                                _infoPageText(data['text'], ''),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              decoration: const BoxDecoration(color: Color(0xFF171520)),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 4,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Message',
                        hintStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: const Color(0xFF252131),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFFF3D8B),
                    ),
                    onPressed: _sending ? null : _sendMessage,
                    icon: const Icon(Icons.send_rounded, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    final user = FirebaseAuth.instance.currentUser;
    if (text.isEmpty || user == null) return;
    setState(() => _sending = true);
    _messageController.clear();
    try {
      final userData = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = userData.data() ?? const <String, dynamic>{};
      final myName = _infoPageText(
        data['name'] ?? data['username'] ?? data['displayName'],
        user.displayName ?? user.phoneNumber ?? 'Likeehit User',
      );
      final myPhoto = _infoPageText(
        data['photoUrl'] ??
            data['photoURL'] ??
            data['avatarUrl'] ??
            data['profileImageUrl'],
        user.photoURL ?? '',
      );
      final chatRef = FirebaseFirestore.instance
          .collection('chats')
          .doc(_chatId);
      final messageRef = chatRef.collection('messages').doc();
      final batch = FirebaseFirestore.instance.batch();
      batch.set(chatRef, {
        'participants': [user.uid, widget.peerUid]..sort(),
        'participantNames': {user.uid: myName, widget.peerUid: widget.peerName},
        'participantPhotos': {
          user.uid: myPhoto,
          widget.peerUid: widget.peerPhotoUrl,
        },
        'lastMessage': text,
        'lastSenderId': user.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      batch.set(messageRef, {
        'senderId': user.uid,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}

String _infoNotificationBody(Map<String, dynamic> data) {
  final category = data['category']?.toString() ?? '';
  final caption = _infoPageText(data['postCaption'], '');
  final comment = _infoPageText(data['commentText'], '');
  final giftName = _infoPageText(data['giftName'], 'Gift');
  final giftStars = _infoPageInt(data['giftStars']);
  final giftCount = _infoPageInt(data['giftCount']);
  final videoLabel = caption.isEmpty ? 'your video' : '"$caption"';
  switch (category) {
    case 'like':
      return 'liked $videoLabel';
    case 'mention':
      return 'mentioned you in $videoLabel';
    case 'follow':
      return 'started following you';
    case 'comment':
      return comment.isEmpty
          ? 'commented on $videoLabel'
          : 'commented: $comment';
    case 'gift':
      final countText = giftCount > 1 ? ' x$giftCount' : '';
      final starsText = giftStars > 0 ? ' ($giftStars stars)' : '';
      return 'sent $giftName$countText$starsText on $videoLabel';
    default:
      return _infoPageText(data['body'], 'New notification');
  }
}

String _infoTimeAgo(dynamic value) {
  DateTime? time;
  if (value is Timestamp) time = value.toDate();
  if (time == null) return 'Just now';
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  return '${diff.inDays} d ago';
}

String _infoPageText(dynamic value, String fallback) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? fallback : text;
}

int _infoPageInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

bool _matchesInfoNotification(Map<String, dynamic> data, _InfoItem item) {
  final category = data['category']?.toString().toLowerCase().trim() ?? '';
  final type = data['type']?.toString().toLowerCase().trim() ?? '';
  final title = data['title']?.toString().toLowerCase().trim() ?? '';
  final body = data['body']?.toString().toLowerCase().trim() ?? '';
  final target = item.key.toLowerCase();
  if (category == target || category == '${target}s') return true;
  switch (target) {
    case 'like':
      return category == 'likes' ||
          type.contains('like') ||
          title.contains('like') ||
          body.contains('liked');
    case 'mention':
      return category == 'mentions' ||
          type.contains('mention') ||
          title.contains('mention') ||
          body.contains('mention') ||
          body.contains('tagged');
    case 'follow':
      return category == 'follower' ||
          category == 'followers' ||
          type.contains('follow') ||
          title.contains('follow') ||
          body.contains('follow');
    case 'comment':
      return category == 'comments' ||
          type.contains('comment') ||
          type.contains('reply') ||
          title.contains('comment') ||
          body.contains('commented');
    case 'gift':
      return category == 'gifts' ||
          type.contains('gift') ||
          title.contains('gift') ||
          body.contains('gift');
    default:
      return false;
  }
}

class _StoryMentionSheet extends StatelessWidget {
  const _StoryMentionSheet({required this.storyRef});

  final DocumentReference<Map<String, dynamic>> storyRef;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.58,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            const _SheetHandle(),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 22),
              child: TextField(
                style: TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search',
                  hintStyle: TextStyle(color: Colors.white54),
                  prefixIcon: Icon(Icons.search, color: Colors.white54),
                  filled: true,
                  fillColor: Colors.white10,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(14)),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: uid == null
                  ? const SizedBox.shrink()
                  : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(uid)
                          .collection('friends')
                          .limit(60)
                          .snapshots(),
                      builder: (context, snapshot) {
                        final friends = snapshot.data?.docs ?? const [];
                        if (friends.isEmpty) {
                          return const Center(
                            child: Text(
                              'People added here will be mentioned in your story.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white54),
                            ),
                          );
                        }
                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 22),
                          itemCount: friends.length,
                          itemBuilder: (context, index) {
                            final friend = friends[index];
                            final data = friend.data();
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: _FriendAvatar(data: data),
                              title: Text(
                                data['name']?.toString() ??
                                    data['username']?.toString() ??
                                    'Likeehit User',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              trailing: FilledButton(
                                onPressed: () async {
                                  await storyRef.set({
                                    'mentions': FieldValue.arrayUnion([
                                      {
                                        'uid': friend.id,
                                        'name':
                                            data['name']?.toString() ??
                                            data['username']?.toString() ??
                                            'Likeehit User',
                                        'photoUrl':
                                            data['photoUrl']?.toString() ??
                                            data['photoURL']?.toString() ??
                                            '',
                                      },
                                    ]),
                                  }, SetOptions(merge: true));
                                  await FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(friend.id)
                                      .collection('inbox')
                                      .add({
                                        'type': 'storyMention',
                                        'storyId': storyRef.id,
                                        'fromUid': uid,
                                        'createdAt':
                                            FieldValue.serverTimestamp(),
                                        'read': false,
                                      });
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                  }
                                },
                                child: const Text('Add'),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoryMoreSheet extends StatelessWidget {
  const _StoryMoreSheet({
    required this.storyId,
    required this.storyRef,
    required this.storyData,
    required this.onShare,
    required this.onDeleted,
  });

  final String storyId;
  final DocumentReference<Map<String, dynamic>> storyRef;
  final Map<String, dynamic> storyData;
  final VoidCallback onShare;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context) {
    final commentsEnabled = storyData['commentsEnabled'] != false;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 12, 28, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(child: _SheetHandle()),
            const SizedBox(height: 22),
            _MoreTile(
              'Delete',
              color: Colors.redAccent,
              onTap: () async {
                await storyRef.delete();
                if (context.mounted) Navigator.pop(context);
                onDeleted();
              },
            ),
            _MoreTile('Archive', onTap: () => _archive(context)),
            _MoreTile('Save video', onTap: () => _save(context)),
            _MoreTile('Highlight', onTap: () => _highlight(context)),
            _MoreTile(
              'Edit AI label',
              onTap: () {
                Navigator.pop(context);
                showModalBottomSheet<void>(
                  context: context,
                  backgroundColor: const Color(0xFF15191D),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(26),
                    ),
                  ),
                  builder: (_) => _AiLabelSheet(storyRef: storyRef),
                );
              },
            ),
            _MoreTile(
              'Share',
              onTap: () {
                Navigator.pop(context);
                onShare();
              },
            ),
            _MoreTile(
              'Go to story settings',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const _StorySettingsScreen(),
                  ),
                );
              },
            ),
            _MoreTile(
              commentsEnabled ? 'Turn off commenting' : 'Turn on commenting',
              onTap: () async {
                await storyRef.set({
                  'commentsEnabled': !commentsEnabled,
                }, SetOptions(merge: true));
                if (context.mounted) Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _archive(BuildContext context) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('storyArchive')
        .doc(storyId)
        .set({...storyData, 'archivedAt': FieldValue.serverTimestamp()});
    await storyRef.set({'archived': true}, SetOptions(merge: true));
    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Story archived')));
    }
  }

  Future<void> _save(BuildContext context) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Saving story to gallery...')),
    );
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('savedStories')
        .doc(storyId)
        .set({...storyData, 'savedAt': FieldValue.serverTimestamp()});
    final saved = await _StoryGallerySaver.save(storyData);
    if (context.mounted) {
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            saved
                ? 'Story saved to phone gallery'
                : 'Saved in Likeehit. Gallery permission or media failed.',
          ),
        ),
      );
    }
  }

  Future<void> _highlight(BuildContext context) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final mediaUrl = _firstNonEmpty([
      storyData['mediaUrl'],
      storyData['videoUrl'],
      storyData['imageUrl'],
      storyData['thumbnailUrl'],
    ]);
    final imageUrl = _firstNonEmpty([
      storyData['imageUrl'],
      storyData['thumbnailUrl'],
      storyData['mediaUrl'],
    ]);
    final highlightData = Map<String, dynamic>.from(storyData)
      ..remove('expiresAt')
      ..remove('archivedAt')
      ..addAll({
        'isHighlight': true,
        'sourceStoryId': storyId,
        'storyId': storyId,
        'mediaUrl': mediaUrl,
        'imageUrl': imageUrl,
        'highlightTitle':
            storyData['highlightTitle']?.toString().trim().isNotEmpty == true
            ? storyData['highlightTitle']
            : 'Collection',
        'highlightedAt': FieldValue.serverTimestamp(),
      });
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('highlights')
          .doc(storyId)
          .set(highlightData, SetOptions(merge: true));
      await storyRef.set({'highlighted': true}, SetOptions(merge: true));
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Added to highlights')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Highlight failed: $error')));
      }
    }
  }

  String _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return '';
  }
}

class _AiLabelSheet extends StatelessWidget {
  const _AiLabelSheet({required this.storyRef});

  final DocumentReference<Map<String, dynamic>> storyRef;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: storyRef.snapshots(),
      builder: (context, snapshot) {
        final enabled = snapshot.data?.data()?['aiLabel'] == true;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _SheetHandle(),
                const SizedBox(height: 24),
                const Text(
                  'AI label',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                  ),
                ),
                const SizedBox(height: 22),
                SwitchListTile(
                  value: enabled,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (value) =>
                      storyRef.set({'aiLabel': value}, SetOptions(merge: true)),
                  title: const Text(
                    'Add AI label',
                    style: TextStyle(color: Colors.white, fontSize: 20),
                  ),
                  subtitle: const Text(
                    "We require you to label certain realistic content that's made with AI.",
                    style: TextStyle(color: Colors.white60),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StoryBottomAction extends StatelessWidget {
  const _StoryBottomAction(this.icon, this.label, {required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 30),
            const SizedBox(height: 4),
            SizedBox(
              width: 58,
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StorySettingsScreen extends StatelessWidget {
  const _StorySettingsScreen();

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final ref = uid == null
        ? null
        : FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('settings')
              .doc('story');
    return Scaffold(
      backgroundColor: const Color(0xFF090E13),
      appBar: AppBar(
        backgroundColor: const Color(0xFF090E13),
        foregroundColor: Colors.white,
        title: const Text(
          'Story',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: ref == null
          ? const Center(child: Text('Login required'))
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: ref.snapshots(),
              builder: (context, snapshot) {
                final data = snapshot.data?.data() ?? <String, dynamic>{};
                final replies =
                    data['messageReplies']?.toString() ?? 'everyone';
                return ListView(
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 34),
                  children: [
                    _SettingsLabel(
                      'Viewing',
                      'Hide story from',
                      '${data['hiddenCount'] ?? 0} people',
                      'Hide your story and live videos from specific people.',
                    ),
                    _SettingsLabel(
                      null,
                      'Close friends',
                      '${data['closeFriendsCount'] ?? 0} people',
                      'Share your story only with specific people.',
                    ),
                    const Divider(color: Colors.white12, height: 34),
                    const Text(
                      'Replying',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Allow message replies',
                      style: TextStyle(color: Colors.white, fontSize: 20),
                    ),
                    const Text(
                      'Choose who can reply to your story.',
                      style: TextStyle(color: Colors.white54),
                    ),
                    _SettingsRadio(
                      label: 'Everyone',
                      value: 'everyone',
                      groupValue: replies,
                      onChanged: (value) => ref.set({
                        'messageReplies': value,
                      }, SetOptions(merge: true)),
                    ),
                    _SettingsRadio(
                      label: 'People you follow',
                      value: 'following',
                      groupValue: replies,
                      onChanged: (value) => ref.set({
                        'messageReplies': value,
                      }, SetOptions(merge: true)),
                    ),
                    _SettingsRadio(
                      label: 'Off',
                      value: 'off',
                      groupValue: replies,
                      onChanged: (value) => ref.set({
                        'messageReplies': value,
                      }, SetOptions(merge: true)),
                    ),
                    const Divider(color: Colors.white12, height: 34),
                    _SettingsSwitch(
                      title: 'Allow comments',
                      value: data['allowComments'] != false,
                      onChanged: (value) => ref.set({
                        'allowComments': value,
                      }, SetOptions(merge: true)),
                    ),
                    _SettingsSwitch(
                      title: 'Save story to Gallery',
                      subtitle:
                          "Automatically save your story to your phone's gallery.",
                      value: data['saveToGallery'] == true,
                      onChanged: (value) => ref.set({
                        'saveToGallery': value,
                      }, SetOptions(merge: true)),
                    ),
                    _SettingsSwitch(
                      title: 'Save story to archive',
                      subtitle:
                          'Automatically save photos and videos to your archive.',
                      value: data['saveToArchive'] != false,
                      onChanged: (value) => ref.set({
                        'saveToArchive': value,
                      }, SetOptions(merge: true)),
                    ),
                    const Divider(color: Colors.white12, height: 34),
                    const Text(
                      'Sharing',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    _SettingsSwitch(
                      title: 'Allow sharing to story',
                      value: data['allowStorySharing'] != false,
                      onChanged: (value) => ref.set({
                        'allowStorySharing': value,
                      }, SetOptions(merge: true)),
                    ),
                    _SettingsSwitch(
                      title: 'Allow sharing to messages',
                      value: data['allowMessageSharing'] != false,
                      onChanged: (value) => ref.set({
                        'allowMessageSharing': value,
                      }, SetOptions(merge: true)),
                    ),
                    _SettingsSwitch(
                      title: 'Share your story to Facebook',
                      value: data['shareToFacebook'] == true,
                      onChanged: (value) => ref.set({
                        'shareToFacebook': value,
                      }, SetOptions(merge: true)),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 5,
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }
}

class _MiniStoryPreview extends StatelessWidget {
  const _MiniStoryPreview({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final image =
        data['imageUrl']?.toString() ??
        data['thumbnailUrl']?.toString() ??
        data['mediaUrl']?.toString() ??
        '';
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 70,
        height: 88,
        color: Colors.white10,
        child: image.isEmpty
            ? const Icon(Icons.image_rounded, color: Colors.white)
            : Image.network(image, fit: BoxFit.cover),
      ),
    );
  }
}

class _ActivityCount extends StatelessWidget {
  const _ActivityCount({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 3),
            Text(
              '$value',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
            Text(
              label,
              style: const TextStyle(color: Colors.white60, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoryGallerySaver {
  const _StoryGallerySaver._();

  static Future<bool> save(Map<String, dynamic> storyData) async {
    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.isAuth && !permission.hasAccess) return false;

    final mediaType = storyData['mediaType']?.toString() ?? 'image';
    final url =
        storyData['mediaUrl']?.toString() ??
        storyData['imageUrl']?.toString() ??
        storyData['thumbnailUrl']?.toString() ??
        '';
    if (url.trim().isEmpty || !url.startsWith('http')) return false;

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return false;
      }
      final extension = _extensionFor(mediaType, url);
      final file = File(
        '${Directory.systemTemp.path}/likeehit_story_${DateTime.now().millisecondsSinceEpoch}.$extension',
      );
      await file.writeAsBytes(response.bodyBytes, flush: true);
      if (mediaType == 'video') {
        await PhotoManager.editor.saveVideo(
          file,
          title: 'Likeehit Story',
          relativePath: 'Pictures/Likeehit',
        );
      } else {
        await PhotoManager.editor.saveImageWithPath(
          file.path,
          title: 'Likeehit Story',
          relativePath: 'Pictures/Likeehit',
        );
      }
      unawaited(file.delete().catchError((_) => file));
      return true;
    } catch (_) {
      return false;
    }
  }

  static String _extensionFor(String mediaType, String url) {
    if (mediaType == 'video') return 'mp4';
    final lower = url.toLowerCase();
    if (lower.contains('.png')) return 'png';
    if (lower.contains('.webp')) return 'webp';
    return 'jpg';
  }
}

class _ShareChoice {
  const _ShareChoice(this.platform, this.label, this.icon, this.color);

  final String platform;
  final String label;
  final IconData icon;
  final Color color;
}

class _FriendBubble extends StatelessWidget {
  const _FriendBubble({required this.data, required this.onTap});

  final Map<String, dynamic> data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name =
        data['name']?.toString() ?? data['username']?.toString() ?? 'Friend';
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Column(
        children: [
          _FriendAvatar(data: data, radius: 31),
          const SizedBox(height: 8),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _FriendAvatar extends StatelessWidget {
  const _FriendAvatar({required this.data, this.radius = 24});

  final Map<String, dynamic> data;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final photo =
        data['photoUrl']?.toString() ?? data['photoURL']?.toString() ?? '';
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.white12,
      backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
      child: photo.isEmpty
          ? const Icon(Icons.person_rounded, color: Colors.white)
          : null,
    );
  }
}

class _ExternalSendButton extends StatelessWidget {
  const _ExternalSendButton(this.label, this.icon, this.color, this.onTap);

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(40),
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: color.withValues(alpha: 0.18),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MoreTile extends StatelessWidget {
  const _MoreTile(this.label, {required this.onTap, this.color = Colors.white});

  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      title: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SettingsLabel extends StatelessWidget {
  const _SettingsLabel(this.section, this.title, this.value, this.subtitle);

  final String? section;
  final String title;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (section != null) ...[
            Text(
              section!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 20),
          ],
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 14),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.white54, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

class _SettingsRadio extends StatelessWidget {
  const _SettingsRadio({
    required this.label,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  final String label;
  final String value;
  final String groupValue;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    return InkWell(
      onTap: () => onChanged(value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
            Container(
              width: 26,
              height: 26,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? Colors.white : Colors.white54,
                  width: 3,
                ),
              ),
              child: selected
                  ? const DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSwitch extends StatelessWidget {
  const _SettingsSwitch({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      value: value,
      onChanged: onChanged,
      title: Text(title, style: const TextStyle(color: Colors.white)),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, style: const TextStyle(color: Colors.white54)),
    );
  }
}

class _StoryViewerSticker extends StatelessWidget {
  const _StoryViewerSticker({required this.storyId, required this.sticker});

  final String storyId;
  final Map<String, dynamic> sticker;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final dx = _asDouble(sticker['dx']).clamp(0, size.width - 80).toDouble();
    final dy = _asDouble(sticker['dy']).clamp(76, size.height - 120).toDouble();
    final scale = _asDouble(sticker['scale'], fallback: 1).clamp(0.45, 3.0);
    return Positioned(
      left: dx,
      top: dy,
      child: Transform.scale(
        scale: scale,
        alignment: Alignment.center,
        child: _content(),
      ),
    );
  }

  Widget _content() {
    final type = sticker['type']?.toString() ?? '';
    final action = sticker['action']?.toString() ?? '';
    final label = sticker['label']?.toString() ?? '';
    final metadata =
        (sticker['metadata'] as Map?)?.map(
          (key, value) => MapEntry(key.toString(), value.toString()),
        ) ??
        const <String, String>{};
    final color = _color(sticker['color']);
    if (type == 'gif') {
      final url = metadata['url'] ?? '';
      return SizedBox(
        width: 112,
        height: 112,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Image.network(url, fit: BoxFit.cover),
        ),
      );
    }
    if (type == 'poll') return _pollSticker(label, metadata, color);
    if (type == 'link') {
      return GestureDetector(
        onTap: () => _openLink(metadata['url'] ?? label),
        child: _card(
          label,
          metadata['cta'] ?? 'Open link',
          Icons.link_rounded,
          color,
        ),
      );
    }
    if (type == 'card') {
      return _card(
        label,
        metadata['cta'] ?? action,
        _iconForAction(action),
        color,
        subtitle: metadata['subtitle'] ?? '',
      );
    }
    if (type == 'chip') return _chip(label, _iconForAction(action), color);
    if (type == 'text') return _storyText(label, metadata, color);
    return Text(
      label,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: color,
        fontSize: type == 'premium' ? 38 : 46,
        fontWeight: FontWeight.w900,
        height: 1.15,
        shadows: const [
          Shadow(color: Colors.black87, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
    );
  }

  Widget _storyText(String label, Map<String, String> metadata, Color color) {
    final align = _viewerTextAlign(metadata['align']);
    final styleKey = metadata['style'] ?? 'classic';
    final withBackground = metadata['background'] == 'true';
    return Container(
      constraints: const BoxConstraints(maxWidth: 300),
      padding: withBackground
          ? const EdgeInsets.symmetric(horizontal: 10, vertical: 5)
          : EdgeInsets.zero,
      decoration: BoxDecoration(
        color: withBackground ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        textAlign: align,
        style: _viewerStoryTextStyle(
          styleKey,
          withBackground ? Colors.black : color,
          fontSize: 38,
        ),
      ),
    );
  }

  Widget _chip(String label, IconData icon, Color color) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 230),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 21),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF2B2B2D),
                fontWeight: FontWeight.w900,
                fontSize: 19,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(
    String label,
    String cta,
    IconData icon,
    Color color, {
    String subtitle = '',
  }) {
    return Container(
      width: 230,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF1F2028),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF727381),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    cta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pollSticker(
    String question,
    Map<String, String> metadata,
    Color color,
  ) {
    final pollId =
        sticker['pollId']?.toString() ?? sticker['id']?.toString() ?? '';
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('stories')
          .doc(storyId)
          .collection('polls')
          .doc(pollId)
          .snapshots(),
      builder: (context, snapshot) {
        final poll = snapshot.data?.data() ?? <String, dynamic>{};
        final yesLabel =
            poll['yesLabel']?.toString() ?? metadata['yesLabel'] ?? 'Yes';
        final noLabel =
            poll['noLabel']?.toString() ?? metadata['noLabel'] ?? 'No';
        final yesVotes = _asDouble(poll['yesVotes']).toInt();
        final noVotes = _asDouble(poll['noVotes']).toInt();
        return Container(
          width: 238,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Colors.black45,
                blurRadius: 14,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                question,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF1F2028),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _voteButton(
                      yesLabel,
                      yesVotes,
                      color,
                      () => _vote(pollId, 'yes'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _voteButton(
                      noLabel,
                      noVotes,
                      color,
                      () => _vote(pollId, 'no'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _voteButton(String label, int votes, Color color, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          '$label\n$votes',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Future<void> _vote(String pollId, String vote) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || pollId.isEmpty) return;
    final ref = FirebaseFirestore.instance
        .collection('stories')
        .doc(storyId)
        .collection('polls')
        .doc(pollId);
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snap = await transaction.get(ref);
      final data = snap.data() ?? <String, dynamic>{};
      final voters = Map<String, dynamic>.from(data['voters'] as Map? ?? {});
      final previous = voters[uid]?.toString();
      if (previous == vote) return;
      final updates = <String, dynamic>{'voters.$uid': vote};
      if (previous == 'yes') updates['yesVotes'] = FieldValue.increment(-1);
      if (previous == 'no') updates['noVotes'] = FieldValue.increment(-1);
      updates[vote == 'yes' ? 'yesVotes' : 'noVotes'] = FieldValue.increment(1);
      transaction.set(ref, updates, SetOptions(merge: true));
    });
  }

  Future<void> _openLink(String urlText) async {
    if (urlText.trim().isEmpty) return;
    final url = urlText.startsWith('http') ? urlText : 'https://$urlText';
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  TextAlign _viewerTextAlign(String? key) {
    switch (key) {
      case 'left':
        return TextAlign.left;
      case 'right':
        return TextAlign.right;
      default:
        return TextAlign.center;
    }
  }

  TextStyle _viewerStoryTextStyle(
    String styleKey,
    Color color, {
    double fontSize = 42,
  }) {
    final base = TextStyle(
      color: color,
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      height: 1.12,
      shadows: const [
        Shadow(color: Colors.black87, blurRadius: 9, offset: Offset(0, 2)),
      ],
    );
    switch (styleKey) {
      case 'neon':
        return base.copyWith(
          fontStyle: FontStyle.italic,
          shadows: [
            Shadow(color: color.withValues(alpha: 0.9), blurRadius: 14),
            const Shadow(
              color: Colors.black87,
              blurRadius: 9,
              offset: Offset(0, 2),
            ),
          ],
        );
      case 'typewriter':
        return base.copyWith(fontFamily: 'monospace');
      case 'strong':
        return base.copyWith(
          fontStyle: FontStyle.italic,
          fontSize: fontSize + 2,
        );
      case 'soft':
        return base.copyWith(fontWeight: FontWeight.w700);
      default:
        return base;
    }
  }

  IconData _iconForAction(String action) {
    switch (action) {
      case 'addYours':
        return Icons.camera_alt_rounded;
      case 'location':
        return Icons.location_on_rounded;
      case 'time':
        return Icons.access_time_rounded;
      case 'event':
        return Icons.event_available_rounded;
      case 'tag':
        return Icons.alternate_email_rounded;
      case 'feelings':
        return Icons.sentiment_satisfied_alt_rounded;
      case 'donate':
        return Icons.favorite_rounded;
      case 'question':
        return Icons.contact_support_rounded;
      case 'captions':
        return Icons.closed_caption_rounded;
      case 'link':
        return Icons.link_rounded;
      default:
        return Icons.auto_awesome_rounded;
    }
  }

  Color _color(dynamic value) {
    if (value is int) return Color(value);
    return const Color(0xFF1677FF);
  }

  double _asDouble(dynamic value, {double fallback = 0}) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }
}

class _InfoItem {
  const _InfoItem(this.key, this.label, this.icon, this.color);

  final String key;
  final String label;
  final IconData icon;
  final Color color;
}
