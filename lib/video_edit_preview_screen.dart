import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'publish_post_screen.dart';
import 'package:audioplayers/audioplayers.dart';
import 'models/text_overlay_item.dart';
import 'widgets/text_editor_overlay.dart';
import 'models/sticker_overlay_item.dart';
import 'widgets/sticker_discovery_sheet.dart';
import 'models/audio_track.dart';
import 'models/audio_track_item.dart';
import 'audio_discovery_sheet.dart';
import 'package:image_picker/image_picker.dart';
import 'models/video_clip_item.dart';
import 'models/editor_state_snapshot.dart';
import 'effects_discovery_sheet.dart';
import 'models/effect_model.dart';

class VideoEditPreviewScreen extends StatefulWidget {
  final String filePath;

  const VideoEditPreviewScreen({super.key, required this.filePath});

  @override
  State<VideoEditPreviewScreen> createState() => _VideoEditPreviewScreenState();
}

class _VideoEditPreviewScreenState extends State<VideoEditPreviewScreen> {
  final List<VideoClipItem> _clips = [];
  int _currentClipIndex = 0;
  bool _isInitialized = false;
  bool _isPlaying = false;

  int? _selectedEditorClipIndex;
  EffectModel? _activeEffect;

  // Crop & History State
  double _currentAspectRatio = 9 / 16;
  final List<EditorStateSnapshot> _undoStack = [];
  final List<EditorStateSnapshot> _redoStack = [];

  VideoPlayerController get _videoPlayerController =>
      _clips[_currentClipIndex].controller;

  // Timeline Scrolling State
  final double _timelineWidth = 1000.0;
  double _scrollOffset = 0.0;
  bool _isUserScrolling = false;

  // Overlay State
  final List<TextOverlayItem> _textOverlays = [];
  final List<StickerOverlayItem> _stickerOverlays = [];

  // Audio Overlay State
  final List<AudioTrackItem> _audioOverlays = [];
  final Map<AudioTrackItem, AudioPlayer> _audioPlayers = {};

  // Drag-to-delete state
  bool _isDraggingItem = false;
  bool _isHoveringTrash = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer(widget.filePath);

