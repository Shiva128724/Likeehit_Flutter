import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../../services/agora_service.dart';
import '../../widgets/live_control_button.dart';

class LivePage extends StatefulWidget {
  const LivePage({
    super.key,
    required this.channelId,
    required this.isHost,
  });

  final String channelId;
  final bool isHost;

  @override
  State<LivePage> createState() => _LivePageState();
}

class _LivePageState extends State<LivePage> with WidgetsBindingObserver {
  late final AgoraService _agora;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _opening = true;
  bool _leaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _agora = AgoraService()..addListener(_onAgoraChanged);
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      _handleConnectivity,
    );
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
    } else if (state == AppLifecycleState.resumed && _agora.isJoined) {
      unawaited(_agora.engine!.muteLocalVideoStream(false));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySubscription?.cancel();
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
      await _agora.join(channelId: widget.channelId, isHost: widget.isHost);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  void _onAgoraChanged() {
    if (mounted) setState(() {});
  }

  void _handleConnectivity(List<ConnectivityResult> results) {
    final offline = results.every((result) => result == ConnectivityResult.none);
    if (offline || !mounted) return;
    if (_agora.status == LiveConnectionStatus.failed) {
      unawaited(_agora.reconnect(isHost: widget.isHost));
    }
  }

  Future<void> _leave() async {
    if (_leaving) return;
    setState(() => _leaving = true);
    await _agora.leave();
    if (mounted) Navigator.of(context).pop();
  }

  Widget _videoSurface() {
    final engine = _agora.engine;
    if (engine == null) {
      return const ColoredBox(color: Colors.black);
    }

    if (widget.isHost) {
      return AgoraVideoView(
        controller: VideoViewController(
          rtcEngine: engine,
          canvas: const VideoCanvas(uid: 0),
          useAndroidSurfaceView: true,
        ),
      );
    }

    final remoteUid = _agora.remoteUids.isEmpty ? null : _agora.remoteUids.first;
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
        connection: RtcConnection(channelId: widget.channelId),
        useAndroidSurfaceView: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = _agora.status;
    final busy = _opening ||
        status == LiveConnectionStatus.initializing ||
        status == LiveConnectionStatus.joining;

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
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.55),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.65),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              Positioned(
                top: 14,
                left: 14,
                right: 14,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        widget.isHost ? 'HOST' : 'LIVE',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.channelId,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const Icon(Icons.visibility_rounded, size: 18),
                    const SizedBox(width: 4),
                    Text('${_agora.viewerCount}'),
                  ],
                ),
              ),
              if (busy)
                const Center(
                  child: CircularProgressIndicator(color: Colors.redAccent),
                ),
              if (_agora.status == LiveConnectionStatus.reconnecting)
                const Positioned(
                  top: 58,
                  left: 14,
                  right: 14,
                  child: _StatusPill(text: 'Reconnecting...'),
                ),
              if (_error != null)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: Colors.redAccent,
                          size: 42,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _joinLive,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 22,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.isHost) ...[
                      LiveControlButton(
                        icon: _agora.micMuted
                            ? Icons.mic_off_rounded
                            : Icons.mic_rounded,
                        label: 'Mic',
                        onTap: _agora.toggleMic,
                      ),
                      const SizedBox(width: 16),
                      LiveControlButton(
                        icon: Icons.cameraswitch_rounded,
                        label: 'Flip',
                        onTap: _agora.switchCamera,
                      ),
                      const SizedBox(width: 16),
                    ],
                    LiveControlButton(
                      icon: Icons.close_rounded,
                      label: 'End',
                      danger: true,
                      onTap: _leave,
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
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}
