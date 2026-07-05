import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:camera/camera.dart';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';

import 'live_page.dart';
import 'main.dart'; // To access the global 'cameras' list
import 'services/live_service.dart';
import 'video_edit_preview_screen.dart';

class CreateContentScreen extends StatefulWidget {
  const CreateContentScreen({super.key});

  @override
  State<CreateContentScreen> createState() => _CreateContentScreenState();
}

class _CreateContentScreenState extends State<CreateContentScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  int _selectedCameraIndex = 0;

  final List<String> _modes = ['15s', '60s', 'Templates', 'LIVE'];
  int _selectedModeIndex = 1; // Default to '60s'

  final TextEditingController _liveTitleController = TextEditingController();

  bool _isRecording = false;
  int _recordDuration = 0;
  Timer? _recordTimer;

  bool _isFlashOn = false;

  int _selectedEffectIndex = 0;
  bool _isBeautifyOn = false;

  double _currentSpeed = 1.0;
  bool _showSpeedBar = false;
  final List<double> _speedOptions = [0.3, 0.5, 1.0, 2.0, 3.0];

  int _selectedTimerSeconds = 0; // 0 means no timer
  bool _isCountingDown = false;
  int _currentCountdownValue = 0;
  Timer? _countdownTimer;

  // Music handling
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _selectedMusicUrl;
  String? _selectedMusicName;
  bool _isPlayingPreview = false;
  int? _previewingIndex;

  bool _isProcessing = false;

  final List<Map<String, dynamic>> _recordedSegments = [];
  int _totalSegmentsDuration = 0; // In seconds

  final List<Map<String, String>> _mockSounds = [
    {
      'name': 'Trending Track 1',
      'url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
    },
    {
      'name': 'Trending Track 2',
      'url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
    },
    {
      'name': 'Trending Track 3',
      'url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3',
    },
    {
      'name': 'Trending Track 4',
      'url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3',
    },
    {
      'name': 'Trending Track 5',
      'url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-8.mp3',
    },
  ];

  final List<String> _effectNames = [
    'Normal',
    'Warm',
    'Cool',
    'Mono',
    'Sepia',
    'Pink',
    'Vivid',
    'Dark',
  ];

  final List<ColorFilter> _filters = [
    const ColorFilter.mode(Colors.transparent, BlendMode.dst),
    const ColorFilter.matrix([
      1.1,
      0,
      0,
      0,
      20,
      0,
      1.0,
      0,
      0,
      0,
      0,
      0,
      0.9,
      0,
      -10,
      0,
      0,
      0,
      1,
      0,
    ]),
    const ColorFilter.matrix([
      0.9,
      0,
      0,
      0,
      -10,
      0,
      1.0,
      0,
      0,
      0,
      0,
      0,
      1.2,
      0,
      20,
      0,
      0,
      0,
      1,
      0,
    ]),
    const ColorFilter.matrix([
      0.21,
      0.72,
      0.07,
      0,
      0,
      0.21,
      0.72,
      0.07,
      0,
      0,
      0.21,
      0.72,
      0.07,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ]),
    const ColorFilter.matrix([
      0.39,
      0.77,
      0.19,
      0,
      0,
      0.35,
      0.69,
      0.17,
      0,
      0,
      0.27,
      0.53,
      0.13,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ]),
    const ColorFilter.matrix([
      1.2,
      0,
      0,
      0,
      0,
      0,
      0.9,
      0,
      0,
      0,
      0,
      0,
      1.1,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ]),
    const ColorFilter.matrix([
      1.3,
      0,
      0,
      0,
      0,
      0,
      1.3,
      0,
      0,
      0,
      0,
      0,
      1.3,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ]),
    const ColorFilter.matrix([
      0.7,
      0,
      0,
      0,
      0,
      0,
      0.7,
      0,
      0,
      0,
      0,
      0,
      0.7,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ]),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (cameras.isNotEmpty) {
      _initCamera(cameras[_selectedCameraIndex]);
    }
  }

  Future<void> _initCamera(CameraDescription cameraDescription) async {
    if (_controller != null) {
      await _controller!.dispose();
    }

    _controller = CameraController(
      cameraDescription,
      ResolutionPreset.high,
      enableAudio: true,
    );

    _initializeControllerFuture = _controller!.initialize();

    try {
      await _initializeControllerFuture;
    } catch (e) {
      debugPrint('Camera Error: $e');
    }

    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _liveTitleController.dispose();
    _recordTimer?.cancel();
    _countdownTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _controller;

    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera(cameraController.description);
    }
  }

  Future<void> _onCapturePressed() async {
    if (_modes[_selectedModeIndex] == 'LIVE') {
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
        if (mounted && cameras.isNotEmpty) {
          await _initCamera(cameras[_selectedCameraIndex]);
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to start live: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } else {
      if (_isRecording) {
        _stopRecording();
      } else {
        if (_selectedTimerSeconds > 0) {
          _startCountdown();
        } else {
          _startRecording();
        }
      }
    }
  }

  Future<void> _releaseCameraForLive() async {
    final camera = _controller;
    _controller = null;
    _initializeControllerFuture = null;
    if (mounted) setState(() {});
    if (camera == null) return;
    try {
      if (camera.value.isRecordingVideo) {
        await camera.stopVideoRecording();
      }
      await camera.dispose();
      debugPrint('[LikeeHit Live] Released Flutter camera before Agora live.');
    } catch (e) {
      debugPrint('[LikeeHit Live] Camera release before live ignored: $e');
    }
  }

  void _startCountdown() {
    setState(() {
      _isCountingDown = true;
      _currentCountdownValue = _selectedTimerSeconds;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_currentCountdownValue > 1) {
          _currentCountdownValue--;
        } else {
          _isCountingDown = false;
          _countdownTimer?.cancel();
          _startRecording();
        }
      });
    });
  }

  Future<void> _startRecording() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    if (_controller!.value.isRecordingVideo) return;

    try {
      if (_selectedMusicUrl != null) {
        // Sync music playback rate with recording speed
        await _audioPlayer.setPlaybackRate(1.0 / _currentSpeed);

        // Seek to the current total duration to keep music in sync across segments
        int seekPos = (_totalSegmentsDuration * 1000).toInt();
        await _audioPlayer.seek(Duration(milliseconds: seekPos));
        await _audioPlayer.play(UrlSource(_selectedMusicUrl!));
      }
      await _controller!.startVideoRecording();
      setState(() {
        _isRecording = true;
        _recordDuration = 0;
      });
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _recordDuration++;
          if (_totalSegmentsDuration + _recordDuration >=
              (_selectedModeIndex == 0 ? 15 : 60)) {
            _stopRecording();
          }
        });
      });
    } catch (e) {
      debugPrint('Error starting recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    if (_controller == null || !_controller!.value.isRecordingVideo) return;

    _recordTimer?.cancel();
    await _audioPlayer.stop();
    try {
      XFile file = await _controller!.stopVideoRecording();
      setState(() {
        _isRecording = false;
        _recordedSegments.add({'path': file.path, 'duration': _recordDuration});
        _totalSegmentsDuration += _recordDuration;
      });
    } catch (e) {
      debugPrint('Error stopping recording: $e');
    }
  }

  void _deleteLastSegment() {
    if (_recordedSegments.isNotEmpty) {
      setState(() {
        final lastSegment = _recordedSegments.removeLast();
        _totalSegmentsDuration -= (lastSegment['duration'] as int);
        _showFeedback("Last segment removed");
      });
    }
  }

  Future<void> _finishRecording() async {
    if (_recordedSegments.isEmpty) return;
    await _processVideo();
  }

  Future<void> _processVideo() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final Directory extDir = Directory.systemTemp;
      final String outPath =
          '${extDir.path}/processed_${DateTime.now().millisecondsSinceEpoch}.mp4';

      String filterString = "";
      // Map filters to FFmpeg filters
      switch (_selectedEffectIndex) {
        case 1: // Warm
          filterString = "eq=brightness=0.05:saturation=1.2:contrast=1.1";
          break;
        case 2: // Cool
          filterString = "colorbalance=rs=0.1:gs=0:bs=0.2";
          break;
        case 3: // Mono
          filterString = "colorchannelmixer=.3:.4:.3:0:.3:.4:.3:0:.3:.4:.3";
          break;
        case 4: // Sepia
          filterString =
              "colorchannelmixer=.393:.769:.189:0:.349:.686:.168:0:.272:.534:.131";
          break;
        case 5: // Pink
          filterString = "hue=h=300:s=1.2";
          break;
        case 6: // Vivid
          filterString = "curves=all='0/0 0.5/0.6 1/1'";
          break;
        case 7: // Dark
          filterString = "eq=brightness=-0.1:contrast=1.2";
          break;
        default:
          filterString = "";
      }

      // Add beautify effect to processing if enabled
      if (_isBeautifyOn) {
        String beautifyFilter = "eq=brightness=0.05:contrast=1.05";
        filterString = filterString.isEmpty
            ? beautifyFilter
            : "$filterString,$beautifyFilter";
      }

      String command = "";
      String speedFilter = "";
      if (_currentSpeed != 1.0) {
        double setpts = 1.0 / _currentSpeed;
        speedFilter = "setpts=$setpts*PTS";
        if (filterString.isNotEmpty) {
          filterString = "$filterString,$speedFilter";
        } else {
          filterString = speedFilter;
        }
      }

      // Handle multiple segments
      String inputArgs = "";
      String concatFilter = "";
      for (int i = 0; i < _recordedSegments.length; i++) {
        inputArgs += "-i ${_recordedSegments[i]['path']} ";
        concatFilter += "[$i:v][$i:a]";
      }
      concatFilter += "concat=n=${_recordedSegments.length}:v=1:a=1[v][a]";

      if (_selectedMusicUrl != null) {
        // Merge segments, apply filters, and add music
        command =
            "$inputArgs -i $_selectedMusicUrl -filter_complex \"$concatFilter${filterString.isNotEmpty ? ";[v]$filterString[outv]" : ""}\" "
            "-map \"${filterString.isNotEmpty ? "[outv]" : "[v]"}\" -map ${_recordedSegments.length}:a -c:v libx264 -preset ultrafast -c:a aac -shortest -y $outPath";
      } else {
        // Merge segments and apply filters
        command =
            "$inputArgs -filter_complex \"$concatFilter${filterString.isNotEmpty ? ";[v]$filterString[outv]" : ""}\" "
            "-map \"${filterString.isNotEmpty ? "[outv]" : "[v]"}\" -map \"[a]\" ${(_currentSpeed != 1.0) ? "-af \"atempo=$_currentSpeed\"" : ""} -c:v libx264 -preset ultrafast -c:a aac -y $outPath";
      }

      if (command.isNotEmpty) {
        debugPrint("FFmpeg command stub (skipped): $command");
        await Future.delayed(const Duration(milliseconds: 500));
        setState(() {
          _isProcessing = false;
        });
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VideoEditPreviewScreen(filePath: outPath),
            ),
          );
        }
      } else {
        setState(() {
          _isProcessing = false;
        });
        if (mounted && _recordedSegments.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VideoEditPreviewScreen(
                filePath: _recordedSegments.last['path'],
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Error in processing: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  void _showSoundSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Discover Sounds',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    if (_selectedMusicUrl != null)
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedMusicUrl = null;
                            _selectedMusicName = null;
                          });
                          setModalState(() {});
                          _audioPlayer.stop();
                        },
                        child: const Text(
                          'Remove',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _mockSounds.length,
                  itemBuilder: (context, index) {
                    final sound = _mockSounds[index];
                    final isPreviewing =
                        _previewingIndex == index && _isPlayingPreview;
                    final isSelected = _selectedMusicUrl == sound['url'];

                    return ListTile(
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.redAccent.withValues(alpha: 0.1)
                              : Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                          border: isSelected
                              ? Border.all(color: Colors.redAccent, width: 2)
                              : null,
                        ),
                        child: Icon(
                          isSelected ? Icons.check : Icons.music_note,
                          color: isSelected ? Colors.redAccent : Colors.black54,
                        ),
                      ),
                      title: Text(
                        sound['name']!,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      subtitle: const Text(
                        'Popular Creator',
                        style: TextStyle(color: Colors.grey),
                      ),
                      trailing: IconButton(
                        icon: Icon(
                          isPreviewing
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_filled,
                          size: 32,
                          color: Colors.redAccent,
                        ),
                        onPressed: () async {
                          if (isPreviewing) {
                            await _audioPlayer.pause();
                            setModalState(() => _isPlayingPreview = false);
                          } else {
                            await _audioPlayer.play(UrlSource(sound['url']!));
                            setModalState(() {
                              _previewingIndex = index;
                              _isPlayingPreview = true;
                            });
                          }
                        },
                      ),
                      onTap: () {
                        setState(() {
                          _selectedMusicUrl = sound['url'];
                          _selectedMusicName = sound['name'];
                        });
                        _audioPlayer.stop();
                        Navigator.pop(context);
                        _showFeedback('Selected: $_selectedMusicName');
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showUploadSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const _GalleryBottomSheet(),
    );
  }

  void _toggleFlip() {
    if (cameras.length < 2) return;

    _selectedCameraIndex = (_selectedCameraIndex + 1) % cameras.length;
    _initCamera(cameras[_selectedCameraIndex]);
  }

  void _toggleFlash() {
    if (_controller == null || !_controller!.value.isInitialized) return;

    setState(() {
      _isFlashOn = !_isFlashOn;
    });

    _controller!.setFlashMode(_isFlashOn ? FlashMode.torch : FlashMode.off);
  }

  void _toggleBeautify() {
    setState(() {
      _isBeautifyOn = !_isBeautifyOn;
    });
    _showFeedback(_isBeautifyOn ? 'Beautify ON' : 'Beautify OFF');
  }

  void _showEffectsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black26,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: 220,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white30,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Effects & Filters',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Inter',
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() => _selectedEffectIndex = 0);
                        setModalState(() {});
                      },
                      child: const Text(
                        'Reset',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  itemCount: _effectNames.length,
                  itemBuilder: (context, index) {
                    final isSelected = _selectedEffectIndex == index;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedEffectIndex = index;
                        });
                        setModalState(() {});
                      },
                      child: Container(
                        width: 75,
                        margin: const EdgeInsets.only(right: 12),
                        child: Column(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.redAccent
                                      : Colors.white24,
                                  width: 2.5,
                                ),
                                color: isSelected
                                    ? Colors.redAccent.withValues(alpha: 0.1)
                                    : Colors.white10,
                              ),
                              child: Icon(
                                _getEffectIcon(index),
                                color: isSelected
                                    ? Colors.redAccent
                                    : Colors.white70,
                                size: 28,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _effectNames[index],
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.white54,
                                fontSize: 11,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                fontFamily: 'Inter',
                              ),
                              textAlign: TextAlign.center,
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
      ),
    );
  }

  IconData _getEffectIcon(int index) {
    switch (index) {
      case 0:
        return Icons.block;
      case 1:
        return Icons.wb_sunny_outlined;
      case 2:
        return Icons.ac_unit;
      case 3:
        return Icons.filter_b_and_w;
      case 4:
        return Icons.history_edu;
      case 5:
        return Icons.auto_fix_high;
      case 6:
        return Icons.flare;
      case 7:
        return Icons.nightlight_round;
      default:
        return Icons.auto_awesome;
    }
  }

  void _showTimerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: 200,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white30,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'Set Timer',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [3, 10].map((seconds) {
                  final isSelected = _selectedTimerSeconds == seconds;
                  return GestureDetector(
                    onTap: () {
                      setState(
                        () => _selectedTimerSeconds = isSelected ? 0 : seconds,
                      );
                      setModalState(() {});
                      Navigator.pop(context);
                      _showFeedback(
                        _selectedTimerSeconds > 0
                            ? 'Timer set to $seconds seconds'
                            : 'Timer Off',
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.redAccent : Colors.white10,
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(
                          color: isSelected ? Colors.redAccent : Colors.white24,
                        ),
                      ),
                      child: Text(
                        '${seconds}s',
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFeedback(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 1)),
    );
  }

  Widget _buildRightControlIcon(
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          splashColor: Colors.white24,
          child: Column(
            children: [
              Icon(icon, color: Colors.white, size: 28),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Inter',
                  shadows: [
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLiveMode = _modes[_selectedModeIndex] == 'LIVE';

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera Preview
          Positioned.fill(
            child: FutureBuilder<void>(
              future: _initializeControllerFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done &&
                    _controller != null &&
                    _controller!.value.isInitialized) {
                  Widget preview = CameraPreview(_controller!);

                  // Apply Beautify (subtle glow/brightness)
                  if (_isBeautifyOn) {
                    preview = ColorFiltered(
                      colorFilter: const ColorFilter.matrix([
                        1.05,
                        0,
                        0,
                        0,
                        10,
                        0,
                        1.05,
                        0,
                        0,
                        10,
                        0,
                        0,
                        1.05,
                        0,
                        10,
                        0,
                        0,
                        0,
                        1,
                        0,
                      ]),
                      child: preview,
                    );
                  }

                  // Apply selected filter
                  return ColorFiltered(
                    colorFilter: _filters[_selectedEffectIndex],
                    child: preview,
                  );
                } else {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                }
              },
            ),
          ),

          // Recording indicator
          if (_isRecording && !isLiveMode)
            Positioned(
              top: 100,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'REC ${_formatDuration(_recordDuration)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
              ),
            ),

          // Countdown Overlay
          if (_isCountingDown)
            Positioned.fill(
              child: Container(
                color: Colors.black26,
                child: Center(
                  child: Text(
                    '$_currentCountdownValue',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 120,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Inter',
                      shadows: [Shadow(color: Colors.black54, blurRadius: 20)],
                    ),
                  ),
                ),
              ),
            ),

          // Processing Overlay
          if (_isProcessing)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 16),
                      Text(
                        'Processing video...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          SafeArea(
            child: Column(
              children: [
                // Top Control Bar
                // Multi-clip Progress Bar
                if (!isLiveMode &&
                    (_isRecording || _recordedSegments.isNotEmpty))
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Stack(
                      children: [
                        Container(
                          height: 6,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor:
                              ((_totalSegmentsDuration + _recordDuration) /
                                      (_selectedModeIndex == 0 ? 15 : 60))
                                  .clamp(0.0, 1.0),
                          child: Container(
                            height: 6,
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 30,
                        ),
                        onPressed: () {
                          if (_isRecording) {
                            _stopRecording();
                          }
                          Navigator.pop(context);
                        },
                      ),

                      Expanded(
                        child: isLiveMode
                            ? Padding(
                                padding: const EdgeInsets.only(
                                  top: 8.0,
                                  left: 8.0,
                                  right: 16.0,
                                ),
                                child: TextField(
                                  controller: _liveTitleController,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.center,
                                  decoration: InputDecoration(
                                    hintText: 'Add a title for your LIVE...',
                                    hintStyle: const TextStyle(
                                      color: Colors.white54,
                                      fontWeight: FontWeight.normal,
                                    ),
                                    filled: true,
                                    fillColor: Colors.black45,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(24),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              )
                            : Align(
                                alignment: Alignment.topCenter,
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: GestureDetector(
                                    onTap: _showSoundSheet,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black45,
                                        borderRadius: BorderRadius.circular(20),
                                        border: _selectedMusicUrl != null
                                            ? Border.all(
                                                color: Colors.redAccent,
                                                width: 1.5,
                                              )
                                            : null,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.music_note,
                                            color: _selectedMusicUrl != null
                                                ? Colors.redAccent
                                                : Colors.white,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            _selectedMusicName ?? 'Add sound',
                                            style: TextStyle(
                                              color: _selectedMusicUrl != null
                                                  ? Colors.redAccent
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
                                ),
                              ),
                      ),

                      if (!isLiveMode)
                        Column(
                          children: [
                            _buildRightControlIcon(
                              Icons.flip_camera_android,
                              'Flip',
                              _toggleFlip,
                            ),
                            _buildRightControlIcon(
                              Icons.speed,
                              'Speed',
                              () => setState(
                                () => _showSpeedBar = !_showSpeedBar,
                              ),
                            ),
                            _buildRightControlIcon(
                              Icons.auto_awesome,
                              'Filters',
                              _showEffectsSheet,
                            ),
                            _buildRightControlIcon(
                              _isBeautifyOn
                                  ? Icons.face_retouching_natural
                                  : Icons.face_retouching_off,
                              'Beautify',
                              _toggleBeautify,
                            ),
                            _buildRightControlIcon(
                              _selectedTimerSeconds > 0
                                  ? Icons.timer
                                  : Icons.timer_outlined,
                              'Timer',
                              _showTimerSheet,
                            ),
                            _buildRightControlIcon(
                              _isFlashOn ? Icons.flash_on : Icons.flash_off,
                              'Flash',
                              _toggleFlash,
                            ),
                          ],
                        )
                      else
                        Column(
                          children: [
                            _buildRightControlIcon(
                              Icons.flip_camera_android,
                              'Flip',
                              _toggleFlip,
                            ),
                            _buildRightControlIcon(
                              Icons.auto_awesome,
                              'Enhance',
                              () => _showFeedback('Enhance selected'),
                            ),
                            _buildRightControlIcon(
                              Icons.tune,
                              'Settings',
                              () => _showFeedback('Settings opened'),
                            ),
                            _buildRightControlIcon(
                              Icons.share,
                              'Share',
                              () => _showFeedback('Share menu opened'),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),

                const Spacer(),

                // Bottom Interaction Area
                Container(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Column(
                    children: [
                      // Speed Bar
                      if (_showSpeedBar && !isLiveMode)
                        Container(
                          margin: const EdgeInsets.only(bottom: 20),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: _speedOptions.map((speed) {
                              final isSelected = _currentSpeed == speed;
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _currentSpeed = speed;
                                  });
                                  _showFeedback('Speed set to ${speed}x');
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: Text(
                                    '${speed}x',
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.black
                                          : Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),

                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40.0,
                          vertical: 16.0,
                        ),
                        child: isLiveMode
                            ? Center(
                                child: GestureDetector(
                                  onTap: _onCapturePressed,
                                  child: Container(
                                    width: double.infinity,
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFFBA68C8),
                                          Color(0xFF9C27B0),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(30),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Colors.black45,
                                          blurRadius: 10,
                                          offset: Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: const Center(
                                      child: Text(
                                        'Start LIVE',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                          fontFamily: 'Inter',
                                          letterSpacing: 1,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            : Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  GestureDetector(
                                    onTap: _recordedSegments.isNotEmpty
                                        ? _deleteLastSegment
                                        : _showEffectsSheet,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color:
                                                (_recordedSegments.isNotEmpty ||
                                                    _selectedEffectIndex != 0)
                                                ? Colors.redAccent.withValues(
                                                    alpha: 0.2,
                                                  )
                                                : Colors.transparent,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color:
                                                  (_recordedSegments
                                                          .isNotEmpty ||
                                                      _selectedEffectIndex != 0)
                                                  ? Colors.redAccent
                                                  : Colors.white,
                                              width: 2,
                                            ),
                                          ),
                                          child: Icon(
                                            _recordedSegments.isNotEmpty
                                                ? Icons.backspace
                                                : Icons.auto_awesome_mosaic,
                                            color:
                                                (_recordedSegments.isNotEmpty ||
                                                    _selectedEffectIndex != 0)
                                                ? Colors.redAccent
                                                : Colors.white,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          _recordedSegments.isNotEmpty
                                              ? 'Delete'
                                              : 'Effects',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'Inter',
                                            shadows: [
                                              Shadow(
                                                color: Colors.black54,
                                                blurRadius: 2,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: _onCapturePressed,
                                    child: Container(
                                      width: 80,
                                      height: 80,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: _isRecording
                                              ? Colors.redAccent
                                              : Colors.white,
                                          width: 4,
                                        ),
                                        color: Colors.transparent,
                                      ),
                                      child: Center(
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 200,
                                          ),
                                          width: _isRecording ? 32 : 64,
                                          height: _isRecording ? 32 : 64,
                                          decoration: BoxDecoration(
                                            color: Colors.redAccent,
                                            borderRadius: BorderRadius.circular(
                                              _isRecording ? 8 : 32,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: _recordedSegments.isNotEmpty
                                        ? _finishRecording
                                        : _showUploadSheet,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: _recordedSegments.isNotEmpty
                                                ? Colors.redAccent
                                                : Colors.transparent,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 2,
                                            ),
                                          ),
                                          child: Icon(
                                            _recordedSegments.isNotEmpty
                                                ? Icons.check
                                                : Icons.photo_library,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          _recordedSegments.isNotEmpty
                                              ? 'Done'
                                              : 'Upload',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'Inter',
                                            shadows: [
                                              Shadow(
                                                color: Colors.black54,
                                                blurRadius: 2,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                      ),

                      const SizedBox(height: 16),

                      SizedBox(
                        height: 30,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(_modes.length, (index) {
                            final isSelected = _selectedModeIndex == index;
                            return GestureDetector(
                              onTap: () {
                                if (_isRecording) {
                                  _stopRecording();
                                }
                                setState(() {
                                  _selectedModeIndex = index;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  _modes[index],
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.white54,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.w600,
                                    fontSize: 15,
                                    fontFamily: 'Inter',
                                    shadows: isSelected
                                        ? [
                                            const Shadow(
                                              color: Colors.black87,
                                              blurRadius: 4,
                                            ),
                                          ]
                                        : null,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GalleryBottomSheet extends StatefulWidget {
  const _GalleryBottomSheet();

  @override
  State<_GalleryBottomSheet> createState() => _GalleryBottomSheetState();
}

class _GalleryBottomSheetState extends State<_GalleryBottomSheet>
    with WidgetsBindingObserver {
  final List<AssetEntity> _assets = [];
  bool _isLoading = true;
  bool _hasPermission = false;
  int _currentPage = 0;
  final int _pageSize = 30;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _requestPermissionAndFetch();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_hasPermission) {
      _requestPermissionAndFetch();
    }
  }

  Future<void> _requestPermissionAndFetch() async {
    setState(() => _isLoading = true);
    bool isGranted = false;

    if (Platform.isAndroid) {
      final statuses = await [
        Permission.photos,
        Permission.videos,
        Permission.storage,
      ].request();
      final photos = statuses[Permission.photos];
      final videos = statuses[Permission.videos];
      final storage = statuses[Permission.storage];
      isGranted =
          (photos?.isGranted == true && videos?.isGranted == true) ||
          photos?.isLimited == true ||
          videos?.isLimited == true ||
          storage?.isGranted == true;
    } else {
      final PermissionState ps = await PhotoManager.requestPermissionExtend();
      isGranted = ps.isAuth;
    }

    if (isGranted) {
      if (mounted) {
        setState(() {
          _hasPermission = true;
          _assets.clear();
          _currentPage = 0;
          _hasMore = true;
        });
        await _fetchAssets();
      }
    } else {
      if (mounted) {
        setState(() {
          _hasPermission = false;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchAssets() async {
    if (!_hasMore) return;

    try {
      final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
        type: RequestType.image | RequestType.video,
      );
      if (albums.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final AssetPathEntity recentAlbum = albums.first;
      final List<AssetEntity> recentAssets = await recentAlbum
          .getAssetListPaged(page: _currentPage, size: _pageSize);

      if (mounted) {
        setState(() {
          _assets.addAll(recentAssets);
          _currentPage++;
          _isLoading = false;
          if (recentAssets.length < _pageSize) {
            _hasMore = false;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatVideoDuration(int seconds) {
    final minutes = (seconds ~/ 60).toString();
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Upload from Gallery',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
          Expanded(
            child: _isLoading && _assets.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.black),
                  )
                : !_hasPermission
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.photo_library_outlined,
                          size: 60,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Gallery permission denied.',
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'We need access to your photos to upload media.',
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                        const SizedBox(height: 24),
                        TextButton(
                          onPressed: () => openAppSettings(),
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.redAccent.withValues(
                              alpha: 0.1,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Open Phone Settings',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : _assets.isEmpty
                ? const Center(
                    child: Text(
                      'No media files found in gallery',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  )
                : NotificationListener<ScrollNotification>(
                    onNotification: (ScrollNotification scrollInfo) {
                      if (!_isLoading &&
                          _hasMore &&
                          scrollInfo.metrics.pixels ==
                              scrollInfo.metrics.maxScrollExtent) {
                        _fetchAssets();
                      }
                      return false;
                    },
                    child: GridView.builder(
                      padding: const EdgeInsets.all(2),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 2,
                            mainAxisSpacing: 2,
                          ),
                      itemCount: _assets.length,
                      itemBuilder: (context, index) {
                        final asset = _assets[index];
                        return GestureDetector(
                          onTap: () async {
                            final file = await asset.file;
                            if (file != null && context.mounted) {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => VideoEditPreviewScreen(
                                    filePath: file.path,
                                  ),
                                ),
                              );
                            }
                          },
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              FutureBuilder<Uint8List?>(
                                future: asset.thumbnailDataWithSize(
                                  const ThumbnailSize.square(250),
                                ),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return Container(color: Colors.grey[200]);
                                  }
                                  if (snapshot.hasData &&
                                      snapshot.data != null) {
                                    return Image.memory(
                                      snapshot.data!,
                                      fit: BoxFit.cover,
                                    );
                                  }
                                  return Container(
                                    color: Colors.grey[300],
                                    child: const Icon(Icons.error),
                                  );
                                },
                              ),
                              if (asset.type == AssetType.video) ...[
                                const Positioned(
                                  bottom: 4,
                                  left: 4,
                                  child: Icon(
                                    Icons.play_circle_outline,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                                Positioned(
                                  bottom: 4,
                                  right: 4,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      _formatVideoDuration(asset.duration),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
