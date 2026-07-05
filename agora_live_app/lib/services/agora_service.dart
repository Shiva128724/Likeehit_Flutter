import 'dart:async';
import 'dart:math';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:permission_handler/permission_handler.dart';

enum LiveConnectionStatus {
  idle,
  initializing,
  joining,
  connected,
  reconnecting,
  failed,
  ended,
}

class AgoraService extends ChangeNotifier {
  AgoraService();

  static const Duration joinTimeout = Duration(seconds: 5);

  RtcEngine? _engine;
  bool _initializing = false;
  bool _joining = false;
  bool _joined = false;
  bool _disposed = false;
  bool _micMuted = false;
  int _uid = 0;
  String? _channelId;
  String? _lastError;
  LiveConnectionStatus _status = LiveConnectionStatus.idle;
  final Set<int> _remoteUids = <int>{};

  RtcEngine? get engine => _engine;
  bool get isJoined => _joined;
  bool get isJoining => _joining;
  bool get micMuted => _micMuted;
  int get uid => _uid;
  String? get channelId => _channelId;
  String? get lastError => _lastError;
  LiveConnectionStatus get status => _status;
  List<int> get remoteUids => List.unmodifiable(_remoteUids);
  int get viewerCount => 1 + _remoteUids.length;

  Future<void> join({
    required String channelId,
    required bool isHost,
  }) async {
    if (_joining || _joined) return;
    _joining = true;
    _lastError = null;
    _channelId = channelId.trim();
    _uid = _makeUid();
    _setStatus(LiveConnectionStatus.initializing);
    _log('init start');

    try {
      if (_channelId == null || _channelId!.isEmpty) {
        throw StateError('Channel ID cannot be empty.');
      }

      await _ensurePermissions(isHost: isHost);
      await _ensureEngine();

      if (isHost) {
        _log('preview start');
        await _engine!.enableLocalVideo(true);
        await _engine!.muteLocalAudioStream(false);
        await _engine!.startPreview();
      }

      _log('join start');
      _setStatus(LiveConnectionStatus.joining);
      await _engine!
          .joinChannel(
            token: dotenv.env['AGORA_TOKEN']?.trim() ?? '',
            channelId: _channelId!,
            uid: _uid,
            options: ChannelMediaOptions(
              channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
              clientRoleType: isHost
                  ? ClientRoleType.clientRoleBroadcaster
                  : ClientRoleType.clientRoleAudience,
              publishCameraTrack: isHost,
              publishMicrophoneTrack: isHost,
              autoSubscribeAudio: true,
              autoSubscribeVideo: true,
            ),
          )
          .timeout(joinTimeout);

      _log('publish start');
      if (isHost) {
        await _engine!.muteLocalAudioStream(false);
        await _engine!.enableLocalVideo(true);
      }
    } catch (error) {
      _lastError = error.toString();
      _log('failure $_lastError');
      _setStatus(LiveConnectionStatus.failed);
      rethrow;
    } finally {
      _joining = false;
      _safeNotify();
    }
  }

  Future<void> leave() async {
    _log('dispose');
    try {
      await _engine?.leaveChannel();
      await _engine?.stopPreview();
    } catch (error) {
      _log('leave ignored: $error');
    }
    _joined = false;
    _joining = false;
    _remoteUids.clear();
    _setStatus(LiveConnectionStatus.ended);
  }

  Future<void> disposeEngine() async {
    _disposed = true;
    await leave();
    try {
      await _engine?.release();
    } catch (error) {
      _log('release ignored: $error');
    }
    _engine = null;
  }

  Future<void> toggleMic() async {
    if (_engine == null) return;
    _micMuted = !_micMuted;
    await _engine!.muteLocalAudioStream(_micMuted);
    _safeNotify();
  }

  Future<void> switchCamera() async {
    if (_engine == null) return;
    await _engine!.switchCamera();
  }

