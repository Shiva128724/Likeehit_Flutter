import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/agora_service.dart';
import '../../services/live_service.dart';
import '../../widgets/svip_badge.dart';
import 'room_exp_page.dart';

class AudioPartyRoomPage extends StatefulWidget {
  const AudioPartyRoomPage({
    super.key,
    required this.roomId,
    required this.isHost,
  });

  final String roomId;
  final bool isHost;

  @override
  State<AudioPartyRoomPage> createState() => _AudioPartyRoomPageState();
}

class _AudioPartyRoomPageState extends State<AudioPartyRoomPage> {
  final TextEditingController _messageController = TextEditingController();
  late final AgoraService _agora;
  StreamSubscription<List<PartySeatState>>? _seatSub;
  List<PartySeatState> _seats = const <PartySeatState>[];
  String _uid = '';
  bool _micMuted = false;
  bool _audioJoined = false;
  int? _mySeatIndex;
  int? _lastSyncedSeatIndex;
  bool? _lastSyncedMuted;
  bool _lastSyncedBroadcaster = false;
  final List<_PartyGiftItem> _giftCatalog = _buildPartyGiftCatalog();

  @override
  void initState() {
    super.initState();
    _agora = AgoraService()..addListener(_onAgoraChanged);
    _uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _seatSub = LiveService.instance.watchPartySeats(widget.roomId).listen((
      seats,
    ) {
      if (!mounted) return;
      setState(() => _seats = seats);
      unawaited(_syncAgoraRole(seats));
    });
    unawaited(_bootstrapRoom());
  }