    // Replaced Timer with direct video listener for perfect 60FPS sync
  }

  void _videoListener() {
    if (!_isInitialized || _clips.isEmpty) return;

    // Only process if playing OR if we need to update UI on pause (seeking)
    if (!_isUserScrolling) {
      final clip = _clips[_currentClipIndex];
      final localPosMs = clip.controller.value.position.inMilliseconds;

      if (_isPlaying && localPosMs >= clip.endMs) {
        clip.controller.pause();
        if (_currentClipIndex < _clips.length - 1) {
          _currentClipIndex++;
          _clips[_currentClipIndex].controller.seekTo(
            Duration(milliseconds: _clips[_currentClipIndex].startMs),
          );
          _clips[_currentClipIndex].controller.play();
        } else {
          _pauseVideo();
          _seekToGlobalTime(_totalDurationMs); // Snap to the very end
        }
      }

      setState(() {
        if (_totalDurationMs > 0) {
          final globalProgress = _actualGlobalPositionMs / _totalDurationMs;
          _scrollOffset = globalProgress * _timelineWidth;
        }
        _syncAudioPlayers();
      });
    }
  }

  int get _totalDurationMs {
    return _clips.fold(0, (sum, clip) => sum + clip.activeDurationMs);
  }

  int get _actualGlobalPositionMs {
    if (!_isInitialized || _clips.isEmpty) return 0;
    int globalMs = 0;
    for (int i = 0; i < _currentClipIndex; i++) {
      globalMs += _clips[i].activeDurationMs;
    }
    final currentLocalMs =
        _clips[_currentClipIndex].controller.value.position.inMilliseconds;
    int activePlayed = currentLocalMs - _clips[_currentClipIndex].startMs;
    if (activePlayed < 0) activePlayed = 0;
    return globalMs + activePlayed;
  }

  int get _currentPositionMs {
    return _actualGlobalPositionMs;
  }

  void _syncAudioPlayers() {
    final currentMs = _currentPositionMs;
    for (var audio in _audioOverlays) {
      final player = _audioPlayers[audio];
      if (player != null) {
        if (currentMs >= audio.startTimeMs &&
            currentMs <= audio.startTimeMs + audio.durationMs) {
          if (_isPlaying) {
            if (player.state != PlayerState.playing) {
              player.seek(
                Duration(milliseconds: currentMs - audio.startTimeMs),
              );
              player.play(UrlSource(audio.track.url));
            }
          } else {
            if (player.state == PlayerState.playing) {
              player.pause();
            }
            player.seek(Duration(milliseconds: currentMs - audio.startTimeMs));
          }
        } else {
          if (player.state == PlayerState.playing) player.pause();
        }
      }
    }
  }

  Future<void> _initializePlayer(String path) async {
    final controller = VideoPlayerController.file(File(path));
    await controller.initialize();
    controller.addListener(_videoListener);
    _clips.add(VideoClipItem(filePath: path, controller: controller));

    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
      if (_clips.length == 1) {
        _playVideo();
      }
    }
  }

  void _seekToGlobalTime(int globalTimeMs) {
    if (_clips.isEmpty) return;
    int accMs = 0;
    for (int i = 0; i < _clips.length; i++) {
      final clip = _clips[i];
      if (globalTimeMs >= accMs &&
          globalTimeMs <= accMs + clip.activeDurationMs) {
        if (_currentClipIndex != i) {
          _clips[_currentClipIndex].controller.pause();
          _currentClipIndex = i;
          if (_isPlaying) {
            _clips[_currentClipIndex].controller.play();
          }
        }
        int localMs = clip.startMs + (globalTimeMs - accMs);
        _clips[_currentClipIndex].controller.seekTo(
          Duration(milliseconds: localMs),
        );
        return;
      }
      accMs += clip.activeDurationMs;
    }
    if (globalTimeMs > accMs) {
      _currentClipIndex = 0;
      for (var c in _clips) {
        c.controller.pause();
      }
      _clips[0].controller.seekTo(Duration(milliseconds: _clips[0].startMs));
      if (_isPlaying) _clips[0].controller.play();
    }

    _syncAudioPlayers();
  }

  void _playVideo() {
    if (!_isInitialized || _clips.isEmpty) return;
    if (_scrollOffset >= _timelineWidth * 0.99) {
      _scrollOffset = 0.0;
      _seekToGlobalTime(0);
    }
    _clips[_currentClipIndex].controller.play();
    setState(() {
      _isPlaying = true;
    });
    _syncAudioPlayers();
  }

  void _pauseVideo() {
    if (!_isInitialized || _clips.isEmpty) return;
    _clips[_currentClipIndex].controller.pause();
    for (var player in _audioPlayers.values) {
      if (player.state == PlayerState.playing) player.pause();
    }
    setState(() {
      _isPlaying = false;
    });
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      _pauseVideo();
    } else {
      _playVideo();
    }
  }

  void _onTimelinePanUpdate(DragUpdateDetails details) {
    if (!_isInitialized || _clips.isEmpty) return;

    setState(() {
      _isUserScrolling = true;
      if (_isPlaying) _pauseVideo();

      _scrollOffset -= details.delta.dx;
      _scrollOffset = _scrollOffset.clamp(0.0, _timelineWidth);

      double progress = _scrollOffset / _timelineWidth;
      int targetMs = (progress * _totalDurationMs).toInt();
      _seekToGlobalTime(targetMs);
    });
  }

  void _onTimelinePanEnd(DragEndDetails details) {
    setState(() {
      _isUserScrolling = false;
    });
  }

  @override
  void dispose() {
    for (var clip in _clips) {
      clip.controller.dispose();
    }
    for (var player in _audioPlayers.values) {
      player.dispose();
    }
    super.dispose();
  }

  void _onNextPressed() {
    _pauseVideo();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PublishPostScreen(videoPath: widget.filePath),
      ),
    );
  }

  void _showCropMenu() {
    _pauseVideo();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: 200,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Aspect Ratio',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildCropOption(9 / 16, '9:16', Icons.crop_portrait),
                  _buildCropOption(1.0, '1:1', Icons.crop_square),
                  _buildCropOption(16 / 9, '16:9', Icons.crop_landscape),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCropOption(double ratio, String label, IconData icon) {
    final isSelected = _currentAspectRatio == ratio;
    return GestureDetector(
      onTap: () {
        setState(() => _currentAspectRatio = ratio);
        Navigator.pop(context);
      },
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.yellow.withValues(alpha: 0.2)
                  : Colors.white12,
              shape: BoxShape.circle,
              border: isSelected
                  ? Border.all(color: Colors.yellow, width: 2)
                  : null,
            ),
            child: Icon(
              icon,
              color: isSelected ? Colors.yellow : Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.yellow : Colors.white70,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  EditorStateSnapshot _createCurrentSnapshot() {
    return EditorStateSnapshot(
      clips: _clips
          .map(
            (c) => ClipStateSnapshot(
              filePath: c.filePath,
              trimStart: c.trimStart,
              trimEnd: c.trimEnd,
            ),
          )
          .toList(),
      audioOverlays: _audioOverlays.map((a) => a.clone()).toList(),
      textOverlays: _textOverlays.map((t) => t.clone()).toList(),
      stickerOverlays: _stickerOverlays.map((s) => s.clone()).toList(),
    );
  }

  void _saveStateToUndo() {
    _redoStack.clear();
    _undoStack.add(_createCurrentSnapshot());
  }

  Future<void> _undo() async {
    if (_undoStack.isEmpty) return;
    _pauseVideo();

    _redoStack.add(_createCurrentSnapshot());
    await _restoreSnapshot(_undoStack.removeLast());
  }

  Future<void> _redo() async {
    if (_redoStack.isEmpty) return;
    _pauseVideo();

    _undoStack.add(_createCurrentSnapshot());
    await _restoreSnapshot(_redoStack.removeLast());
  }

  Future<void> _restoreSnapshot(EditorStateSnapshot snapshot) async {
    for (var clip in _clips) {
      clip.controller.dispose();
    }
    for (var player in _audioPlayers.values) {
      player.dispose();
    }

    _clips.clear();
    _audioPlayers.clear();
    _selectedEditorClipIndex = null;

    for (var snap in snapshot.clips) {
      final controller = VideoPlayerController.file(File(snap.filePath));
      await controller.initialize();
      controller.addListener(_videoListener);
      _clips.add(
        VideoClipItem(
          filePath: snap.filePath,
          controller: controller,
          trimStart: snap.trimStart,
          trimEnd: snap.trimEnd,
        ),
      );
    }

    _textOverlays.clear();
    _textOverlays.addAll(snapshot.textOverlays.map((t) => t.clone()));

    _stickerOverlays.clear();
    _stickerOverlays.addAll(snapshot.stickerOverlays.map((s) => s.clone()));

    _audioOverlays.clear();
    _audioOverlays.addAll(snapshot.audioOverlays.map((a) => a.clone()));

    for (var audio in _audioOverlays) {
      final player = AudioPlayer();
      await player.setSource(UrlSource(audio.track.url));
      _audioPlayers[audio] = player;
    }

    setState(() {
      _currentClipIndex = 0;
      if (_clips.isNotEmpty) {
        _scrollOffset = 0.0;
        _seekToGlobalTime(0);
      } else {
        _isInitialized = false;
      }
    });
  }

  Future<void> _pickAndAddClip() async {
    final ImagePicker picker = ImagePicker();
    final XFile? video = await picker.pickVideo(source: ImageSource.gallery);

    if (video != null) {
      _saveStateToUndo();
      _pauseVideo();
      await _initializePlayer(video.path);
    }
  }

  void _deleteClip() {
    if (_selectedEditorClipIndex == null || _clips.isEmpty) return;

    _saveStateToUndo();
    setState(() {
      final clip = _clips.removeAt(_selectedEditorClipIndex!);
      clip.controller.dispose();

      _selectedEditorClipIndex = null;
      if (_clips.isEmpty) {
        _scrollOffset = 0.0;
        _isInitialized = false;
      } else {
        _scrollOffset = _scrollOffset.clamp(0.0, _timelineWidth);
        _seekToGlobalTime(
          (_scrollOffset / _timelineWidth * _totalDurationMs).toInt(),
        );
      }
    });
  }

  Future<void> _splitClip() async {
    if (_selectedEditorClipIndex == null || _clips.isEmpty) return;

    final int globalMs = (_scrollOffset / _timelineWidth * _totalDurationMs)
        .toInt();
    int accMs = 0;
    for (int i = 0; i < _selectedEditorClipIndex!; i++) {
      accMs += _clips[i].activeDurationMs;
    }

    final clip = _clips[_selectedEditorClipIndex!];
    final int localMs = clip.startMs + (globalMs - accMs);

    if (localMs <= clip.startMs + 100 || localMs >= clip.endMs - 100) return;

    _saveStateToUndo();

    double splitFraction =
        localMs / clip.controller.value.duration.inMilliseconds;
    double oldTrimEnd = clip.trimEnd;

    _pauseVideo();

    final newController = VideoPlayerController.file(File(clip.filePath));
    await newController.initialize();
    newController.addListener(_videoListener);

    final newClip = VideoClipItem(
      filePath: clip.filePath,
      controller: newController,
      trimStart: splitFraction,
      trimEnd: oldTrimEnd,
    );

    setState(() {
      clip.trimEnd = splitFraction;
      _clips.insert(_selectedEditorClipIndex! + 1, newClip);
      _selectedEditorClipIndex = _selectedEditorClipIndex! + 1;
    });
  }

  Future<void> _replaceClip() async {
    if (_selectedEditorClipIndex == null || _clips.isEmpty) return;

    final ImagePicker picker = ImagePicker();
    final XFile? video = await picker.pickVideo(source: ImageSource.gallery);

    if (video != null) {
      _saveStateToUndo();
      _pauseVideo();

      final newController = VideoPlayerController.file(File(video.path));
      await newController.initialize();
      newController.addListener(_videoListener);

      final oldClip = _clips[_selectedEditorClipIndex!];
      oldClip.controller.dispose();

      _clips[_selectedEditorClipIndex!] = VideoClipItem(
        filePath: video.path,
        controller: newController,
        trimStart: 0.0,
        trimEnd: 1.0,
      );

      setState(() {});
    }
  }

  void _reorderClip() {
    if (_selectedEditorClipIndex == null ||
        _clips.isEmpty ||
        _clips.length == 1) {
      return;
    }

    _saveStateToUndo();

    setState(() {
      final int currentIndex = _selectedEditorClipIndex!;
      final int targetIndex = currentIndex < _clips.length - 1
          ? currentIndex + 1
          : currentIndex - 1;

      final clip = _clips.removeAt(currentIndex);
      _clips.insert(targetIndex, clip);

      _selectedEditorClipIndex = targetIndex;
    });
  }

  double _getClipStartPos(int index) {
    if (_totalDurationMs == 0) return 0;
    int accMs = 0;
    for (int i = 0; i < index; i++) {
      accMs += _clips[i].activeDurationMs;
    }
    return (accMs / _totalDurationMs) * _timelineWidth;
  }

  double _getClipWidth(int index) {
    if (_totalDurationMs == 0) return 0;
    return (_clips[index].activeDurationMs / _totalDurationMs) * _timelineWidth;
  }

  Widget _buildVideoTrack() {
    if (_clips.isEmpty || _totalDurationMs == 0) return const SizedBox();

    return SizedBox(
      height: 60,
      width: _timelineWidth + 60, // Extra space for + button
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (int i = 0; i < _clips.length; i++) _buildClipTrimmerBlock(i),

          // Persistent + button at the end of the timeline
          Positioned(
            left: _timelineWidth + 8,
            top: 10,
            bottom: 10,
            width: 40,
            child: GestureDetector(
              onTap: _pickAndAddClip,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClipTrimmerBlock(int index) {
    final clip = _clips[index];
    final double leftPos = _getClipStartPos(index);
    final double width = _getClipWidth(index);
    final bool isSelected = _selectedEditorClipIndex == index;

    return Positioned(
      left: leftPos,
      width: width,
      top: 0,
      bottom: 0,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(
              () => _selectedEditorClipIndex = isSelected ? null : index,
            ),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: isSelected ? Colors.yellow : Colors.transparent,
                  width: isSelected ? 3.0 : 0.0,
                ),
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: List.generate(
                  (width / 40).clamp(1, 100).toInt(),
                  (_) => const Expanded(
                    child: Icon(Icons.movie, color: Colors.white30, size: 24),
                  ),
                ),
              ),
            ),
          ),

          // Vertical action divider (only if not the first clip)
          if (index > 0)
            Positioned(
              left: -6,
              top: 20,
              bottom: 20,
              width: 12,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),

          if (isSelected)
            Positioned(
              left: -10,
              top: -2,
              bottom: -2,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragUpdate: (details) {
                  setState(() {
                    _isUserScrolling = true;
                    if (_isPlaying) _pauseVideo();
                    double msDelta =
                        (details.delta.dx / _timelineWidth) * _totalDurationMs;
                    double rawDelta =
                        msDelta / clip.controller.value.duration.inMilliseconds;
                    clip.trimStart += rawDelta;
                    clip.trimStart = clip.trimStart.clamp(
                      0.0,
                      clip.trimEnd - 0.05,
                    );
                    _scrollOffset = _getClipStartPos(index);
                    _seekToGlobalTime(
                      (_scrollOffset / _timelineWidth * _totalDurationMs)
                          .toInt(),
                    );
                  });
                },
                onHorizontalDragEnd: (_) =>
                    setState(() => _isUserScrolling = false),
                child: Container(
                  width: 20,
                  decoration: BoxDecoration(
                    color: Colors.yellow,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Center(
                    child: Container(
                      width: 4,
                      height: 20,
                      color: Colors.black54,
                    ),
                  ),
                ),
              ),
            ),

          if (isSelected)
            Positioned(
              right: -10,
              top: -2,
              bottom: -2,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragUpdate: (details) {
                  setState(() {
                    _isUserScrolling = true;
                    if (_isPlaying) _pauseVideo();
                    double msDelta =
                        (details.delta.dx / _timelineWidth) * _totalDurationMs;
                    double rawDelta =
                        msDelta / clip.controller.value.duration.inMilliseconds;
                    clip.trimEnd += rawDelta;
                    clip.trimEnd = clip.trimEnd.clamp(
                      clip.trimStart + 0.05,
                      1.0,
                    );
                    _scrollOffset = _getClipStartPos(index) + width;
                    _seekToGlobalTime(
                      (_scrollOffset / _timelineWidth * _totalDurationMs)
                          .toInt(),
                    );
                  });
                },
                onHorizontalDragEnd: (_) =>
                    setState(() => _isUserScrolling = false),
                child: Container(
                  width: 20,
                  decoration: BoxDecoration(
                    color: Colors.yellow,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Center(
                    child: Container(
                      width: 4,
                      height: 20,
                      color: Colors.black54,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Text Input Logic
  Future<void> _showTextInput([TextOverlayItem? existingItem]) async {
    _pauseVideo();
    final result = await Navigator.push<TextOverlayItem>(
      context,
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (context, animation, secondaryAnimation) =>
            TextEditorOverlay(initialItem: existingItem),
      ),
    );

    if (result != null) {
      _saveStateToUndo();
      setState(() {
        if (existingItem != null) {
          final index = _textOverlays.indexOf(existingItem);
          if (index != -1) {
            _textOverlays[index] = result;
          }
        } else {
          result.startTimeMs = _currentPositionMs;
          result.durationMs = 5000;
          _textOverlays.add(result);
        }
      });
    }
  }

  TextStyle _buildTextStyle(TextOverlayItem item) {
    FontWeight weight = FontWeight.bold;
    String family = 'sans-serif';
    double letterSpacing = 0.0;

    if (item.fontFamily == 'Classic') {
      family = 'serif';
      weight = FontWeight.normal;
    } else if (item.fontFamily == 'Neon') {
      family = 'sans-serif';
      weight = FontWeight.w900;
      letterSpacing = 1.5;
    } else if (item.fontFamily == 'Serif') {
      family = 'serif';
      weight = FontWeight.w600;
    }

    Color textColor = item.color;
    Color bgColor = Colors.transparent;

    if (item.bgType == 1) {
      // Filled
      bgColor = item.color == Colors.black ? Colors.white : Colors.black;
    } else if (item.bgType == 2) {
      // Inverted
      bgColor = item.color;
      textColor = item.color == Colors.white ? Colors.black : Colors.white;
      if (item.color == Colors.black) {
        bgColor = Colors.white;
        textColor = Colors.black;
      }
    }

    List<Shadow>? shadows;
    if (item.effect == 'Hard Shadow') {
      shadows = [
        Shadow(
          color: Colors.black.withValues(alpha: 0.8),
          offset: const Offset(2, 2),
          blurRadius: 0,
        ),
      ];
    } else if (item.effect == 'Block Offset') {
      shadows = [
        Shadow(
          color: item.color == Colors.black ? Colors.white : Colors.black,
          offset: const Offset(3, 3),
          blurRadius: 0,
        ),
      ];
    } else {
      if (item.bgType == 0) {
        shadows = [
          Shadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 4),
        ];
      }
    }

    return TextStyle(
      fontSize: item.fontSize,
      color: textColor,
      backgroundColor: bgColor,
      fontFamily: family,
      fontWeight: weight,
      letterSpacing: letterSpacing,
      shadows: shadows,
      height: 1.2,
    );
  }

  // Audio Sheet Logic
  Future<void> _showAudioSheet() async {
    _pauseVideo();
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 40),
        child: AudioDiscoverySheet(),
      ),
    );

    if (result != null && result is AudioTrack) {
      _saveStateToUndo();

      final int remainingMs = _totalDurationMs - _currentPositionMs;
      final newItem = AudioTrackItem(
        track: result,
        startTimeMs: _currentPositionMs,
        durationMs: remainingMs > 0 ? remainingMs : 5000,
      );

      final player = AudioPlayer();
      await player.setSource(UrlSource(result.url));

      setState(() {
        _audioOverlays.add(newItem);
        _audioPlayers[newItem] = player;
      });
    }
  }

  // Sticker Sheet Logic
  Future<void> _showStickerSheet() async {
    _pauseVideo();
    final result = await showModalBottomSheet<StickerOverlayItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: const StickerDiscoverySheet(),
      ),
    );

    if (result != null) {
      _saveStateToUndo();
      setState(() {
        _stickerOverlays.add(result);
      });
    }
  }

  void _showEffectsSheet() {
    _pauseVideo();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: EffectsDiscoverySheet(
          onEffectSelected: (effect) {
            _saveStateToUndo();
            setState(() {
              _activeEffect = effect;
            });
          },
        ),
      ),
    );
  }

  void _simulateExport() async {
    _pauseVideo();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.black87,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text(
                'Saving to Gallery...',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );

    // Simulate export delay
    await Future.delayed(const Duration(seconds: 3));

    if (mounted) {
      Navigator.pop(context); // Dismiss dialog
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Video saved successfully to Gallery!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _checkTrashHover(double dx, double dy) {
    final screenHeight = MediaQuery.of(context).size.height;
    // Check if the sticker's Y coordinate reaches the bottom 15% of the screen
    final isHovering = dy > screenHeight * 0.85;
    if (_isHoveringTrash != isHovering) {
      setState(() {
        _isHoveringTrash = isHovering;
      });
    }
  }

  Widget _buildBottomActionIcon(
    IconData icon,
    String label, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Colors.white12,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackBlock({
    required int startTimeMs,
    required int durationMs,
    required Color color,
    required String label,
    required Function(int newStart) onStartChanged,
  }) {
    if (!_isInitialized) return const SizedBox();
    final videoDurationMs =
        _videoPlayerController.value.duration.inMilliseconds;
    if (videoDurationMs == 0) return const SizedBox();

    final double leftPos = (startTimeMs / videoDurationMs) * _timelineWidth;
    final double width = (durationMs / videoDurationMs) * _timelineWidth;

    return Container(
      height: 32,
      width: _timelineWidth,
      margin: const EdgeInsets.only(bottom: 8),
      child: Stack(
        children: [
          // The Draggable Block
          Positioned(
            left: leftPos,
            width: width,
            top: 0,
            bottom: 0,
            child: GestureDetector(
              onHorizontalDragUpdate: (details) {
                final msDelta =
                    (details.delta.dx / _timelineWidth * videoDurationMs)
                        .toInt();
                int newStart = (startTimeMs + msDelta).clamp(
                  0,
                  videoDurationMs - durationMs,
                );
                onStartChanged(newStart);
              },
              child: Container(
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: color.withValues(alpha: 0.8)),
                ),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
          // Left Handle
          Positioned(
            left: leftPos,
            top: 0,
            bottom: 0,
            child: Container(
              width: 8,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(6),
                ),
              ),
            ),
          ),
          // Right Handle
          Positioned(
            left: leftPos + width - 8,
            top: 0,
            bottom: 0,
            child: Container(
              width: 8,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.horizontal(
                  right: Radius.circular(6),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final paddingHorizontal = screenWidth / 2;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. BACKGROUND VIDEO LAYER
          if (_isInitialized)
            SizedBox.expand(
              child: Center(
                child: AspectRatio(
                  aspectRatio: _currentAspectRatio,
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _videoPlayerController.value.size.width,
                      height: _videoPlayerController.value.size.height,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _activeEffect != null
                              ? ColorFiltered(
                                  colorFilter: ColorFilter.matrix(
                                    _activeEffect!.matrix,
                                  ),
                                  child: VideoPlayer(_videoPlayerController),
                                )
                              : VideoPlayer(_videoPlayerController),

                          // Render Text Overlays
                          for (var item in _textOverlays.toList())
                            if (_currentPositionMs >= item.startTimeMs &&
                                _currentPositionMs <=
                                    (item.startTimeMs + item.durationMs))
                              Positioned(
                                left: item.dx,
                                top: item.dy,
                                child: GestureDetector(
                                  onTap: () => _showTextInput(item),
                                  onPanStart: (_) {
                                    setState(() => _isDraggingItem = true);
                                  },
                                  onPanUpdate: (details) {
                                    setState(() {
                                      item.dx += details.delta.dx;
                                      item.dy += details.delta.dy;
                                      _checkTrashHover(item.dx, item.dy);
                                    });
                                  },
                                  onPanEnd: (_) {
                                    setState(() {
                                      if (_isHoveringTrash) {
                                        _saveStateToUndo();
                                        _textOverlays.remove(item);
                                      }
                                      _isDraggingItem = false;
                                      _isHoveringTrash = false;
                                    });
                                  },
                                  child: Material(
                                    color: Colors.transparent,
                                    child: Text(
                                      item.text,
                                      style: _buildTextStyle(item),
                                      textAlign: item.alignment,
                                    ),
                                  ),
                                ),
                              ),

                          // Render Sticker Overlays
                          for (var item in _stickerOverlays.toList())
                            Positioned(
                              left: item.dx,
                              top: item.dy,
                              child: Transform(
                                alignment: Alignment.center,
                                transform: Matrix4.identity()
                                  ..scaleByDouble(
                                    item.scale,
                                    item.scale,
                                    1.0,
                                    1.0,
                                  )
                                  ..rotateZ(item.rotation),
                                child: GestureDetector(
                                  onScaleStart: (details) {
                                    setState(() => _isDraggingItem = true);
                                    item.baseScale = item.scale;
                                    item.baseRotation = item.rotation;
                                  },
                                  onScaleUpdate: (details) {
                                    setState(() {
                                      item.dx += details.focalPointDelta.dx;
                                      item.dy += details.focalPointDelta.dy;
                                      item.scale =
                                          item.baseScale * details.scale;
                                      item.rotation =
                                          item.baseRotation + details.rotation;
                                      _checkTrashHover(item.dx, item.dy);
                                    });
                                  },
                                  onScaleEnd: (details) {
                                    setState(() {
                                      if (_isHoveringTrash) {
                                        _saveStateToUndo();
                                        _stickerOverlays.remove(item);
                                      }
                                      _isDraggingItem = false;
                                      _isHoveringTrash = false;
                                    });
                                  },
                                  child: SizedBox(
                                    width: 150, // Base initial hit box
                                    height: 150,
                                    child: item.isLottie
                                        ? const Icon(
                                            Icons.auto_awesome,
                                            color: Colors.white70,
                                            size: 72,
                                          )
                                        : Image.network(
                                            item.assetUrl,
                                            fit: BoxFit.contain,
                                            loadingBuilder:
                                                (context, child, progress) {
                                                  if (progress == null) {
                                                    return child;
                                                  }
                                                  return const Center(
                                                    child:
                                                        CircularProgressIndicator(
                                                          color: Colors.white24,
                                                        ),
                                                  );
                                                },
                                            errorBuilder:
                                                (context, error, stackTrace) =>
                                                    const Icon(
                                                      Icons.broken_image,
                                                      color: Colors.white24,
                                                      size: 48,
                                                    ),
                                          ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            )
          else
            const Center(child: CircularProgressIndicator(color: Colors.white)),

          // 2. TIMELINE EDITOR PANEL (Bottom)
          AnimatedOpacity(
            opacity: _isDraggingItem ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: IgnorePointer(
              ignoring: _isDraggingItem,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  height: 380,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black,
                        Colors.black.withValues(alpha: 0.8),
                        Colors.black.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Playback Controls Layer
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 8.0,
                        ),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: _togglePlayPause,
                              behavior: HitTestBehavior.opaque,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: Colors.white24,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _isPlaying ? Icons.pause : Icons.play_arrow,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ValueListenableBuilder<VideoPlayerValue>(
                              valueListenable: _videoPlayerController,
                              builder: (context, value, child) {
                                if (!_isInitialized || _clips.isEmpty) {
                                  return const Text(
                                    '00:00 / 00:00',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  );
                                }

                                int globalMs = 0;
                                for (int i = 0; i < _currentClipIndex; i++) {
                                  globalMs += _clips[i].activeDurationMs;
                                }
                                int activePlayed =
                                    value.position.inMilliseconds -
                                    _clips[_currentClipIndex].startMs;
                                if (activePlayed < 0) activePlayed = 0;
                                int currentMs = globalMs + activePlayed;

                                final currentPosition = Duration(
                                  milliseconds: currentMs,
                                );
                                final totalDuration = Duration(
                                  milliseconds: _totalDurationMs,
                                );

                                String twoDigits(int n) =>
                                    n.toString().padLeft(2, '0');
                                final currentMin = twoDigits(
                                  currentPosition.inMinutes.remainder(60),
                                );
                                final currentSec = twoDigits(
                                  currentPosition.inSeconds.remainder(60),
                                );
                                final totalMin = twoDigits(
                                  totalDuration.inMinutes.remainder(60),
                                );
                                final totalSec = twoDigits(
                                  totalDuration.inSeconds.remainder(60),
                                );

                                return Text(
                                  '$currentMin:$currentSec / $totalMin:$totalSec',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                );
                              },
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(
                                Icons.add_to_photos,
                                color: Colors.white70,
                              ),
                              onPressed: _pickAndAddClip,
                              tooltip: 'Add clips',
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.undo,
                                color: Colors.white70,
                              ),
                              onPressed: () {},
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.redo,
                                color: Colors.white70,
                              ),
                              onPressed: () {},
                            ),
                          ],
                        ),
                      ),

                      // Multi-Track Timeline Layer
                      SizedBox(
                        height: 160,
                        width: double.infinity,
                        child: Stack(
                          children: [
                            // Scrolling Timeline
                            GestureDetector(
                              onPanUpdate: _onTimelinePanUpdate,
                              onPanEnd: _onTimelinePanEnd,
                              onPanCancel: () =>
                                  setState(() => _isUserScrolling = false),
                              behavior: HitTestBehavior.opaque,
                              child: Container(
                                color: Colors.transparent,
                                width: double.infinity,
                                height: double.infinity,
                                child: Stack(
                                  children: [
                                    ValueListenableBuilder<VideoPlayerValue>(
                                      valueListenable: _videoPlayerController,
                                      builder: (context, value, child) {
                                        double currentOffset = _scrollOffset;
                                        if (!_isUserScrolling &&
                                            _isInitialized &&
                                            _clips.isNotEmpty &&
                                            _totalDurationMs > 0) {
                                          int globalMs = 0;
                                          for (
                                            int i = 0;
                                            i < _currentClipIndex;
                                            i++
                                          ) {
                                            globalMs +=
                                                _clips[i].activeDurationMs;
                                          }
                                          int activePlayed =
                                              value.position.inMilliseconds -
                                              _clips[_currentClipIndex].startMs;
                                          if (activePlayed < 0) {
                                            activePlayed = 0;
                                          }
                                          int currentMs =
                                              globalMs + activePlayed;
                                          final globalProgress =
                                              currentMs / _totalDurationMs;
                                          currentOffset =
                                              globalProgress * _timelineWidth;
                                        }

                                        return Transform.translate(
                                          offset: Offset(
                                            -currentOffset + paddingHorizontal,
                                            0,
                                          ),
                                          child: SingleChildScrollView(
                                            scrollDirection: Axis.vertical,
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                // Video Track with Trimmers
                                                _buildVideoTrack(),

                                                const SizedBox(height: 8),

                                                // Dynamic Audio Tracks
                                                for (
                                                  int i = 0;
                                                  i < _audioOverlays.length;
                                                  i++
                                                )
                                                  _buildTrackBlock(
                                                    startTimeMs:
                                                        _audioOverlays[i]
                                                            .startTimeMs,
                                                    durationMs:
                                                        _audioOverlays[i]
                                                            .durationMs,
                                                    color: Colors.blueAccent,
                                                    label: _audioOverlays[i]
                                                        .track
                                                        .title,
                                                    onStartChanged: (start) =>
                                                        setState(
                                                          () =>
                                                              _audioOverlays[i]
                                                                      .startTimeMs =
                                                                  start,
                                                        ),
                                                  ),

                                                // Add Audio Button Track
                                                GestureDetector(
                                                  onTap: _showAudioSheet,
                                                  child: Container(
                                                    height: 32,
                                                    width: _timelineWidth,
                                                    margin:
                                                        const EdgeInsets.only(
                                                          bottom: 8,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.blueAccent
                                                          .withValues(
                                                            alpha: 0.2,
                                                          ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            6,
                                                          ),
                                                      border: Border.all(
                                                        color: Colors.blueAccent
                                                            .withValues(
                                                              alpha: 0.5,
                                                            ),
                                                      ),
                                                    ),
                                                    alignment: Alignment.center,
                                                    child: const Text(
                                                      '+ Add audio',
                                                      style: TextStyle(
                                                        color:
                                                            Colors.blueAccent,
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ),

                                                // Dynamic Text Tracks
                                                for (
                                                  int i = 0;
                                                  i < _textOverlays.length;
                                                  i++
                                                )
                                                  _buildTrackBlock(
                                                    startTimeMs:
                                                        _textOverlays[i]
                                                            .startTimeMs,
                                                    durationMs: _textOverlays[i]
                                                        .durationMs,
                                                    color: Colors.orangeAccent,
                                                    label:
                                                        _textOverlays[i].text,
                                                    onStartChanged: (start) =>
                                                        setState(
                                                          () =>
                                                              _textOverlays[i]
                                                                      .startTimeMs =
                                                                  start,
                                                        ),
                                                  ),

                                                // Add Text Button Track
                                                GestureDetector(
                                                  onTap: _showTextInput,
                                                  child: Container(
                                                    height: 32,
                                                    width: _timelineWidth,
                                                    margin:
                                                        const EdgeInsets.only(
                                                          bottom: 8,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.orangeAccent
                                                          .withValues(
                                                            alpha: 0.2,
                                                          ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            6,
                                                          ),
                                                      border: Border.all(
                                                        color: Colors
                                                            .orangeAccent
                                                            .withValues(
                                                              alpha: 0.5,
                                                            ),
                                                      ),
                                                    ),
                                                    alignment: Alignment.center,
                                                    child: const Text(
                                                      '+ Add text',
                                                      style: TextStyle(
                                                        color:
                                                            Colors.orangeAccent,
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Fixed Center Playhead Indicator
                            Align(
                              alignment: Alignment.center,
                              child: IgnorePointer(
                                child: Container(
                                  width: 2,
                                  height: 160,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.5,
                                        ),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Bottom Action Bar
                      _buildBottomToolbar(),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 3. TOP HEADER BAR
          AnimatedOpacity(
            opacity: _isDraggingItem ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: IgnorePointer(
              ignoring: _isDraggingItem,
              child: SafeArea(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                            size: 28,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.undo,
                                color: _undoStack.isEmpty
                                    ? Colors.white38
                                    : Colors.white,
                                size: 28,
                              ),
                              onPressed: _undoStack.isEmpty ? null : _undo,
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.redo,
                                color: _redoStack.isEmpty
                                    ? Colors.white38
                                    : Colors.white,
                                size: 28,
                              ),
                              onPressed: _redoStack.isEmpty ? null : _redo,
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.auto_awesome,
                                color: Colors.amber,
                                size: 16,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Try Edits',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: _onNextPressed,
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: const BoxDecoration(
                              color: Colors.blueAccent,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_forward,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 4. TRASH CAN OVERLAY (Global Stack Layer)
          if (_isDraggingItem)
            Positioned(
              bottom: 60,
              left: MediaQuery.of(context).size.width / 2 - 35,
              child: AnimatedScale(
                scale: _isHoveringTrash ? 1.3 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: _isHoveringTrash
                        ? Colors.red
                        : Colors.red.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.delete,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomToolbar() {
    if (_selectedEditorClipIndex != null) {
      // Contextual Action Toolbar for Selected Clip
      return Container(
        height: 80,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(
                Icons.arrow_back_ios,
                color: Colors.white,
                size: 20,
              ),
              onPressed: () => setState(() => _selectedEditorClipIndex = null),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ListView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                children: [
                  _buildBottomActionIcon(
                    Icons.call_split,
                    'Split',
                    onTap: _splitClip,
                  ),
                  const SizedBox(width: 16),
                  _buildBottomActionIcon(
                    Icons.delete_outline,
                    'Delete',
                    onTap: _deleteClip,
                  ),
                  const SizedBox(width: 16),
                  _buildBottomActionIcon(
                    Icons.crop,
                    'Crop',
                    onTap: _showCropMenu,
                  ),
                  const SizedBox(width: 16),
                  _buildBottomActionIcon(
                    Icons.swap_horiz,
                    'Replace',
                    onTap: _replaceClip,
                  ),
                  const SizedBox(width: 16),
                  _buildBottomActionIcon(
                    Icons.reorder,
                    'Reorder',
                    onTap: _reorderClip,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Default Main Toolbar
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: [
          _buildBottomActionIcon(Icons.title, 'Text', onTap: _showTextInput),
          const SizedBox(width: 16),
          _buildBottomActionIcon(
            Icons.sticky_note_2_outlined,
            'Stickers',
            onTap: _showStickerSheet,
          ),
          const SizedBox(width: 16),
          _buildBottomActionIcon(
            Icons.music_note,
            'Audio',
            onTap: _showAudioSheet,
          ),
          const SizedBox(width: 16),
          _buildBottomActionIcon(
            Icons.add_to_photos,
            'Add clips',
            onTap: _pickAndAddClip,
          ),
          const SizedBox(width: 16),
          _buildBottomActionIcon(
            Icons.auto_awesome,
            'Effects',
            onTap: _showEffectsSheet,
          ),
          const SizedBox(width: 16),
          _buildBottomActionIcon(Icons.closed_caption, 'Captions'),
          const SizedBox(width: 16),
          _buildBottomActionIcon(
            Icons.save_alt,
            'Download',
            onTap: _simulateExport,
          ),
        ],
      ),
    );
  }
}
