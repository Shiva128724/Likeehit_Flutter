import 'dart:io';

import 'package:camera/camera.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/live_service.dart';
import 'live_page.dart';

class LiveHostSetupPage extends StatefulWidget {
  const LiveHostSetupPage({super.key});

  @override
  State<LiveHostSetupPage> createState() => _LiveHostSetupPageState();
}

class _LiveHostSetupPageState extends State<LiveHostSetupPage> {
  final TextEditingController _titleController = TextEditingController(
    text: 'welcome',
  );
  final TextEditingController _hashtagController = TextEditingController(
    text: '#Hosting',
  );

  final List<String> _beautifyItems = const <String>[
    'none',
    'smooth',
    'slimming',
    'slimface',
    'whiten',
    'size',
    'nose',
    'wing',
    'shape',
  ];
  final List<String> _filterItems = const <String>[
    'none',
    'fair',
    'milk tea',
    'fresh',
    'forest',
    'city',
    'paris',
    'cookie',
    'girl',
    'sweet',
    'rose',
    'memory',
    'spring',
    'lime',
    'island',
    'elegant',
    'art',
    'starlikee',
    'canvas',
    'gray',
    'vintage',
    'cream',
  ];

  bool _beautifyTab = true;
  bool _hdOn = true;
  bool _is3DOn = false;
  bool _isFrontCamera = true;
  bool _busy = false;
  String _selectedBeautify = 'smooth';
  String _selectedFilter = 'none';
  double _beautifyValue = 100;
  XFile? _cover;
  CameraController? _cameraController;
  List<CameraDescription> _cameras = const <CameraDescription>[];
  bool _cameraReady = false;
  bool _cameraBusy = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _titleController.dispose();
    _hashtagController.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) return;
      final lens = _isFrontCamera
          ? CameraLensDirection.front
          : CameraLensDirection.back;
      final picked =
          _cameras.where((c) => c.lensDirection == lens).toList().isNotEmpty
          ? _cameras.firstWhere((c) => c.lensDirection == lens)
          : _cameras.first;
      await _startController(picked);
    } catch (_) {}
  }

  Future<void> _startController(CameraDescription camera) async {
    final old = _cameraController;
    final controller = CameraController(
      camera,
      _hdOn ? ResolutionPreset.high : ResolutionPreset.medium,
      enableAudio: false,
    );
    _cameraController = controller;
    await old?.dispose();
    await controller.initialize();
    if (!mounted) return;
    setState(() => _cameraReady = true);
  }

  Future<void> _switchCamera() async {
    if (_cameraBusy || _cameras.isEmpty) return;
    _cameraBusy = true;
    try {
      setState(() => _isFrontCamera = !_isFrontCamera);
      final lens = _isFrontCamera
          ? CameraLensDirection.front
          : CameraLensDirection.back;
      final next = _cameras.firstWhere(
        (c) => c.lensDirection == lens,
        orElse: () => _cameras.first,
      );
      await _startController(next);
    } catch (_) {} finally {
      _cameraBusy = false;
    }
  }

  Future<void> _toggleHd() async {
    setState(() => _hdOn = !_hdOn);
    final current = _cameraController?.description;
    if (current != null) {
      await _startController(current);
    }
  }

  Future<void> _pickCover() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null || !mounted) return;
    setState(() => _cover = picked);
  }

  Future<String?> _uploadCoverIfNeeded() async {
    if (_cover == null) return null;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    final file = File(_cover!.path);
    final ref = FirebaseStorage.instance.ref(
      'live_covers/$uid/${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await ref.putFile(file);
    return ref.getDownloadURL();
  }

  Future<void> _goLive() async {
    setState(() => _busy = true);
    try {
      final uploadedCover = await _uploadCoverIfNeeded();
      final roomId = await LiveService.instance.createRoom(
        liveTitle: _titleController.text,
        hashtag: _hashtagController.text,
        coverUrl: uploadedCover,
        setupConfig: <String, dynamic>{
          'beautifyMode': _selectedBeautify,
          'beautifyValue': _beautifyValue.round(),
          'filter': _selectedFilter,
          'hdOn': _hdOn,
          'is3DOn': _is3DOn,
          'isFrontCamera': _isFrontCamera,
        },
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => LivePage(liveID: roomId, isHost: true),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to start live: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxW = constraints.maxWidth;
            return Stack(
              children: [
                Positioned.fill(
                  child: _cameraReady && _cameraController != null
                      ? FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: _cameraController!.value.previewSize?.height,
                            height: _cameraController!.value.previewSize?.width,
                            child: CameraPreview(_cameraController!),
                          ),
                        )
                      : Container(
                          color: const Color(0xFF131313),
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white54,
                            ),
                          ),
                        ),
                ),
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x66000000), Color(0xAA000000)],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Tip: Upload a clear half-body cover',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close, color: Colors.white),
                          ),
                        ],
                      ),
                      Container(
                        width: maxW,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: _pickCover,
                              child: Container(
                                width: 98,
                                height: 112,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  color: Colors.white10,
                                  image: _cover == null
                                      ? null
                                      : DecorationImage(
                                          image: FileImage(File(_cover!.path)),
                                          fit: BoxFit.cover,
                                        ),
                                ),
                                child: Align(
                                  alignment: Alignment.bottomCenter,
                                  child: Container(
                                    width: double.infinity,
                                    color: Colors.black54,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 6,
                                    ),
                                    child: const Text(
                                      'Change Cover',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  TextField(
                                    controller: _titleController,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      hintText: 'welcome',
                                      isDense: true,
                                      hintStyle: TextStyle(color: Colors.white54),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white24,
                                      borderRadius: BorderRadius.circular(22),
                                    ),
                                    child: TextField(
                                      controller: _hashtagController,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      decoration: const InputDecoration(
                                        border: InputBorder.none,
                                        isDense: true,
                                        contentPadding: EdgeInsets.zero,
                                        hintText: '#Hosting',
                                        hintStyle: TextStyle(
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _toggleChip(
                            label: _hdOn ? 'HD ON' : 'HD OFF',
                            icon: Icons.hd_rounded,
                            active: _hdOn,
                            onTap: _toggleHd,
                          ),
                          _toggleChip(
                            label: _isFrontCamera ? 'Front' : 'Back',
                            icon: Icons.cameraswitch_rounded,
                            active: _isFrontCamera,
                            onTap: _switchCamera,
                          ),
                          _toggleChip(
                            label: _is3DOn ? '3D ON' : '3D OFF',
                            icon: Icons.view_in_ar_rounded,
                            active: _is3DOn,
                            onTap: () => setState(() => _is3DOn = !_is3DOn),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                _tabBtn('Beautify', _beautifyTab, () {
                                  setState(() => _beautifyTab = true);
                                }),
                                const SizedBox(width: 18),
                                _tabBtn('Filters', !_beautifyTab, () {
                                  setState(() => _beautifyTab = false);
                                }),
                                const Spacer(),
                                IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _selectedBeautify = 'none';
                                      _selectedFilter = 'none';
                                      _beautifyValue = 0;
                                    });
                                  },
                                  icon: const Icon(
                                    Icons.refresh_rounded,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                            if (_beautifyTab) ...[
                              Text(
                                '${_selectedBeautify.toUpperCase()} ${_beautifyValue.round()}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                              Slider(
                                value: _beautifyValue,
                                min: 0,
                                max: 100,
                                activeColor: Colors.pinkAccent,
                                onChanged: (v) => setState(
                                  () => _beautifyValue = v,
                                ),
                              ),
                            ],
                            SizedBox(
                              height: 82,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: _beautifyTab
                                    ? _beautifyItems.length
                                    : _filterItems.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(width: 8),
                                itemBuilder: (context, index) {
                                  final value = _beautifyTab
                                      ? _beautifyItems[index]
                                      : _filterItems[index];
                                  final selected = _beautifyTab
                                      ? value == _selectedBeautify
                                      : value == _selectedFilter;
                                  return GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        if (_beautifyTab) {
                                          _selectedBeautify = value;
                                        } else {
                                          _selectedFilter = value;
                                        }
                                      });
                                    },
                                    child: Container(
                                      width: 88,
                                      decoration: BoxDecoration(
                                        color: Colors.white10,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: selected
                                              ? Colors.pinkAccent
                                              : Colors.transparent,
                                          width: 2,
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          value.toUpperCase(),
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: selected
                                                ? Colors.white
                                                : Colors.white70,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: _busy ? null : _goLive,
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFFFF3A74),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                                child: _busy
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        'Go Live',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _tabBtn(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: active ? Colors.white : Colors.white70,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          if (active)
            Container(
              width: 36,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.pinkAccent,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
        ],
      ),
    );
  }

  Widget _toggleChip({
    required String label,
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: active ? Colors.white24 : Colors.black54,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? Colors.white70 : Colors.white24),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
