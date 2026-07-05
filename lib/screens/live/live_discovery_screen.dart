import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/live_room.dart';
import '../../services/live_service.dart';
import 'audio_party_room_page.dart';
import 'live_host_setup_page.dart';
import 'live_page.dart';

class LiveDiscoveryScreen extends StatefulWidget {
  const LiveDiscoveryScreen({super.key});

  @override
  State<LiveDiscoveryScreen> createState() => _LiveDiscoveryScreenState();
}

class _LiveDiscoveryScreenState extends State<LiveDiscoveryScreen> {
  final TextEditingController _roomController = TextEditingController();
  bool _creatingRoom = false;
  int _topTab = 0; // 0 Party, 1 Live, 2 Anniversary
  int _categoryTab = 0;
  late final ScrollController _tickerController;

  @override
  void initState() {
    super.initState();
    _tickerController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startTicker());
  }

  @override
  void dispose() {
    _tickerController.dispose();
    _roomController.dispose();
    super.dispose();
  }

  void _startTicker() async {
    while (mounted) {
      if (_tickerController.hasClients) {
        final max = _tickerController.position.maxScrollExtent;
        if (max > 0) {
          await _tickerController.animateTo(
            max,
            duration: const Duration(seconds: 7),
            curve: Curves.linear,
          );
          if (!mounted) return;
          await _tickerController.animateTo(
            0,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
          );
        }
      }
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  Future<void> _createLiveRoom() async {
    if (_creatingRoom) return;
    setState(() => _creatingRoom = true);
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LiveHostSetupPage()),
    );
    if (mounted) setState(() => _creatingRoom = false);
  }

  Future<void> _createPartyRoom() async {
    if (_creatingRoom) return;
    setState(() => _creatingRoom = true);
    try {
      final roomId = await LiveService.instance.createRoom(
        liveTitle: 'My Room',
        hashtag: '#Party',
        roomType: 'party',
        audioOnly: true,
        setupConfig: const {'stage': 'audio_party'},
      );
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AudioPartyRoomPage(roomId: roomId, isHost: true),
        ),
      );
    } finally {
      if (mounted) setState(() => _creatingRoom = false);
    }
  }

  void _joinRoom(LiveRoom room) {
    const isHost = false;
    final liveID = room.id;
    debugPrint('OPEN LIVE PAGE isHost=$isHost liveID=$liveID');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => room.isParty || _topTab == 0
            ? AudioPartyRoomPage(roomId: liveID, isHost: isHost)
            : LivePage(liveID: liveID, isHost: isHost),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = _topTab == 0
        ? ['Recommended', 'Fun Hub', 'Karaoke', 'Chat']
        : ['Global', 'Hot', 'Charming', 'NewComers'];

    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1323), Color(0xFF0F1016), Color(0xFF050506)],
          ),
        ),
        child: Column(
          children: [
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                child: Row(
                  children: [
                    _topLabel('Party', 0),
                    const SizedBox(width: 18),
                    _topLabel('Live', 1),
                    const SizedBox(width: 18),
                    _topLabel('10th Anniver', 2),
                    const Spacer(),
                    const Icon(
                      Icons.search_rounded,
                      color: Colors.white70,
                      size: 30,
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<List<LiveRoom>>(
                stream: LiveService.instance.liveRooms(),
                builder: (context, snapshot) {
                  final allRooms = snapshot.data ?? [];
                  final rooms = _topTab == 0
                      ? allRooms
                            .where(
                              (r) =>
                                  r.isParty ||
                                  r.hostName.toLowerCase().contains('party') ||
                                  r.id.toLowerCase().contains('party'),
                            )
                            .toList()
                      : allRooms;

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    children: [
                      _storyRow(rooms),
                      const SizedBox(height: 8),
                      _tickerBannerPro(),
                      const SizedBox(height: 12),
                      if (_topTab == 0) _partyFeatureCards(rooms),
                      if (_topTab != 0) ...[
                        const SizedBox(height: 2),
                        _countryChips(),
                      ],
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: List.generate(categories.length, (i) {
                            final active = _categoryTab == i;
                            return GestureDetector(
                              onTap: () => setState(() => _categoryTab = i),
                              child: Container(
                                margin: EdgeInsets.only(
                                  right: i == categories.length - 1 ? 0 : 18,
                                ),
                                padding: const EdgeInsets.only(bottom: 6),
                                decoration: BoxDecoration(
                                  border: active
                                      ? const Border(
                                          bottom: BorderSide(
                                            color: Color(0xFFFF3F8B),
                                            width: 4,
                                          ),
                                        )
                                      : null,
                                ),
                                child: Text(
                                  categories[i],
                                  style: TextStyle(
                                    color: active
                                        ? Colors.white
                                        : const Color(0xFFB6BBC8),
                                    fontWeight: active
                                        ? FontWeight.w800
                                        : FontWeight.w500,
                                    fontSize: 19,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (rooms.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 90),
                          child: Center(
                            child: Text(
                              'No creators are live right now',
                              style: TextStyle(
                                color: Color(0xFFB6BBC8),
                                fontSize: 22,
                              ),
                            ),
                          ),
                        )
                      else
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                                childAspectRatio: 0.76,
                              ),
                          itemCount: rooms.length,
                          itemBuilder: (context, index) =>
                              _roomCard(rooms[index]),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topLabel(String text, int idx) {
    final active = _topTab == idx;
    return GestureDetector(
      onTap: () => setState(() => _topTab = idx),
      child: Column(
        children: [
          Text(
            text,
            style: TextStyle(
              color: active ? Colors.white : const Color(0xFFB6BBC8),
              fontSize: 17,
              fontWeight: active ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Container(
            width: active ? 34 : 0,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFFF3F8B),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ],
      ),
    );
  }

  Widget _storyRow(List<LiveRoom> rooms) {
    return SizedBox(
      height: 108,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: (rooms.length > 8 ? 8 : rooms.length) + 1,
        separatorBuilder: (_, separatorIndex) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          if (index == 0) {
            return GestureDetector(
              onTap: _topTab == 0 ? _createPartyRoom : _createLiveRoom,
              child: SizedBox(
                width: 82,
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 34,
                      backgroundColor: _topTab == 0
                          ? const Color(0xFFB091FF)
                          : const Color(0xFFF78CB3),
                      child: Icon(
                        _topTab == 0
                            ? Icons.home_rounded
                            : Icons.videocam_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _topTab == 0 ? 'My Room' : 'Go Live',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          final room = rooms[index - 1];
          final liveLabel = _topTab == 0 ? 'CHAT' : 'LIVE';
          return GestureDetector(
            onTap: () => _joinRoom(room),
            child: SizedBox(
              width: 82,
              child: Column(
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFFFF83AF), Color(0xFFA97DFF)],
                      ),
                    ),
                    child: CircleAvatar(
                      backgroundColor: const Color(0xFF1A1A22),
                      backgroundImage: room.coverUrl.isNotEmpty
                          ? NetworkImage(room.coverUrl)
                          : null,
                      child: room.coverUrl.isEmpty
                          ? const Icon(Icons.person, color: Colors.white54)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF74A5),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      liveLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
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

  // ignore: unused_element
  Widget _tickerBanner() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collectionGroup('giftEvents')
          .orderBy('createdAt', descending: true)
          .limit(20)
          .snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? const [];
        final messages = <String>[];
        for (final d in docs) {
          final m = d.data();
          final sender = m['name']?.toString().trim();
          final giftName = m['giftName']?.toString().trim();
          final qty = _safeInt(m['quantity']);
          if ((sender ?? '').isEmpty || (giftName ?? '').isEmpty) continue;
          messages.add('$sender sent $giftName x${qty <= 0 ? 1 : qty}');
        }
        if (messages.isEmpty) {
          messages.addAll(const [
            'Live party ongoing',
            'Join now and win rewards',
            'Top rooms are trending',
          ]);
        }
        final marquee = messages.join('   •   ');
        return Container(
          height: 34,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF62A4), Color(0xFFB260FF)],
            ),
            borderRadius: BorderRadius.circular(999),
          ),
          child: ListView(
            controller: _tickerController,
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              const SizedBox(width: 12),
              const Icon(
                Icons.card_giftcard_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              Center(
                child: Text(
                  marquee,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 24),
            ],
          ),
        );
      },
    );
  }

  int _safeInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  Widget _countryChips() {
    final items = [
      'Europe & America',
      'Indonesia',
      'India',
      'Philippines',
      'Nepal',
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(items.length, (i) {
          return Container(
            margin: EdgeInsets.only(right: i == items.length - 1 ? 0 : 18),
            child: Text(
              items[i],
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _partyFeatureCards(List<LiveRoom> rooms) {
    final cards = [
      ('Family', const Color(0xFF2A1C0E)),
      ('Sing', const Color(0xFF241536)),
      ('Chat', const Color(0xFF2A1C0E)),
      ('Play Ludo', const Color(0xFF13273D)),
      ('Play Billiards', const Color(0xFF112C23)),
      ('Play Games', const Color(0xFF13273D)),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cards.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.05,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemBuilder: (context, index) {
        final item = cards[index];
        return Container(
          decoration: BoxDecoration(
            color: item.$2,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Text(
                    item.$1,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              Text(
                '${(rooms.length * (index + 7)) + 12}K',
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _roomCard(LiveRoom room) {
    final title = room.hostName.isEmpty ? 'Live Room' : room.hostName;
    return GestureDetector(
      onTap: () => _joinRoom(room),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (room.coverUrl.isNotEmpty)
              Image.network(room.coverUrl, fit: BoxFit.cover)
            else
              Container(color: const Color(0xFF20212A)),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.68),
                  ],
                  begin: Alignment.center,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF4D92),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Live',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 10,
              left: 10,
              right: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${room.viewers} watching',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tickerBannerPro() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collectionGroup('giftEvents')
          .orderBy('createdAt', descending: true)
          .limit(40)
          .snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? const [];
        final events = <_TickerEvent>[];
        for (final d in docs) {
          final m = d.data();
          final sender = m['name']?.toString().trim();
          final giftName = m['giftName']?.toString().trim();
          final qty = _safeInt(m['quantity']);
          final totalStars = _safeInt(m['totalStars']);
          final roomId = m['roomId']?.toString() ?? '';
          if ((sender ?? '').isEmpty || (giftName ?? '').isEmpty) continue;
          events.add(
            _TickerEvent(
              message: '$sender sent $giftName x${qty <= 0 ? 1 : qty}',
              roomId: roomId,
              score: totalStars,
              tag: _tickerTagFor(giftName ?? ''),
            ),
          );
        }
        events.sort((a, b) => b.score.compareTo(a.score));
        if (events.isEmpty) {
          events.addAll(const [
            _TickerEvent(
              message: 'Live party ongoing',
              roomId: '',
              score: 0,
              tag: 'LIVE',
            ),
            _TickerEvent(
              message: 'Join now and win rewards',
              roomId: '',
              score: 0,
              tag: 'GIFT',
            ),
            _TickerEvent(
              message: 'Top rooms are trending',
              roomId: '',
              score: 0,
              tag: 'LIVE',
            ),
          ]);
        }

        return Container(
          height: 34,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF62A4), Color(0xFFB260FF)],
            ),
            borderRadius: BorderRadius.circular(999),
          ),
          child: ListView(
            controller: _tickerController,
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              const SizedBox(width: 12),
              ...events.map((e) {
                final tagColor = _tickerTagColor(e.tag);
                return GestureDetector(
                  onTap: e.roomId.isEmpty
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  LivePage(liveID: e.roomId, isHost: false),
                            ),
                          );
                        },
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: tagColor,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          e.tag,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        e.message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 16),
                    ],
                  ),
                );
              }),
              const SizedBox(width: 24),
            ],
          ),
        );
      },
    );
  }

  String _tickerTagFor(String giftName) {
    final g = giftName.toLowerCase();
    if (g.contains('pk')) return 'PK';
    if (g.contains('live')) return 'LIVE';
    return 'GIFT';
  }

  Color _tickerTagColor(String tag) {
    switch (tag) {
      case 'PK':
        return const Color(0xFF6D5CFF);
      case 'LIVE':
        return const Color(0xFFFF5E92);
      default:
        return const Color(0xFFFF9A3C);
    }
  }
}

class _TickerEvent {
  const _TickerEvent({
    required this.message,
    required this.roomId,
    required this.score,
    required this.tag,
  });

  final String message;
  final String roomId;
  final int score;
  final String tag;
}