  Future<void> reconnect({required bool isHost}) async {
    if (_joining || _joined || _channelId == null || _channelId!.isEmpty) {
      return;
    }
    _setStatus(LiveConnectionStatus.reconnecting);
    await join(channelId: _channelId!, isHost: isHost);
  }

  Future<void> _ensureEngine() async {
    if (_engine != null || _initializing) {
      while (_initializing) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      return;
    }

    final appId = dotenv.env['AGORA_APP_ID']?.trim() ?? '';
    if (appId.isEmpty) {
      throw StateError('AGORA_APP_ID is missing in .env');
    }

    _initializing = true;
    try {
      final engine = createAgoraRtcEngine();
      await engine.initialize(
        RtcEngineContext(
          appId: appId,
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        ),
      );
      _engine = engine;
      _registerEvents(engine);
      await engine.enableVideo();
      await engine.setVideoEncoderConfiguration(
        const VideoEncoderConfiguration(
          codecType: VideoCodecType.videoCodecH264,
          dimensions: VideoDimensions(width: 540, height: 960),
          frameRate: 24,
          bitrate: 800,
          orientationMode: OrientationMode.orientationModeFixedPortrait,
          degradationPreference: DegradationPreference.maintainFramerate,
        ),
      );
    } finally {
      _initializing = false;
    }
  }

  Future<void> _ensurePermissions({required bool isHost}) async {
    if (kIsWeb || !isHost) return;
    final statuses = await [
      Permission.camera,
      Permission.microphone,
    ].request();
    final cameraGranted = statuses[Permission.camera]?.isGranted ?? false;
    final micGranted = statuses[Permission.microphone]?.isGranted ?? false;
    if (!cameraGranted || !micGranted) {
      throw StateError('Camera and microphone permissions are required.');
    }
  }

  void _registerEvents(RtcEngine engine) {
    engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          _joined = true;
          _joining = false;
          _lastError = null;
          _log('success');
          _setStatus(LiveConnectionStatus.connected);
        },
        onUserJoined: (connection, remoteUid, elapsed) {
          _remoteUids.add(remoteUid);
          _safeNotify();
        },
        onUserOffline: (connection, remoteUid, reason) {
          _remoteUids.remove(remoteUid);
          _safeNotify();
        },
        onLeaveChannel: (connection, stats) {
          _joined = false;
          _remoteUids.clear();
          _setStatus(LiveConnectionStatus.ended);
        },
        onConnectionStateChanged: (connection, state, reason) {
          if (state == ConnectionStateType.connectionStateReconnecting) {
            _setStatus(LiveConnectionStatus.reconnecting);
          } else if (state == ConnectionStateType.connectionStateConnected) {
            _joined = true;
            _setStatus(LiveConnectionStatus.connected);
          } else if (state == ConnectionStateType.connectionStateFailed) {
            _joined = false;
            _setStatus(LiveConnectionStatus.failed);
          } else if (state == ConnectionStateType.connectionStateDisconnected) {
            _joined = false;
            if (_status != LiveConnectionStatus.ended) {
              _setStatus(LiveConnectionStatus.failed);
            }
          }
        },
        onError: (error, message) {
          _lastError = '$error $message';
          _log('failure $_lastError');
          _setStatus(LiveConnectionStatus.failed);
        },
        onPermissionError: (permissionType) {
          _lastError = 'Permission error: $permissionType';
          _setStatus(LiveConnectionStatus.failed);
        },
      ),
    );
  }

  int _makeUid() {
    final seed = DateTime.now().microsecondsSinceEpoch;
    return 100000 + Random(seed).nextInt(899999999);
  }

  void _setStatus(LiveConnectionStatus value) {
    if (_status == value || _disposed) return;
    _status = value;
    _safeNotify();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  void _log(String message) {
    debugPrint('[AgoraLive] $message');
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(disposeEngine());
    super.dispose();
  }
}
