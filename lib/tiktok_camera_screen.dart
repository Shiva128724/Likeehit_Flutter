import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'video_edit_preview_screen.dart';
import 'live_page.dart';
import 'audio_discovery_sheet.dart';
import 'models/audio_track.dart';
import 'effects_discovery_sheet.dart';
import 'models/effect_model.dart';
import 'services/live_service.dart';

class TikTokCameraScreen extends StatefulWidget {
  final String? initialAudioUrl;
  final String? initialAudioTitle;

  const TikTokCameraScreen({
    super.key,
    this.initialAudioUrl,
    this.initialAudioTitle,
  });

  @override
  State<TikTokCameraScreen> createState() => _TikTokCameraScreenState();
}

class _TikTokCameraScreenState extends State<TikTokCameraScreen>
    with SingleTickerProviderStateMixin {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;
  bool _isRecording = false;
  bool _isCameraInitialized = false;
  bool _isFlashOn = false;

  // Audio Sync State
  bool _isMusicSelected = false;
  String _selectedMusicTitle = 'Select Music';
  String _selectedMusicUrl = '';
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioPlayer _previewAudioPlayer = AudioPlayer();

  // Speed State
  double _recordingSpeed = 1.0;
  final List<double> _speedOptions = [0.5, 1.0, 2.0, 3.0];

  // Timer State
  int _countdownTimer = 0;
  int _timerOption = 0; // 0 = off, 3 = 3s, 10 = 10s
  Timer? _countdownTimerInstance;

  // Duration State
  final List<int> _durationOptions = [15, 30, 45, 60];
  int _selectedDuration = 15;

  // Recording Progress State
  double _recordingProgress = 0.0;
  Timer? _recordingTimer;
  int _elapsedRecordingMs = 0;

  // Filter State
  List<double> _currentFilterMatrix = [
    1.0,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    1.0,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    1.0,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    1.0,
    0.0,
  ];

  late AnimationController _recordAnimationController;

  @override
  void initState() {
    super.initState();

    // Initialize with passed audio metadata if available
    if (widget.initialAudioUrl != null && widget.initialAudioUrl!.isNotEmpty) {
      _isMusicSelected = true;
      _selectedMusicUrl = widget.initialAudioUrl!;
      _selectedMusicTitle = widget.initialAudioTitle ?? 'Selected Audio';
    }

    _recordAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _checkPermissionsAndInit();
  }

  Future<void> _checkPermissionsAndInit() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.camera,
      Permission.microphone,
    ].request();

    if (statuses[Permission.camera]!.isGranted &&
        statuses[Permission.microphone]!.isGranted) {
      await _initCamera();
    } else {
      debugPrint('Camera or Microphone permissions denied');
    }
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isNotEmpty) {
        _setCamera(_selectedCameraIndex);
      }
    } catch (e) {
      debugPrint('Error fetching cameras: $e');
    }
  }

  Future<void> _setCamera(int cameraIndex) async {
    if (_cameraController != null) {
      await _cameraController!.dispose();
    }

    _cameraController = CameraController(
      _cameras[cameraIndex],
      ResolutionPreset.high,
      enableAudio: true,
    );

    try {
      await _cameraController!.initialize();
      _isFlashOn = false;
      if (mounted) {
        setState(() {
          _selectedCameraIndex = cameraIndex;
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  void _toggleCamera() {
    if (_cameras.length > 1) {
      int newIndex = _selectedCameraIndex == 0 ? 1 : 0;
      _setCamera(newIndex);
    }
  }

  void _toggleFlash() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    try {
      if (_isFlashOn) {
        await _cameraController!.setFlashMode(FlashMode.off);
      } else {
        await _cameraController!.setFlashMode(FlashMode.torch);
      }
      setState(() {
        _isFlashOn = !_isFlashOn;
      });
    } catch (e) {
      debugPrint('Error toggling flash: $e');
    }
  }

  void _toggleSpeed() {
    int currentIndex = _speedOptions.indexOf(_recordingSpeed);
    setState(() {
      _recordingSpeed =
          _speedOptions[(currentIndex + 1) % _speedOptions.length];
    });
  }

  void _showTimerSelection() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text(
            'Select Timer',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.timer_off, color: Colors.white),
                title: const Text('Off', style: TextStyle(color: Colors.white)),
                onTap: () {
                  setState(() => _timerOption = 0);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.timer_3, color: Colors.white),
                title: const Text(
                  '3 Seconds',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  setState(() => _timerOption = 3);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.timer_10, color: Colors.white),
                title: const Text(
                  '10 Seconds',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  setState(() => _timerOption = 10);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickVideoFromGallery() async {
    final ImagePicker picker = ImagePicker();
    final XFile? video = await picker.pickVideo(source: ImageSource.gallery);

    if (video != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoEditPreviewScreen(filePath: video.path),
        ),
      );
    }
  }

  Future<void> _showMusicBottomSheet() async {
    final selectedTrack = await showModalBottomSheet<AudioTrack>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: const AudioDiscoverySheet(),
      ),
    );

    if (selectedTrack != null && mounted) {
      setState(() {
        _isMusicSelected = true;
        _selectedMusicTitle = selectedTrack.title;
        _selectedMusicUrl = selectedTrack.url;
      });
    }
  }

  void _showEffectsBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.45,
        child: EffectsDiscoverySheet(
          onEffectSelected: (EffectModel effect) {
            setState(() {
              _currentFilterMatrix = effect.matrix;
            });
          },
        ),
      ),
    );
  }

  void _onRecordButtonPressed() {
    if (_isRecording) {
      _stopRecording();
    } else {
      if (_timerOption > 0) {
        _runCountdownAndRecord();
      } else {
        _startRecording();
      }
    }
  }

  void _runCountdownAndRecord() {
    setState(() {
      _countdownTimer = _timerOption;
    });
    _countdownTimerInstance = Timer.periodic(const Duration(seconds: 1), (
      timer,
    ) {
      if (!mounted) return;
      if (_countdownTimer <= 1) {
        timer.cancel();
        setState(() {
          _countdownTimer = 0;
        });
        _startRecording();
      } else {
        setState(() {
          _countdownTimer--;
        });
      }
    });
  }

  Future<void> _startRecording() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    try {
      await _cameraController!.startVideoRecording();
      if (_isMusicSelected && _selectedMusicUrl.isNotEmpty) {
        await _audioPlayer.setPlaybackRate(_recordingSpeed);
        await _audioPlayer.play(UrlSource(_selectedMusicUrl));
      }

      if (mounted) {
        setState(() {
          _isRecording = true;
          _recordingProgress = 0.0;
          _elapsedRecordingMs = 0;
        });

        const int updateIntervalMs = 50;
        _recordingTimer = Timer.periodic(
          const Duration(milliseconds: updateIntervalMs),
          (timer) {
            if (!mounted) {
              timer.cancel();
              return;
            }

            setState(() {
              _elapsedRecordingMs += updateIntervalMs;
              _recordingProgress =
                  _elapsedRecordingMs / (_selectedDuration * 1000);
            });

            if (_elapsedRecordingMs >= (_selectedDuration * 1000)) {
              _stopRecording();
            }
          },
        );
      }
    } catch (e) {
      debugPrint('Error starting recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    _recordingTimer?.cancel();

    try {
      XFile videoFile = await _cameraController!.stopVideoRecording();
      if (_isMusicSelected) {
        await _audioPlayer.stop();
      }

      if (mounted) {
        setState(() {
          _isRecording = false;
          _recordingProgress = 0.0;
          _elapsedRecordingMs = 0;
        });

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                VideoEditPreviewScreen(filePath: videoFile.path),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error stopping recording: $e');
    }
  }

  Future<void> _goToLive() async {
    try {
      final roomId = await LiveService.instance.createRoom();
      if (!mounted) return;
      await _releaseCameraForLive();
      if (!mounted) return;
      const isHost = true;
      final liveID = roomId;
      debugPrint('OPEN LIVE PAGE isHost=$isHost liveID=$liveID');
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LivePage(liveID: liveID, isHost: isHost),
        ),
      );
      if (mounted) await _initCamera();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to start live: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _releaseCameraForLive() async {
    final camera = _cameraController;
    _cameraController = null;
    _isCameraInitialized = false;
    if (mounted) setState(() {});
    if (camera == null) return;
    try {
      if (camera.value.isRecordingVideo) {
        await camera.stopVideoRecording();
      }
      await camera.dispose();
      debugPrint('[LikeeHit Live] Released TikTok camera before Agora live.');
    } catch (e) {
      debugPrint(
        '[LikeeHit Live] TikTok camera release before live ignored: $e',
      );
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _audioPlayer.dispose();
    _previewAudioPlayer.dispose();
    _recordAnimationController.dispose();
    _countdownTimerInstance?.cancel();
    _recordingTimer?.cancel();
    super.dispose();
  }

  Widget _buildRightIcon(
    IconData icon,
    String label, {
    VoidCallback? onTap,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Icon(icon, color: color ?? Colors.white, size: 28),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color ?? Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                fontFamily: 'Inter',
                shadows: const [
                  Shadow(
                    color: Colors.black54,
                    blurRadius: 2,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Full Screen Camera Preview with Color Filter
          if (_isCameraInitialized && _cameraController != null)
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _cameraController!.value.previewSize?.height ?? 1,
                  height: _cameraController!.value.previewSize?.width ?? 1,
                  child: ColorFiltered(
                    colorFilter: ColorFilter.matrix(_currentFilterMatrix),
                    child: CameraPreview(_cameraController!),
                  ),
                ),
              ),
            )
          else
            const Center(child: CircularProgressIndicator(color: Colors.white)),

          // 2. Recording Progress Bar (Top)
          if (_isRecording || _recordingProgress > 0)
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 0.0,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: _recordingProgress,
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.redAccent,
                      ),
                      minHeight: 4,
                    ),
                  ),
                ),
              ),
            ),

          // 3. Central Timer Overlay
          if (_countdownTimer > 0)
            Center(
              child: Text(
                '$_countdownTimer',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 120,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(color: Colors.black, blurRadius: 10)],
                ),
              ),
            ),

          // 4. Overlay UI
          SafeArea(
            child: Column(
              children: [
                // Top Row: Close Button & Music Selector
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 30,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      // Top Center: Music Selection Capsule
                      GestureDetector(
                        onTap: _showMusicBottomSheet,
                        child: Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _isMusicSelected
                                  ? Colors.greenAccent
                                  : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.music_note,
                                color: _isMusicSelected
                                    ? Colors.greenAccent
                                    : Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _selectedMusicTitle,
                                style: TextStyle(
                                  color: _isMusicSelected
                                      ? Colors.greenAccent
                                      : Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  fontFamily: 'Inter',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Placeholder for symmetry
                      const SizedBox(width: 48),
                    ],
                  ),
                ),

                // Right Sidebar Column
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),
                          _buildRightIcon(
                            Icons.flip_camera_android,
                            'Flip',
                            onTap: _toggleCamera,
                          ),
                          _buildRightIcon(
                            Icons.speed,
                            '${_recordingSpeed}x',
                            onTap: _toggleSpeed,
                          ),
                          _buildRightIcon(
                            Icons.auto_awesome,
                            'Filters',
                            onTap: _showEffectsBottomSheet,
                          ),
                          _buildRightIcon(
                            Icons.timer,
                            _timerOption == 0 ? 'Timer' : '${_timerOption}s',
                            onTap: _showTimerSelection,
                          ),
                          _buildRightIcon(
                            _isFlashOn ? Icons.flash_on : Icons.flash_off,
                            'Flash',
                            onTap: _toggleFlash,
                            color: _isFlashOn ? Colors.amber : Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Bottom Section: Duration, Record Row, Mode Switcher
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Duration Selector
                    if (!_isRecording && _countdownTimer == 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: _durationOptions.map((duration) {
                            final isSelected = _selectedDuration == duration;
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedDuration = duration;
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                ),
                                child: Text(
                                  '${duration}s',
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.white54,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                    // Record Row: Effects, Record Button, Upload
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32.0,
                        vertical: 8.0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Effects
                          GestureDetector(
                            onTap: _showEffectsBottomSheet,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.black45,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.face,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Effects',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Record Button
                          GestureDetector(
                            onTap: _onRecordButtonPressed,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Outer Ring
                                AnimatedBuilder(
                                  animation: _recordAnimationController,
                                  builder: (context, child) {
                                    return Container(
                                      width: 80,
                                      height: 80,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: _isRecording
                                              ? Colors.redAccent.withValues(
                                                  alpha:
                                                      0.5 +
                                                      (_recordAnimationController
                                                              .value *
                                                          0.5),
                                                )
                                              : Colors.white54,
                                          width: 6,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                // Inner Circle / Square
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: _isRecording ? 30 : 60,
                                  height: _isRecording ? 30 : 60,
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent,
                                    borderRadius: BorderRadius.circular(
                                      _isRecording ? 8 : 30,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Upload
                          GestureDetector(
                            onTap: _pickVideoFromGallery,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.black45,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.upload_file,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Upload',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Mode Switcher (Camera | Live)
                    if (!_isRecording && _countdownTimer == 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0, top: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Camera',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(width: 24),
                            GestureDetector(
                              onTap: _goToLive,
                              child: Text(
                                'Live',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      const SizedBox(
                        height: 52,
                      ), // Placeholder to keep spacing stable when recording
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
