import 'dart:async';
import 'dart:math';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/agora_service.dart';
import '../../services/live_service.dart';
import '../../share_sheet.dart';
import '../../widgets/svip_badge.dart';

class LivePage extends StatefulWidget {
  const LivePage({super.key, required this.liveID, this.isHost = false});

  final String liveID;
  final bool isHost;

  @override
  State<LivePage> createState() => _LivePageState();
}

class _LivePageState extends State<LivePage>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late final AgoraService _agora;
  late final AnimationController _pkScanController;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _opening = true;
  bool _leaving = false;
  bool _firestoreJoined = false;
  bool _hostConnectedSynced = false;
  String? _error;

  static const String _agoraChannelName = AgoraService.defaultChannelName;
  final TextEditingController _commentController = TextEditingController();
  final List<_FloatingHeart> _hearts = <_FloatingHeart>[];
  final List<_GiftItem> _giftCatalog = _buildGiftCatalog();
  Timer? _heartTimer;
  int _heartSeed = 0;
  final Random _random = Random();
  final AudioPlayer _giftAudioPlayer = AudioPlayer();
  bool _showMegaGift = false;
  _GiftItem? _activeGift;
  String? _giftTicker;
  String? _giftTickerEventId;
  Timer? _giftTickerTimer;
  _GlobalGiftBannerData? _globalGiftBanner;
  String? _globalGiftEventId;
  Timer? _globalGiftTimer;
  String? _vipTicker;
  _GiftTab _selectedGiftTab = _GiftTab.gift;
  int _giftQuantity = 1;
  StreamSubscription<List<LiveVipEntryEvent>>? _vipSub;
  StreamSubscription<PkBattleState?>? _pkSub;
  StreamSubscription<List<PkRequestItem>>? _sentPkRequestSub;
  StreamSubscription<List<PkRequestItem>>? _incomingPkRequestSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _liveBlockSub;
  Timer? _pkTimer;
  Timer? _pkSearchTimer;
  _VipOverlayData? _vipOverlay;
  _PkResultOverlayData? _pkResultOverlay;
  bool _pkWasActive = false;
  bool _pkSettling = false;
  PkBattleState? _currentPkState;
  String _pkRivalName = 'Rival Host';
  String? _pendingPkRequestId;
  PkMode _pendingPkMode = PkMode.forAll;
  int _pkSearchSecondsLeft = 0;
  bool _pkSearching = false;
  bool _pkInviteDialogOpen = false;
  final Set<String> _handledIncomingPkRequests = <String>{};
  bool _audienceTab = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pkScanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _agora = AgoraService()..addListener(_onAgoraChanged);
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      _handleConnectivity,
    );
    _heartTimer = Timer.periodic(const Duration(milliseconds: 900), (_) {
      _spawnHeart();
    });
    _vipSub = LiveService.instance
        .watchVipEntries(widget.liveID, limit: 1)
        .listen((events) {
          if (events.isEmpty || !mounted) return;
          final latest = events.first;
          setState(
            () => _vipOverlay = _VipOverlayData(latest.name, latest.tier),
          );
          Future<void>.delayed(const Duration(milliseconds: 2400), () {
            if (!mounted) return;
            setState(() => _vipOverlay = null);
          });
        });
    _pkSub = LiveService.instance.watchPkState(widget.liveID).listen((pk) {
      final wasActive = _pkWasActive;
      _currentPkState = pk;
      final isBattleActive =
          pk != null &&
          (pk.active ||
              pk.status.toUpperCase() == 'CONNECTED' ||
              pk.status.toUpperCase() == 'ACTIVE');
      _pkWasActive = isBattleActive;
      _pkTimer?.cancel();
      if (!mounted) return;
      if (pk != null && isBattleActive) {
        _pkSettling = false;
      }
      if (wasActive && (pk == null || !isBattleActive)) {
        unawaited(_finalizePkIfNeeded(pk));
      }
      if (!widget.isHost || pk == null || !isBattleActive) return;
      _pkTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
        final deadline = pk.battleEndsAt?.millisecondsSinceEpoch;
        final next = deadline == null
            ? pk.secondsLeft - timer.tick
            : max(
                0,
                ((deadline - DateTime.now().millisecondsSinceEpoch) / 1000)
                    .ceil(),
              );
        if (next <= 0) {
          timer.cancel();
          await LiveService.instance.updatePkState(
            widget.liveID,
            active: false,
            leftScore: pk.leftScore,
            rightScore: pk.rightScore,
            secondsLeft: 0,
            leftHostName: pk.leftHostName,
            rightHostName: pk.rightHostName,
          );
          await _finalizePkIfNeeded(
            const PkBattleState(
              active: false,
              status: 'ENDED',
              leftScore: 0,
              rightScore: 0,
              secondsLeft: 0,
              leftHostName: 'You',
              rightHostName: 'Rival',
            ),
            leftScoreOverride: pk.leftScore,
            rightScoreOverride: pk.rightScore,
          );
          return;
        }
        await LiveService.instance.updatePkState(
          widget.liveID,
          active: true,
          leftScore: pk.leftScore,
          rightScore: pk.rightScore,
          secondsLeft: next,
          leftHostName: pk.leftHostName,
          rightHostName: pk.rightHostName,
        );
      });
    });
    _sentPkRequestSub = LiveService.instance
        .watchSentPkRequests(widget.liveID)
        .listen(_handleSentPkRequests);
    _incomingPkRequestSub = LiveService.instance
        .watchIncomingPkRequests(widget.liveID)
        .listen(_handleIncomingPkRequests);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_joinLive());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!widget.isHost || _agora.engine == null) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      unawaited(_agora.engine!.muteLocalVideoStream(true));
    } else if (state == AppLifecycleState.resumed &&
        _agora.isJoined &&
        !_agora.cameraMuted) {
      unawaited(_agora.engine!.muteLocalVideoStream(false));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pkScanController.dispose();
    _connectivitySubscription?.cancel();
    _heartTimer?.cancel();
    _giftTickerTimer?.cancel();
    _globalGiftTimer?.cancel();
    _pkTimer?.cancel();
    _pkSearchTimer?.cancel();
    _vipSub?.cancel();
    _pkSub?.cancel();
    _sentPkRequestSub?.cancel();
    _incomingPkRequestSub?.cancel();
    _liveBlockSub?.cancel();
    _giftAudioPlayer.dispose();
    _commentController.dispose();
    _agora.removeListener(_onAgoraChanged);
    _agora.dispose();
    super.dispose();
  }

  Future<void> _joinLive() async {
    if (!mounted) return;
    setState(() {
      _opening = true;
      _error = null;
    });

    try {
      if (!widget.isHost) {
        final available = await LiveService.instance.roomIsAvailable(
          widget.liveID,
        );
        if (!available) throw StateError('Live unavailable');
        await LiveService.instance.ensureLiveRoomAccess(widget.liveID);
      }
      await _agora.join(isHost: widget.isHost, channelName: _agoraChannelName);
      await _syncFirestoreConnected();
    } catch (error) {
      await _agora.leave();
      if (widget.isHost) {
        await LiveService.instance.markRoomFailed(
          widget.liveID,
          error.toString(),
        );
      }
      if (mounted) {
        setState(() => _error = _liveErrorMessage(error));
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _syncFirestoreConnected() async {
    if (widget.isHost && !_hostConnectedSynced) {
      _hostConnectedSynced = true;
      await LiveService.instance.markRoomConnected(widget.liveID);
      return;
    }

    if (!widget.isHost && !_firestoreJoined) {
      _firestoreJoined = true;
      await LiveService.instance.joinRoom(widget.liveID);
      _watchCurrentUserBlockState();
    }
  }

  void _watchCurrentUserBlockState() {
    if (widget.isHost || _liveBlockSub != null) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;
    _liveBlockSub = FirebaseFirestore.instance
        .collection('liveRooms')
        .doc(widget.liveID)
        .collection('blockedUsers')
        .doc(uid)
        .snapshots()
        .listen((snapshot) {
          if (!snapshot.exists || _leaving || !mounted) return;
          _notifyPkToast('You are blocked from this room.');
          unawaited(_leave());
        });
  }

  void _onAgoraChanged() {
    if (!mounted) return;
    final serviceError = _agora.lastError;
    if (_agora.status == LiveConnectionStatus.failed && serviceError != null) {
      setState(() => _error = serviceError);
    } else {
      setState(() {});
    }
  }

  String _liveErrorMessage(Object error) {
    final message = error.toString();
    if (message.toLowerCase().contains('errtokenexpired') ||
        message.toLowerCase().contains('tokenexpired') ||
        message.toLowerCase().contains('token expired')) {
      return 'Reconnecting live stream...';
    }
    if (message.contains('replace_with_your') ||
        message.contains('AGORA_APP_ID') ||
        message.contains('AGORA_TEMP_RTC_TOKEN')) {
      return 'Reconnecting live stream...';
    }
    if (message.contains('token server') || message.contains('token service')) {
      return 'Live token service unavailable. Trying reconnect...';
    }
    if (message.contains('permission')) {
      return 'Camera and microphone permissions required.';
    }
    return message.isEmpty ? 'Unable to load live stream' : message;
  }

  void _handleConnectivity(List<ConnectivityResult> results) {
    final offline = results.every(
      (result) => result == ConnectivityResult.none,
    );
    if (offline || !mounted) return;
    if (_agora.status == LiveConnectionStatus.failed) {
      unawaited(_agora.reconnect(isHost: widget.isHost));
    }
  }

  Future<void> _leave() async {
    if (_leaving) return;
    setState(() => _leaving = true);
    await _agora.leave();
    await LiveService.instance.leaveRoom(widget.liveID, isHost: widget.isHost);
    if (mounted) Navigator.of(context).pop();
  }

  void _spawnHeart() {
    if (!mounted) return;
    final heart = _FloatingHeart(
      key: _heartSeed++,
      right: 12 + _random.nextDouble() * 34,
      travel: 140 + _random.nextDouble() * 90,
      duration: Duration(milliseconds: 1800 + _random.nextInt(700)),
      color: _heartColors[_random.nextInt(_heartColors.length)],
    );
    setState(() => _hearts.add(heart));
    Future<void>.delayed(heart.duration, () {
      if (!mounted) return;
      setState(() => _hearts.removeWhere((item) => item.key == heart.key));
    });
  }

  Future<void> _quickTopUpStars() async {
    try {
      await LiveService.instance.topUpCurrentUserStars(50000);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Added +50000 STAR for testing')),
      );
    } catch (_) {}
  }

  Future<void> _finalizePkIfNeeded(
    PkBattleState? pk, {
    int? leftScoreOverride,
    int? rightScoreOverride,
  }) async {
    if (!widget.isHost || _pkSettling) return;
    _pkSettling = true;
    try {
      final leftScore = leftScoreOverride ?? (pk?.leftScore ?? 0);
      final rightScore = rightScoreOverride ?? (pk?.rightScore ?? 0);
      await LiveService.instance.settlePkResult(
        widget.liveID,
        leftScore: leftScore,
        rightScore: rightScore,
      );
      final winner = leftScore == rightScore
          ? 'DRAW'
          : (leftScore > rightScore ? 'LEFT WINS' : 'RIGHT WINS');
      final reward = leftScore > rightScore ? ' +PK STAR REWARD' : '';
      if (!mounted) return;
      setState(() {
        _pkResultOverlay = _PkResultOverlayData('$winner$reward');
      });
      Future<void>.delayed(const Duration(seconds: 3), () {
        if (!mounted) return;
        setState(() => _pkResultOverlay = null);
      });
    } finally {
      _pkSettling = false;
    }
  }

  void _handleSentPkRequests(List<PkRequestItem> requests) {
    if (!mounted || requests.isEmpty) return;
    final request = requests.first;

    if (_pendingPkRequestId != request.requestId &&
        _pendingPkRequestId != null) {
      return;
    }

    if (request.status.toUpperCase() == 'CONNECTED') {
      _stopPkSearchTimer();
      _stopPkScanAnimation();
      if (mounted && _pkSearching) {
        setState(() {
          _pkSearching = false;
          _pendingPkRequestId = request.requestId;
        });
        _notifyPkToast('PK connected');
      }
      return;
    }

    if (request.status.toUpperCase() == 'REJECTED' ||
        request.status.toUpperCase() == 'DECLINED' ||
        request.status.toUpperCase() == 'CANCELLED' ||
        request.status.toUpperCase() == 'EXPIRED') {
      _stopPkSearchTimer();
      _stopPkScanAnimation();
      if (mounted) {
        setState(() {
          _pkSearching = false;
          _pendingPkRequestId = null;
        });
      }
      _notifyPkToast('Request declined');
    }
  }

  void _handleIncomingPkRequests(List<PkRequestItem> requests) {
    if (!mounted || requests.isEmpty || !widget.isHost) return;
    final request = requests.firstWhere(
      (item) => item.isSearching,
      orElse: () => requests.first,
    );
    if (request.status.toUpperCase() != 'INVITED') return;
    if (_handledIncomingPkRequests.contains(request.requestId)) return;
    _handledIncomingPkRequests.add(request.requestId);
    unawaited(_showIncomingPkInvite(request));
  }

  Future<void> _showIncomingPkInvite(PkRequestItem request) async {
    if (_pkInviteDialogOpen || !mounted) return;
    _pkInviteDialogOpen = true;
    try {
      final accept = await showModalBottomSheet<bool>(
        context: context,
        backgroundColor: const Color(0xFF101014),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (context) {
          return SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'PK Invite',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${request.senderHostName} wants to battle you in ${_pkModeLabel(request.mode)}.',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Decline'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Accept'),
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
      if (!mounted) return;
      if (accept == true) {
        await LiveService.instance.respondPkRequest(
          requestId: request.requestId,
          accept: true,
          roomId: widget.liveID,
        );
        _notifyPkToast('PK connected');
      } else {
        await LiveService.instance.respondPkRequest(
          requestId: request.requestId,
          accept: false,
          roomId: widget.liveID,
        );
        _notifyPkToast('Request declined');
      }
    } catch (_) {
      if (mounted) {
        _notifyPkToast('Unable to process PK invite');
      }
    } finally {
      _pkInviteDialogOpen = false;
    }
  }

  void _notifyPkToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  String _cleanError(Object error) {
    final text = error.toString();
    return text
        .replaceFirst('Bad state: ', '')
        .replaceFirst('Exception: ', '')
        .trim();
  }

  void _startPkScanAnimation() {
    if (!_pkScanController.isAnimating) {
      _pkScanController.repeat();
    }
  }

  void _stopPkScanAnimation() {
    if (_pkScanController.isAnimating) {
      _pkScanController.stop();
    }
  }

  void _stopPkSearchTimer() {
    _pkSearchTimer?.cancel();
    _pkSearchTimer = null;
  }

  Future<void> _beginPkRequest({
    required PkMode mode,
    String? targetIdentifier,
  }) async {
    if (_pkSearching) return;

    setState(() {
      _pkSearching = true;
      _pkSearchSecondsLeft = 30;
      _pendingPkRequestId = null;
      _pendingPkMode = mode;
    });
    _startPkScanAnimation();

    _stopPkSearchTimer();
    _pkSearchTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_pkSearchSecondsLeft <= 1) {
        timer.cancel();
        await _timeoutPkRequest();
        return;
      }
      setState(() => _pkSearchSecondsLeft -= 1);
    });

    try {
      final request = await LiveService.instance.createPkRequest(
        roomId: widget.liveID,
        mode: mode.key,
        targetIdentifier: targetIdentifier,
      );
      if (!mounted) return;
      final expiresAt = request.expiresAt;
      setState(() {
        _pendingPkRequestId = request.requestId;
        _pkSearching = request.isSearching;
        final remainingMs = expiresAt == null
            ? null
            : expiresAt.millisecondsSinceEpoch -
                  DateTime.now().millisecondsSinceEpoch;
        _pkSearchSecondsLeft = remainingMs == null
            ? _pkSearchSecondsLeft
            : max(0, Duration(milliseconds: remainingMs).inSeconds);
      });
      if (request.isConnected) {
        _stopPkSearchTimer();
        _stopPkScanAnimation();
        if (mounted) {
          setState(() => _pkSearching = false);
          _notifyPkToast('PK connected');
        }
      }
    } catch (error) {
      _stopPkSearchTimer();
      _stopPkScanAnimation();
      if (!mounted) return;
      setState(() {
        _pkSearching = false;
        _pendingPkRequestId = null;
      });
      _notifyPkToast(error.toString());
    }
  }

  Future<void> _timeoutPkRequest() async {
    final requestId = _pendingPkRequestId;
    if (requestId != null) {
      try {
        await LiveService.instance.cancelPkRequest(requestId);
      } catch (_) {}
    }
    _stopPkScanAnimation();
    if (!mounted) return;
    setState(() {
      _pkSearching = false;
      _pendingPkRequestId = null;
      _pkSearchSecondsLeft = 0;
    });
    _notifyPkToast('No opponent found');
  }

  Future<void> _triggerGift(_GiftItem gift) async {
    setState(() {
      _activeGift = gift;
    });
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final currentPk = _currentPkState;
    final pkSide = currentPk == null || currentUid == null
        ? 'left'
        : currentPk.leftHostId == currentUid
        ? 'left'
        : currentPk.rightHostId == currentUid
        ? 'right'
        : 'left';
    if (gift.stars >= 10000) {
      setState(() => _showMegaGift = true);
      try {
        await _giftAudioPlayer.stop();
        await _giftAudioPlayer.play(
          UrlSource(
            'https://cdn.pixabay.com/audio/2022/03/15/audio_c8f2b8f79f.mp3',
          ),
        );
      } catch (_) {}
      Future<void>.delayed(const Duration(milliseconds: 2600), () async {
        if (!mounted) return;
        setState(() => _showMegaGift = false);
        try {
          await _giftAudioPlayer.stop();
        } catch (_) {}
      });
    } else {
      _spawnHeart();
      _spawnHeart();
    }
    try {
      await LiveService.instance.sendGiftEvent(
        widget.liveID,
        giftName: gift.name,
        stars: gift.stars,
        quantity: _giftQuantity,
        pkSide: pkSide,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().contains('Not enough stars')
                ? 'Not enough STAR balance'
                : 'Gift send failed',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    unawaited(
      LiveService.instance.sendMessage(
        widget.liveID,
        'sent ${gift.name} x$_giftQuantity (${gift.stars * _giftQuantity} stars)',
      ),
    );
  }

  Future<void> _openGiftBox() async {
    _selectedGiftTab = _GiftTab.gift;
    _giftQuantity = 1;
    final selected = await showModalBottomSheet<_GiftItem>(
      context: context,
      backgroundColor: const Color(0xFF101014),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        _GiftItem? selectedGift;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final filtered = _giftCatalog
                .where((gift) => gift.tab == _selectedGiftTab)
                .toList();
            selectedGift ??= filtered.isNotEmpty ? filtered.first : null;
            return SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Star Gifts',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '1 to 100000 stars',
                        style: TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 6),
                    StreamBuilder<int>(
                      stream: LiveService.instance.watchCurrentUserStars(),
                      builder: (context, snapshot) {
                        final stars = snapshot.data ?? 0;
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'My Stars: $stars\u2605',
                            style: const TextStyle(
                              color: Color(0xFFFFD66B),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: _GiftTab.values.map((tab) {
                        final selectedTab = tab == _selectedGiftTab;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setSheetState(() {
                                _selectedGiftTab = tab;
                                final list = _giftCatalog
                                    .where(
                                      (gift) => gift.tab == _selectedGiftTab,
                                    )
                                    .toList();
                                selectedGift = list.isNotEmpty
                                    ? list.first
                                    : null;
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: selectedTab
                                        ? const Color(0xFFFF3A74)
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                              ),
                              child: Text(
                                tab.label,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: selectedTab
                                      ? const Color(0xFFFF5B86)
                                      : Colors.white70,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.42,
                      child: GridView.builder(
                        itemCount: filtered.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              childAspectRatio: 0.86,
                              crossAxisSpacing: 9,
                              mainAxisSpacing: 9,
                            ),
                        itemBuilder: (context, index) {
                          final gift = filtered[index];
                          final highTier = gift.stars >= 10000;
                          return GestureDetector(
                            onTap: () =>
                                setSheetState(() => selectedGift = gift),
                            child: Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.identity()
                                ..setEntry(3, 2, 0.001)
                                ..rotateX(0.03)
                                ..rotateY(index.isEven ? -0.04 : 0.04),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: highTier
                                        ? const [
                                            Color(0xFF2F1848),
                                            Color(0xFF6B1C90),
                                            Color(0xFFFF3A74),
                                          ]
                                        : const [
                                            Color(0xFF1A1A28),
                                            Color(0xFF22223A),
                                          ],
                                  ),
                                  border: Border.all(
                                    color: selectedGift == gift
                                        ? const Color(0xFFFF3A74)
                                        : highTier
                                        ? const Color(0xFFFFD66B)
                                        : Colors.white12,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: Center(
                                        child: Icon(
                                          gift.icon,
                                          size: highTier ? 30 : 24,
                                          color: highTier
                                              ? const Color(0xFFFFD66B)
                                              : Colors.white,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      gift.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${gift.stars}\u2605',
                                      style: TextStyle(
                                        color: highTier
                                            ? const Color(0xFFFFD66B)
                                            : Colors.white70,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF171A31),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              selectedGift == null
                                  ? 'Select gift'
                                  : '${selectedGift!.name}  ${selectedGift!.stars}\u2605',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              if (_giftQuantity > 1) {
                                setSheetState(() => _giftQuantity -= 1);
                              }
                            },
                            icon: const Icon(
                              Icons.remove,
                              color: Colors.white70,
                            ),
                          ),
                          Text(
                            '$_giftQuantity',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              if (_giftQuantity < 99) {
                                setSheetState(() => _giftQuantity += 1);
                              }
                            },
                            icon: const Icon(Icons.add, color: Colors.white70),
                          ),
                          const SizedBox(width: 6),
                          FilledButton(
                            onPressed: selectedGift == null
                                ? null
                                : () => Navigator.pop(context, selectedGift),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFFF3A74),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 22,
                                vertical: 12,
                              ),
                            ),
                            child: const Text(
                              'SEND',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
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

    if (selected != null) {
      for (int i = 0; i < _giftQuantity; i++) {
        await _triggerGift(selected);
      }
    }
  }

  Widget _videoSurface() {
    final engine = _agora.engine;
    if (engine == null) {
      return const ColoredBox(color: Colors.black);
    }

    if (widget.isHost) {
      if (_agora.cameraMuted) {
        return const _CameraOffSurface();
      }
      return AgoraVideoView(
        controller: VideoViewController(
          rtcEngine: engine,
          canvas: const VideoCanvas(uid: 0),
        ),
      );
    }

    final remoteUid = _agora.remoteUids.isEmpty
        ? null
        : _agora.remoteUids.first;
    if (remoteUid == null) {
      return const Center(
        child: Text(
          'Waiting for host video...',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return AgoraVideoView(
      controller: VideoViewController.remote(
        rtcEngine: engine,
        canvas: VideoCanvas(uid: remoteUid),
        connection: const RtcConnection(channelId: _agoraChannelName),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_leaving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_leave());
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            fit: StackFit.expand,
            children: [
              _videoSurface(),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.25),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.45),
                    ],
                  ),
                ),
              ),
              _buildTopBar(),
              _buildRankingsShortcut(),
              _buildRealtimeEventBars(),
              _buildGlobalHighValueGiftBanner(),
              _buildPkOverlay(),
              _buildPkHistory(),
              _buildCommentsLayer(),
              _buildRightActions(),
              _buildBottomBar(),
              if (_vipOverlay != null) _VipEntryOverlay(data: _vipOverlay!),
              if (_pkResultOverlay != null)
                _PkResultOverlay(data: _pkResultOverlay!),
              if (_showMegaGift && _activeGift != null)
                _MegaGiftOverlay(gift: _activeGift!),
              _buildPkSearchOverlay(),
              if (_opening)
                const Center(
                  child: CircularProgressIndicator(color: Colors.redAccent),
                ),
              if (_error != null)
                _LiveError(message: _error!, onRetry: _joinLive),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 14,
      left: 12,
      right: 12,
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: LiveService.instance.watchRoom(widget.liveID),
        builder: (context, snapshot) {
          final data = snapshot.data?.data() ?? <String, dynamic>{};
          final hostName =
              (data['hostName']?.toString().trim().isNotEmpty ?? false)
              ? data['hostName'].toString().trim()
              : 'Likeehit';
          final hostPhoto = data['hostPhotoUrl']?.toString() ?? '';
          final hostId = _compactProfileId(
            (data['hostUsername']?.toString().trim().isNotEmpty ?? false)
                ? data['hostUsername'].toString().trim()
                : data['hostId']?.toString() ?? '',
          );
          final viewers = _asInt(data['viewers']);
          final totalGiftStars = _asInt(data['totalGiftStars']);
          final roomExp = LiveService.roomExpFromRoomData(data);
          final hostSvipTier = _activeHostSvipTier(data);

          return Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: const Color(0xFF2E2E2E),
                        backgroundImage: hostPhoto.isNotEmpty
                            ? NetworkImage(hostPhoto)
                            : null,
                        child: hostPhoto.isEmpty
                            ? const Icon(Icons.person, color: Colors.white70)
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              hostName,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Wrap(
                              spacing: 5,
                              runSpacing: 2,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                const Text(
                                  '\u{1F31F}',
                                  style: TextStyle(fontSize: 12),
                                ),
                                Text(
                                  '$totalGiftStars',
                                  style: const TextStyle(
                                    color: Color(0xFFFFD66B),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                                if (hostId.isNotEmpty)
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 86,
                                    ),
                                    child: Text(
                                      'ID $hostId',
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                _hostLevelPill(roomExp.level),
                                if (hostSvipTier > 0)
                                  SvipBadge(tier: hostSvipTier, compact: true),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (!widget.isHost)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF4C8D),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.favorite,
                                color: Colors.white,
                                size: 16,
                              ),
                              SizedBox(width: 4),
                              Text(
                                '+',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF3A74),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'HOST',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _openAudienceSheet,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.visibility,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '$viewers',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _leave,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 24),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _hostLevelPill(int level) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5F79FF), Color(0xFFC493FF)],
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9073FF).withValues(alpha: 0.28),
            blurRadius: 8,
          ),
        ],
      ),
      child: Text(
        'Lv.$level',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _buildRankingsShortcut() {
    return Positioned(
      top: 74,
      right: 24,
      width: 96,
      child: GestureDetector(
        onTap: _openWorldRankingsSheet,
        child: Container(
          height: 24,
          padding: const EdgeInsets.symmetric(horizontal: 7),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF7D2C9D), Color(0xFF3C1E65)],
            ),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7D2C9D).withValues(alpha: 0.25),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: const Row(
            children: [
              Icon(Icons.public_rounded, color: Color(0xFFFFD66B), size: 12),
              SizedBox(width: 4),
              Text(
                'Rankings',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _compactProfileId(String value) {
    final id = value.trim();
    if (id.length <= 12) return id;
    return '${id.substring(0, 6)}...${id.substring(id.length - 4)}';
  }

  Widget _buildPkOverlay() {
    return Positioned.fill(
      child: StreamBuilder<PkBattleState?>(
        stream: LiveService.instance.watchPkState(widget.liveID),
        builder: (context, snapshot) {
          final pk = snapshot.data;
          if (pk == null || !pk.active) return const SizedBox.shrink();

          return StreamBuilder<List<RoomGiftLeaderEntry>>(
            stream: LiveService.instance.watchRoomGiftLeaders(
              widget.liveID,
              limit: 24,
            ),
            builder: (context, leaderSnapshot) {
              final leaders =
                  leaderSnapshot.data ?? const <RoomGiftLeaderEntry>[];
              final leftLeaders = _topLeadersForSide(leaders, 'left');
              final rightLeaders = _topLeadersForSide(leaders, 'right');
              final totalStars = pk.leftScore + pk.rightScore;
              final leftRatio = totalStars <= 0
                  ? 0.5
                  : pk.leftScore / totalStars;

              return IgnorePointer(
                ignoring: false,
                child: Stack(
                  children: [
                    Positioned(
                      top: 94,
                      left: 0,
                      right: 0,
                      child: _buildPkBattleCard(pk: pk, leftRatio: leftRatio),
                    ),
                    Positioned(
                      top: 132,
                      left: 0,
                      right: 0,
                      child: _buildPkSupporterDeck(
                        leftName: pk.leftHostName,
                        rightName: pk.rightHostName,
                        leftScore: pk.leftScore,
                        rightScore: pk.rightScore,
                        leftLeaders: leftLeaders,
                        rightLeaders: rightLeaders,
                      ),
                    ),
                    if (widget.isHost)
                      Positioned(
                        top: 214,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _pkBtn('L+', () {
                              LiveService.instance.updatePkState(
                                widget.liveID,
                                active: true,
                                leftScore: pk.leftScore + 100,
                                rightScore: pk.rightScore,
                                secondsLeft: pk.secondsLeft,
                                leftHostName: pk.leftHostName,
                                rightHostName: pk.rightHostName,
                                mode: pk.mode,
                              );
                            }),
                            const SizedBox(width: 8),
                            _pkBtn('R+', () {
                              LiveService.instance.updatePkState(
                                widget.liveID,
                                active: true,
                                leftScore: pk.leftScore,
                                rightScore: pk.rightScore + 100,
                                secondsLeft: pk.secondsLeft,
                                leftHostName: pk.leftHostName,
                                rightHostName: pk.rightHostName,
                                mode: pk.mode,
                              );
                            }),
                            const SizedBox(width: 8),
                            _pkBtn('END', () {
                              LiveService.instance.updatePkState(
                                widget.liveID,
                                active: false,
                                leftScore: pk.leftScore,
                                rightScore: pk.rightScore,
                                secondsLeft: 0,
                                leftHostName: pk.leftHostName,
                                rightHostName: pk.rightHostName,
                                mode: pk.mode,
                              );
                            }),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildPkSearchOverlay() {
    if (!_pkSearching) return const SizedBox.shrink();

    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _pkScanController,
        builder: (context, _) {
          final progress = _pkScanController.value;
          return Container(
            color: Colors.black.withValues(alpha: 0.26),
            alignment: Alignment.center,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2A103B), Color(0xFF120F24)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(color: Colors.white12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.45),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 230,
                        height: 230,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CustomPaint(
                              size: const Size(230, 230),
                              painter: _PkRadarPainter(
                                progress: progress,
                                accent: const Color(0xFFB04DFF),
                              ),
                            ),
                            Container(
                              width: 86,
                              height: 86,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    const Color(
                                      0xFFB04DFF,
                                    ).withValues(alpha: 0.95),
                                    const Color(
                                      0xFF6A2BFF,
                                    ).withValues(alpha: 0.72),
                                    Colors.black.withValues(alpha: 0.82),
                                  ],
                                  stops: const [0.0, 0.55, 1.0],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFFB04DFF,
                                    ).withValues(alpha: 0.35),
                                    blurRadius: 20,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.radar_rounded,
                                color: Colors.white,
                                size: 34,
                              ),
                            ),
                            Positioned.fill(
                              child: Center(
                                child: _scanDot(
                                  progress,
                                  const Color(0xFFB04DFF),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Searching for a worthy opponent...',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          height: 1.08,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Scanning live hosts (up to 30 seconds).',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.72),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.36),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Text(
                          _formatPkCountdown(_pkSearchSecondsLeft),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _timeoutPkRequest,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFFF4D8D),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            textStyle: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPkBattleCard({
    required PkBattleState pk,
    required double leftRatio,
  }) {
    return SizedBox(
      height: 34,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _buildPkLinearScoreBar(pk: pk, leftRatio: leftRatio),
          _buildPkCenterBadge(pk),
        ],
      ),
    );
  }

  Widget _buildPkLinearScoreBar({
    required PkBattleState pk,
    required double leftRatio,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final safeLeftWidth = totalWidth * leftRatio;
        final safeRightWidth = max(0.0, totalWidth - safeLeftWidth);
        return SizedBox(
          height: 16,
          child: Stack(
            children: [
              Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    width: safeLeftWidth,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFFF2F75), Color(0xFFFF78A8)],
                      ),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    width: safeRightWidth,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF2377FF), Color(0xFF5FD0FF)],
                      ),
                    ),
                  ),
                ],
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.symmetric(
                      horizontal: BorderSide(
                        color: Colors.white.withValues(alpha: 0.18),
                        width: 0.6,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Row(
                    children: [
                      Text(
                        '${pk.leftScore}\u2605',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          shadows: [
                            Shadow(
                              color: Colors.black87,
                              blurRadius: 5,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${pk.rightScore}\u2605',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          shadows: [
                            Shadow(
                              color: Colors.black87,
                              blurRadius: 5,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPkCenterBadge(PkBattleState pk) {
    return SizedBox(
      width: 86,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'VS ${pk.secondsLeft.toString().padLeft(2, '0')}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              shadows: [
                Shadow(
                  color: Colors.black,
                  blurRadius: 8,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
          Text(
            _pkModeLabel(pk.mode),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 8,
              fontWeight: FontWeight.w700,
              shadows: [
                Shadow(
                  color: Colors.black,
                  blurRadius: 6,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPkHostLabel({
    required String name,
    required int score,
    required CrossAxisAlignment align,
    required Color accent,
  }) {
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            shadows: [
              Shadow(
                color: Colors.black87,
                blurRadius: 8,
                offset: Offset(0, 1),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '$score\u2605',
          style: TextStyle(
            color: accent,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            shadows: const [
              Shadow(
                color: Colors.black87,
                blurRadius: 6,
                offset: Offset(0, 1),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPkSupporterDeck({
    required String leftName,
    required String rightName,
    required int leftScore,
    required int rightScore,
    required List<RoomGiftLeaderEntry> leftLeaders,
    required List<RoomGiftLeaderEntry> rightLeaders,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildPkHostLabel(
                  name: leftName,
                  score: leftScore,
                  align: CrossAxisAlignment.start,
                  accent: const Color(0xFFFF4D8D),
                ),
              ),
              const SizedBox(width: 36),
              Expanded(
                child: _buildPkHostLabel(
                  name: rightName,
                  score: rightScore,
                  align: CrossAxisAlignment.end,
                  accent: const Color(0xFF2A78FF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _buildPkSeatGroup(
                  accent: const Color(0xFFFF4D8D),
                  leaders: leftLeaders,
                ),
              ),
              const SizedBox(width: 36),
              Expanded(
                child: _buildPkSeatGroup(
                  accent: const Color(0xFF2A78FF),
                  leaders: rightLeaders,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPkSeatGroup({
    required Color accent,
    required List<RoomGiftLeaderEntry> leaders,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(3, (index) {
        final leader = index < leaders.length ? leaders[index] : null;
        return _buildPkSeatSlot(index: index, leader: leader, accent: accent);
      }),
    );
  }

  Widget _buildPkSeatSlot({
    required int index,
    required RoomGiftLeaderEntry? leader,
    required Color accent,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: accent.withValues(alpha: 0.95),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.22),
                    blurRadius: 10,
                  ),
                ],
                image: leader != null && leader.photoUrl.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(leader.photoUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
                gradient: leader == null
                    ? LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.10),
                          Colors.white.withValues(alpha: 0.04),
                        ],
                      )
                    : null,
              ),
              child: leader == null
                  ? Icon(
                      Icons.person_outline_rounded,
                      size: 18,
                      color: Colors.white.withValues(alpha: 0.65),
                    )
                  : null,
            ),
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 15,
                height: 15,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black, width: 1.3),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${index + 1}',
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
        const SizedBox(height: 5),
        Text(
          '${index + 1}',
          style: TextStyle(
            color: accent,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _scanDot(double progress, Color accent) {
    final angle = progress * pi * 2 - pi / 2;
    final orbit = Offset(cos(angle), sin(angle));
    return Transform.translate(
      offset: Offset(orbit.dx * 68, orbit.dy * 68),
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: accent,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.65),
              blurRadius: 14,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }

  String _formatPkCountdown(int seconds) {
    final safeSeconds = max(0, seconds);
    final minutes = safeSeconds ~/ 60;
    final remainder = safeSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainder.toString().padLeft(2, '0')}';
  }

  Widget _buildRealtimeEventBars() {
    return Positioned(
      top: 76,
      left: 12,
      right: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StreamBuilder<List<LiveGiftEvent>>(
            stream: LiveService.instance.watchGiftEvents(
              widget.liveID,
              limit: 1,
            ),
            builder: (context, snapshot) {
              final event = snapshot.data?.isNotEmpty == true
                  ? snapshot.data!.first
                  : null;
              if (event != null && event.id != _giftTickerEventId) {
                Future.microtask(() => _showGiftTicker(event));
              }
              if (_giftTicker == null) return const SizedBox.shrink();
              return _eventPill(_giftTicker!, const Color(0xFF7A3FF2));
            },
          ),
          const SizedBox(height: 6),
          StreamBuilder<List<LiveVipEntryEvent>>(
            stream: LiveService.instance.watchVipEntries(
              widget.liveID,
              limit: 1,
            ),
            builder: (context, snapshot) {
              final event = snapshot.data?.isNotEmpty == true
                  ? snapshot.data!.first
                  : null;
              if (event != null) {
                _vipTicker = '${event.name} entered as ${event.tier}';
              }
              if (_vipTicker == null) return const SizedBox.shrink();
              return _eventPill(_vipTicker!, const Color(0xFF2A78FF));
            },
          ),
          if (_pkSearching) ...[
            const SizedBox(height: 6),
            _eventPill(
              'Searching ${_pkModeLabel(_pendingPkMode.key)} \u2022 ${_pkSearchSecondsLeft}s',
              const Color(0xFF8F4BFF),
              trailing: const Icon(
                Icons.timelapse_rounded,
                color: Colors.white,
                size: 16,
              ),
              onTap: _pendingPkRequestId == null ? null : _timeoutPkRequest,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCommentsLayer() {
    return Positioned(
      left: 12,
      right: 68,
      bottom: 92,
      child: StreamBuilder<List<LiveChatMessage>>(
        stream: LiveService.instance.watchMessages(widget.liveID, limit: 60),
        builder: (context, snapshot) {
          final messages = snapshot.data ?? const <LiveChatMessage>[];
          return SizedBox(
            height: 210,
            child: ListView.builder(
              itemCount: messages.length,
              reverse: true,
              itemBuilder: (context, index) {
                final message = messages[index];
                return Align(
                  alignment: Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.fromLTRB(10, 8, 12, 9),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: message.svipTier > 0
                              ? const [Color(0xCC0F7A45), Color(0xAA36B76B)]
                              : const [Color(0x85343434), Color(0x66343434)],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: message.svipTier > 0
                              ? const Color(0xFFFFD76A).withValues(alpha: 0.5)
                              : Colors.white10,
                        ),
                        boxShadow: [
                          if (message.svipTier > 0)
                            BoxShadow(
                              color: const Color(
                                0xFF2EEA83,
                              ).withValues(alpha: 0.25),
                              blurRadius: 14,
                            ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              if (message.svipTier > 0)
                                SvipBadge(
                                  tier: message.svipTier,
                                  compact: true,
                                ),
                              if (message.isHost)
                                _chatTag('Host', const Color(0xFFFF4D8D)),
                              Text(
                                message.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  shadows: [
                                    Shadow(color: Colors.black, blurRadius: 5),
                                  ],
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
                              _chatTag(
                                'Lv.${message.userLevel}',
                                const Color(0xFF7E6BFF),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            message.text,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              height: 1.2,
                              fontWeight: FontWeight.w700,
                              shadows: [
                                Shadow(color: Colors.black, blurRadius: 5),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _chatTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color,
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

  void _showGiftTicker(LiveGiftEvent event) {
    if (!mounted || event.id == _giftTickerEventId) return;
    setState(() {
      _giftTickerEventId = event.id;
      _giftTicker =
          '${event.name} sent ${event.giftName} x${event.quantity} (${event.totalStars}\u2605)';
    });
    _giftTickerTimer?.cancel();
    _giftTickerTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _giftTicker = null);
    });
  }

  Widget _buildGlobalHighValueGiftBanner() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collectionGroup('giftEvents')
          .orderBy('createdAt', descending: true)
          .limit(12)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? const [];
        for (final doc in docs) {
          final data = doc.data();
          final totalStars = _asInt(data['totalStars']);
          final roomId = data['roomId']?.toString() ?? '';
          if (totalStars < 1000 || roomId.isEmpty) continue;
          if (doc.id != _globalGiftEventId) {
            Future.microtask(() => _showGlobalGiftBanner(doc.id, data));
          }
          break;
        }

        final banner = _globalGiftBanner;
        if (banner == null) return const SizedBox.shrink();
        return Positioned(
          left: 24,
          right: 86,
          bottom: 128,
          child: GestureDetector(
            onTap: () {
              if (banner.roomId == widget.liveID) return;
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => LivePage(liveID: banner.roomId),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1FC36B).withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFFFD66B)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1FC36B).withValues(alpha: 0.36),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (banner.hostSvipTier > 0)
                        SvipBadge(tier: banner.hostSvipTier, compact: true),
                      const Text(
                        'Host',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        banner.hostName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${banner.senderName} sent ${banner.giftName} x${banner.quantity} (${banner.totalStars} stars)',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
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

  void _showGlobalGiftBanner(String eventId, Map<String, dynamic> data) {
    if (!mounted || eventId == _globalGiftEventId) return;
    final roomId = data['roomId']?.toString() ?? '';
    if (roomId.isEmpty) return;
    setState(() {
      _globalGiftEventId = eventId;
      _globalGiftBanner = _GlobalGiftBannerData(
        roomId: roomId,
        senderName: data['name']?.toString() ?? 'Viewer',
        hostName: data['hostName']?.toString() ?? 'Host',
        giftName: data['giftName']?.toString() ?? 'Gift',
        quantity: _asInt(data['quantity']).clamp(1, 999),
        totalStars: _asInt(data['totalStars']),
        hostSvipTier: _asInt(data['hostSvipTier']).clamp(0, 3),
      );
    });
    _globalGiftTimer?.cancel();
    _globalGiftTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _globalGiftBanner = null);
    });
  }

  Widget _buildRightActions() {
    return Positioned(
      right: 10,
      bottom: 158,
      width: 54,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          SizedBox(
            height: 210,
            child: Stack(
              children: _hearts
                  .map((heart) => _HeartBubble(heart: heart))
                  .toList(),
            ),
          ),
          GestureDetector(
            onTap: _spawnHeart,
            child: const Icon(
              Icons.favorite,
              color: Color(0xFFFF3A60),
              size: 34,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Positioned(
      left: 10,
      right: 10,
      bottom: 10,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final iconSize = constraints.maxWidth < 360 ? 48.0 : 52.0;
          final iconGlyph = constraints.maxWidth < 360 ? 23.0 : 24.0;
          final labelSize = constraints.maxWidth < 360 ? 10.0 : 11.0;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.62),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: _liveDockAction(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: 'Chat',
                    gradient: const [Color(0xFF34343B), Color(0xFF15151A)],
                    onTap: _openChatComposer,
                    size: iconSize,
                    glyphSize: iconGlyph,
                    labelSize: labelSize,
                  ),
                ),
                Expanded(
                  child: _liveDockAction(
                    icon: Icons.menu_rounded,
                    label: 'More',
                    gradient: const [Color(0xFF52525D), Color(0xFF22222A)],
                    onTap: _openMoreSheet,
                    size: iconSize,
                    glyphSize: iconGlyph,
                    labelSize: labelSize,
                  ),
                ),
                Expanded(
                  child: _liveDockAction(
                    pkBadge: true,
                    label: 'PK',
                    gradient: const [Color(0xFFFF5A98), Color(0xFF8F4BFF)],
                    onTap: _openPkModeSheet,
                    size: iconSize,
                    glyphSize: iconGlyph,
                    labelSize: labelSize,
                  ),
                ),
                Expanded(
                  child: _liveDockAction(
                    icon: Icons.card_giftcard_rounded,
                    label: 'Gifts',
                    gradient: const [Color(0xFFFF69C1), Color(0xFFE63F8C)],
                    onTap: _openGiftBox,
                    size: iconSize,
                    glyphSize: iconGlyph,
                    labelSize: labelSize,
                  ),
                ),
                Expanded(
                  child: _liveDockAction(
                    icon: Icons.ios_share_rounded,
                    label: 'Live share',
                    gradient: const [Color(0xFF4AD1C0), Color(0xFF1A9C92)],
                    onTap: _openLiveShare,
                    size: iconSize,
                    glyphSize: iconGlyph,
                    labelSize: labelSize,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _liveDockAction({
    IconData? icon,
    bool pkBadge = false,
    required String label,
    required List<Color> gradient,
    required VoidCallback? onTap,
    required double size,
    required double glyphSize,
    required double labelSize,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradient,
              ),
              boxShadow: [
                BoxShadow(
                  color: gradient.last.withValues(alpha: 0.45),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: pkBadge
                ? Center(
                    child: Text(
                      'PK',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: glyphSize - 3,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.4,
                      ),
                    ),
                  )
                : Stack(
                    children: [
                      Positioned(
                        top: 5,
                        left: 9,
                        right: 9,
                        child: Container(
                          height: 7,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(9),
                          ),
                        ),
                      ),
                      Center(
                        child: Icon(
                          icon!,
                          color: Colors.white,
                          size: glyphSize,
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: labelSize,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  void _openLiveShare() {
    showLikeehitShareSheet(
      context,
      shareUrl: 'https://likeehit.com/live/${widget.liveID}',
    );
  }

  void _openMoreSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111115),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'More',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GridView.count(
                    shrinkWrap: true,
                    crossAxisCount: 4,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.98,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _moreAction(
                        icon: Icons.remove_red_eye_outlined,
                        label: 'Audience',
                        gradient: const [Color(0xFF3C53E6), Color(0xFF6A7BFF)],
                        onTap: () {
                          Navigator.pop(context);
                          _openAudienceSheet();
                        },
                      ),
                      _moreAction(
                        icon: Icons.person_add_alt_1_rounded,
                        label: 'Invite',
                        gradient: const [Color(0xFF4AD1C0), Color(0xFF1A9C92)],
                        onTap: () {
                          Navigator.pop(context);
                          _openLiveShare();
                        },
                      ),
                      _moreAction(
                        icon: Icons.add_circle_rounded,
                        label: 'Top Up',
                        gradient: const [Color(0xFF6EFF7A), Color(0xFF19B85F)],
                        onTap: () {
                          Navigator.pop(context);
                          _quickTopUpStars();
                        },
                      ),
                      _moreAction(
                        icon: Icons.shield_rounded,
                        label: 'Safety',
                        gradient: const [Color(0xFF67A9FF), Color(0xFF2D6CE0)],
                        onTap: () {
                          Navigator.pop(context);
                          if (widget.isHost) {
                            _openLiveModerationSheet(
                              title: 'Block users',
                              activeTitle: 'Audience',
                              listTitle: 'Blocked',
                              emptyListText: 'No blocked users',
                              actionLabel: 'Block',
                              undoLabel: 'Unblock',
                              actionColor: const Color(0xFFFF5B86),
                              stream: LiveService.instance
                                  .watchLiveBlockedUsers(widget.liveID),
                              onAction: LiveService.instance.blockLiveUser,
                              onUndo: LiveService.instance.unblockLiveUser,
                            );
                          } else {
                            _notifyPkToast('Only host can manage safety.');
                          }
                        },
                      ),
                      _moreAction(
                        icon: Icons.notifications_none_rounded,
                        label: 'Alerts',
                        gradient: const [Color(0xFFF59D3C), Color(0xFFE06B2E)],
                        onTap: () {
                          Navigator.pop(context);
                          _openLiveAlertsSheet();
                        },
                      ),
                      _moreAction(
                        icon: Icons.public_rounded,
                        label: 'Rankings',
                        gradient: const [Color(0xFF8F4BFF), Color(0xFFFF5A98)],
                        onTap: () {
                          Navigator.pop(context);
                          _openWorldRankingsSheet();
                        },
                      ),
                      if (widget.isHost)
                        _moreAction(
                          icon: Icons.tune_rounded,
                          label: 'Host',
                          gradient: const [
                            Color(0xFF7C6DFF),
                            Color(0xFF4A3DFF),
                          ],
                          onTap: () {
                            Navigator.pop(context);
                            _openHostControls();
                          },
                        ),
                      if (widget.isHost)
                        _moreAction(
                          icon: _agora.micMuted
                              ? Icons.mic_off_rounded
                              : Icons.mic_rounded,
                          label: 'Mic',
                          gradient: const [
                            Color(0xFFF55B88),
                            Color(0xFFB63E73),
                          ],
                          onTap: () {
                            Navigator.pop(context);
                            unawaited(_toggleHostMic());
                          },
                        ),
                      if (widget.isHost)
                        _moreAction(
                          icon: _agora.cameraMuted
                              ? Icons.videocam_off_rounded
                              : Icons.videocam_rounded,
                          label: 'Camera',
                          gradient: const [
                            Color(0xFFF59D3C),
                            Color(0xFFE06B2E),
                          ],
                          onTap: () {
                            Navigator.pop(context);
                            unawaited(_toggleHostCamera());
                          },
                        ),
                      if (widget.isHost)
                        _moreAction(
                          icon: Icons.cameraswitch_rounded,
                          label: 'Flip',
                          gradient: const [
                            Color(0xFF6E7CFF),
                            Color(0xFF475DFF),
                          ],
                          onTap: () {
                            Navigator.pop(context);
                            _agora.switchCamera();
                          },
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _moreAction({
    required IconData icon,
    required String label,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradient,
              ),
              boxShadow: [
                BoxShadow(
                  color: gradient.last.withValues(alpha: 0.42),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  void _openPkModeSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF101014),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Live PK',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Pick the battle style you want to start now.',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 16),
                _pkModeCard(
                  title: 'PK For All',
                  subtitle: 'Open battle for any creator to join.',
                  gradient: const [Color(0xFFFF4D8D), Color(0xFFFFA54D)],
                  onTap: () {
                    Navigator.pop(context);
                    _startPkSession(mode: PkMode.forAll);
                  },
                ),
                const SizedBox(height: 12),
                _pkModeCard(
                  title: 'PK With Friends',
                  subtitle: 'Battle only with creators you invite.',
                  gradient: const [Color(0xFF28D9A4), Color(0xFF5BCBFF)],
                  onTap: () {
                    Navigator.pop(context);
                    _startPkSession(mode: PkMode.withFriends);
                  },
                ),
                const SizedBox(height: 12),
                _pkModeCard(
                  title: 'Random PK',
                  subtitle: 'Find a random opponent automatically.',
                  gradient: const [Color(0xFFFF8D4D), Color(0xFFFFC84D)],
                  onTap: () {
                    Navigator.pop(context);
                    _startPkSession(mode: PkMode.random);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _pkModeCard({
    required String title,
    required String subtitle,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradient,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: gradient.last.withValues(alpha: 0.28),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _pkModeLabel(String mode) {
    switch (mode) {
      case 'withFriends':
        return 'PK WITH FRIENDS';
      case 'random':
        return 'RANDOM PK';
      case 'forAll':
      default:
        return 'PK FOR ALL';
    }
  }

  List<RoomGiftLeaderEntry> _topLeadersForSide(
    List<RoomGiftLeaderEntry> leaders,
    String side,
  ) {
    return leaders.where((entry) => entry.pkSide == side).take(3).toList();
  }

  Future<void> _toggleHostMic() async {
    try {
      await _agora.toggleMic();
      if (mounted) {
        setState(() {});
        _notifyPkToast(_agora.micMuted ? 'Mic off' : 'Mic on');
      }
    } catch (error) {
      _notifyPkToast(_cleanError(error));
    }
  }

  Future<void> _toggleHostCamera() async {
    try {
      await _agora.toggleCamera();
      if (mounted) {
        setState(() {});
        _notifyPkToast(_agora.cameraMuted ? 'Camera off' : 'Camera on');
      }
    } catch (error) {
      _notifyPkToast(_cleanError(error));
    }
  }

  void _openHostControls() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF141414),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Host tools',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 14),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 3,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.08,
                    children: [
                      _hostControl(
                        icon: _agora.micMuted
                            ? Icons.mic_off_rounded
                            : Icons.mic_rounded,
                        label: 'Mic',
                        onTap: () {
                          Navigator.pop(context);
                          unawaited(_toggleHostMic());
                        },
                      ),
                      _hostControl(
                        icon: _agora.cameraMuted
                            ? Icons.videocam_off_rounded
                            : Icons.videocam_rounded,
                        label: 'Camera',
                        onTap: () {
                          Navigator.pop(context);
                          unawaited(_toggleHostCamera());
                        },
                      ),
                      _hostControl(
                        icon: Icons.cameraswitch_rounded,
                        label: 'Flip',
                        onTap: () {
                          Navigator.pop(context);
                          _agora.switchCamera();
                        },
                      ),
                      _hostControl(
                        icon: Icons.sports_mma_rounded,
                        label: 'PK',
                        onTap: () {
                          Navigator.pop(context);
                          _openPkModeSheet();
                        },
                      ),
                      _hostControl(
                        icon: Icons.block_rounded,
                        label: 'Block',
                        onTap: () {
                          Navigator.pop(context);
                          _openLiveModerationSheet(
                            title: 'Block users',
                            activeTitle: 'Audience',
                            listTitle: 'Blocked',
                            emptyListText: 'No blocked users',
                            actionLabel: 'Block',
                            undoLabel: 'Unblock',
                            actionColor: const Color(0xFFFF5B86),
                            stream: LiveService.instance.watchLiveBlockedUsers(
                              widget.liveID,
                            ),
                            onAction: LiveService.instance.blockLiveUser,
                            onUndo: LiveService.instance.unblockLiveUser,
                          );
                        },
                      ),
                      _hostControl(
                        icon: Icons.speaker_notes_off_rounded,
                        label: 'Chat off',
                        onTap: () {
                          Navigator.pop(context);
                          _openLiveModerationSheet(
                            title: 'Chat disable',
                            activeTitle: 'Audience',
                            listTitle: 'Disabled',
                            emptyListText: 'No chat disabled users',
                            actionLabel: 'Disable',
                            undoLabel: 'Enable',
                            actionColor: const Color(0xFFFFD166),
                            stream: LiveService.instance
                                .watchLiveChatDisabledUsers(widget.liveID),
                            onAction: LiveService.instance.disableLiveUserChat,
                            onUndo: LiveService.instance.enableLiveUserChat,
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _openLiveModerationSheet({
    required String title,
    required String activeTitle,
    required String listTitle,
    required String emptyListText,
    required String actionLabel,
    required String undoLabel,
    required Color actionColor,
    required Stream<List<PartyModerationUser>> stream,
    required Future<void> Function(String roomId, String uid) onAction,
    required Future<void> Function(String roomId, String uid) onUndo,
  }) {
    if (!widget.isHost) {
      _notifyPkToast('Only host can manage room users.');
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111115),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DefaultTabController(
          length: 2,
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.72,
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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
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
                      fontSize: 15,
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
                        _liveModerationAudienceList(
                          actionLabel: actionLabel,
                          actionColor: actionColor,
                          onAction: onAction,
                        ),
                        _liveModerationAppliedList(
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

  Widget _liveModerationAudienceList({
    required String actionLabel,
    required Color actionColor,
    required Future<void> Function(String roomId, String uid) onAction,
  }) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return StreamBuilder<List<RoomAudienceEntry>>(
      stream: LiveService.instance.watchRoomAudience(widget.liveID),
      builder: (context, snapshot) {
        final users =
            snapshot.data?.where((user) => user.uid != currentUid).toList() ??
            const <RoomAudienceEntry>[];
        if (users.isEmpty) return _liveModerationEmpty('No audience users');
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            return _liveModerationUserTile(
              name: user.name,
              photoUrl: user.photoUrl,
              userLevel: user.userLevel,
              helperText: '${user.currentGiftStars}\u2605 sent in this room',
              actionLabel: actionLabel,
              actionColor: actionColor,
              onTap: () => unawaited(
                _runLiveModerationAction(user.uid, actionLabel, onAction),
              ),
            );
          },
        );
      },
    );
  }

  Widget _liveModerationAppliedList({
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
        if (users.isEmpty) return _liveModerationEmpty(emptyText);
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            return _liveModerationUserTile(
              name: user.name,
              photoUrl: user.photoUrl,
              userLevel: user.userLevel,
              helperText: 'Lv.${user.userLevel}',
              actionLabel: actionLabel,
              actionColor: actionColor,
              onTap: () => unawaited(
                _runLiveModerationAction(user.uid, actionLabel, onAction),
              ),
            );
          },
        );
      },
    );
  }

  Widget _liveModerationEmpty(String text) {
    return Center(
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white60,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Future<void> _runLiveModerationAction(
    String uid,
    String actionLabel,
    Future<void> Function(String roomId, String uid) action,
  ) async {
    try {
      await action(widget.liveID, uid);
      _notifyPkToast('$actionLabel updated');
    } catch (error) {
      _notifyPkToast(_cleanError(error));
    }
  }

  Widget _liveModerationUserTile({
    required String name,
    required String photoUrl,
    required int userLevel,
    required String helperText,
    required String actionLabel,
    required Color actionColor,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: Colors.white12,
            backgroundImage: photoUrl.isNotEmpty
                ? NetworkImage(photoUrl)
                : null,
            child: photoUrl.isEmpty
                ? const Icon(Icons.person, color: Colors.white70)
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
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  helperText.isEmpty ? 'Lv.$userLevel' : helperText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
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

  void _openLiveAlertsSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111115),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.62,
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
                const Padding(
                  padding: EdgeInsets.fromLTRB(18, 16, 18, 10),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Live alerts',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: StreamBuilder<List<LiveGiftEvent>>(
                    stream: LiveService.instance.watchGiftEvents(
                      widget.liveID,
                      limit: 50,
                    ),
                    builder: (context, snapshot) {
                      final events = snapshot.data ?? const <LiveGiftEvent>[];
                      if (events.isEmpty) {
                        return _liveModerationEmpty('No alerts yet');
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
                        itemCount: events.length,
                        itemBuilder: (context, index) {
                          final event = events[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.07),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.card_giftcard_rounded,
                                  color: Color(0xFFFF5B86),
                                  size: 24,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    '${event.name} sent ${event.giftName} x${event.quantity}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${event.totalStars}\u2605',
                                  style: const TextStyle(
                                    color: Color(0xFFFFD66B),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
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
          ),
        );
      },
    );
  }

  Widget _hostControl({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.48),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 25),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _eventPill(
    String text,
    Color color, {
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final pill = Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: 12,
        vertical: trailing == null ? 8 : 7,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing],
        ],
      ),
    );

    if (onTap == null) return pill;
    return GestureDetector(onTap: onTap, child: pill);
  }

  Widget _pkBtn(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  void _openChatComposer() {
    _commentController.clear();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF151515),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 12,
            right: 12,
            top: 12,
            bottom: MediaQuery.of(context).viewInsets.bottom + 12,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Type message...',
                    hintStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: const Color(0xFF232323),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (_) async {
                    final text = _commentController.text.trim();
                    if (text.isEmpty) return;
                    try {
                      await LiveService.instance.sendMessage(
                        widget.liveID,
                        text,
                      );
                      _commentController.clear();
                      if (!context.mounted) return;
                      Navigator.pop(context);
                    } catch (error) {
                      _notifyPkToast(_cleanError(error));
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: () async {
                  final text = _commentController.text.trim();
                  if (text.isEmpty) return;
                  try {
                    await LiveService.instance.sendMessage(widget.liveID, text);
                    _commentController.clear();
                    if (!context.mounted) return;
                    Navigator.pop(context);
                  } catch (error) {
                    _notifyPkToast(_cleanError(error));
                  }
                },
                child: const Text('Send'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openAudienceSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111115),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              top: false,
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.72,
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _audTab(
                          'Audience',
                          _audienceTab,
                          () => setSheetState(() => _audienceTab = true),
                        ),
                        const SizedBox(width: 28),
                        _audTab(
                          'Total leaderboard',
                          !_audienceTab,
                          () => setSheetState(() => _audienceTab = false),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: _audienceTab
                          ? _buildAudienceList()
                          : _buildTotalLeaderboardList(),
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
              top: false,
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
          CircleAvatar(
            radius: 24,
            backgroundColor: rankColor,
            child: CircleAvatar(
              radius: 22,
              backgroundColor: const Color(0xFF15151D),
              backgroundImage: entry.photoUrl.isNotEmpty
                  ? NetworkImage(entry.photoUrl)
                  : null,
              child: entry.photoUrl.isEmpty
                  ? const Icon(Icons.person, color: Colors.white70, size: 20)
                  : null,
            ),
          ),
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

  Widget _buildAudienceList() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: LiveService.instance.watchRoom(widget.liveID),
      builder: (context, roomSnap) {
        final data = roomSnap.data?.data() ?? <String, dynamic>{};
        final ids =
            (data['activeUserIds'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            <String>[];
        return StreamBuilder<List<LiveGiftEvent>>(
          stream: LiveService.instance.watchGiftEvents(
            widget.liveID,
            limit: 200,
          ),
          builder: (context, giftSnap) {
            final giftEvents = giftSnap.data ?? const <LiveGiftEvent>[];
            final giftByUid = <String, int>{};
            for (final event in giftEvents) {
              giftByUid[event.uid] =
                  (giftByUid[event.uid] ?? 0) + event.totalStars;
            }
            final audienceIds = <String>{...ids, ...giftByUid.keys}.toList();
            final rows = audienceIds.map((uid) {
              final gifted = giftByUid[uid] ?? 0;
              return _AudienceRow(uid: uid, giftedStars: gifted);
            }).toList()..sort((a, b) => b.giftedStars.compareTo(a.giftedStars));

            if (rows.isEmpty) {
              return const Center(
                child: Text(
                  'No audience yet',
                  style: TextStyle(color: Colors.white70),
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
              itemCount: rows.length,
              itemBuilder: (context, i) => rows[i],
            );
          },
        );
      },
    );
  }

  Widget _buildTotalLeaderboardList() {
    return StreamBuilder<List<TotalGiftLeaderboardEntry>>(
      stream: LiveService.instance.watchTotalGiftLeaderboard(limit: 200),
      builder: (context, snapshot) {
        final rows = snapshot.data ?? const <TotalGiftLeaderboardEntry>[];
        if (rows.isEmpty) {
          return const Center(
            child: Text(
              'No gift data yet',
              style: TextStyle(color: Colors.white70),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
          itemCount: rows.length,
          itemBuilder: (context, i) {
            final entry = rows[i];
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 34,
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.white12,
                    backgroundImage: entry.photoUrl.isNotEmpty
                        ? NetworkImage(entry.photoUrl)
                        : null,
                    child: entry.photoUrl.isEmpty
                        ? const Icon(Icons.person, color: Colors.white70)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      entry.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  Text(
                    '${entry.totalGiftedStars}\u2605',
                    style: const TextStyle(
                      color: Color(0xFFFFD66B),
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
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

  Widget _audTab(String text, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        text,
        style: TextStyle(
          color: active ? const Color(0xFFFF4D8D) : Colors.white70,
          fontWeight: FontWeight.w800,
          fontSize: 24,
        ),
      ),
    );
  }

  Widget _buildPkHistory() {
    return Positioned(
      top: 248,
      left: 12,
      child: StreamBuilder<List<PkResultEvent>>(
        stream: LiveService.instance.watchPkResults(widget.liveID, limit: 3),
        builder: (context, snapshot) {
          final rows = snapshot.data ?? const <PkResultEvent>[];
          if (rows.isEmpty) return const SizedBox.shrink();
          return Container(
            width: 212,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.38),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PK History',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                ...rows.map(
                  (row) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '${row.leftScore}-${row.rightScore}  ${row.winner.toUpperCase()}  +${row.rewardStars}\u2605',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _startPkSession({PkMode mode = PkMode.forAll}) async {
    if (mode == PkMode.withFriends) {
      final controller = TextEditingController(text: _pkRivalName);
      final pickedRival = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1B1B1F),
          title: const Text(
            'Start PK Battle',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
          content: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Enter friend host name',
              hintStyle: TextStyle(color: Colors.white54),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Start'),
            ),
          ],
        ),
      );
      if (pickedRival == null || pickedRival.isEmpty) return;
      _pkRivalName = pickedRival;
      await _beginPkRequest(mode: mode, targetIdentifier: pickedRival);
      return;
    }

    _pkRivalName = mode == PkMode.random ? 'Random Opponent' : 'Open Match';
    await _beginPkRequest(mode: mode);
  }
}

class _PkRadarPainter extends CustomPainter {
  _PkRadarPainter({required this.progress, required this.accent});

  final double progress;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;
    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = Colors.white.withValues(alpha: 0.08);

    for (var i = 1; i <= 4; i++) {
      canvas.drawCircle(center, radius * (i / 4), basePaint);
    }

    canvas.drawLine(
      Offset(center.dx, center.dy - radius),
      Offset(center.dx, center.dy + radius),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.06)
        ..strokeWidth = 1,
    );
    canvas.drawLine(
      Offset(center.dx - radius, center.dy),
      Offset(center.dx + radius, center.dy),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.06)
        ..strokeWidth = 1,
    );

    final sweepAngle = progress * pi * 2;
    final sweepRect = Rect.fromCircle(center: center, radius: radius * 0.98);
    final sweepPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = SweepGradient(
        colors: [
          accent.withValues(alpha: 0.0),
          accent.withValues(alpha: 0.12),
          accent.withValues(alpha: 0.45),
          accent.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.55, 0.9, 1.0],
        startAngle: sweepAngle - 0.45,
        endAngle: sweepAngle + 0.02,
      ).createShader(sweepRect);

    canvas.drawArc(sweepRect, sweepAngle - 0.42, 0.68, true, sweepPaint);

    final sweepLinePaint = Paint()
      ..color = accent.withValues(alpha: 0.85)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    final sweepEnd = Offset(
      center.dx + cos(sweepAngle) * radius * 0.98,
      center.dy + sin(sweepAngle) * radius * 0.98,
    );
    canvas.drawLine(center, sweepEnd, sweepLinePaint);

    canvas.drawCircle(
      center,
      7,
      Paint()
        ..color = const Color(0xFFFFD54F)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
  }

  @override
  bool shouldRepaint(covariant _PkRadarPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.accent != accent;
  }
}

enum PkMode {
  forAll('forAll'),
  withFriends('withFriends'),
  random('random');

  const PkMode(this.key);
  final String key;
}

class _HeartBubble extends StatelessWidget {
  const _HeartBubble({required this.heart});

  final _FloatingHeart heart;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: heart.duration,
      builder: (context, value, child) {
        final eased = Curves.easeOut.transform(value);
        return Positioned(
          right: heart.right + (1 - eased) * 8,
          bottom: eased * heart.travel,
          child: Opacity(
            opacity: (1 - eased).clamp(0, 1),
            child: Transform.scale(
              scale: 0.7 + eased * 0.6,
              child: Icon(Icons.favorite, size: 24, color: heart.color),
            ),
          ),
        );
      },
    );
  }
}

class _LiveError extends StatelessWidget {
  const _LiveError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.78),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Colors.redAccent,
                size: 54,
              ),
              const SizedBox(height: 18),
              const Text(
                'Live could not start',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white60, fontSize: 15),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: onRetry,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 14,
                  ),
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FloatingHeart {
  const _FloatingHeart({
    required this.key,
    required this.right,
    required this.travel,
    required this.duration,
    required this.color,
  });

  final int key;
  final double right;
  final double travel;
  final Duration duration;
  final Color color;
}

class _VipOverlayData {
  const _VipOverlayData(this.name, this.tier);
  final String name;
  final String tier;
}

class _PkResultOverlayData {
  const _PkResultOverlayData(this.text);
  final String text;
}

class _GlobalGiftBannerData {
  const _GlobalGiftBannerData({
    required this.roomId,
    required this.senderName,
    required this.hostName,
    required this.giftName,
    required this.quantity,
    required this.totalStars,
    required this.hostSvipTier,
  });

  final String roomId;
  final String senderName;
  final String hostName;
  final String giftName;
  final int quantity;
  final int totalStars;
  final int hostSvipTier;
}

class _AudienceRow extends StatelessWidget {
  const _AudienceRow({required this.uid, required this.giftedStars});

  final String uid;
  final int giftedStars;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? <String, dynamic>{};
        final name = data['name']?.toString() ?? 'Viewer';
        final photo =
            data['photoURL']?.toString() ?? data['photoUrl']?.toString() ?? '';
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.white12,
                backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
                child: photo.isEmpty
                    ? const Icon(Icons.person, color: Colors.white70)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ),
              Text(
                '$giftedStars\u2605',
                style: const TextStyle(
                  color: Color(0xFFFFD66B),
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CameraOffSurface extends StatelessWidget {
  const _CameraOffSurface();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Colors.black,
      child: Center(
        child: Icon(
          Icons.videocam_off_rounded,
          color: Colors.white38,
          size: 64,
        ),
      ),
    );
  }
}

class _VipEntryOverlay extends StatelessWidget {
  const _VipEntryOverlay({required this.data});
  final _VipOverlayData data;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: const Alignment(0, -0.08),
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.7, end: 1.0),
          duration: const Duration(milliseconds: 500),
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.scale(
                scale: value,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 18),
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xAA3B2D9E),
                        Color(0xAA4E7BFF),
                        Color(0xAA57A3FF),
                      ],
                    ),
                    border: Border.all(color: const Color(0xCC9BC6FF)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x554E7BFF),
                        blurRadius: 18,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.workspace_premium_rounded,
                        color: Color(0xFFFFE28C),
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          '${data.name} entered as ${data.tier}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PkResultOverlay extends StatelessWidget {
  const _PkResultOverlay({required this.data});
  final _PkResultOverlayData data;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: const Alignment(0, -0.3),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 22),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              colors: [Color(0xCCFF3A74), Color(0xCC6F5BFF)],
            ),
            border: Border.all(color: const Color(0xFFFFC6DA)),
          ),
          child: Text(
            data.text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }
}

class _GiftItem {
  const _GiftItem({
    required this.name,
    required this.stars,
    required this.icon,
    required this.tab,
  });

  final String name;
  final int stars;
  final IconData icon;
  final _GiftTab tab;
}

List<_GiftItem> _buildGiftCatalog() {
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

  return List<_GiftItem>.generate(values.length, (index) {
    final stars = values[index];
    final tab = _GiftTab.values[index % _GiftTab.values.length];
    return _GiftItem(
      name: 'Gift ${index + 1}',
      stars: stars,
      icon: icons[index % icons.length],
      tab: tab,
    );
  });
}

enum _GiftTab {
  gift('Gift'),
  activity('Activity'),
  mysterious('Mysterious Box'),
  special('Special'),
  bag('Bag'),
  custom('Custom');

  const _GiftTab(this.label);
  final String label;
}

class _MegaGiftOverlay extends StatelessWidget {
  const _MegaGiftOverlay({required this.gift});

  final _GiftItem gift;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 0.9,
            colors: [Color(0x66FF2A6D), Color(0x661B1856), Color(0x00000000)],
          ),
        ),
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.7, end: 1.0),
            duration: const Duration(milliseconds: 700),
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Opacity(
                  opacity: value,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        size: 120,
                        color: Color(0xFFFFD66B),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        gift.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${gift.stars} STARS',
                        style: const TextStyle(
                          color: Color(0xFFFFD66B),
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Premium Gift Blast',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

const List<Color> _heartColors = <Color>[
  Color(0xFFFF3E63),
  Color(0xFFFF5A8D),
  Color(0xFFFF2F4A),
  Color(0xFFE646A1),
  Color(0xFFFF6A4C),
];

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return 0;
}

int _activeHostSvipTier(Map<String, dynamic> data) {
  final until = data['hostSvipUntil'];
  if (until is Timestamp && !until.toDate().isAfter(DateTime.now())) return 0;
  return _asInt(data['hostSvipTier']).clamp(0, 3);
}
