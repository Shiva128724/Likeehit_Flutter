import 'dart:async';
import 'dart:convert';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
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

  static const String defaultChannelName = 'Likeehit';
  static const Duration joinTimeout = Duration(seconds: 12);

  RtcEngine? _engine;
  bool _initializing = false;
  bool _joining = false;
  bool _joined = false;
  bool _released = false;
  bool _micMuted = false;
  bool _cameraMuted = false;
  bool _leaveRequested = false;
  bool _tokenFallbackAttempted = false;
  bool _currentIsHost = false;
  int _localUid = 0;
  String _channelName = defaultChannelName;
  String? _lastError;
  LiveConnectionStatus _status = LiveConnectionStatus.idle;
  final Set<int> _remoteUids = <int>{};

  RtcEngine? get engine => _engine;
  bool get isJoined => _joined;
  bool get isJoining => _joining;
  bool get micMuted => _micMuted;
  bool get cameraMuted => _cameraMuted;
  int get localUid => _localUid;
  String get channelName => _channelName;
  String? get lastError => _lastError;
  LiveConnectionStatus get status => _status;
  List<int> get remoteUids => List.unmodifiable(_remoteUids);
  int get viewerCount => 1 + _remoteUids.length;

  Future<void> join({
    required bool isHost,
    String channelName = defaultChannelName,
    bool audioOnly = false,
  }) async {
    if (_joining || _joined) return;

    _joining = true;
    _joined = false;
    _leaveRequested = false;
    _lastError = null;
    _currentIsHost = isHost;
    _remoteUids.clear();
    _tokenFallbackAttempted = false;
    _channelName = channelName.trim().isEmpty
        ? defaultChannelName
        : channelName.trim();
    _localUid = 0;
    _setStatus(LiveConnectionStatus.initializing);
    _log(
      'Agora init start role=${isHost ? 'host' : 'viewer'} channel=$_channelName uid=$_localUid',
    );

    try {
      await _validateConfig();
      await _ensurePermissions(isHost: isHost);
      await _ensureEngine();

      if (isHost) {
        _micMuted = false;
        _cameraMuted = audioOnly;
        await _engine!.setClientRole(
          role: ClientRoleType.clientRoleBroadcaster,
        );
        await _engine!.enableLocalAudio(true);
        if (!audioOnly) {
          await _engine!.enableLocalVideo(true);
        }
        await _engine!.muteLocalAudioStream(false);
        await _engine!.muteLocalVideoStream(audioOnly);
        if (!audioOnly) {
          await _engine!.startPreview();
          _log('Agora local preview started before join');
        }
      } else {
        _micMuted = true;
        _cameraMuted = true;
        await _engine!.setClientRole(role: ClientRoleType.clientRoleAudience);
        await _engine!.muteLocalAudioStream(true);
        await _engine!.muteLocalVideoStream(true);
      }

      _setStatus(LiveConnectionStatus.joining);
      final token = await _resolveRtcToken(isHost: isHost);
      await _joinWithTokenRetry(
        isHost: isHost,
        token: token,
        audioOnly: audioOnly,
      );

      if (isHost) _log('Agora broadcaster join completed');
    } catch (error) {
      _joined = false;
      _joining = false;
      _lastError = error.toString();
      _log('Agora join failed: $_lastError');
      _setStatus(LiveConnectionStatus.failed);
      rethrow;
    } finally {
      _joining = false;
      _safeNotify();
    }
  }

  Future<void> leave() async {
    _leaveRequested = true;
    _log('Agora leave start');
    try {
      await _engine?.leaveChannel();
      await _engine?.stopPreview();
    } catch (error) {
      _log('Agora leave ignored: $error');
    }
    _joined = false;
    _joining = false;
    _remoteUids.clear();
    _setStatus(LiveConnectionStatus.ended);
  }

  Future<void> release() async {
    if (_released) return;
    _released = true;
    await leave();
    try {
      await _engine?.release();
    } catch (error) {
      _log('Agora release ignored: $error');
    }
    _engine = null;
  }

  Future<void> toggleMic() async {
    if (_engine == null) return;
    _micMuted = !_micMuted;
    if (_micMuted) {
      await _engine!.muteLocalAudioStream(true);
      await _engine!.enableLocalAudio(false);
    } else {
      await _engine!.enableLocalAudio(true);
      await _engine!.muteLocalAudioStream(false);
    }
    await _syncHostMediaOptions();
    _safeNotify();
  }

  Future<void> setLocalAudioMuted(bool muted) async {
    if (_engine == null) return;
    _micMuted = muted;
    if (_micMuted) {
      await _engine!.muteLocalAudioStream(true);
      await _engine!.enableLocalAudio(false);
    } else {
      await _engine!.enableLocalAudio(true);
      await _engine!.muteLocalAudioStream(false);
    }
    await _syncHostMediaOptions();
    _safeNotify();
  }

  Future<void> setAudioBroadcaster({
    required bool enabled,
    bool muted = false,
  }) async {
    if (_engine == null || !_joined) return;
    if (enabled && !kIsWeb) {
      final mic = await Permission.microphone.request();
      if (!mic.isGranted) {
        throw StateError('Microphone permission is required to take a seat.');
      }
    }
    await _engine!.setClientRole(
      role: enabled
          ? ClientRoleType.clientRoleBroadcaster
          : ClientRoleType.clientRoleAudience,
    );
    await _engine!.updateChannelMediaOptions(
      ChannelMediaOptions(
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        clientRoleType: enabled
            ? ClientRoleType.clientRoleBroadcaster
            : ClientRoleType.clientRoleAudience,
        publishCameraTrack: false,
        publishMicrophoneTrack: enabled && !muted,
        autoSubscribeAudio: true,
        autoSubscribeVideo: false,
      ),
    );
    _micMuted = !enabled || muted;
    await _engine!.muteLocalAudioStream(_micMuted);
    _safeNotify();
  }

  Future<void> toggleCamera() async {
    if (_engine == null) return;
    _cameraMuted = !_cameraMuted;
    if (_cameraMuted) {
      await _syncHostMediaOptions();
      await _engine!.muteLocalVideoStream(true);
      await _engine!.stopPreview();
      await _engine!.enableLocalVideo(false);
    } else {
      await _engine!.enableLocalVideo(true);
      await _engine!.startPreview();
      await _engine!.muteLocalVideoStream(false);
      await _syncHostMediaOptions();
    }
    _safeNotify();
  }

  Future<void> _syncHostMediaOptions() async {
    if (_engine == null) return;
    await _engine!.updateChannelMediaOptions(
      ChannelMediaOptions(
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        clientRoleType: _currentIsHost
            ? ClientRoleType.clientRoleBroadcaster
            : ClientRoleType.clientRoleAudience,
        publishMicrophoneTrack: _currentIsHost && !_micMuted,
        publishCameraTrack: _currentIsHost && !_cameraMuted,
        autoSubscribeAudio: true,
        autoSubscribeVideo: true,
      ),
    );
  }

  Future<void> switchCamera() async {
    await _engine?.switchCamera();
  }

  Future<void> reconnect({required bool isHost}) async {
    if (_joining || _joined) return;
    _setStatus(LiveConnectionStatus.reconnecting);
    await join(isHost: isHost, channelName: _channelName);
  }

  Future<void> _ensureEngine() async {
    if (_engine != null) return;
    if (_initializing) {
      while (_initializing) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      return;
    }

    _initializing = true;
    try {
      final engine = createAgoraRtcEngine();
      await engine.initialize(
        RtcEngineContext(
          appId: _appId,
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        ),
      );
      _engine = engine;
      _registerEvents(engine);
      await engine.enableVideo();
      await engine.enableAudio();
      await engine.setVideoEncoderConfiguration(
        const VideoEncoderConfiguration(
          dimensions: VideoDimensions(width: 720, height: 1280),
          frameRate: 24,
          bitrate: 1200,
          orientationMode: OrientationMode.orientationModeFixedPortrait,
          degradationPreference: DegradationPreference.maintainFramerate,
        ),
      );
      _log('Agora engine initialized');
    } finally {
      _initializing = false;
    }
  }

  Future<void> _ensurePermissions({required bool isHost}) async {
    if (kIsWeb || !isHost) return;
    final statuses = await [Permission.camera, Permission.microphone].request();
    final cameraGranted = statuses[Permission.camera]?.isGranted ?? false;
    final micGranted = statuses[Permission.microphone]?.isGranted ?? false;
    _log('Permissions camera=$cameraGranted microphone=$micGranted');
    if (!cameraGranted || !micGranted) {
      throw StateError('Camera and microphone permissions are required.');
    }
  }

  Future<void> _validateConfig() async {
    if (_appId.isEmpty || _appId.contains('replace_with')) {
      throw StateError('AGORA_APP_ID is missing in .env');
    }
    final appIdLooksValid = RegExp(r'^[a-fA-F0-9]{32}$').hasMatch(_appId);
    if (!appIdLooksValid) {
      throw StateError(
        'AGORA_APP_ID format is invalid. Expected 32-char App ID.',
      );
    }
    if (_tokenServerUrl.isEmpty &&
        (_token.isEmpty || _token.contains('replace_with')) &&
        !_allowNoTokenFallback) {
      throw StateError(
        'AGORA_TOKEN_SERVER_URL or AGORA_TEMP_RTC_TOKEN is missing in .env',
      );
    }
    if (_token.isNotEmpty && _token.length < 20) {
      throw StateError('AGORA_TEMP_RTC_TOKEN format is invalid.');
    }
  }

  Future<void> _joinWithTokenRetry({
    required bool isHost,
    required String token,
    required bool audioOnly,
  }) async {
    _log(
      'Agora joinChannel start channel=$_channelName tokenPresent=${token.isNotEmpty}',
    );
    try {
      await _engine!
          .joinChannel(
            token: token,
            channelId: _channelName,
            uid: _localUid,
            options: ChannelMediaOptions(
              channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
              clientRoleType: isHost
                  ? ClientRoleType.clientRoleBroadcaster
                  : ClientRoleType.clientRoleAudience,
              publishCameraTrack: isHost && !audioOnly,
              publishMicrophoneTrack: isHost,
              autoSubscribeAudio: true,
              autoSubscribeVideo: !audioOnly,
            ),
          )
          .timeout(joinTimeout);
    } catch (error) {
      final raw = error.toString().toLowerCase();
      final tokenError =
          raw.contains('token') || raw.contains('errtokenexpired');
      if (_allowNoTokenFallback && tokenError) {
        _log('Retrying Agora join without token (ALLOW_NO_TOKEN=true)');
        await _engine!
            .joinChannel(
              token: '',
              channelId: _channelName,
              uid: _localUid,
              options: ChannelMediaOptions(
                channelProfile:
                    ChannelProfileType.channelProfileLiveBroadcasting,
                clientRoleType: isHost
                    ? ClientRoleType.clientRoleBroadcaster
                    : ClientRoleType.clientRoleAudience,
                publishCameraTrack: isHost && !audioOnly,
                publishMicrophoneTrack: isHost,
                autoSubscribeAudio: true,
                autoSubscribeVideo: !audioOnly,
              ),
            )
            .timeout(joinTimeout);
        return;
      }
      rethrow;
    }
  }

  void _registerEvents(RtcEngine engine) {
    engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          _joined = true;
          _joining = false;
          _leaveRequested = false;
          _lastError = null;
          _log(
            'onJoinChannelSuccess channel=${connection.channelId} uid=${connection.localUid} elapsed=$elapsed',
          );
          _setStatus(LiveConnectionStatus.connected);
        },
        onUserJoined: (connection, remoteUid, elapsed) {
          _remoteUids.add(remoteUid);
          _log('Remote user joined uid=$remoteUid elapsed=$elapsed');
          _safeNotify();
        },
        onUserOffline: (connection, remoteUid, reason) {
          _remoteUids.remove(remoteUid);
          _log('Remote user offline uid=$remoteUid reason=$reason');
          _safeNotify();
        },
        onLocalVideoStateChanged: (source, state, error) {
          _log(
            'onLocalVideoStateChanged source=$source state=$state error=$error',
          );
          if (error != LocalVideoStreamReason.localVideoStreamReasonOk) {
            _lastError = 'Local camera error: $error';
            _setStatus(LiveConnectionStatus.failed);
          }
        },
        onRemoteVideoStateChanged: (connection, remoteUid, state, reason, elapsed) {
          _log(
            'onRemoteVideoStateChanged uid=$remoteUid state=$state reason=$reason elapsed=$elapsed',
          );
        },
        onLeaveChannel: (connection, stats) {
          _joined = false;
          _remoteUids.clear();
          _log('Agora leaveChannel complete');
          _setStatus(LiveConnectionStatus.ended);
        },
        onConnectionStateChanged: (connection, state, reason) {
          _log('onConnectionStateChanged state=$state reason=$reason');
          if (state == ConnectionStateType.connectionStateReconnecting) {
            _setStatus(LiveConnectionStatus.reconnecting);
          } else if (state == ConnectionStateType.connectionStateConnected) {
            _joined = true;
            _setStatus(LiveConnectionStatus.connected);
          } else if (state == ConnectionStateType.connectionStateFailed) {
            _joined = false;
            final reasonText = reason.toString().toLowerCase();
            if (reasonText.contains('token') ||
                reasonText.contains('expired')) {
              _lastError = 'Agora token expired. Trying refresh reconnect...';
              if (_allowNoTokenFallback && !_tokenFallbackAttempted) {
                _tokenFallbackAttempted = true;
                unawaited(_rejoinWithoutToken());
              }
            } else {
              _lastError = 'Agora connection failed: $reason';
            }
            _setStatus(LiveConnectionStatus.failed);
          } else if (state == ConnectionStateType.connectionStateDisconnected &&
              !_leaveRequested &&
              _joined) {
            _joined = false;
            _lastError = 'Agora disconnected: $reason';
            _setStatus(LiveConnectionStatus.failed);
          }
        },
        onError: (error, message) {
          final raw = '$error $message'.toLowerCase();
          if (raw.contains('errtokenexpired') ||
              raw.contains('tokenexpired') ||
              raw.contains('token expired')) {
            _lastError = 'Agora token expired. Trying refresh reconnect...';
            if (_allowNoTokenFallback && !_tokenFallbackAttempted) {
              _tokenFallbackAttempted = true;
              unawaited(_rejoinWithoutToken());
            }
          } else {
            _lastError = 'Agora error $error: $message';
          }
          _log('onError $_lastError');
          _setStatus(LiveConnectionStatus.failed);
        },
        onPermissionError: (permissionType) {
          _lastError = 'Permission error: $permissionType';
          _log(_lastError!);
          _setStatus(LiveConnectionStatus.failed);
        },
      ),
    );
  }

  Future<void> _rejoinWithoutToken() async {
    try {
      await _engine?.leaveChannel();
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (_engine == null) return;
      _log('Agora rejoin without token start');
      await _engine!
          .joinChannel(
            token: '',
            channelId: _channelName,
            uid: _localUid,
            options: ChannelMediaOptions(
              channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
              clientRoleType: _currentIsHost
                  ? ClientRoleType.clientRoleBroadcaster
                  : ClientRoleType.clientRoleAudience,
              publishCameraTrack: _currentIsHost,
              publishMicrophoneTrack: _currentIsHost,
              autoSubscribeAudio: true,
              autoSubscribeVideo: true,
            ),
          )
          .timeout(joinTimeout);
    } catch (error) {
      _log('Agora rejoin without token failed: $error');
      _lastError = 'Live could not start. Token refresh failed.';
      _setStatus(LiveConnectionStatus.failed);
    }
  }

  String get _appId => dotenv.env['AGORA_APP_ID']?.trim() ?? '';

  String get _token {
    return (dotenv.env['AGORA_TEMP_RTC_TOKEN'] ??
            dotenv.env['AGORA_TOKEN'] ??
            '')
        .trim();
  }

  String get _tokenServerUrl =>
      (dotenv.env['AGORA_TOKEN_SERVER_URL'] ?? '').trim();

  Future<String> _resolveRtcToken({required bool isHost}) async {
    if (_tokenServerUrl.isNotEmpty) {
      try {
        final uri = Uri.parse(_tokenServerUrl).replace(
          queryParameters: {
            'channelName': _channelName,
            'uid': _localUid.toString(),
            'role': isHost ? 'host' : 'subscriber',
            'ttlSeconds': '7200',
          },
        );
        _log('Fetching Agora token from server: $uri');
        final response = await http
            .get(uri)
            .timeout(const Duration(seconds: 12));
        if (response.statusCode >= 200 && response.statusCode < 300) {
          final payload = jsonDecode(response.body);
          final token = payload is Map
              ? (payload['token']?.toString() ?? '')
              : '';
          if (token.isNotEmpty) {
            return token;
          }
          throw StateError('Token server returned empty token');
        }
        throw StateError(
          'Token server HTTP ${response.statusCode}: ${response.body}',
        );
      } catch (error) {
        _log('Token server fetch failed: $error');
        rethrow;
      }
    }

    if (_token.isNotEmpty && !_token.contains('replace_with')) {
      return _token;
    }
    if (_allowNoTokenFallback) {
      return '';
    }
    throw StateError('No Agora token available');
  }

  bool get _allowNoTokenFallback {
    final value =
        dotenv.env['AGORA_ALLOW_NO_TOKEN']?.trim().toLowerCase() ?? '';
    if (value.isEmpty) return false;
    return value == '1' || value == 'true' || value == 'yes';
  }

  void _setStatus(LiveConnectionStatus value) {
    if (_status == value || _released) return;
    _status = value;
    _safeNotify();
  }

  void _safeNotify() {
    if (!_released) notifyListeners();
  }

  void _log(String message) {
    debugPrint('[LikeeHit Agora] $message');
  }

  @override
  void dispose() {
    unawaited(release());
    super.dispose();
  }
}