  @override
  void dispose() {
    _seatSub?.cancel();
    unawaited(
      LiveService.instance.leaveRoom(widget.roomId, isHost: widget.isHost),
    );
    _agora.removeListener(_onAgoraChanged);
    unawaited(_agora.release());
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _bootstrapRoom() async {
    await LiveService.instance.joinRoom(widget.roomId);
    await LiveService.instance.ensurePartySeats(widget.roomId);
    try {
      await _agora.join(
        isHost: widget.isHost,
        channelName: AgoraService.defaultChannelName,
        audioOnly: true,
      );
      if (mounted) setState(() => _audioJoined = true);
      await _syncAgoraRole(_seats);
    } catch (error) {
      if (mounted) _toast(error.toString());
    }
  }

  void _onAgoraChanged() {
    if (mounted) setState(() => _micMuted = _agora.micMuted);
  }

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: LiveService.instance.watchRoom(widget.roomId),
        builder: (context, snapshot) {
          final data = snapshot.data?.data() ?? <String, dynamic>{};
          final hostName = _string(data['hostName'], fallback: 'Party Room');
          final hostUid = _string(data['hostId']);
          final hostId = _compactProfileId(
            _string(data['hostUsername'], fallback: hostUid),
          );
          final hostPhoto = _string(data['hostPhotoUrl']);
          final viewers = _asInt(data['viewers']);
          final roomExp = LiveService.roomExpFromRoomData(data);
          final hostSvipTier = _activeHostSvipTier(data);

          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: LiveService.instance.watchPartyRoom(widget.roomId),
            builder: (context, partySnapshot) {
              final partyData =
                  partySnapshot.data?.data() ?? <String, dynamic>{};
              final backgroundTheme = _string(
                partyData['backgroundTheme'],
                fallback: 'royal',
              );
              return Stack(
                fit: StackFit.expand,
                children: [
                  _AudioPartyBackground(theme: backgroundTheme),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.12),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.78),
                        ],
                      ),
                    ),
                  ),
                  SafeArea(
                    child: Column(
                      children: [
                        _topBar(
                          hostName: hostName,
                          hostId: hostId,
                          hostUid: hostUid,
                          hostPhoto: hostPhoto,
                          viewers: viewers,
                          roomLevel: roomExp.level,
                          svipTier: hostSvipTier,
                        ),
                        const SizedBox(height: 8),
                        _statsRow(roomExp: roomExp),
                        const SizedBox(height: 8),
                        _partyBadges(),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final seatHeight = keyboardOpen
                                  ? (constraints.maxHeight * 0.48)
                                        .clamp(132.0, 220.0)
                                        .toDouble()
                                  : (constraints.maxHeight * 0.58)
                                        .clamp(300.0, 390.0)
                                        .toDouble();
                              return Column(
                                children: [
                                  SizedBox(
                                    height: seatHeight,
                                    child: Stack(
                                      children: [
                                        _stageSeats(seats: _normalizedSeats()),
                                        if (widget.isHost)
                                          _requestBanner(_seats),
                                      ],
                                    ),
                                  ),
                                  Expanded(child: _chatView()),
                                ],
                              );
                            },
                          ),
                        ),
                        _bottomControls(),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _topBar({
    required String hostName,
    required String hostId,
    required String hostUid,
    required String hostPhoto,
    required int viewers,
    required int roomLevel,
    required int svipTier,
  }) {
    final vipAccent = _roomLevelAccent(roomLevel);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 12, 0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 50,
              padding: const EdgeInsets.fromLTRB(5, 4, 6, 4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3A220D), Color(0xFF171018)],
                ),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFFE5B85D), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE9B657).withValues(alpha: 0.28),
                    blurRadius: 14,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _avatar(hostPhoto, 18, borderColor: vipAccent),
                      Positioned(
                        right: -5,
                        bottom: -6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [vipAccent, const Color(0xFFFF3F8B)],
                            ),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: Colors.white, width: 0.8),
                          ),
                          child: Text(
                            'Lv.$roomLevel',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hostName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                hostId.isEmpty
                                    ? 'Audio party host'
                                    : 'ID $hostId',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFFD8C7A1),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (svipTier > 0) ...[
                              const SizedBox(width: 4),
                              SvipBadge(tier: svipTier, compact: true),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  _followHostButton(hostUid),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          _topIcon(
            Icons.people_alt_rounded,
            '$viewers',
            onTap: _openAudienceSheet,
          ),
          _topIcon(Icons.card_giftcard_rounded, null, onTap: _openGiftSheet),
          _topIcon(Icons.near_me_rounded, null, onTap: _openLiveShareSheet),
          GestureDetector(
            onTap: () => Navigator.maybePop(context),
            child: const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(Icons.close_rounded, color: Colors.white, size: 30),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statsRow({required RoomExpState roomExp}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Flexible(
            flex: 5,
            child: _statChip(
              label: 'REXP',
              value: roomExp.chipText,
              colors: const [Color(0xFF103F46), Color(0xFF17212E)],
              icon: Icons.bolt_rounded,
              onTap: _openRoomExpPage,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            flex: 6,
            child: _statChip(
              label: 'Rankings',
              value: '',
              colors: const [Color(0xFF7D2C9D), Color(0xFF3C1E65)],
              icon: Icons.public_rounded,
              onTap: _openWorldRankingsSheet,
            ),
          ),
        ],
      ),
    );
  }

  Widget _followHostButton(String hostUid) {
    if (hostUid.isEmpty || hostUid == _uid) return const SizedBox.shrink();
    return StreamBuilder<bool>(
      stream: LiveService.instance.watchIsFollowing(hostUid),
      builder: (context, snapshot) {
        final following = snapshot.data ?? false;
        return GestureDetector(
          onTap: () => unawaited(_toggleHostFollow(hostUid, following)),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: following ? Colors.white24 : const Color(0xFFFF3F8B),
              border: following ? Border.all(color: Colors.white30) : null,
            ),
            child: Icon(
              following ? Icons.check_rounded : Icons.add,
              color: Colors.white,
              size: 24,
            ),
          ),
        );
      },
    );
  }

  Future<void> _toggleHostFollow(String hostUid, bool following) async {
    try {
      await LiveService.instance.setFollowing(hostUid, follow: !following);
      _toast(following ? 'Unfollowed host' : 'Following host');
    } catch (error) {
      _toast(error.toString());
    }
  }

  Widget _partyBadges() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _miniReward(Icons.emoji_events_rounded, '0/140'),
          const SizedBox(width: 18),
          _miniReward(Icons.local_fire_department_rounded, '2d'),
          const Spacer(),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.26),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.chevron_left_rounded,
              color: Colors.white70,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stageSeats({required List<PartySeatState> seats}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final seatWidth = width / 4;
        return Align(
          alignment: Alignment.topCenter,
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.only(top: 4),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              childAspectRatio: seatWidth / 104,
            ),
            itemCount: seats.length,
            itemBuilder: (context, index) => _seat(seats[index], index),
          ),
        );
      },
    );
  }

  Widget _seat(PartySeatState seat, int index) {
    final empty = seat.status == PartySeatStatus.empty;
    final requesting = seat.status == PartySeatStatus.requesting;
    final occupied = seat.status == PartySeatStatus.occupied;
    final ownedByMe = seat.userId == _uid && _uid.isNotEmpty;
    final label = occupied || requesting
        ? (seat.userName.isEmpty ? 'Speaker' : seat.userName)
        : 'NO. ${index + 1}';
    final accent = index % 3 == 0
        ? const Color(0xFFFF4D8D)
        : index % 3 == 1
        ? const Color(0xFF6AD7FF)
        : const Color(0xFFFFD36B);
    return GestureDetector(
      onTap: () => _onSeatTap(seat),
      onLongPress: widget.isHost && occupied
          ? () => _showHostSeatMenu(seat)
          : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    colors: [
                      seat.isLocked ? Colors.grey : accent,
                      Colors.white,
                      seat.isLocked ? Colors.grey : accent,
                      const Color(0xFF6A2BFF),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: ownedByMe ? 0.55 : 0.35),
                      blurRadius: ownedByMe ? 22 : 16,
                    ),
                  ],
                ),
              ),
              _avatar(seat.userPhotoUrl, 25, borderColor: Colors.black),
              if (empty)
                Icon(
                  seat.isLocked ? Icons.lock_rounded : Icons.person_rounded,
                  color: Colors.white70,
                  size: 24,
                ),
              if (requesting)
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.46),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.hourglass_top_rounded,
                    color: Color(0xFFFFD36B),
                    size: 22,
                  ),
                ),
              if (seat.isMuted || requesting)
                Positioned(
                  right: -4,
                  bottom: 0,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF3F8B),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      requesting ? Icons.more_horiz_rounded : Icons.mic_off,
                      color: Colors.white,
                      size: 15,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              shadows: [Shadow(color: Colors.black, blurRadius: 6)],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.star_rounded,
                color: Color(0xFFFF4D8D),
                size: 12,
              ),
              _seatStarText(seat),
            ],
          ),
        ],
      ),
    );
  }

  Widget _seatStarText(PartySeatState seat) {
    if (!seat.isOccupied || seat.userId.isEmpty) {
      return const Text(
        '0',
        style: TextStyle(
          color: Colors.white70,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      );
    }

    return StreamBuilder<int>(
      stream: LiveService.instance.watchRoomUserGiftStars(
        widget.roomId,
        seat.userId,
      ),
      builder: (context, snapshot) {
        return Text(
          '${snapshot.data ?? 0}',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        );
      },
    );
  }

  List<PartySeatState> _normalizedSeats() {
    final byIndex = {for (final seat in _seats) seat.index: seat};
    return List.generate(
      12,
      (index) =>
          byIndex[index] ??
          PartySeatState(
            index: index,
            userId: '',
            userName: '',
            userPhotoUrl: '',
            isLocked: false,
            isMuted: false,
            status: PartySeatStatus.empty,
            updatedAt: null,
          ),
    );
  }

  Future<void> _syncAgoraRole(List<PartySeatState> seats) async {
    if (!_audioJoined || _uid.isEmpty) return;
    PartySeatState? ownSeat;
    for (final seat in seats) {
      if (seat.userId == _uid && seat.isOccupied) {
        ownSeat = seat;
        break;
      }
    }

    final shouldBroadcast = ownSeat != null;
    final seatIndex = ownSeat?.index;
    final muted = ownSeat?.isMuted ?? true;
    if (_lastSyncedBroadcaster == shouldBroadcast &&
        _lastSyncedSeatIndex == seatIndex &&
        _lastSyncedMuted == muted) {
      return;
    }

    _lastSyncedBroadcaster = shouldBroadcast;
    _lastSyncedSeatIndex = seatIndex;
    _lastSyncedMuted = muted;
    _mySeatIndex = seatIndex;
    try {
      await _agora.setAudioBroadcaster(enabled: shouldBroadcast, muted: muted);
      if (mounted) setState(() => _micMuted = _agora.micMuted);
    } catch (error) {
      if (mounted) _toast(error.toString());
    }
  }

  Future<void> _onSeatTap(PartySeatState seat) async {
    try {
      if (seat.isLocked) {
        _toast('Seat is locked');
        return;
      }
      if (seat.isRequesting) {
        if (widget.isHost) {
          _showSeatRequestActions(seat);
        } else if (seat.userId == _uid) {
          _toast('Request sent. Waiting for host approval.');
        } else {
          _toast('Someone already requested this seat.');
        }
        return;
      }
      if (seat.isOccupied) {
        if (seat.userId == _uid) {
          _showMySeatActions(seat);
        } else if (widget.isHost) {
          _showHostSeatMenu(seat);
        } else {
          _toast('Seat already occupied');
        }
        return;
      }

      final existingSeat = await LiveService.instance.currentPartySeatForUser(
        widget.roomId,
      );
      if (existingSeat != null && existingSeat.index != seat.index) {
        _toast('You are already seated on another seat.');
        return;
      }
      await LiveService.instance.requestPartySeat(widget.roomId, seat.index);
      if (widget.isHost) {
        await LiveService.instance.acceptPartySeat(widget.roomId, seat.index);
      } else {
        _toast('Request sent to host');
      }
    } catch (error) {
      _toast(error.toString());
    }
  }

  void _showSeatRequestActions(PartySeatState seat) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF101018),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${seat.userName.isEmpty ? 'User' : seat.userName} wants to join seat ${seat.index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          await LiveService.instance.acceptPartySeat(
                            widget.roomId,
                            seat.index,
                          );
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFFF3F8B),
                        ),
                        child: const Text('Accept'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          await LiveService.instance.rejectPartySeat(
                            widget.roomId,
                            seat.index,
                          );
                        },
                        child: const Text('Reject'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showMySeatActions(PartySeatState seat) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF101018),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(
                    seat.isMuted ? Icons.mic_rounded : Icons.mic_off_rounded,
                    color: Colors.white,
                  ),
                  title: Text(
                    seat.isMuted ? 'Unmute mic' : 'Mute mic',
                    style: const TextStyle(color: Colors.white),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    await _toggleMic();
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.event_seat_rounded,
                    color: Colors.white,
                  ),
                  title: const Text(
                    'Leave seat',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    await LiveService.instance.leavePartySeat(
                      widget.roomId,
                      seat.index,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showHostSeatMenu(PartySeatState seat) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF101018),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(
                    seat.isMuted ? Icons.mic_rounded : Icons.mic_off_rounded,
                    color: Colors.white,
                  ),
                  title: Text(
                    seat.isMuted ? 'Unmute speaker' : 'Mute speaker',
                    style: const TextStyle(color: Colors.white),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    await LiveService.instance.updatePartySeatMute(
                      widget.roomId,
                      seat.index,
                      isMuted: !seat.isMuted,
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.remove_circle_outline,
                    color: Colors.white,
                  ),
                  title: const Text(
                    'Remove from seat',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    await LiveService.instance.leavePartySeat(
                      widget.roomId,
                      seat.index,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _requestBanner(List<PartySeatState> seats) {
    final requests = seats.where((seat) => seat.isRequesting).toList();
    if (requests.isEmpty) return const SizedBox.shrink();
    final request = requests.first;
    return Positioned(
      left: 16,
      right: 16,
      top: 4,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.62),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFFF3F8B)),
        ),
        child: Row(
          children: [
            _avatar(
              request.userPhotoUrl,
              16,
              borderColor: const Color(0xFFFF3F8B),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${request.userName.isEmpty ? 'User' : request.userName} requested seat ${request.index + 1}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            TextButton(
              onPressed: () => LiveService.instance.acceptPartySeat(
                widget.roomId,
                request.index,
              ),
              child: const Text('Accept'),
            ),
            TextButton(
              onPressed: () => LiveService.instance.rejectPartySeat(
                widget.roomId,
                request.index,
              ),
              child: const Text('Reject'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chatView() {
    return StreamBuilder<List<PartyChatMessage>>(
      stream: LiveService.instance.watchPartyChats(widget.roomId),
      builder: (context, snapshot) {
        final messages = snapshot.data ?? const <PartyChatMessage>[];
        if (messages.isEmpty) {
          return const Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: EdgeInsets.fromLTRB(22, 0, 22, 14),
              child: Text(
                'Say hello to start the party chat.',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
        }
        return ListView.builder(
          reverse: true,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
          itemCount: messages.length,
          itemBuilder: (context, index) => _chatBubble(messages[index]),
        );
      },
    );
  }

  Widget _chatBubble(PartyChatMessage message) {
    final mine = message.senderId == _uid && _uid.isNotEmpty;
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.fromLTRB(11, 8, 12, 9),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: message.svipTier > 0
                  ? const [Color(0xCC0F7A45), Color(0xAA36B76B)]
                  : [
                      mine
                          ? const Color(0xFFFF3F8B).withValues(alpha: 0.34)
                          : Colors.black.withValues(alpha: 0.38),
                      Colors.black.withValues(alpha: 0.24),
                    ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: message.svipTier > 0
                  ? const Color(0xFFFFD76A).withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.08),
            ),
            boxShadow: [
              if (message.svipTier > 0)
                BoxShadow(
                  color: const Color(0xFF2EEA83).withValues(alpha: 0.24),
                  blurRadius: 14,
                ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (message.svipTier > 0)
                    SvipBadge(tier: message.svipTier, compact: true),
                  Text(
                    message.username,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      shadows: [Shadow(color: Colors.black, blurRadius: 5)],
                    ),
                  ),
                  if (message.profileId.isNotEmpty)
                    Text(
                      'ID ${message.profileId}',
                      style: const TextStyle(
                        color: Color(0xFFD7F2FF),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  _miniChatPill('Lv.${message.userLevel}'),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                message.messageText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                  shadows: [Shadow(color: Colors.black, blurRadius: 5)],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniChatPill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7E6BFF), Color(0xFFFF4D8D)],
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _bottomControls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              style: const TextStyle(color: Colors.white),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => unawaited(_sendPartyChat()),
              decoration: InputDecoration(
                hintText: "Let's talk",
                hintStyle: const TextStyle(color: Colors.white70, fontSize: 18),
                filled: true,
                fillColor: Colors.black.withValues(alpha: 0.18),
                suffixIcon: IconButton(
                  onPressed: () => unawaited(_sendPartyChat()),
                  icon: const Icon(
                    Icons.send_rounded,
                    color: Color(0xFFFFD36B),
                    size: 22,
                  ),
                ),
                border: OutlineInputBorder(
                  borderSide: BorderSide.none,
                  borderRadius: BorderRadius.circular(999),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _bottomIcon(
            _micMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
            active: !_micMuted,
            onTap: _toggleMic,
          ),
          _bottomIcon(Icons.people_outline_rounded, onTap: _openSpeakersSheet),
          _bottomIcon(Icons.menu_rounded, onTap: _openRoomSettings),
          _bottomIcon(
            Icons.card_giftcard_rounded,
            gift: true,
            onTap: _openGiftSheet,
          ),
        ],
      ),
    );
  }

  Future<void> _sendPartyChat() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    _messageController.clear();
    try {
      await LiveService.instance.sendPartyMessage(widget.roomId, text);
    } catch (error) {
      _messageController.text = text;
      _toast(error.toString());
    }
  }

  Future<void> _toggleMic() async {
    final seatIndex = _mySeatIndex;
    if (seatIndex == null) {
      _toast('Take a seat first to speak.');
      return;
    }
    final seat = _normalizedSeats().firstWhere(
      (item) => item.index == seatIndex,
    );
    final nextMuted = !seat.isMuted;
    try {
      await LiveService.instance.updatePartySeatMute(
        widget.roomId,
        seatIndex,
        isMuted: nextMuted,
      );
      await _agora.setLocalAudioMuted(nextMuted);
      if (mounted) setState(() => _micMuted = nextMuted);
    } catch (error) {
      _toast(error.toString());
    }
  }

  void _openRoomExpPage() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => RoomExpPage(roomId: widget.roomId),
      ),
    );
  }

  void _openAudienceSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF171326),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return DefaultTabController(
          length: 2,
          child: SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.72,
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 46,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const TabBar(
                    indicatorColor: Color(0xFFFF4D8D),
                    labelColor: Color(0xFFFF4D8D),
                    unselectedLabelColor: Colors.white54,
                    labelStyle: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                    tabs: [
                      Tab(text: 'Audience'),
                      Tab(text: 'Total leaderboard'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [_audienceList(), _totalLeaderboardList()],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _audienceList() {
    return StreamBuilder<List<RoomAudienceEntry>>(
      stream: LiveService.instance.watchRoomAudience(widget.roomId),
      builder: (context, snapshot) {
        final users = snapshot.data ?? const <RoomAudienceEntry>[];
        if (users.isEmpty) return _emptySheetText('No audience yet');
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            return _leaderTile(
              rank: index + 1,
              name: user.name,
              photoUrl: user.photoUrl,
              userLevel: user.userLevel,
              primaryStars: user.currentGiftStars,
              secondaryText: 'Total ${user.totalGiftStars} stars',
            );
          },
        );
      },
    );
  }

  Widget _totalLeaderboardList() {
    return StreamBuilder<List<TotalGiftLeaderboardEntry>>(
      stream: LiveService.instance.watchTotalGiftLeaderboard(limit: 100),
      builder: (context, snapshot) {
        final users = snapshot.data ?? const <TotalGiftLeaderboardEntry>[];
        if (users.isEmpty) return _emptySheetText('No leaderboard yet');
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            return _leaderTile(
              rank: index + 1,
              name: user.name,
              photoUrl: user.photoUrl,
              userLevel: user.userLevel,
              primaryStars: user.totalGiftedStars,
              secondaryText: 'All-time gifts',
            );
          },
        );
      },
    );
  }

  void _openWorldRankingsSheet() {
    var selectedPeriod = WorldRankingPeriod.hourly;
    var showRegionRankings = true;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Container(
                height: MediaQuery.sizeOf(context).height * 0.72,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF171023),
                      Color(0xFF08080D),
                      Color(0xFF000000),
                    ],
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 46,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: _rankingScopeTab(
                              'Region Rankings',
                              showRegionRankings,
                              () => setSheetState(
                                () => showRegionRankings = true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: _rankingScopeTab(
                              'World Rankings',
                              !showRegionRankings,
                              () => setSheetState(
                                () => showRegionRankings = false,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white12),
                            ),
                            child: const Icon(
                              Icons.help_outline_rounded,
                              color: Colors.white70,
                              size: 22,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                      child: Row(
                        children: WorldRankingPeriod.values.map((period) {
                          final active = selectedPeriod == period;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: GestureDetector(
                                onTap: () => setSheetState(
                                  () => selectedPeriod = period,
                                ),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  height: 42,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: active
                                        ? const Color(0xFFFFE2EE)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: active
                                          ? Colors.transparent
                                          : Colors.white.withValues(
                                              alpha: 0.10,
                                            ),
                                    ),
                                  ),
                                  child: Text(
                                    _worldPeriodLabel(period),
                                    style: TextStyle(
                                      color: active
                                          ? const Color(0xFFFF3F8B)
                                          : Colors.white70,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: StreamBuilder<int>(
                          stream: Stream<int>.periodic(
                            const Duration(seconds: 30),
                            (tick) => tick,
                          ),
                          builder: (context, _) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFE2EE),
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFFFF3F8B,
                                    ).withValues(alpha: 0.22),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.access_time_filled_rounded,
                                    color: Color(0xFFFF3F8B),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'UTC+5:30  ${_worldPeriodCountdown(selectedPeriod)}',
                                    style: const TextStyle(
                                      color: Color(0xFFFF3F8B),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF39FF88),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Text(
                                    'LIVE',
                                    style: TextStyle(
                                      color: Color(0xFFFF3F8B),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    Expanded(
                      child: _worldRankingList(
                        selectedPeriod,
                        regionMode: showRegionRankings,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _rankingScopeTab(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: active ? Colors.white : Colors.white54,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: active ? 32 : 0,
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

  Widget _worldRankingList(
    WorldRankingPeriod period, {
    required bool regionMode,
  }) {
    return StreamBuilder<List<WorldRankingEntry>>(
      stream: LiveService.instance.watchWorldGiftRankings(
        period,
        limit: 100,
        regionMode: regionMode,
      ),
      builder: (context, snapshot) {
        final entries = snapshot.data ?? const <WorldRankingEntry>[];
        if (entries.isEmpty) {
          return const Center(
            child: Text(
              'No ranking yet',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
          itemCount: entries.length,
          itemBuilder: (context, index) {
            final entry = entries[index];
            return _worldRankingTile(
              entry: entry,
              rank: index + 1,
              regionMode: regionMode,
            );
          },
        );
      },
    );
  }

  Widget _worldRankingTile({
    required WorldRankingEntry entry,
    required int rank,
    required bool regionMode,
  }) {
    final rankColor = switch (rank) {
      1 => const Color(0xFFFFA72E),
      2 => const Color(0xFF96A7D8),
      3 => const Color(0xFFD28A52),
      _ => Colors.white60,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 42,
            child: Text(
              'Top$rank',
              style: TextStyle(
                color: rankColor,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          _avatar(entry.photoUrl, 24, borderColor: rankColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${regionMode ? 'Region' : 'World'} ID ${_compactProfileId(entry.profileId)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 5,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (entry.svipTier > 0)
                      SvipBadge(tier: entry.svipTier, compact: true),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8D5CFF).withValues(alpha: 0.24),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Lv.${entry.userLevel}',
                        style: const TextStyle(
                          color: Color(0xFF8D5CFF),
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.star_rounded, color: Color(0xFFFFC43D), size: 19),
          const SizedBox(width: 4),
          Text(
            entry.stars.toString(),
            style: const TextStyle(
              color: Color(0xFFFFA72E),
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  String _worldPeriodLabel(WorldRankingPeriod period) {
    return switch (period) {
      WorldRankingPeriod.hourly => 'Hourly',
      WorldRankingPeriod.daily => 'Daily',
      WorldRankingPeriod.weekly => 'Weekly',
    };
  }

  String _worldPeriodCountdown(WorldRankingPeriod period) {
    final now = DateTime.now();
    final end = switch (period) {
      WorldRankingPeriod.hourly => DateTime(
        now.year,
        now.month,
        now.day,
        now.hour + 1,
      ),
      WorldRankingPeriod.daily => DateTime(now.year, now.month, now.day + 1),
      WorldRankingPeriod.weekly => DateTime(
        now.year,
        now.month,
        now.day + (8 - now.weekday),
      ),
    };
    final left = end.difference(now);
    final days = left.inDays;
    final hours = left.inHours.remainder(24);
    final minutes = left.inMinutes.remainder(60);
    if (period == WorldRankingPeriod.hourly) return '$minutes min';
    return '$days d : $hours h : $minutes min';
  }

  Widget _leaderTile({
    required int rank,
    required String name,
    required String photoUrl,
    required int userLevel,
    required int primaryStars,
    required String secondaryText,
  }) {
    final rankColor = switch (rank) {
      1 => const Color(0xFFFFD36B),
      2 => const Color(0xFFC9E4FF),
      3 => const Color(0xFFFFB082),
      _ => Colors.white54,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Text(
              rank <= 3 ? 'Top$rank' : '$rank',
              style: TextStyle(
                color: rankColor,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          _avatar(photoUrl, 22, borderColor: rankColor),
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
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  secondaryText,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8D5CFF).withValues(alpha: 0.24),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Lv.$userLevel',
                    style: const TextStyle(
                      color: Color(0xFFB69BFF),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.star_rounded, color: Color(0xFFFFD36B), size: 18),
          const SizedBox(width: 4),
          Text(
            primaryStars.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptySheetText(String text) {
    return Center(
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  void _openLiveShareSheet() {
    final shareText = 'Join my Likeehit audio party: ${widget.roomId}';
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF101018),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Live share',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  shareText,
                  style: const TextStyle(color: Colors.white70, fontSize: 15),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () async {
                          final modalNavigator = Navigator.of(context);
                          await Clipboard.setData(
                            ClipboardData(text: shareText),
                          );
                          if (!mounted) return;
                          modalNavigator.pop();
                          _toast('Live room copied');
                        },
                        icon: const Icon(Icons.copy_rounded),
                        label: const Text('Copy invite'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _toast('Share invite ready');
                        },
                        icon: const Icon(Icons.near_me_rounded),
                        label: const Text('Share'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openGiftSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF101018),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.72,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(18, 16, 18, 0),
                  child: Text(
                    'Star Gifts',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 18),
                  child: Text(
                    'Live room gifts are available in party too.',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
                    itemCount: _giftCatalog.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 0.86,
                        ),
                    itemBuilder: (context, index) {
                      final gift = _giftCatalog[index];
                      return GestureDetector(
                        onTap: () async {
                          Navigator.pop(context);
                          try {
                            await LiveService.instance.sendGiftEvent(
                              widget.roomId,
                              giftName: gift.name,
                              stars: gift.stars,
                              quantity: 1,
                            );
                            _toast('Sent ${gift.name}');
                          } catch (error) {
                            _toast(error.toString());
                          }
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                gift.icon,
                                color: const Color(0xFFFF4D8D),
                                size: 34,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                gift.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                '${gift.$3}★',
                                style: const TextStyle(
                                  color: Color(0xFFFFD36B),
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
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
    );
  }

  void _openRoomSettings() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF101018),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.76,
            ),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
              children: [
                const ListTile(
                  leading: Icon(Icons.settings_rounded, color: Colors.white),
                  title: Text(
                    'Room settings',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  subtitle: Text(
                    'Seat requests, mic control and party tools are live.',
                    style: TextStyle(color: Colors.white60),
                  ),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.event_seat_rounded,
                    color: Colors.white,
                  ),
                  title: Text(
                    '${_seats.where((seat) => seat.isOccupied).length} speakers seated',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.pending_actions_rounded,
                    color: Colors.white,
                  ),
                  title: Text(
                    '${_seats.where((seat) => seat.isRequesting).length} pending requests',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                ListTile(
                  onTap: () {
                    Navigator.pop(context);
                    _openBackgroundEffectsSheet();
                  },
                  leading: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Color(0xFFFFD36B),
                  ),
                  title: const Text(
                    '3D background effects',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  subtitle: const Text(
                    'Premium room stage, synced for everyone.',
                    style: TextStyle(color: Colors.white60),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white54,
                  ),
                ),
                if (widget.isHost) ...[
                  ListTile(
                    onTap: () {
                      Navigator.pop(context);
                      _openBlockedUsersSheet();
                    },
                    leading: const Icon(
                      Icons.block_rounded,
                      color: Color(0xFFFF5B77),
                    ),
                    title: const Text(
                      'Block list users',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    subtitle: const Text(
                      'Block users or unblock from the room list.',
                      style: TextStyle(color: Colors.white60),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white54,
                    ),
                  ),
                  ListTile(
                    onTap: () {
                      Navigator.pop(context);
                      _openChatDisabledUsersSheet();
                    },
                    leading: const Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: Color(0xFFFFD36B),
                    ),
                    title: const Text(
                      'Users chat disable list',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    subtitle: const Text(
                      'Disable chat for selected users or enable again.',
                      style: TextStyle(color: Colors.white60),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white54,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _openBlockedUsersSheet() {
    _openModerationUsersSheet(
      title: 'Block users',
      activeTitle: 'Audience',
      listTitle: 'Blocked users',
      emptyListText: 'No blocked users',
      stream: LiveService.instance.watchPartyBlockedUsers(widget.roomId),
      actionLabel: 'Block',
      undoLabel: 'Unblock',
      actionColor: const Color(0xFFFF5B77),
      onAction: LiveService.instance.blockPartyUser,
      onUndo: LiveService.instance.unblockPartyUser,
    );
  }

  void _openChatDisabledUsersSheet() {
    _openModerationUsersSheet(
      title: 'Chat disable',
      activeTitle: 'Audience',
      listTitle: 'Chat disabled users',
      emptyListText: 'No chat disabled users',
      stream: LiveService.instance.watchPartyChatDisabledUsers(widget.roomId),
      actionLabel: 'Disable',
      undoLabel: 'Enable',
      actionColor: const Color(0xFFFFD36B),
      onAction: LiveService.instance.disablePartyUserChat,
      onUndo: LiveService.instance.enablePartyUserChat,
    );
  }

  void _openModerationUsersSheet({
    required String title,
    required String activeTitle,
    required String listTitle,
    required String emptyListText,
    required Stream<List<PartyModerationUser>> stream,
    required String actionLabel,
    required String undoLabel,
    required Color actionColor,
    required Future<void> Function(String roomId, String uid) onAction,
    required Future<void> Function(String roomId, String uid) onUndo,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF101018),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.72,
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 46,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TabBar(
                    indicatorColor: actionColor,
                    labelColor: actionColor,
                    unselectedLabelColor: Colors.white54,
                    labelStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                    tabs: [
                      Tab(text: activeTitle),
                      Tab(text: listTitle),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _moderationAudienceList(
                          actionLabel: actionLabel,
                          actionColor: actionColor,
                          onAction: onAction,
                        ),
                        _moderationAppliedList(
                          emptyText: emptyListText,
                          stream: stream,
                          actionLabel: undoLabel,
                          actionColor: actionColor,
                          onAction: onUndo,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _moderationAudienceList({
    required String actionLabel,
    required Color actionColor,
    required Future<void> Function(String roomId, String uid) onAction,
  }) {
    return StreamBuilder<List<RoomAudienceEntry>>(
      stream: LiveService.instance.watchRoomAudience(widget.roomId),
      builder: (context, snapshot) {
        final users =
            snapshot.data?.where((user) => user.uid != _uid).toList() ??
            const <RoomAudienceEntry>[];
        if (users.isEmpty) return _emptySheetText('No audience users');
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            return _moderationUserTile(
              name: user.name,
              photoUrl: user.photoUrl,
              userLevel: user.userLevel,
              actionLabel: actionLabel,
              actionColor: actionColor,
              onTap: () => unawaited(
                _runModerationAction(user.uid, actionLabel, onAction),
              ),
            );
          },
        );
      },
    );
  }

  Widget _moderationAppliedList({
    required String emptyText,
    required Stream<List<PartyModerationUser>> stream,
    required String actionLabel,
    required Color actionColor,
    required Future<void> Function(String roomId, String uid) onAction,
  }) {
    return StreamBuilder<List<PartyModerationUser>>(
      stream: stream,
      builder: (context, snapshot) {
        final users = snapshot.data ?? const <PartyModerationUser>[];
        if (users.isEmpty) return _emptySheetText(emptyText);
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            return _moderationUserTile(
              name: user.name,
              photoUrl: user.photoUrl,
              userLevel: user.userLevel,
              actionLabel: actionLabel,
              actionColor: actionColor,
              onTap: () => unawaited(
                _runModerationAction(user.uid, actionLabel, onAction),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _runModerationAction(
    String uid,
    String actionLabel,
    Future<void> Function(String roomId, String uid) action,
  ) async {
    try {
      await action(widget.roomId, uid);
      _toast('$actionLabel updated');
    } catch (error) {
      _toast(error.toString());
    }
  }

  Widget _moderationUserTile({
    required String name,
    required String photoUrl,
    required int userLevel,
    required String actionLabel,
    required Color actionColor,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          _avatar(photoUrl, 22, borderColor: actionColor),
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
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Lv.$userLevel',
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(foregroundColor: actionColor),
            child: Text(
              actionLabel,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  void _openBackgroundEffectsSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0D0B14),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: LiveService.instance.watchPartyRoom(widget.roomId),
          builder: (context, snapshot) {
            final selected = _string(
              snapshot.data?.data()?['backgroundTheme'],
              fallback: 'royal',
            );
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            '3D Background Effects',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: widget.isHost
                              ? () => unawaited(_selectBackgroundTheme('royal'))
                              : null,
                          child: const Text('Reset'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Host changes are realtime for all speakers and listeners.',
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: MediaQuery.sizeOf(context).height * 0.58,
                      child: GridView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: _partyBackgroundPresets.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 0.78,
                            ),
                        itemBuilder: (context, index) {
                          final preset = _partyBackgroundPresets[index];
                          final active = selected == preset.id;
                          return _backgroundPresetCard(
                            preset,
                            active: active,
                            locked: false,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _backgroundPresetCard(
    _PartyBackgroundPreset preset, {
    required bool active,
    required bool locked,
  }) {
    return GestureDetector(
      onTap: () {
        if (!widget.isHost) {
          _toast('Only host can change background effects.');
          return;
        }
        if (locked) {
          _toast('Unlocks at room level ${preset.requiredLevel}.');
          return;
        }
        unawaited(_selectBackgroundTheme(preset.id));
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: active ? const Color(0xFFFFD36B) : Colors.white12,
            width: active ? 2 : 1,
          ),
          boxShadow: [
            if (active)
              BoxShadow(
                color: preset.accent.withValues(alpha: 0.38),
                blurRadius: 20,
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(17),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _MiniBackgroundPreview(theme: preset.id),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.04),
                      Colors.black.withValues(alpha: 0.68),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 28,
                right: 28,
                child: Container(
                  height: 26,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Color(0xFF9C2D64),
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Lv${preset.requiredLevel}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        preset.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          shadows: [Shadow(color: Colors.black, blurRadius: 6)],
                        ),
                      ),
                    ),
                    Icon(
                      locked
                          ? Icons.lock_rounded
                          : active
                          ? Icons.check_circle_rounded
                          : Icons.auto_awesome_rounded,
                      color: locked
                          ? Colors.white70
                          : active
                          ? const Color(0xFFFFD36B)
                          : Colors.white,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectBackgroundTheme(String theme) async {
    try {
      await LiveService.instance.updatePartyBackgroundTheme(
        widget.roomId,
        theme: theme,
      );
      _toast('Background updated');
    } catch (error) {
      _toast(error.toString());
    }
  }

  void _openSpeakersSheet() {
    final seats = _normalizedSeats().where((seat) => seat.isOccupied).toList();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF101018),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
            children: [
              const Text(
                'Speakers',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              if (seats.isEmpty)
                const Text(
                  'No speakers on seat yet.',
                  style: TextStyle(color: Colors.white60),
                )
              else
                ...seats.map(
                  (seat) => ListTile(
                    leading: _avatar(
                      seat.userPhotoUrl,
                      18,
                      borderColor: const Color(0xFFFF3F8B),
                    ),
                    title: Text(
                      seat.userName,
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      seat.isMuted ? 'Muted' : 'Speaking enabled',
                      style: const TextStyle(color: Colors.white60),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF22202A),
      ),
    );
  }

  Widget _avatar(String photoUrl, double radius, {required Color borderColor}) {
    return Container(
      padding: const EdgeInsets.all(1.4),
      decoration: BoxDecoration(color: borderColor, shape: BoxShape.circle),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: const Color(0xFF15151D),
        backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
        child: photoUrl.isEmpty
            ? const Icon(Icons.person, color: Colors.white70, size: 18)
            : null,
      ),
    );
  }

  Color _roomLevelAccent(int level) {
    if (level >= 40) return const Color(0xFFFFD36B);
    if (level >= 25) return const Color(0xFFFF8B36);
    if (level >= 10) return const Color(0xFFC47BFF);
    if (level >= 4) return const Color(0xFF62C7FF);
    return const Color(0xFF77F2CC);
  }

  Widget _topIcon(IconData icon, String? label, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 22),
            if (label != null) ...[
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statChip({
    required String label,
    required String value,
    required List<Color> colors,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 31,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFFFFD84E), size: 17),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF93F5FF),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (value.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _miniReward(IconData icon, String text) {
    return Column(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFA132), Color(0xFFFF4D8D)],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF4D8D).withValues(alpha: 0.24),
                blurRadius: 12,
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        const SizedBox(height: 2),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _bottomIcon(
    IconData icon, {
    bool active = true,
    String? badge,
    bool gift = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: gift
                    ? const LinearGradient(
                        colors: [Color(0xFFFF3F8B), Color(0xFFFFB13B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: gift ? null : Colors.black.withValues(alpha: 0.24),
              ),
              child: Icon(
                icon,
                color: active ? Colors.white : Colors.white54,
                size: 25,
              ),
            ),
            if (badge != null)
              Positioned(
                right: -2,
                top: -6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF3F8B),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static int _activeHostSvipTier(Map<String, dynamic> data) {
    final until = data['hostSvipUntil'];
    if (until is Timestamp && !until.toDate().isAfter(DateTime.now())) {
      return 0;
    }
    return _asInt(data['hostSvipTier']).clamp(0, 3);
  }

  static String _string(dynamic value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  static String _compactProfileId(String value) {
    final id = value.trim();
    if (id.length <= 12) return id;
    return '${id.substring(0, 6)}...${id.substring(id.length - 4)}';
  }
}

class _PartyGiftItem {
  const _PartyGiftItem({
    required this.name,
    required this.stars,
    required this.icon,
    required this.tab,
  });

  final String name;
  final int stars;
  final IconData icon;
  final _PartyGiftTab tab;

  int get $3 => stars;
}

List<_PartyGiftItem> _buildPartyGiftCatalog() {
  const values = <int>[
    1,
    2,
    3,
    4,
    5,
    6,
    8,
    10,
    12,
    15,
    18,
    20,
    25,
    30,
    35,
    40,
    45,
    50,
    55,
    60,
    65,
    70,
    75,
    80,
    85,
    90,
    95,
    100,
    105,
    110,
    115,
    120,
    125,
    130,
    135,
    140,
    150,
    160,
    170,
    180,
    190,
    200,
    225,
    250,
    275,
    300,
    325,
    350,
    375,
    400,
    450,
    500,
    550,
    600,
    650,
    700,
    750,
    800,
    900,
    1000,
    1100,
    1200,
    1300,
    1400,
    1500,
    1600,
    1700,
    1800,
    1900,
    2000,
    2250,
    2500,
    2750,
    3000,
    3500,
    4000,
    4500,
    5000,
    5500,
    6000,
    6500,
    7000,
    7500,
    8000,
    9000,
    10000,
    12000,
    15000,
    18000,
    20000,
    25000,
    30000,
    35000,
    40000,
    50000,
    60000,
    70000,
    80000,
    90000,
    100000,
  ];

  const icons = <IconData>[
    Icons.star_rounded,
    Icons.auto_awesome,
    Icons.diamond_rounded,
    Icons.favorite,
    Icons.rocket_launch,
    Icons.workspace_premium,
    Icons.emoji_events,
    Icons.local_fire_department,
  ];

  return List<_PartyGiftItem>.generate(values.length, (index) {
    final stars = values[index];
    final tab = _PartyGiftTab.values[index % _PartyGiftTab.values.length];
    return _PartyGiftItem(
      name: 'Gift ${index + 1}',
      stars: stars,
      icon: icons[index % icons.length],
      tab: tab,
    );
  });
}

enum _PartyGiftTab {
  gift('Gift'),
  activity('Activity'),
  mysterious('Mysterious Box'),
  special('Special'),
  bag('Bag'),
  custom('Custom');

  const _PartyGiftTab(this.label);
  final String label;
}

const List<_PartyBackgroundPreset> _partyBackgroundPresets = [
  _PartyBackgroundPreset(
    id: 'royal',
    title: 'Royal Gold',
    requiredLevel: 1,
    colors: [Color(0xFF2C1609), Color(0xFF5E3813), Color(0xFF070506)],
    accent: Color(0xFFFFD36B),
  ),
  _PartyBackgroundPreset(
    id: 'velvet',
    title: 'Velvet Star',
    requiredLevel: 4,
    colors: [Color(0xFF2B073F), Color(0xFF5C175F), Color(0xFF050308)],
    accent: Color(0xFFFF4DCE),
  ),
  _PartyBackgroundPreset(
    id: 'neon',
    title: 'Neon Stage',
    requiredLevel: 5,
    colors: [Color(0xFF081236), Color(0xFF19105B), Color(0xFF05070D)],
    accent: Color(0xFF63E5FF),
  ),
  _PartyBackgroundPreset(
    id: 'galaxy',
    title: 'Galaxy Sky',
    requiredLevel: 6,
    colors: [Color(0xFF061B33), Color(0xFF1D1145), Color(0xFF030509)],
    accent: Color(0xFF8C6BFF),
  ),
  _PartyBackgroundPreset(
    id: 'moon',
    title: 'Moon Palace',
    requiredLevel: 7,
    colors: [Color(0xFF221027), Color(0xFF71421A), Color(0xFF060506)],
    accent: Color(0xFFFFB85D),
  ),
  _PartyBackgroundPreset(
    id: 'aurora',
    title: 'Aurora Flow',
    requiredLevel: 8,
    colors: [Color(0xFF061C1E), Color(0xFF12385B), Color(0xFF040608)],
    accent: Color(0xFF35F5BA),
  ),
  _PartyBackgroundPreset(
    id: 'spotlight',
    title: 'Spotlight',
    requiredLevel: 9,
    colors: [Color(0xFF100C22), Color(0xFF251A54), Color(0xFF050508)],
    accent: Color(0xFFFF5FA2),
  ),
  _PartyBackgroundPreset(
    id: 'crown',
    title: 'Crown Hall',
    requiredLevel: 10,
    colors: [Color(0xFF31130C), Color(0xFF7A2638), Color(0xFF080404)],
    accent: Color(0xFFFFA63D),
  ),
];

class _PartyBackgroundPreset {
  const _PartyBackgroundPreset({
    required this.id,
    required this.title,
    required this.requiredLevel,
    required this.colors,
    required this.accent,
  });

  final String id;
  final String title;
  final int requiredLevel;
  final List<Color> colors;
  final Color accent;
}

_PartyBackgroundPreset _backgroundPresetById(String theme) {
  for (final preset in _partyBackgroundPresets) {
    if (preset.id == theme) return preset;
  }
  return _partyBackgroundPresets.first;
}

class _MiniBackgroundPreview extends StatelessWidget {
  const _MiniBackgroundPreview({required this.theme});

  final String theme;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _AudioPartyBackgroundPainter(theme: theme, compact: true),
      child: const SizedBox.expand(),
    );
  }
}

class _AudioPartyBackground extends StatelessWidget {
  const _AudioPartyBackground({required this.theme});

  final String theme;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _AudioPartyBackgroundPainter(theme: theme),
      child: const SizedBox.expand(),
    );
  }
}

class _AudioPartyBackgroundPainter extends CustomPainter {
  const _AudioPartyBackgroundPainter({
    required this.theme,
    this.compact = false,
  });

  final String theme;
  final bool compact;

  @override
  void paint(Canvas canvas, Size size) {
    final preset = _backgroundPresetById(theme);
    final sky = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: preset.colors,
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, sky);

    _drawLightBloom(canvas, size, preset);
    _drawStageArchitecture(canvas, size, preset);
    _drawParticles(canvas, size, preset);
    _drawSeatGlowFloor(canvas, size, preset);
    if (compact) return;
    _drawWaveform(canvas, size);
  }

  void _drawLightBloom(
    Canvas canvas,
    Size size,
    _PartyBackgroundPreset preset,
  ) {
    final moon = Paint()
      ..shader =
          RadialGradient(
            colors: [
              preset.accent.withValues(alpha: 0.82),
              preset.accent.withValues(alpha: 0.16),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.62, size.height * 0.16),
              radius: compact ? 42 : 106,
            ),
          );
    canvas.drawCircle(
      Offset(size.width * 0.62, size.height * 0.16),
      compact ? 42 : 106,
      moon,
    );
  }

  void _drawStageArchitecture(
    Canvas canvas,
    Size size,
    _PartyBackgroundPreset preset,
  ) {
    final mountain = Paint()..color = const Color(0xFF0F1017);
    final path = Path()
      ..moveTo(0, size.height * 0.36)
      ..lineTo(size.width * 0.18, size.height * 0.22)
      ..lineTo(size.width * 0.34, size.height * 0.34)
      ..lineTo(size.width * 0.48, size.height * 0.19)
      ..lineTo(size.width * 0.7, size.height * 0.35)
      ..lineTo(size.width, size.height * 0.23)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, mountain);

    final archPaint = Paint()
      ..color = preset.accent.withValues(alpha: compact ? 0.38 : 0.24)
      ..style = PaintingStyle.stroke
      ..strokeWidth = compact ? 3 : 5;
    for (var i = 0; i < 3; i++) {
      final inset = size.width * (0.08 + i * 0.09);
      final top = size.height * (0.08 + i * 0.035);
      final rect = Rect.fromLTWH(
        inset,
        top,
        size.width - inset * 2,
        size.height * (0.54 + i * 0.06),
      );
      canvas.drawArc(rect, 3.22, 3.90, false, archPaint);
    }

    final beamPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          preset.accent.withValues(alpha: compact ? 0.12 : 0.18),
          Colors.transparent,
        ],
      ).createShader(Offset.zero & size);
    final leftBeam = Path()
      ..moveTo(size.width * 0.48, size.height * 0.04)
      ..lineTo(size.width * 0.12, size.height)
      ..lineTo(size.width * 0.32, size.height)
      ..close();
    final rightBeam = Path()
      ..moveTo(size.width * 0.58, size.height * 0.05)
      ..lineTo(size.width * 0.72, size.height)
      ..lineTo(size.width * 0.94, size.height)
      ..close();
    canvas.drawPath(leftBeam, beamPaint);
    canvas.drawPath(rightBeam, beamPaint);
  }

  void _drawSeatGlowFloor(
    Canvas canvas,
    Size size,
    _PartyBackgroundPreset preset,
  ) {
    final sea = Paint()
      ..shader =
          LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              preset.accent.withValues(alpha: compact ? 0.12 : 0.18),
              const Color(0xFF090910).withValues(alpha: 0.98),
            ],
          ).createShader(
            Rect.fromLTWH(0, size.height * 0.5, size.width, size.height * 0.5),
          );
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.5, size.width, size.height * 0.5),
      sea,
    );

    final floorPaint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              preset.accent.withValues(alpha: compact ? 0.42 : 0.34),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.5, size.height * 0.68),
              radius: size.width * 0.42,
            ),
          );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.7),
        width: size.width * 0.78,
        height: compact ? size.height * 0.32 : size.height * 0.18,
      ),
      floorPaint,
    );
  }

  void _drawParticles(Canvas canvas, Size size, _PartyBackgroundPreset preset) {
    final particlePaint = Paint()
      ..color = preset.accent.withValues(alpha: 0.62);
    final count = compact ? 12 : 26;
    for (var i = 0; i < count; i++) {
      final x = ((i * 47) % 100) / 100 * size.width;
      final y = ((i * 31) % 100) / 100 * size.height * 0.82;
      final radius = (i % 3 + 1) * (compact ? 0.8 : 1.1);
      canvas.drawCircle(Offset(x, y), radius, particlePaint);
    }
  }

  void _drawWaveform(Canvas canvas, Size size) {
    final waveform = Paint()
      ..color = Colors.white.withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final mid = size.height * 0.3;
    final signal = Path()..moveTo(0, mid);
    for (var x = 0.0; x <= size.width; x += 18) {
      final up = (x / 18) % 2 == 0;
      signal.lineTo(x, mid + (up ? -10 : 10));
    }
    canvas.drawPath(signal, waveform);
  }

  @override
  bool shouldRepaint(covariant _AudioPartyBackgroundPainter oldDelegate) {
    return oldDelegate.theme != theme || oldDelegate.compact != compact;
  }
}
