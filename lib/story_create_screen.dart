import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_player/video_player.dart';

class StoryCreateScreen extends StatefulWidget {
  const StoryCreateScreen({super.key});

  @override
  State<StoryCreateScreen> createState() => _StoryCreateScreenState();
}

class _StoryCreateScreenState extends State<StoryCreateScreen> {
  final List<AssetEntity> _assets = [];
  final Set<String> _selectedIds = <String>{};
  final List<AssetEntity> _selectedAssets = [];
  bool _loading = true;
  bool _hasPermission = false;
  bool _selectMultiple = false;
  int _page = 0;
  bool _hasMore = true;
  static const int _pageSize = 60;

  @override
  void initState() {
    super.initState();
    _loadGallery();
  }

  Future<void> _loadGallery() async {
    setState(() => _loading = true);
    final granted = await _requestGalleryPermission();
    if (!granted) {
      setState(() {
        _hasPermission = false;
        _loading = false;
      });
      return;
    }
    if (!mounted) return;
    setState(() => _hasPermission = true);
    await _fetchNextPage(reset: true);
  }

  Future<bool> _requestGalleryPermission() async {
    final mediaPermission = await PhotoManager.requestPermissionExtend();
    if (mediaPermission.hasAccess) return true;

    if (Platform.isAndroid) {
      final statuses = await [
        Permission.photos,
        Permission.videos,
        Permission.storage,
      ].request();
      final photos = statuses[Permission.photos];
      final videos = statuses[Permission.videos];
      final storage = statuses[Permission.storage];
      final granted =
          photos?.isGranted == true ||
          photos?.isLimited == true ||
          videos?.isGranted == true ||
          videos?.isLimited == true ||
          storage?.isGranted == true;
      if (!granted) return false;
      final retryPermission = await PhotoManager.requestPermissionExtend();
      return retryPermission.hasAccess;
    }
    return false;
  }

  Future<void> _fetchNextPage({bool reset = false}) async {
    if (!reset && (!_hasMore || _loading)) return;
    if (reset) {
      _assets.clear();
      _page = 0;
      _hasMore = true;
    }
    setState(() => _loading = true);
    final albums = await PhotoManager.getAssetPathList(
      onlyAll: true,
      type: RequestType.common,
      filterOption: FilterOptionGroup(
        orders: const [OrderOption(type: OrderOptionType.createDate)],
      ),
    );
    if (albums.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    final items = await albums.first.getAssetListPaged(
      page: _page,
      size: _pageSize,
    );
    setState(() {
      _assets.addAll(items);
      _page++;
      _hasMore = items.length == _pageSize;
      _loading = false;
    });
  }

  void _toggleSelection(AssetEntity asset) {
    if (!_selectMultiple) {
      _openEditor([asset]);
      return;
    }
    setState(() {
      if (_selectedIds.remove(asset.id)) {
        _selectedAssets.removeWhere((item) => item.id == asset.id);
      } else {
        _selectedIds.add(asset.id);
        _selectedAssets.add(asset);
      }
    });
  }

  void _openEditor(List<AssetEntity> assets) {
    if (assets.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => StoryEditorScreen(assets: assets)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF252525),
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            _toolRail(),
            _galleryHeader(),
            Expanded(child: _galleryGrid()),
            if (_selectedAssets.isNotEmpty) _selectionBar(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: const Color(0xFF1677FF),
        child: const Icon(Icons.camera_alt_rounded, color: Colors.black),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 14, 16),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.close_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
          const Expanded(
            child: Text(
              'Create story',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.settings_outlined,
              color: Colors.white,
              size: 34,
            ),
          ),
        ],
      ),
    );
  }

  Widget _toolRail() {
    final tools = [
      _StoryTool('Text', Icons.text_fields_rounded),
      _StoryTool('Music', Icons.music_note_rounded),
      _StoryTool('Collage', Icons.view_comfy_alt_rounded),
      _StoryTool('AI images', Icons.add_photo_alternate_outlined),
      _StoryTool('Templates', Icons.filter_none_rounded),
      _StoryTool('Boomerang', Icons.all_inclusive_rounded),
    ];
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemBuilder: (context, index) => _toolCard(tools[index]),
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemCount: tools.length,
      ),
    );
  }

  Widget _toolCard(_StoryTool tool) {
    return GestureDetector(
      onTap: () => _showToolToast(tool.label),
      child: Container(
        width: 118,
        decoration: BoxDecoration(
          color: const Color(0xFF333333),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(tool.icon, color: Colors.white, size: 28),
            const SizedBox(height: 8),
            Text(
              tool.label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _galleryHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Row(
        children: [
          const Text(
            'Gallery',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _selectMultiple = !_selectMultiple;
                if (!_selectMultiple) {
                  _selectedIds.clear();
                  _selectedAssets.clear();
                }
              });
            },
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Select multiple'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(
                color: _selectMultiple ? const Color(0xFF1677FF) : Colors.white,
                width: 2,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _galleryGrid() {
    if (!_hasPermission) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton(
              onPressed: _loadGallery,
              child: const Text('Allow gallery access'),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: openAppSettings,
              child: const Text(
                'Open app settings',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
      );
    }
    if (_assets.isEmpty && _loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF1677FF)),
      );
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.extentAfter < 520 && !_loading) {
          _fetchNextPage();
        }
        return false;
      },
      child: GridView.builder(
        padding: EdgeInsets.zero,
        itemCount: _assets.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
          childAspectRatio: 0.82,
        ),
        itemBuilder: (context, index) {
          final asset = _assets[index];
          return _GalleryAssetTile(
            asset: asset,
            selectedIndex:
                _selectedAssets.indexWhere((item) => item.id == asset.id) >= 0
                ? _selectedAssets.indexWhere((item) => item.id == asset.id) + 1
                : 0,
            onTap: () => _toggleSelection(asset),
          );
        },
      ),
    );
  }

  Widget _selectionBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Text(
            '${_selectedAssets.length} selected',
            style: const TextStyle(
              color: Color(0xFF20212B),
              fontWeight: FontWeight.w900,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () =>
                _openEditor(List<AssetEntity>.from(_selectedAssets)),
            icon: const Icon(Icons.edit_rounded),
          ),
          IconButton(
            onPressed: () =>
                _openEditor(List<AssetEntity>.from(_selectedAssets)),
            icon: const Icon(Icons.share_rounded),
          ),
        ],
      ),
    );
  }

  void _showToolToast(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label coming soon'),
        duration: const Duration(seconds: 1),
      ),
    );
  }
}

class StoryEditorScreen extends StatefulWidget {
  const StoryEditorScreen({super.key, required this.assets});

  final List<AssetEntity> assets;

  @override
  State<StoryEditorScreen> createState() => _StoryEditorScreenState();
}

class _StoryEditorScreenState extends State<StoryEditorScreen> {
  final AudioPlayer _editorAudioPlayer = AudioPlayer();
  bool _sharing = false;
  int _index = 0;
  _StoryAudio? _selectedAudio;
  _StoryEffect _selectedEffect = _storyEffects.first;
  bool _showEffects = false;
  final List<_PlacedSticker> _stickers = [];
  int _stickerSeed = 0;
  String? _activeStickerId;
  String? _gestureStickerId;
  double _gestureStartScale = 1;

  AssetEntity get _asset => widget.assets[_index];

  @override
  void dispose() {
    _editorAudioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: _StoryAssetPreview(asset: _asset, effect: _selectedEffect),
            ),
            ..._stickers.map(_stickerOverlay),
            _topBar(),
            _rightTools(),
            if (_showEffects) _effectsRow(),
            _bottomBar(),
            if (widget.assets.length > 1) _assetDots(),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    return Positioned(
      left: 12,
      right: 12,
      top: 16,
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.close_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _openAudioPicker,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 250),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.music_note_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedAudio?.title ?? 'Add audio',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          _selectedAudio?.artist ?? 'Discover suggestions',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _rightTools() {
    final tools = [
      _StoryTool('Stickers', Icons.theater_comedy_rounded),
      _StoryTool('Text', Icons.text_fields_rounded),
      _StoryTool('Audio', Icons.music_note_rounded),
      _StoryTool('Effects', Icons.auto_awesome_rounded),
    ];
    return Positioned(
      right: 12,
      top: 250,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: tools
            .map(
              (tool) => GestureDetector(
                onTap: () {
                  if (tool.label == 'Audio') {
                    _openAudioPicker();
                  } else if (tool.label == 'Stickers') {
                    _openStickerSheet();
                  } else if (tool.label == 'Text') {
                    _openTextEditor();
                  } else if (tool.label == 'Effects') {
                    setState(() => _showEffects = !_showEffects);
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 22),
                  child: Row(
                    children: [
                      Text(
                        tool.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          shadows: [Shadow(color: Colors.black, blurRadius: 8)],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(tool.icon, color: Colors.white, size: 34),
                    ],
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Future<void> _openAudioPicker() async {
    final selected = await showModalBottomSheet<_StoryAudio>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF262728),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => const _StoryAudioPickerSheet(),
    );
    if (selected == null || !mounted) return;
    setState(() => _selectedAudio = selected);
    unawaited(_playEditorAudio(selected));
  }

  Future<void> _playEditorAudio(_StoryAudio audio) async {
    final url = audio.previewUrl.trim();
    if (url.isEmpty) return;
    try {
      await _editorAudioPlayer.stop();
      await _editorAudioPlayer.setReleaseMode(ReleaseMode.loop);
      await _editorAudioPlayer.setVolume(0.75);
      await _editorAudioPlayer.play(UrlSource(url));
    } catch (_) {}
  }

  Future<void> _openStickerSheet() async {
    final selected = await showModalBottomSheet<_StickerChoice>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _StoryStickerSheet(),
    );
    if (selected == null || !mounted) return;
    if (selected.action == 'music') {
      await _openAudioPicker();
      return;
    }
    final prepared = await _prepareStickerChoice(selected);
    if (prepared == null || !mounted) return;
    _addSticker(prepared);
  }

  Future<void> _openTextEditor() async {
    final selected = await Navigator.of(context).push<_StickerChoice>(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black.withValues(alpha: 0.42),
        pageBuilder: (_, _, _) => const _StoryTextEditorOverlay(),
      ),
    );
    if (selected == null || !mounted) return;
    _addSticker(selected);
  }

  Future<_StickerChoice?> _prepareStickerChoice(_StickerChoice selected) async {
    if (selected.action.endsWith('Prompt')) {
      await Future<void>.delayed(const Duration(milliseconds: 180));
      if (!mounted) return null;
    }
    switch (selected.action) {
      case 'addYoursPrompt':
        final text = await _textPrompt(
          context,
          title: 'Add Yours',
          hint: 'Type your prompt',
          actionLabel: 'Add yours',
        );
        if (text == null) return null;
        return _StickerChoice(
          text,
          _StickerKind.card,
          icon: Icons.camera_alt_rounded,
          color: const Color(0xFF1677FF),
          action: 'addYours',
          metadata: const {'cta': 'Add yours'},
        );
      case 'donatePrompt':
        final text = await _textPrompt(
          context,
          title: 'Donate',
          hint: 'Donation title or amount',
          actionLabel: 'Add donate',
        );
        if (text == null) return null;
        return _StickerChoice(
          text,
          _StickerKind.card,
          icon: Icons.favorite_rounded,
          color: const Color(0xFFE33A5D),
          action: 'donate',
          metadata: const {'cta': 'Donate'},
        );
      case 'questionPrompt':
        final text = await _textPrompt(
          context,
          title: 'Question',
          hint: 'Ask a question',
          actionLabel: 'Add question',
        );
        if (text == null) return null;
        return _StickerChoice(
          text,
          _StickerKind.card,
          icon: Icons.contact_support_rounded,
          color: const Color(0xFFE33A5D),
          action: 'question',
          metadata: const {'cta': 'Reply'},
        );
      case 'captionsPrompt':
        final text = await _textPrompt(
          context,
          title: 'Captions',
          hint: 'Write caption',
          actionLabel: 'Add captions',
        );
        if (text == null) return null;
        return _StickerChoice(
          text,
          _StickerKind.card,
          icon: Icons.closed_caption_rounded,
          color: const Color(0xFF8B5CF6),
          action: 'captions',
          metadata: const {'cta': 'Captions'},
        );
      case 'pollPrompt':
        return showModalBottomSheet<_StickerChoice>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => const _PollStickerSheet(),
        );
      case 'linkPrompt':
        final text = await _textPrompt(
          context,
          title: 'Link',
          hint: 'https://example.com',
          actionLabel: 'Add link',
          keyboardType: TextInputType.url,
        );
        if (text == null) return null;
        final url = text.startsWith('http') ? text : 'https://$text';
        return _StickerChoice(
          url,
          _StickerKind.link,
          icon: Icons.link_rounded,
          color: const Color(0xFF1677FF),
          action: 'link',
          metadata: {'url': url, 'cta': 'Open link'},
        );
    }
    return selected;
  }

  void _addSticker(_StickerChoice selected) {
    setState(() {
      _stickerSeed++;
      final stickerId = 'sticker_$_stickerSeed';
      _activeStickerId = stickerId;
      _stickers.add(
        _PlacedSticker(
          id: stickerId,
          choice: selected,
          offset: const Offset(92, 260),
          scale: 1,
        ),
      );
    });
  }

  Future<String?> _textPrompt(
    BuildContext context, {
    required String title,
    required String hint,
    required String actionLabel,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _TextStickerPromptSheet(
        title: title,
        hint: hint,
        actionLabel: actionLabel,
        keyboardType: keyboardType,
      ),
    );
  }

  Widget _stickerOverlay(_PlacedSticker sticker) {
    return Positioned(
      left: sticker.offset.dx,
      top: sticker.offset.dy,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => setState(() => _activeStickerId = sticker.id),
        onLongPress: () => _removeSticker(sticker.id),
        onScaleStart: (_) {
          _gestureStickerId = sticker.id;
          _gestureStartScale = sticker.scale;
        },
        onScaleUpdate: (details) {
          setState(() {
            _activeStickerId = sticker.id;
            final index = _stickers.indexWhere((item) => item.id == sticker.id);
            if (index == -1) return;
            final size = MediaQuery.sizeOf(context);
            final current = _stickers[index];
            final next = current.offset + details.focalPointDelta;
            _stickers[index] = _stickers[index].copyWith(
              offset: Offset(
                next.dx.clamp(0, size.width - 72).toDouble(),
                next.dy.clamp(0, size.height - 120).toDouble(),
              ),
              scale:
                  ((_gestureStickerId == sticker.id
                              ? _gestureStartScale
                              : current.scale) *
                          details.scale)
                      .clamp(0.45, 3.0),
            );
          });
        },
        onScaleEnd: (_) => _gestureStickerId = null,
        child: Transform.translate(
          offset: const Offset(-36, -36),
          child: Padding(
            padding: const EdgeInsets.all(36),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Transform.scale(
                  scale: sticker.scale,
                  alignment: Alignment.center,
                  child: _placedStickerContent(sticker.choice),
                ),
                if (_activeStickerId == sticker.id)
                  Positioned(
                    right: -13,
                    top: -13,
                    child: GestureDetector(
                      onTap: () => _removeSticker(sticker.id),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.78),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _placedStickerContent(_StickerChoice choice) {
    switch (choice.kind) {
      case _StickerKind.gif:
        return _placedGifSticker(choice);
      case _StickerKind.card:
      case _StickerKind.poll:
      case _StickerKind.link:
        return _placedCardSticker(choice);
      case _StickerKind.chip:
        return _placedChipSticker(choice);
      case _StickerKind.text:
        return _placedStoryTextSticker(choice);
      case _StickerKind.premium:
      case _StickerKind.emoji:
        return _placedTextSticker(choice);
    }
  }

  void _removeSticker(String id) {
    setState(() {
      _stickers.removeWhere((item) => item.id == id);
      if (_activeStickerId == id) _activeStickerId = null;
    });
  }

  Widget _placedChipSticker(_StickerChoice choice) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 230),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (choice.icon != null) ...[
            Icon(choice.icon, color: choice.color, size: 22),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              choice.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF2B2B2D),
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placedGifSticker(_StickerChoice choice) {
    final url = choice.metadata['url'] ?? '';
    return Container(
      width: 112,
      height: 112,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      child: url.isEmpty
          ? const Icon(Icons.gif_box_rounded, color: Colors.white, size: 62)
          : Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  const Icon(Icons.gif_box_rounded, color: Colors.white),
            ),
    );
  }

  Widget _placedCardSticker(_StickerChoice choice) {
    final subtitle = choice.metadata['subtitle'] ?? '';
    final cta = choice.metadata['cta'] ?? '';
    final icon = choice.icon ?? Icons.auto_awesome_rounded;
    final isPoll = choice.kind == _StickerKind.poll;
    return Container(
      width: choice.action == 'addYours' ? 210 : 230,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            choice.label,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF1F2028),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF727381),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (isPoll)
            Row(
              children: [
                Expanded(
                  child: _pollOption(
                    choice.metadata['yesLabel'] ?? 'Yes',
                    choice.color,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _pollOption(
                    choice.metadata['noLabel'] ?? 'No',
                    choice.color,
                  ),
                ),
              ],
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: choice.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: choice.color, size: 20),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      cta.isEmpty ? choice.action : cta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: choice.color,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _pollOption(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _placedTextSticker(_StickerChoice choice) {
    return Text(
      choice.label,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: choice.color,
        fontSize: choice.kind == _StickerKind.premium ? 38 : 46,
        fontWeight: FontWeight.w900,
        height: 1.15,
        shadows: const [
          Shadow(color: Colors.black87, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
    );
  }

  Widget _placedStoryTextSticker(_StickerChoice choice) {
    final align = _textAlignFromKey(choice.metadata['align']);
    final styleKey = choice.metadata['style'] ?? 'classic';
    final withBackground = choice.metadata['background'] == 'true';
    return Container(
      constraints: const BoxConstraints(maxWidth: 300),
      padding: withBackground
          ? const EdgeInsets.symmetric(horizontal: 10, vertical: 5)
          : EdgeInsets.zero,
      decoration: BoxDecoration(
        color: withBackground ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        choice.label,
        textAlign: align,
        style: _storyTextStyle(
          styleKey,
          withBackground ? Colors.black : choice.color,
          fontSize: 38,
        ),
      ),
    );
  }

  Widget _bottomBar() {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 18,
      child: Align(
        alignment: Alignment.centerRight,
        child: SizedBox(
          width: 158,
          height: 58,
          child: FilledButton(
            onPressed: _sharing ? null : _shareStory,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1677FF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _sharing
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text(
                    'Share',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _effectsRow() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 88,
      child: SizedBox(
        height: 86,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          scrollDirection: Axis.horizontal,
          itemCount: _storyEffects.length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            final effect = _storyEffects[index];
            final selected = effect.key == _selectedEffect.key;
            return GestureDetector(
              onTap: () => setState(() => _selectedEffect = effect),
              child: SizedBox(
                width: 64,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: selected ? 62 : 54,
                      height: selected ? 62 : 54,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected ? Colors.white : Colors.white24,
                          width: selected ? 3 : 1,
                        ),
                        boxShadow: selected
                            ? const [
                                BoxShadow(
                                  color: Colors.black54,
                                  blurRadius: 10,
                                ),
                              ]
                            : null,
                      ),
                      child: ClipOval(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: effect.colors),
                          ),
                          child: Icon(
                            effect.icon,
                            color: Colors.white,
                            size: selected ? 27 : 24,
                            shadows: const [
                              Shadow(color: Colors.black54, blurRadius: 5),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      effect.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        shadows: [Shadow(color: Colors.black87, blurRadius: 5)],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _assetDots() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 100,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(widget.assets.length, (index) {
          return GestureDetector(
            onTap: () => setState(() => _index = index),
            child: Container(
              width: _index == index ? 18 : 7,
              height: 7,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: _index == index ? Colors.white : Colors.white54,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          );
        }),
      ),
    );
  }

  Future<void> _shareStory() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    unawaited(_editorAudioPlayer.stop());
    setState(() => _sharing = true);
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final userData = userDoc.data() ?? <String, dynamic>{};
      for (final asset in widget.assets) {
        await _uploadAssetStory(uid, userData, asset);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Story shared')));
      Navigator.pop(context);
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _uploadAssetStory(
    String uid,
    Map<String, dynamic> userData,
    AssetEntity asset,
  ) async {
    final file = await asset.file;
    if (file == null) throw StateError('Unable to read selected media.');
    final storyRef = FirebaseFirestore.instance.collection('stories').doc();
    final isVideo = asset.type == AssetType.video;
    final storyDurationSeconds = isVideo
        ? asset.duration.clamp(15, 60).toInt()
        : 15;
    final extension = isVideo ? 'mp4' : 'jpg';
    final storageRef = FirebaseStorage.instance.ref(
      'stories/$uid/${storyRef.id}.$extension',
    );
    await storageRef.putFile(
      File(file.path),
      SettableMetadata(contentType: isVideo ? 'video/mp4' : 'image/jpeg'),
    );
    final mediaUrl = await storageRef.getDownloadURL();
    String thumbnailUrl = '';
    final thumbnailBytes = await asset.thumbnailDataWithSize(
      const ThumbnailSize(600, 900),
      quality: 82,
    );
    if (thumbnailBytes != null) {
      final thumbRef = FirebaseStorage.instance.ref(
        'stories/$uid/${storyRef.id}_thumb.jpg',
      );
      await thumbRef.putData(
        thumbnailBytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      thumbnailUrl = await thumbRef.getDownloadURL();
    }
    final stickerMaps = _stickers.map((sticker) {
      final map = sticker.toMap();
      if (sticker.choice.kind == _StickerKind.poll) {
        map['pollId'] = sticker.id;
      }
      return map;
    }).toList();
    await storyRef.set({
      'storyId': storyRef.id,
      'uid': uid,
      'userName': userData['name']?.toString() ?? 'Likeehit User',
      'userPhotoUrl':
          userData['photoURL']?.toString() ??
          userData['photoUrl']?.toString() ??
          '',
      'imageUrl': isVideo ? thumbnailUrl : mediaUrl,
      'mediaUrl': mediaUrl,
      'mediaType': isVideo ? 'video' : 'image',
      'storyDurationSeconds': storyDurationSeconds,
      if (isVideo) 'videoDurationSeconds': asset.duration,
      if (_selectedAudio != null) 'audioTitle': _selectedAudio!.title,
      if (_selectedAudio != null) 'audioArtist': _selectedAudio!.artist,
      if (_selectedAudio != null) 'audioMood': _selectedAudio!.mood,
      if (_selectedAudio != null) 'audioUrl': _selectedAudio!.previewUrl,
      if (_selectedEffect.key != 'none') 'effectKey': _selectedEffect.key,
      if (_selectedEffect.key != 'none') 'effectLabel': _selectedEffect.label,
      if (stickerMaps.isNotEmpty) 'stickers': stickerMaps,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(
        DateTime.now().add(const Duration(hours: 24)),
      ),
    });
    for (final sticker in _stickers) {
      if (sticker.choice.kind != _StickerKind.poll) continue;
      await storyRef.collection('polls').doc(sticker.id).set({
        'pollId': sticker.id,
        'question': sticker.choice.label,
        'yesLabel': sticker.choice.metadata['yesLabel'] ?? 'Yes',
        'noLabel': sticker.choice.metadata['noLabel'] ?? 'No',
        'yesVotes': 0,
        'noVotes': 0,
        'voters': <String, String>{},
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    if (_selectedAudio != null) {
      await _upsertStoryAudioLibrary(_selectedAudio!);
    }
  }
}

class _GalleryAssetTile extends StatefulWidget {
  const _GalleryAssetTile({
    required this.asset,
    required this.selectedIndex,
    required this.onTap,
  });

  final AssetEntity asset;
  final int selectedIndex;
  final VoidCallback onTap;

  @override
  State<_GalleryAssetTile> createState() => _GalleryAssetTileState();
}

class _GalleryAssetTileState extends State<_GalleryAssetTile> {
  Uint8List? _thumb;

  @override
  void initState() {
    super.initState();
    _loadThumb();
  }

  @override
  void didUpdateWidget(covariant _GalleryAssetTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset.id != widget.asset.id) {
      _thumb = null;
      _loadThumb();
    }
  }

  Future<void> _loadThumb() async {
    final data = await widget.asset.thumbnailDataWithSize(
      const ThumbnailSize(360, 480),
      quality: 78,
    );
    if (mounted) setState(() => _thumb = data);
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selectedIndex > 0;
    return GestureDetector(
      onTap: widget.onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_thumb == null)
            const ColoredBox(color: Color(0xFF171720))
          else
            Image.memory(_thumb!, fit: BoxFit.cover),
          if (widget.asset.type == AssetType.video)
            const Positioned(
              left: 6,
              bottom: 6,
              child: Icon(
                Icons.play_circle_fill_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          if (selected) Container(color: const Color(0x661677FF)),
          if (selected)
            Positioned(
              right: 7,
              top: 7,
              child: CircleAvatar(
                radius: 14,
                backgroundColor: const Color(0xFF1677FF),
                child: Text(
                  '${widget.selectedIndex}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StoryAudioPickerSheet extends StatefulWidget {
  const _StoryAudioPickerSheet();

  @override
  State<_StoryAudioPickerSheet> createState() => _StoryAudioPickerSheetState();
}

class _StoryAudioPickerSheetState extends State<_StoryAudioPickerSheet> {
  final AudioPlayer _previewPlayer = AudioPlayer();
  StreamSubscription<void>? _completeSub;
  String _query = '';
  String? _playingTitle;

  @override
  void initState() {
    super.initState();
    _completeSub = _previewPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playingTitle = null);
    });
  }

  @override
  void dispose() {
    _completeSub?.cancel();
    _previewPlayer.dispose();
    super.dispose();
  }

  static const List<_StoryAudio> _audios = [
    _StoryAudio('Vo Purane Pal (दो पुराने पल)', 'Sufi Rizwan', '3.7M', 'Sufi', [
      Color(0xFF9B4B20),
      Color(0xFFE0A13A),
    ]),
    _StoryAudio(
      'Aa Jee Le Ik Pal Mein',
      'Udit Narayan, Alka Yagnik',
      '41M',
      'Romantic',
      [Color(0xFF176A7A), Color(0xFF79D4E8)],
    ),
    _StoryAudio(
      'Baagh Ka Kareja',
      'Manoj Tiwari, Aditya Dev',
      '2.2M',
      'Bhojpuri',
      [Color(0xFFC9902B), Color(0xFFF8D36A)],
    ),
    _StoryAudio(
      'Utral Ba Chand Dekha Aaj',
      'Pawan Singh, Manohar Singh',
      '5.8M',
      'Trending',
      [Color(0xFFD24E66), Color(0xFFFFA08C)],
    ),
    _StoryAudio('Waqt Badalta Ha Chehre Bhi', 'Irfan Ali', '1.7M', 'Sad', [
      Color(0xFF633C8A),
      Color(0xFFDDA6FF),
    ]),
    _StoryAudio(
      'Shiv Strotram - Bahubali Version',
      'Kailash Kher',
      '422K',
      'Bhakti',
      [Color(0xFF342B87), Color(0xFFB466FF)],
    ),
    _StoryAudio(
      '15 Saal Ki Age',
      'Aamin Mehmiya, Amit Andane',
      '9.1M',
      'Viral',
      [Color(0xFF801A1E), Color(0xFFE04E59)],
    ),
    _StoryAudio('Zindagi Khoobsoorat Hai', 'Udit Narayan', '8.5M', 'Classic', [
      Color(0xFF264B8A),
      Color(0xFF71A2FF),
    ]),
    _StoryAudio(
      'Shakti Hai Bhakti Hai',
      'Himanshu Singh',
      '50K',
      'Devotional',
      [Color(0xFF6D3A14), Color(0xFFFFB44A)],
    ),
    _StoryAudio('Zindagi Se Jung', 'Alka Yagnik', '10M', 'Bollywood', [
      Color(0xFF343434),
      Color(0xFFC9C9C9),
    ]),
    _StoryAudio('Kyo Kisi Ko', 'Udit Narayan', '8.8M', 'Love', [
      Color(0xFF586373),
      Color(0xFFCED8E8),
    ]),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.92,
        child: Column(
          children: [
            const SizedBox(height: 12),
            _searchHeader(),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Text(
                    'For you',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _openReelsAudioList,
                    child: const Text(
                      'See all',
                      style: TextStyle(
                        color: Color(0xFF75AEFF),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<List<_StoryAudio>>(
                stream: _watchAudioLibrary(),
                builder: (context, snapshot) {
                  final allAudios = _mergeAudios(
                    _audios,
                    snapshot.data ?? const <_StoryAudio>[],
                  );
                  final filtered = allAudios.where((audio) {
                    final haystack =
                        '${audio.title} ${audio.artist} ${audio.mood}'
                            .toLowerCase();
                    return haystack.contains(_query.toLowerCase());
                  }).toList();
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      return _audioRow(filtered[index]);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 54,
              decoration: BoxDecoration(
                color: const Color(0xFF4B4C4F),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                onChanged: (value) => setState(() => _query = value.trim()),
                style: const TextStyle(color: Colors.white, fontSize: 18),
                decoration: const InputDecoration(
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: Color(0xFFD0D0D0),
                    size: 30,
                  ),
                  hintText: 'Search moods',
                  hintStyle: TextStyle(color: Color(0xFFC5C5C5), fontSize: 18),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _openSavedMusic,
            child: Container(
              width: 58,
              height: 54,
              decoration: BoxDecoration(
                color: const Color(0xFF4B4C4F),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.bookmark_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _audioRow(_StoryAudio audio) {
    final isPlaying = _playingTitle == audio.title;
    return GestureDetector(
      onTap: () => Navigator.pop(context, audio),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: audio.colors,
                ),
              ),
              child: const Icon(
                Icons.music_note_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    audio.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${audio.artist} · ${audio.plays}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFB9B9B9),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => _openAudioOptions(audio),
              icon: const Icon(Icons.more_horiz_rounded, color: Colors.white),
            ),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isPlaying ? const Color(0xFF1677FF) : Colors.white12,
                  width: isPlaying ? 3 : 2,
                ),
              ),
              child: IconButton(
                onPressed: () => _togglePreview(audio),
                icon: Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white70,
                  size: 28,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _togglePreview(_StoryAudio audio) async {
    if (_playingTitle == audio.title) {
      await _previewPlayer.pause();
      if (mounted) setState(() => _playingTitle = null);
      return;
    }
    await _previewPlayer.stop();
    await _previewPlayer.play(UrlSource(audio.previewUrl));
    if (mounted) setState(() => _playingTitle = audio.title);
  }

  Stream<List<_StoryAudio>> _watchAudioLibrary() {
    return FirebaseFirestore.instance
        .collection('audioLibrary')
        .orderBy('updatedAt', descending: true)
        .limit(80)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => _StoryAudio.fromDoc(doc))
              .where((audio) => audio.title.trim().isNotEmpty)
              .toList();
        });
  }

  List<_StoryAudio> _mergeAudios(
    List<_StoryAudio> staticAudios,
    List<_StoryAudio> libraryAudios,
  ) {
    final byId = <String, _StoryAudio>{};
    for (final audio in staticAudios) {
      byId[audio.id] = audio;
    }
    for (final audio in libraryAudios) {
      byId[audio.id] = audio;
    }
    return byId.values.toList();
  }

  Future<void> _openSavedMusic() async {
    final selected = await Navigator.push<_StoryAudio>(
      context,
      MaterialPageRoute(builder: (_) => const _SavedMusicScreen()),
    );
    if (selected == null || !mounted) return;
    Navigator.pop(context, selected);
  }

  Future<void> _openReelsAudioList() async {
    final selected = await Navigator.push<_StoryAudio>(
      context,
      MaterialPageRoute(builder: (_) => const _ReelsAudioScreen()),
    );
    if (selected == null || !mounted) return;
    Navigator.pop(context, selected);
  }

  Future<void> _openAudioOptions(_StoryAudio audio) async {
    final pickerContext = context;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF262728),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white30,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 18),
                _audioOptionTile(
                  icon: Icons.music_note_rounded,
                  label: "Select '${audio.title}'",
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.pop(pickerContext, audio);
                  },
                ),
                StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: _savedAudioDoc(audio).snapshots(),
                  builder: (context, snapshot) {
                    final saved = snapshot.data?.exists == true;
                    return _audioOptionTile(
                      icon: saved
                          ? Icons.bookmark_remove_rounded
                          : Icons.bookmark_rounded,
                      label: saved ? 'Unsave audio' : 'Save audio',
                      onTap: () {
                        Navigator.pop(sheetContext);
                        if (saved) {
                          unawaited(_unsaveAudio(audio, pickerContext));
                        } else {
                          unawaited(_saveAudio(audio, pickerContext));
                        }
                      },
                    );
                  },
                ),
                _audioOptionTile(
                  icon: Icons.report_gmailerrorred_rounded,
                  label: 'Report audio',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    unawaited(_reportAudio(audio, pickerContext));
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _audioOptionTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: const Color(0xFF3D3E40),
        child: Icon(icon, color: Colors.white, size: 28),
      ),
      title: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w900,
        ),
      ),
      onTap: onTap,
    );
  }

  DocumentReference<Map<String, dynamic>> _savedAudioDoc(_StoryAudio audio) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '_guest';
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('savedAudios')
        .doc(audio.id);
  }

  Future<void> _saveAudio(_StoryAudio audio, BuildContext context) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _upsertStoryAudioLibrary(audio);
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('savedAudios')
        .doc(audio.id)
        .set({
          ...audio.toMap(),
          'savedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Saved audio: ${audio.title}'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _unsaveAudio(_StoryAudio audio, BuildContext context) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('savedAudios')
        .doc(audio.id)
        .delete();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Unsaved audio: ${audio.title}'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _reportAudio(_StoryAudio audio, BuildContext context) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    await FirebaseFirestore.instance.collection('audioReports').add({
      'audioId': audio.id,
      'title': audio.title,
      'artist': audio.artist,
      'uid': uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Audio report submitted'),
        duration: Duration(seconds: 1),
      ),
    );
  }
}

class _SavedMusicScreen extends StatefulWidget {
  const _SavedMusicScreen();

  @override
  State<_SavedMusicScreen> createState() => _SavedMusicScreenState();
}

class _SavedMusicScreenState extends State<_SavedMusicScreen> {
  final AudioPlayer _previewPlayer = AudioPlayer();
  StreamSubscription<void>? _completeSub;
  String? _playingId;

  @override
  void initState() {
    super.initState();
    _completeSub = _previewPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playingId = null);
    });
  }

  @override
  void dispose() {
    _completeSub?.cancel();
    _previewPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      backgroundColor: const Color(0xFF262728),
      appBar: AppBar(
        backgroundColor: const Color(0xFF262728),
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        ),
        centerTitle: true,
        title: const Text(
          'Saved music',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
      ),
      body: uid == null
          ? const Center(
              child: Text(
                'Sign in required',
                style: TextStyle(color: Colors.white70),
              ),
            )
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .collection('savedAudios')
                  .orderBy('savedAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                final audios =
                    snapshot.data?.docs
                        .map((doc) => _StoryAudio.fromDoc(doc))
                        .toList() ??
                    const <_StoryAudio>[];
                if (audios.isEmpty) {
                  return const Center(
                    child: Text(
                      'No saved music yet',
                      style: TextStyle(color: Colors.white70),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                  itemCount: audios.length,
                  itemBuilder: (context, index) =>
                      _savedAudioRow(audios[index]),
                );
              },
            ),
    );
  }

  Widget _savedAudioRow(_StoryAudio audio) {
    final playing = _playingId == audio.id;
    return GestureDetector(
      onTap: () => Navigator.pop(context, audio),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                gradient: LinearGradient(colors: audio.colors),
              ),
              child: const Icon(Icons.music_note_rounded, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    audio.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${audio.artist} · ${audio.plays}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFB9B9B9),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => _openSavedOptions(audio),
              icon: const Icon(Icons.more_horiz_rounded, color: Colors.white),
            ),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: playing ? const Color(0xFF1677FF) : Colors.white12,
                  width: playing ? 3 : 2,
                ),
              ),
              child: IconButton(
                onPressed: () => _togglePreview(audio),
                icon: Icon(
                  playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white70,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _togglePreview(_StoryAudio audio) async {
    if (_playingId == audio.id) {
      await _previewPlayer.pause();
      if (mounted) setState(() => _playingId = null);
      return;
    }
    await _previewPlayer.stop();
    await _previewPlayer.play(UrlSource(audio.previewUrl));
    if (mounted) setState(() => _playingId = audio.id);
  }

  Future<void> _openSavedOptions(_StoryAudio audio) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF262728),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white30,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 18),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFF3D3E40),
                    child: Icon(Icons.music_note_rounded, color: Colors.white),
                  ),
                  title: Text(
                    "Select '${audio.title}'",
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.pop(context, audio);
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFF3D3E40),
                    child: Icon(
                      Icons.bookmark_remove_rounded,
                      color: Colors.white,
                    ),
                  ),
                  title: const Text(
                    'Unsave audio',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    unawaited(_unsave(audio));
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFF3D3E40),
                    child: Icon(
                      Icons.report_gmailerrorred_rounded,
                      color: Colors.white,
                    ),
                  ),
                  title: const Text(
                    'Report audio',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    unawaited(_report(audio));
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _unsave(_StoryAudio audio) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('savedAudios')
        .doc(audio.id)
        .delete();
  }

  Future<void> _report(_StoryAudio audio) async {
    await FirebaseFirestore.instance.collection('audioReports').add({
      'audioId': audio.id,
      'title': audio.title,
      'artist': audio.artist,
      'uid': FirebaseAuth.instance.currentUser?.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}

class _ReelsAudioScreen extends StatefulWidget {
  const _ReelsAudioScreen();

  @override
  State<_ReelsAudioScreen> createState() => _ReelsAudioScreenState();
}

class _ReelsAudioScreenState extends State<_ReelsAudioScreen> {
  final AudioPlayer _previewPlayer = AudioPlayer();
  StreamSubscription<void>? _completeSub;
  String? _playingId;

  @override
  void initState() {
    super.initState();
    _completeSub = _previewPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playingId = null);
    });
  }

  @override
  void dispose() {
    _completeSub?.cancel();
    _previewPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF262728),
      appBar: AppBar(
        backgroundColor: const Color(0xFF262728),
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        ),
        centerTitle: true,
        title: const Text(
          'For you',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('posts')
            .orderBy('createdAt', descending: true)
            .limit(150)
            .snapshots(),
        builder: (context, snapshot) {
          final audios = _dedupePostAudios(
            snapshot.data?.docs ??
                const <QueryDocumentSnapshot<Map<String, dynamic>>>[],
          );
          if (audios.isEmpty) {
            return const Center(
              child: Text(
                'No reels audio yet',
                style: TextStyle(color: Colors.white70),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
            itemCount: audios.length,
            itemBuilder: (context, index) => _reelAudioRow(audios[index]),
          );
        },
      ),
    );
  }

  List<_StoryAudio> _dedupePostAudios(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final byId = <String, _StoryAudio>{};
    for (final doc in docs) {
      final audio = _StoryAudio.fromPost(doc);
      if (audio.previewUrl.trim().isEmpty) continue;
      byId.putIfAbsent(audio.id, () => audio);
    }
    return byId.values.toList();
  }

  Widget _reelAudioRow(_StoryAudio audio) {
    final playing = _playingId == audio.id;
    return GestureDetector(
      onTap: () => Navigator.pop(context, audio),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                gradient: LinearGradient(colors: audio.colors),
              ),
              child: const Icon(Icons.music_note_rounded, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    audio.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${audio.artist} · ${audio.plays}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFB9B9B9),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => _openOptions(audio),
              icon: const Icon(Icons.more_horiz_rounded, color: Colors.white),
            ),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: playing ? const Color(0xFF1677FF) : Colors.white12,
                  width: playing ? 3 : 2,
                ),
              ),
              child: IconButton(
                onPressed: () => _togglePreview(audio),
                icon: Icon(
                  playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white70,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _togglePreview(_StoryAudio audio) async {
    if (_playingId == audio.id) {
      await _previewPlayer.pause();
      if (mounted) setState(() => _playingId = null);
      return;
    }
    await _previewPlayer.stop();
    await _previewPlayer.play(UrlSource(audio.previewUrl));
    if (mounted) setState(() => _playingId = audio.id);
  }

  Future<void> _openOptions(_StoryAudio audio) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF262728),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white30,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 18),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFF3D3E40),
                    child: Icon(Icons.music_note_rounded, color: Colors.white),
                  ),
                  title: Text(
                    "Select '${audio.title}'",
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.pop(context, audio);
                  },
                ),
                StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: _savedAudioDoc(audio).snapshots(),
                  builder: (context, snapshot) {
                    final saved = snapshot.data?.exists == true;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF3D3E40),
                        child: Icon(
                          saved
                              ? Icons.bookmark_remove_rounded
                              : Icons.bookmark_rounded,
                          color: Colors.white,
                        ),
                      ),
                      title: Text(
                        saved ? 'Unsave audio' : 'Save audio',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        if (saved) {
                          unawaited(_unsave(audio));
                        } else {
                          unawaited(_save(audio));
                        }
                      },
                    );
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFF3D3E40),
                    child: Icon(
                      Icons.report_gmailerrorred_rounded,
                      color: Colors.white,
                    ),
                  ),
                  title: const Text(
                    'Report audio',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    unawaited(_report(audio));
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  DocumentReference<Map<String, dynamic>> _savedAudioDoc(_StoryAudio audio) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '_guest';
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('savedAudios')
        .doc(audio.id);
  }

  Future<void> _save(_StoryAudio audio) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _upsertStoryAudioLibrary(audio);
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('savedAudios')
        .doc(audio.id)
        .set({
          ...audio.toMap(),
          'savedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Future<void> _unsave(_StoryAudio audio) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('savedAudios')
        .doc(audio.id)
        .delete();
  }

  Future<void> _report(_StoryAudio audio) async {
    await FirebaseFirestore.instance.collection('audioReports').add({
      'audioId': audio.id,
      'title': audio.title,
      'artist': audio.artist,
      'sourcePostId': audio.sourcePostId,
      'uid': FirebaseAuth.instance.currentUser?.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}

enum _StickerKind { chip, premium, emoji, gif, card, poll, link, text }

TextAlign _textAlignFromKey(String? key) {
  switch (key) {
    case 'left':
      return TextAlign.left;
    case 'right':
      return TextAlign.right;
    default:
      return TextAlign.center;
  }
}

TextStyle _storyTextStyle(
  String styleKey,
  Color color, {
  double fontSize = 42,
}) {
  final base = TextStyle(
    color: color,
    fontSize: fontSize,
    fontWeight: FontWeight.w900,
    height: 1.12,
    shadows: const [
      Shadow(color: Colors.black87, blurRadius: 9, offset: Offset(0, 2)),
    ],
  );
  switch (styleKey) {
    case 'neon':
      return base.copyWith(
        fontStyle: FontStyle.italic,
        shadows: [
          Shadow(color: color.withValues(alpha: 0.9), blurRadius: 14),
          const Shadow(
            color: Colors.black87,
            blurRadius: 9,
            offset: Offset(0, 2),
          ),
        ],
      );
    case 'typewriter':
      return base.copyWith(fontFamily: 'monospace');
    case 'strong':
      return base.copyWith(fontStyle: FontStyle.italic, fontSize: fontSize + 2);
    case 'soft':
      return base.copyWith(fontWeight: FontWeight.w700);
    default:
      return base;
  }
}

class _StickerChoice {
  const _StickerChoice(
    this.label,
    this.kind, {
    this.icon,
    this.color = Colors.white,
    this.action = '',
    this.metadata = const <String, String>{},
  });

  final String label;
  final _StickerKind kind;
  final IconData? icon;
  final Color color;
  final String action;
  final Map<String, String> metadata;
}

class _PlacedSticker {
  const _PlacedSticker({
    required this.id,
    required this.choice,
    required this.offset,
    required this.scale,
  });

  final String id;
  final _StickerChoice choice;
  final Offset offset;
  final double scale;

  _PlacedSticker copyWith({Offset? offset, double? scale}) {
    return _PlacedSticker(
      id: id,
      choice: choice,
      offset: offset ?? this.offset,
      scale: scale ?? this.scale,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'label': choice.label,
      'type': choice.kind.name,
      'action': choice.action,
      'metadata': choice.metadata,
      'dx': offset.dx,
      'dy': offset.dy,
      'scale': scale,
      'color': choice.color.toARGB32(),
    };
  }
}

class _StoryTextEditorOverlay extends StatefulWidget {
  const _StoryTextEditorOverlay();

  @override
  State<_StoryTextEditorOverlay> createState() =>
      _StoryTextEditorOverlayState();
}

class _StoryTextEditorOverlayState extends State<_StoryTextEditorOverlay> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final FlutterTts _tts = FlutterTts();
  Color _color = Colors.white;
  String _styleKey = 'classic';
  TextAlign _align = TextAlign.center;
  bool _withBackground = false;
  bool _showStyles = false;

  static const List<Color> _colors = [
    Color(0xFFFFFFFF),
    Color(0xFF000000),
    Color(0xFFFF2D8D),
    Color(0xFFFF3B30),
    Color(0xFFFFD60A),
    Color(0xFF34C759),
    Color(0xFF32ADE6),
    Color(0xFFAF52DE),
  ];

  static const List<({String key, String label})> _styles = [
    (key: 'classic', label: 'Classic'),
    (key: 'neon', label: 'Neon'),
    (key: 'typewriter', label: 'Typewriter'),
    (key: 'strong', label: 'Strong'),
    (key: 'soft', label: 'Soft'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _tts.stop();
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _speak() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    await _tts.stop();
    await _tts.setSpeechRate(0.45);
    await _tts.setPitch(1.0);
    await _tts.speak(text);
  }

  void _finish() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      Navigator.pop(context);
      return;
    }
    Navigator.pop(
      context,
      _StickerChoice(
        text,
        _StickerKind.text,
        color: _color,
        action: 'text',
        metadata: {
          'style': _styleKey,
          'align': _align.name,
          'background': _withBackground.toString(),
        },
      ),
    );
  }

  void _cycleAlign() {
    setState(() {
      _align = switch (_align) {
        TextAlign.left => TextAlign.center,
        TextAlign.center => TextAlign.right,
        _ => TextAlign.left,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.45),
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => _focusNode.requestFocus(),
              ),
            ),
            _topActions(),
            Positioned(
              left: 30,
              right: 30,
              top: 220,
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  padding: _withBackground
                      ? const EdgeInsets.symmetric(horizontal: 10, vertical: 5)
                      : EdgeInsets.zero,
                  decoration: BoxDecoration(
                    color: _withBackground ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: IntrinsicWidth(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.sizeOf(context).width - 60,
                      ),
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        autofocus: true,
                        maxLines: null,
                        textAlign: _align,
                        cursorColor: _withBackground ? Colors.black : _color,
                        style: _storyTextStyle(
                          _styleKey,
                          _withBackground ? Colors.black : _color,
                          fontSize: 42,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isCollapsed: true,
                          hintText: 'Type text',
                          hintStyle: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: keyboard,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _showStyles ? _stylePicker() : _colorPicker(),
                  _tagStrip(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topActions() {
    return Positioned(
      left: 16,
      right: 16,
      top: 12,
      child: Row(
        children: [
          _toolbarButton(Icons.record_voice_over_rounded, _speak),
          const SizedBox(width: 14),
          _toolbarButton(
            Icons.color_lens_rounded,
            () => setState(() => _showStyles = false),
            active: !_showStyles,
          ),
          const SizedBox(width: 14),
          _toolbarButton(
            Icons.text_fields_rounded,
            () => setState(() => _showStyles = true),
            active: _showStyles,
          ),
          const SizedBox(width: 14),
          _toolbarButton(Icons.format_align_center_rounded, _cycleAlign),
          const Spacer(),
          TextButton(
            onPressed: _finish,
            style: TextButton.styleFrom(
              backgroundColor: Colors.black.withValues(alpha: 0.45),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Done',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _toolbarButton(
    IconData icon,
    VoidCallback onTap, {
    bool active = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.black.withValues(alpha: 0.32),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: active ? Colors.black : Colors.white,
          size: 23,
        ),
      ),
    );
  }

  Widget _colorPicker() {
    return Container(
      height: 70,
      color: Colors.black.withValues(alpha: 0.42),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        scrollDirection: Axis.horizontal,
        itemCount: _colors.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          if (index == _colors.length) {
            return GestureDetector(
              onTap: () => setState(() => _withBackground = !_withBackground),
              child: CircleAvatar(
                radius: 24,
                backgroundColor: _withBackground
                    ? Colors.white
                    : Colors.black54,
                child: Icon(
                  Icons.crop_square_rounded,
                  color: _withBackground ? Colors.black : Colors.white,
                ),
              ),
            );
          }
          final color = _colors[index];
          final selected = color == _color;
          return GestureDetector(
            onTap: () => setState(() => _color = color),
            child: Container(
              width: selected ? 52 : 48,
              height: selected ? 52 : 48,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? Colors.white : Colors.transparent,
                  width: 4,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _stylePicker() {
    return Container(
      height: 70,
      color: Colors.black.withValues(alpha: 0.42),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        scrollDirection: Axis.horizontal,
        itemCount: _styles.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final style = _styles[index];
          final selected = style.key == _styleKey;
          return GestureDetector(
            onTap: () => setState(() => _styleKey = style.key),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: selected ? Colors.white : Colors.black54,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                style.label,
                style: _storyTextStyle(
                  style.key,
                  selected ? Colors.black : Colors.white,
                  fontSize: 18,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _tagStrip() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      color: Colors.black.withValues(alpha: 0.72),
      child: const Text(
        '@ Tag someone',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _TextStickerPromptSheet extends StatefulWidget {
  const _TextStickerPromptSheet({
    required this.title,
    required this.hint,
    required this.actionLabel,
    required this.keyboardType,
  });

  final String title;
  final String hint;
  final String actionLabel;
  final TextInputType keyboardType;

  @override
  State<_TextStickerPromptSheet> createState() =>
      _TextStickerPromptSheetState();
}

class _TextStickerPromptSheetState extends State<_TextStickerPromptSheet> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.unfocus();
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.all(18),
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          decoration: BoxDecoration(
            color: const Color(0xFF242527),
            borderRadius: BorderRadius.circular(26),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _controller,
                focusNode: _focusNode,
                autofocus: true,
                keyboardType: widget.keyboardType,
                maxLines: widget.title == 'Link' ? 1 : 2,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: widget.hint,
                  hintStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.white10,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      _focusNode.unfocus();
                      Navigator.pop(context);
                    },
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: () {
                      final text = _controller.text.trim();
                      if (text.isEmpty) return;
                      _focusNode.unfocus();
                      Navigator.pop(context, text);
                    },
                    child: Text(widget.actionLabel),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

List<String> _emojiBlock(int start, int end) {
  return List<String>.generate(end - start + 1, (index) {
    return String.fromCharCode(start + index);
  });
}

class _StoryStickerSheet extends StatelessWidget {
  const _StoryStickerSheet();

  static const List<_StickerChoice> _premium = [
    _StickerChoice('HAHA', _StickerKind.premium, color: Color(0xFFFF7043)),
    _StickerChoice(
      'GOOD\nMORNING',
      _StickerKind.premium,
      color: Color(0xFFFFD85A),
    ),
    _StickerChoice('#1', _StickerKind.premium, color: Color(0xFFFF4081)),
    _StickerChoice('BABE', _StickerKind.premium, color: Color(0xFF64FFDA)),
    _StickerChoice('CHILL', _StickerKind.premium, color: Color(0xFF64B5F6)),
    _StickerChoice(
      'SOUND\nON!',
      _StickerKind.premium,
      color: Color(0xFFFF8A80),
    ),
    _StickerChoice('I ❤️', _StickerKind.premium, color: Color(0xFFFF5252)),
    _StickerChoice('WOW', _StickerKind.premium, color: Color(0xFFFFD54F)),
  ];

  static final List<String> _emojis = <String>[
    ..._emojiBlock(0x1F300, 0x1F5FF),
    ..._emojiBlock(0x1F600, 0x1F64F),
    ..._emojiBlock(0x1F680, 0x1F6FF),
    ..._emojiBlock(0x1F700, 0x1F77F),
    ..._emojiBlock(0x1F780, 0x1F7FF),
    ..._emojiBlock(0x1F800, 0x1F8FF),
    ..._emojiBlock(0x1F900, 0x1FAFF),
    '❤️',
    '💙',
    '💚',
    '💛',
    '💜',
    '💔',
    '💕',
    '💘',
    '💝',
    '😍',
    '🥰',
    '😘',
    '😎',
    '😂',
    '🤣',
    '😊',
    '😇',
    '😉',
    '😋',
    '😜',
    '🤩',
    '🥳',
    '😱',
    '😭',
    '😡',
    '😴',
    '😷',
    '😈',
    '👻',
    '💀',
    '👽',
    '😺',
    '🙈',
    '🙉',
    '🙊',
    '👍',
    '👎',
    '👏',
    '🙏',
    '💪',
    '✌️',
    '👌',
    '🤞',
    '👋',
    '👑',
    '💄',
    '👠',
    '💍',
    '🎒',
    '🕶️',
    '🐶',
    '🐱',
    '🐭',
    '🐰',
    '🐻',
    '🐼',
    '🐯',
    '🐮',
    '🐷',
    '🐸',
    '🐵',
    '🐧',
    '🐥',
    '🦋',
    '🐝',
    '🐞',
    '🌹',
    '🌻',
    '🌷',
    '🌸',
    '🍀',
    '🌴',
    '🌙',
    '⭐',
    '✨',
    '☀️',
    '🔥',
    '⚡',
    '🌈',
    '☁️',
    '💧',
    '🍎',
    '🍌',
    '🍓',
    '🍕',
    '🍔',
    '🍟',
    '🍰',
    '🍫',
    '☕',
    '🍻',
    '⚽',
    '🏀',
    '🏆',
    '🎯',
    '🎲',
    '🎰',
    '🎤',
    '🎧',
    '🎹',
    '🎬',
    '🎮',
    '🚗',
    '🚕',
    '🚆',
    '✈️',
    '🚀',
    '🏠',
    '🏥',
    '🏦',
    '💎',
    '💰',
    '🎁',
    '🎉',
    '💌',
    '📌',
    '📚',
    '🔒',
    '✅',
    '❌',
    '❗',
    '❓',
    '💯',
    '🇮🇳',
    '🇺🇸',
    '🇦🇪',
    '🇬🇧',
    '🇨🇦',
    '🇧🇷',
    '🇫🇷',
    '🇯🇵',
  ];

  @override
  Widget build(BuildContext context) {
    final timeLabel = TimeOfDay.now().format(context).toLowerCase();
    final chips = [
      _StickerChoice(
        'Add Yours',
        _StickerKind.chip,
        icon: Icons.camera_alt_outlined,
        color: const Color(0xFF159DFF),
        action: 'addYours',
      ),
      _StickerChoice(
        'Location',
        _StickerKind.chip,
        icon: Icons.location_on_outlined,
        color: const Color(0xFF16B7FF),
        action: 'location',
      ),
      _StickerChoice(
        timeLabel,
        _StickerKind.chip,
        icon: Icons.access_time_rounded,
        color: const Color(0xFFFFC83D),
        action: 'time',
      ),
      _StickerChoice(
        'GIF',
        _StickerKind.chip,
        icon: Icons.search_rounded,
        color: const Color(0xFF6BAA4E),
        action: 'gif',
      ),
      _StickerChoice(
        'Music',
        _StickerKind.chip,
        icon: Icons.music_note_rounded,
        color: const Color(0xFFE34394),
        action: 'music',
      ),
      _StickerChoice(
        'Event',
        _StickerKind.chip,
        icon: Icons.event_available_rounded,
        color: const Color(0xFFE53945),
        action: 'event',
      ),
      _StickerChoice(
        'Tag',
        _StickerKind.chip,
        icon: Icons.alternate_email_rounded,
        color: const Color(0xFF2CBF93),
        action: 'tag',
      ),
      _StickerChoice(
        'Feelings',
        _StickerKind.chip,
        icon: Icons.sentiment_satisfied_alt_rounded,
        color: const Color(0xFFFFD45A),
        action: 'feelings',
      ),
      _StickerChoice(
        'Donate',
        _StickerKind.chip,
        icon: Icons.favorite_border_rounded,
        color: const Color(0xFFE53945),
        action: 'donate',
      ),
      _StickerChoice(
        'Poll',
        _StickerKind.chip,
        icon: Icons.poll_rounded,
        color: const Color(0xFFFF8A2D),
        action: 'poll',
      ),
      _StickerChoice(
        'Question',
        _StickerKind.chip,
        icon: Icons.contact_support_outlined,
        color: const Color(0xFFE33A5D),
        action: 'question',
      ),
      _StickerChoice(
        'Captions',
        _StickerKind.chip,
        icon: Icons.closed_caption_rounded,
        color: const Color(0xFF8B5CF6),
        action: 'captions',
      ),
      _StickerChoice(
        'Link',
        _StickerKind.chip,
        icon: Icons.link_rounded,
        color: const Color(0xFF1677FF),
        action: 'link',
      ),
    ];

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.9,
      builder: (context, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF262728),
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: CustomScrollView(
            controller: controller,
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 84,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 12,
                        runSpacing: 14,
                        children: chips
                            .map((choice) => _stickerChip(context, choice))
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 34),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: GridView.builder(
                        itemCount: _premium.length,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              mainAxisSpacing: 18,
                              crossAxisSpacing: 18,
                              childAspectRatio: 1,
                            ),
                        itemBuilder: (context, index) =>
                            _premiumSticker(context, _premium[index]),
                      ),
                    ),
                    const SizedBox(height: 26),
                  ],
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
                sliver: SliverGrid.builder(
                  itemCount: _emojis.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1,
                  ),
                  itemBuilder: (context, index) {
                    final emoji = _emojis[index];
                    return InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => Navigator.pop(
                        context,
                        _StickerChoice(emoji, _StickerKind.emoji),
                      ),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: FittedBox(
                            fit: BoxFit.contain,
                            child: Text(
                              emoji,
                              style: const TextStyle(
                                fontSize: 30,
                                height: 1.25,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _stickerChip(BuildContext context, _StickerChoice choice) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _handleChipTap(context, choice),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(choice.icon, color: choice.color, size: 22),
            const SizedBox(width: 7),
            Text(
              choice.label,
              style: const TextStyle(
                color: Color(0xFF292A2D),
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleChipTap(
    BuildContext context,
    _StickerChoice choice,
  ) async {
    _StickerChoice? result;
    switch (choice.action) {
      case 'addYours':
        result = const _StickerChoice(
          'Add Yours',
          _StickerKind.card,
          action: 'addYoursPrompt',
        );
        break;
      case 'location':
        result = await showModalBottomSheet<_StickerChoice>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => const _LocationStickerSheet(),
        );
        break;
      case 'time':
        result = _StickerChoice(
          TimeOfDay.now().format(context).toLowerCase(),
          _StickerKind.chip,
          icon: Icons.access_time_rounded,
          color: const Color(0xFFFFC83D),
          action: 'time',
          metadata: {'createdLocalTime': DateTime.now().toIso8601String()},
        );
        break;
      case 'gif':
        result = await showModalBottomSheet<_StickerChoice>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => const _GifStickerSheet(),
        );
        break;
      case 'music':
        result = const _StickerChoice(
          'Music',
          _StickerKind.chip,
          icon: Icons.music_note_rounded,
          color: Color(0xFFE34394),
          action: 'music',
        );
        break;
      case 'event':
        result = await showModalBottomSheet<_StickerChoice>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => const _EventStickerSheet(),
        );
        break;
      case 'tag':
        result = await showModalBottomSheet<_StickerChoice>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => const _FriendTagStickerSheet(),
        );
        break;
      case 'feelings':
        result = await showModalBottomSheet<_StickerChoice>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => const _FeelingStickerSheet(),
        );
        break;
      case 'donate':
        result = const _StickerChoice(
          'Donate',
          _StickerKind.card,
          action: 'donatePrompt',
        );
        break;
      case 'poll':
        result = const _StickerChoice(
          'Poll',
          _StickerKind.poll,
          action: 'pollPrompt',
        );
        break;
      case 'question':
        result = const _StickerChoice(
          'Question',
          _StickerKind.card,
          action: 'questionPrompt',
        );
        break;
      case 'captions':
        result = const _StickerChoice(
          'Captions',
          _StickerKind.card,
          action: 'captionsPrompt',
        );
        break;
      case 'link':
        result = const _StickerChoice(
          'Link',
          _StickerKind.link,
          action: 'linkPrompt',
        );
        break;
      default:
        result = choice;
    }
    if (result != null && context.mounted) {
      Navigator.pop(context, result);
    }
  }

  Widget _premiumSticker(BuildContext context, _StickerChoice choice) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => Navigator.pop(context, choice),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [choice.color.withValues(alpha: 0.95), Colors.black87],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white24),
        ),
        child: Center(
          child: Text(
            choice.label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
              height: 0.95,
              shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
            ),
          ),
        ),
      ),
    );
  }
}

class _LocationStickerSheet extends StatefulWidget {
  const _LocationStickerSheet();

  @override
  State<_LocationStickerSheet> createState() => _LocationStickerSheetState();
}

class _LocationStickerSheetState extends State<_LocationStickerSheet> {
  final TextEditingController _controller = TextEditingController();
  final List<String> _presets = const [
    'Current location',
    'Mumbai, India',
    'Delhi, India',
    'Patna, Bihar',
    'Lucknow, Uttar Pradesh',
    'Kolkata, India',
    'Jaipur, Rajasthan',
    'Likeehit Studio',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _controller.text.trim().toLowerCase();
    final locations = _presets
        .where((location) => location.toLowerCase().contains(query))
        .toList();
    return _PickerShell(
      title: 'Add location',
      child: Column(
        children: [
          _SheetSearchField(
            controller: _controller,
            hint: 'Search or type location',
            onChanged: (_) => setState(() {}),
            onSubmitted: (value) => _select(context, value),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount:
                  locations.length +
                  (_controller.text.trim().isNotEmpty ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == 0 && _controller.text.trim().isNotEmpty) {
                  return _SheetListTile(
                    icon: Icons.add_location_alt_rounded,
                    color: const Color(0xFF16B7FF),
                    title: _controller.text.trim(),
                    subtitle: 'Use typed location',
                    onTap: () => _select(context, _controller.text),
                  );
                }
                final location =
                    locations[index -
                        (_controller.text.trim().isNotEmpty ? 1 : 0)];
                return _SheetListTile(
                  icon: Icons.location_on_rounded,
                  color: const Color(0xFF16B7FF),
                  title: location,
                  subtitle: location == 'Current location'
                      ? 'Realtime from user selection'
                      : 'Place sticker',
                  onTap: () => _select(context, location),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _select(BuildContext context, String value) {
    final text = value.trim();
    if (text.isEmpty) return;
    Navigator.pop(
      context,
      _StickerChoice(
        text,
        _StickerKind.chip,
        icon: Icons.location_on_rounded,
        color: const Color(0xFF16B7FF),
        action: 'location',
        metadata: {'location': text},
      ),
    );
  }
}

class _GifStickerSheet extends StatefulWidget {
  const _GifStickerSheet();

  @override
  State<_GifStickerSheet> createState() => _GifStickerSheetState();
}

class _GifStickerSheetState extends State<_GifStickerSheet> {
  final TextEditingController _controller = TextEditingController();
  String _query = 'trending';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<String> get _urls {
    final safe = _query.trim().isEmpty ? 'trending' : _query.trim();
    return List.generate(48, (index) {
      final seed = Uri.encodeComponent('$safe-${index + 1}');
      if (index % 3 == 0) {
        final dex = ((safe.hashCode + index).abs() % 650) + 1;
        return 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/versions/generation-v/black-white/animated/$dex.gif';
      }
      return 'https://api.dicebear.com/7.x/fun-emoji/png?seed=$seed';
    });
  }

  @override
  Widget build(BuildContext context) {
    final urls = _urls;
    return _PickerShell(
      title: 'Trending GIFs',
      child: Column(
        children: [
          _SheetSearchField(
            controller: _controller,
            hint: 'Search GIFs',
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: GridView.builder(
              itemCount: urls.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
              ),
              itemBuilder: (context, index) {
                final url = urls[index];
                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.pop(
                    context,
                    _StickerChoice(
                      'GIF',
                      _StickerKind.gif,
                      icon: Icons.gif_box_rounded,
                      color: const Color(0xFF6BAA4E),
                      action: 'gif',
                      metadata: {'url': url, 'query': _query},
                    ),
                  ),
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Image.network(url, fit: BoxFit.cover),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EventStickerSheet extends StatelessWidget {
  const _EventStickerSheet();

  static const _fallback = [
    {'title': 'Likeehit Live Event', 'subtitle': 'Join today'},
    {'title': 'Gift Festival', 'subtitle': 'Rewards and tasks'},
    {'title': 'Creator Challenge', 'subtitle': 'Trending now'},
  ];

  @override
  Widget build(BuildContext context) {
    return _PickerShell(
      title: 'Events',
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('events')
            .orderBy('createdAt', descending: true)
            .limit(30)
            .snapshots(),
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? const [];
          final items = docs.isEmpty
              ? _fallback
              : docs.map((doc) {
                  final data = doc.data();
                  return {
                    'title': data['title']?.toString() ?? 'Likeehit Event',
                    'subtitle':
                        data['subtitle']?.toString() ??
                        data['description']?.toString() ??
                        'Realtime event',
                    'eventId': doc.id,
                  };
                }).toList();
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final title = item['title'] ?? 'Event';
              final subtitle = item['subtitle'] ?? '';
              return _SheetListTile(
                icon: Icons.event_available_rounded,
                color: const Color(0xFFE53945),
                title: title,
                subtitle: subtitle,
                onTap: () => Navigator.pop(
                  context,
                  _StickerChoice(
                    title,
                    _StickerKind.card,
                    icon: Icons.event_available_rounded,
                    color: const Color(0xFFE53945),
                    action: 'event',
                    metadata: {
                      'subtitle': subtitle,
                      'cta': 'View event',
                      if (item['eventId'] != null) 'eventId': item['eventId']!,
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _FriendTagStickerSheet extends StatelessWidget {
  const _FriendTagStickerSheet();

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '_guest';
    return _PickerShell(
      title: 'Tag friends',
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('friends')
            .snapshots(),
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? const [];
          final friends = docs.isEmpty
              ? const [
                  {'name': 'Likeehit friend', 'uid': 'friend'},
                  {'name': 'Creator buddy', 'uid': 'creator'},
                ]
              : docs.map((doc) {
                  final data = doc.data();
                  return {
                    'name': data['name']?.toString() ?? doc.id,
                    'uid': data['uid']?.toString() ?? doc.id,
                  };
                }).toList();
          return ListView.builder(
            itemCount: friends.length,
            itemBuilder: (context, index) {
              final friend = friends[index];
              final name = friend['name'] ?? 'User';
              return _SheetListTile(
                icon: Icons.alternate_email_rounded,
                color: const Color(0xFF2CBF93),
                title: '@$name',
                subtitle: 'Tag friend',
                onTap: () => Navigator.pop(
                  context,
                  _StickerChoice(
                    '@$name',
                    _StickerKind.chip,
                    icon: Icons.alternate_email_rounded,
                    color: const Color(0xFF2CBF93),
                    action: 'tag',
                    metadata: {'uid': friend['uid'] ?? '', 'name': name},
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _FeelingStickerSheet extends StatelessWidget {
  const _FeelingStickerSheet();

  static const feelings = [
    ('🙂', 'Happy'),
    ('😇', 'Blessed'),
    ('🥰', 'Loved'),
    ('😢', 'Sad'),
    ('😊', 'Lovely'),
    ('😀', 'Thankful'),
    ('🤩', 'Excited'),
    ('😍', 'In love'),
    ('🤪', 'Crazy'),
    ('🥹', 'Grateful'),
    ('😁', 'Fantastic'),
    ('🎉', 'Festive'),
    ('😎', 'Cool'),
    ('😌', 'Relaxed'),
    ('😋', 'Chill'),
    ('🔥', 'Motivated'),
    ('💪', 'Strong'),
    ('🙏', 'Hopeful'),
    ('😂', 'Funny'),
    ('😭', 'Emotional'),
  ];

  @override
  Widget build(BuildContext context) {
    return _PickerShell(
      title: 'How are you feeling?',
      child: GridView.builder(
        itemCount: feelings.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 3.1,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
        ),
        itemBuilder: (context, index) {
          final feeling = feelings[index];
          final label = '${feeling.$1} ${feeling.$2}';
          return InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => Navigator.pop(
              context,
              _StickerChoice(
                label,
                _StickerKind.chip,
                icon: Icons.sentiment_satisfied_alt_rounded,
                color: const Color(0xFFFFD45A),
                action: 'feelings',
                metadata: {'emoji': feeling.$1, 'feeling': feeling.$2},
              ),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Text(feeling.$1, style: const TextStyle(fontSize: 32)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      feeling.$2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
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
}

class _PollStickerSheet extends StatefulWidget {
  const _PollStickerSheet();

  @override
  State<_PollStickerSheet> createState() => _PollStickerSheetState();
}

class _PollStickerSheetState extends State<_PollStickerSheet> {
  final TextEditingController _question = TextEditingController();
  final TextEditingController _yes = TextEditingController(text: 'Yes');
  final TextEditingController _no = TextEditingController(text: 'No');

  @override
  void dispose() {
    FocusManager.instance.primaryFocus?.unfocus();
    _question.dispose();
    _yes.dispose();
    _no.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _PickerShell(
      title: 'Poll',
      child: Column(
        children: [
          _SheetSearchField(
            controller: _question,
            hint: 'Ask a question',
            onChanged: (_) {},
          ),
          const SizedBox(height: 12),
          _SheetSearchField(
            controller: _yes,
            hint: 'Yes option',
            onChanged: (_) {},
          ),
          const SizedBox(height: 12),
          _SheetSearchField(
            controller: _no,
            hint: 'No option',
            onChanged: (_) {},
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: () {
                final q = _question.text.trim();
                if (q.isEmpty) return;
                Navigator.pop(
                  context,
                  _StickerChoice(
                    q,
                    _StickerKind.poll,
                    icon: Icons.poll_rounded,
                    color: const Color(0xFFFF8A2D),
                    action: 'poll',
                    metadata: {
                      'yesLabel': _yes.text.trim().isEmpty
                          ? 'Yes'
                          : _yes.text.trim(),
                      'noLabel': _no.text.trim().isEmpty
                          ? 'No'
                          : _no.text.trim(),
                      'yesVotes': '0',
                      'noVotes': '0',
                    },
                  ),
                );
              },
              child: const Text('Add poll'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PickerShell extends StatelessWidget {
  const _PickerShell({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      builder: (context, controller) {
        return Container(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
          decoration: const BoxDecoration(
            color: Color(0xFF262728),
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            children: [
              Container(
                width: 84,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(child: child),
            ],
          ),
        );
      },
    );
  }
}

class _SheetSearchField extends StatelessWidget {
  const _SheetSearchField({
    required this.controller,
    required this.hint,
    required this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white54),
        prefixIcon: const Icon(Icons.search_rounded, color: Colors.white54),
        filled: true,
        fillColor: Colors.white10,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _SheetListTile extends StatelessWidget {
  const _SheetListTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.18),
        child: Icon(icon, color: color),
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white54),
      ),
    );
  }
}

class _StoryAssetPreview extends StatefulWidget {
  const _StoryAssetPreview({required this.asset, required this.effect});

  final AssetEntity asset;
  final _StoryEffect effect;

  @override
  State<_StoryAssetPreview> createState() => _StoryAssetPreviewState();
}

class _StoryAssetPreviewState extends State<_StoryAssetPreview> {
  Uint8List? _bytes;
  VideoPlayerController? _videoController;
  Object? _videoToken;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _StoryAssetPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset.id != widget.asset.id) {
      _bytes = null;
      _disposeVideo();
      _load();
    } else if (oldWidget.effect.key != widget.effect.key) {
      setState(() {});
    }
  }

  Future<void> _load() async {
    final bytes = await widget.asset.thumbnailDataWithSize(
      const ThumbnailSize(1080, 1920),
      quality: 96,
    );
    if (mounted) setState(() => _bytes = bytes);
    if (widget.asset.type == AssetType.video) {
      await _loadVideo();
    }
  }

  Future<void> _loadVideo() async {
    final token = Object();
    _videoToken = token;
    final file = await widget.asset.file;
    if (!mounted || _videoToken != token || file == null) return;
    final controller = VideoPlayerController.file(File(file.path));
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0);
      await controller.play();
      if (!mounted || _videoToken != token) {
        await controller.dispose();
        return;
      }
      setState(() => _videoController = controller);
    } catch (_) {
      await controller.dispose();
    }
  }

  void _disposeVideo() {
    _videoToken = null;
    final controller = _videoController;
    _videoController = null;
    controller?.dispose();
  }

  @override
  void dispose() {
    _disposeVideo();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final videoReady =
        widget.asset.type == AssetType.video &&
        _videoController?.value.isInitialized == true;
    if (_bytes == null && !videoReady) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF1677FF)),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        ColorFiltered(
          colorFilter: ColorFilter.matrix(
            _storyEffectMatrix(widget.effect.key),
          ),
          child: videoReady
              ? FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _videoController!.value.size.width,
                    height: _videoController!.value.size.height,
                    child: VideoPlayer(_videoController!),
                  ),
                )
              : Image.memory(_bytes!, fit: BoxFit.cover),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x3D000000),
                Colors.transparent,
                Color(0x52000000),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StoryTool {
  const _StoryTool(this.label, this.icon);

  final String label;
  final IconData icon;
}

class _StoryEffect {
  const _StoryEffect(this.key, this.label, this.icon, this.colors);

  final String key;
  final String label;
  final IconData icon;
  final List<Color> colors;
}

const List<_StoryEffect> _storyEffects = [
  _StoryEffect('none', 'None', Icons.block_rounded, [
    Color(0xFFBDBDBD),
    Color(0xFFEDEDED),
  ]),
  _StoryEffect('beautiful', 'Beauty', Icons.auto_awesome_rounded, [
    Color(0xFFFF75C3),
    Color(0xFFFFC1D9),
  ]),
  _StoryEffect('funny', 'Funny', Icons.sentiment_very_satisfied_rounded, [
    Color(0xFFFFB347),
    Color(0xFFFF5E7E),
  ]),
  _StoryEffect('glow', 'Glow', Icons.wb_sunny_rounded, [
    Color(0xFFFFD54F),
    Color(0xFFFF8A00),
  ]),
  _StoryEffect('cinema', 'Cinema', Icons.local_movies_rounded, [
    Color(0xFF101010),
    Color(0xFFB8860B),
  ]),
  _StoryEffect('vintage', 'Vintage', Icons.photo_camera_back_rounded, [
    Color(0xFF8D6E63),
    Color(0xFFFFD180),
  ]),
  _StoryEffect('cool', 'Cool', Icons.ac_unit_rounded, [
    Color(0xFF00C6FF),
    Color(0xFF0072FF),
  ]),
  _StoryEffect('warm', 'Warm', Icons.local_fire_department_rounded, [
    Color(0xFFFF512F),
    Color(0xFFF09819),
  ]),
  _StoryEffect('dramatic', 'Drama', Icons.theater_comedy_rounded, [
    Color(0xFF232526),
    Color(0xFF8E2DE2),
  ]),
  _StoryEffect('soft', 'Soft', Icons.blur_on_rounded, [
    Color(0xFFFFDEE9),
    Color(0xFFB5FFFC),
  ]),
  _StoryEffect('noir', 'Noir', Icons.contrast_rounded, [
    Color(0xFF111111),
    Color(0xFF777777),
  ]),
  _StoryEffect('8k', '8K', Icons.hd_rounded, [
    Color(0xFFFFD700),
    Color(0xFF111111),
  ]),
  _StoryEffect('pop', 'Pop', Icons.bubble_chart_rounded, [
    Color(0xFFFF00CC),
    Color(0xFF3333FF),
  ]),
  _StoryEffect('dream', 'Dream', Icons.cloud_rounded, [
    Color(0xFFA18CD1),
    Color(0xFFFBC2EB),
  ]),
  _StoryEffect('fairy', 'Fairy', Icons.filter_vintage_rounded, [
    Color(0xFF43E97B),
    Color(0xFF38F9D7),
  ]),
  _StoryEffect('gold', 'Gold', Icons.diamond_rounded, [
    Color(0xFFBF953F),
    Color(0xFFFCF6BA),
  ]),
  _StoryEffect('rose', 'Rose', Icons.favorite_rounded, [
    Color(0xFFFF0844),
    Color(0xFFFFB199),
  ]),
  _StoryEffect('aqua', 'Aqua', Icons.water_drop_rounded, [
    Color(0xFF13547A),
    Color(0xFF80D0C7),
  ]),
  _StoryEffect('sunset', 'Sunset', Icons.wb_twilight_rounded, [
    Color(0xFFFF7E5F),
    Color(0xFFFEB47B),
  ]),
  _StoryEffect('forest', 'Forest', Icons.park_rounded, [
    Color(0xFF134E5E),
    Color(0xFF71B280),
  ]),
  _StoryEffect('neon', 'Neon', Icons.flash_on_rounded, [
    Color(0xFF00F5A0),
    Color(0xFF00D9F5),
  ]),
  _StoryEffect('glitch', 'Glitch', Icons.settings_input_component_rounded, [
    Color(0xFFED213A),
    Color(0xFF93291E),
  ]),
  _StoryEffect('mono', 'Mono', Icons.tonality_rounded, [
    Color(0xFF434343),
    Color(0xFF000000),
  ]),
  _StoryEffect('bright', 'Bright', Icons.light_mode_rounded, [
    Color(0xFFFFFFFF),
    Color(0xFFFFF176),
  ]),
  _StoryEffect('shadow', 'Shadow', Icons.dark_mode_rounded, [
    Color(0xFF000000),
    Color(0xFF434343),
  ]),
  _StoryEffect('blush', 'Blush', Icons.face_retouching_natural_rounded, [
    Color(0xFFFF9A9E),
    Color(0xFFFAD0C4),
  ]),
  _StoryEffect('party', 'Party', Icons.celebration_rounded, [
    Color(0xFF8E2DE2),
    Color(0xFFFF6A00),
  ]),
  _StoryEffect('love', 'Love', Icons.favorite_border_rounded, [
    Color(0xFFFF512F),
    Color(0xFFDD2476),
  ]),
  _StoryEffect('fresh', 'Fresh', Icons.eco_rounded, [
    Color(0xFF56AB2F),
    Color(0xFFA8E063),
  ]),
  _StoryEffect('ice', 'Ice', Icons.severe_cold_rounded, [
    Color(0xFF74EBD5),
    Color(0xFFACB6E5),
  ]),
];

List<double> _storyEffectMatrix(String key) {
  switch (key) {
    case 'beautiful':
    case 'blush':
      return _colorMatrix(saturation: 1.18, brightness: 10, red: 1.08);
    case 'funny':
    case 'pop':
    case 'party':
      return _colorMatrix(saturation: 1.55, brightness: 8);
    case 'glow':
    case 'bright':
      return _colorMatrix(saturation: 1.12, brightness: 24);
    case 'cinema':
    case 'dramatic':
      return _colorMatrix(saturation: 1.18, brightness: -16, contrast: 1.18);
    case 'vintage':
      return const [
        0.9,
        0.18,
        0.08,
        0,
        12,
        0.08,
        0.82,
        0.08,
        0,
        6,
        0.06,
        0.12,
        0.68,
        0,
        -4,
        0,
        0,
        0,
        1,
        0,
      ];
    case 'cool':
    case 'aqua':
    case 'ice':
      return _colorMatrix(saturation: 1.08, brightness: 4, blue: 1.18);
    case 'warm':
    case 'sunset':
      return _colorMatrix(saturation: 1.22, brightness: 6, red: 1.14);
    case 'soft':
    case 'dream':
    case 'fairy':
      return _colorMatrix(saturation: 0.88, brightness: 18);
    case 'noir':
    case 'mono':
      return const [
        0.2126,
        0.7152,
        0.0722,
        0,
        0,
        0.2126,
        0.7152,
        0.0722,
        0,
        0,
        0.2126,
        0.7152,
        0.0722,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
      ];
    case '8k':
      return _colorMatrix(saturation: 1.35, brightness: 5, contrast: 1.22);
    case 'gold':
      return _colorMatrix(
        saturation: 1.15,
        brightness: 10,
        red: 1.16,
        green: 1.08,
      );
    case 'rose':
    case 'love':
      return _colorMatrix(
        saturation: 1.18,
        brightness: 5,
        red: 1.2,
        blue: 0.92,
      );
    case 'neon':
      return _colorMatrix(saturation: 1.7, brightness: 10, contrast: 1.12);
    case 'glitch':
      return _colorMatrix(
        saturation: 1.45,
        brightness: -4,
        red: 1.22,
        blue: 1.18,
      );
    case 'shadow':
      return _colorMatrix(saturation: 1.0, brightness: -28, contrast: 1.2);
    case 'forest':
    case 'fresh':
      return _colorMatrix(saturation: 1.2, brightness: 4, green: 1.18);
    default:
      return const [1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0];
  }
}

List<double> _colorMatrix({
  double saturation = 1,
  double brightness = 0,
  double contrast = 1,
  double red = 1,
  double green = 1,
  double blue = 1,
}) {
  final inv = 1 - saturation;
  final r = 0.213 * inv;
  final g = 0.715 * inv;
  final b = 0.072 * inv;
  final translate = 128 * (1 - contrast) + brightness;
  return [
    (r + saturation) * contrast * red,
    g * contrast * red,
    b * contrast * red,
    0,
    translate,
    r * contrast * green,
    (g + saturation) * contrast * green,
    b * contrast * green,
    0,
    translate,
    r * contrast * blue,
    g * contrast * blue,
    (b + saturation) * contrast * blue,
    0,
    translate,
    0,
    0,
    0,
    1,
    0,
  ];
}

class _StoryAudio {
  const _StoryAudio(
    this.title,
    this.artist,
    this.plays,
    this.mood,
    this.colors, {
    this.url = '',
    this.sourcePostId = '',
  });

  final String title;
  final String artist;
  final String plays;
  final String mood;
  final List<Color> colors;
  final String url;
  final String sourcePostId;

  String get id => _audioId(title, artist);

  String get previewUrl {
    if (url.trim().isNotEmpty) return url.trim();
    const urls = [
      'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
      'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
      'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3',
      'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3',
      'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-5.mp3',
      'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-6.mp3',
      'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-7.mp3',
      'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-8.mp3',
    ];
    final hash = title.codeUnits.fold<int>(0, (total, code) => total + code);
    return urls[hash % urls.length];
  }

  Map<String, dynamic> toMap() {
    return {
      'audioId': id,
      'title': title,
      'artist': artist,
      'plays': plays,
      'mood': mood,
      'previewUrl': previewUrl,
      'sourcePostId': sourcePostId,
      'colorA': colors.first.toARGB32(),
      'colorB': colors.length > 1
          ? colors[1].toARGB32()
          : colors.first.toARGB32(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory _StoryAudio.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final colorA = data['colorA'] is int
        ? Color(data['colorA'] as int)
        : const Color(0xFF9B4B20);
    final colorB = data['colorB'] is int
        ? Color(data['colorB'] as int)
        : const Color(0xFFE0A13A);
    return _StoryAudio(
      data['title']?.toString() ?? 'Audio',
      data['artist']?.toString() ?? 'Likeehit',
      data['plays']?.toString() ?? '0',
      data['mood']?.toString() ?? 'Music',
      [colorA, colorB],
      url:
          data['previewUrl']?.toString() ??
          data['audioUrl']?.toString() ??
          data['url']?.toString() ??
          '',
      sourcePostId: data['sourcePostId']?.toString() ?? '',
    );
  }

  factory _StoryAudio.fromPost(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final username = data['username']?.toString() ?? 'Likeehit creator';
    final title = data['audioTitle']?.toString().trim().isNotEmpty == true
        ? data['audioTitle'].toString().trim()
        : data['musicName']?.toString().trim().isNotEmpty == true
        ? data['musicName'].toString().trim()
        : 'Original sound - $username';
    final artist = data['audioArtist']?.toString().trim().isNotEmpty == true
        ? data['audioArtist'].toString().trim()
        : username.replaceFirst('@', '');
    final audioUrl = data['audioUrl']?.toString().trim().isNotEmpty == true
        ? data['audioUrl'].toString().trim()
        : data['musicUrl']?.toString().trim().isNotEmpty == true
        ? data['musicUrl'].toString().trim()
        : data['videoUrl']?.toString().trim() ?? '';
    final views = _formatAudioCount(
      _asInt(data['viewsCount']) > 0 ? data['viewsCount'] : data['views'],
    );
    final colors = _colorsForId(doc.id);
    return _StoryAudio(
      title,
      artist,
      views,
      data['audioMood']?.toString() ?? 'Reels',
      colors,
      url: audioUrl,
      sourcePostId: doc.id,
    );
  }
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return 0;
}

String _formatAudioCount(dynamic value) {
  final count = _asInt(value);
  if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
  if (count >= 1000) return '${(count / 1000).toStringAsFixed(0)}K';
  return '$count';
}

List<Color> _colorsForId(String id) {
  final palettes = [
    [const Color(0xFF9B4B20), const Color(0xFFE0A13A)],
    [const Color(0xFF176A7A), const Color(0xFF79D4E8)],
    [const Color(0xFFC9902B), const Color(0xFFF8D36A)],
    [const Color(0xFFD24E66), const Color(0xFFFFA08C)],
    [const Color(0xFF633C8A), const Color(0xFFDDA6FF)],
    [const Color(0xFF342B87), const Color(0xFFB466FF)],
    [const Color(0xFF801A1E), const Color(0xFFE04E59)],
    [const Color(0xFF264B8A), const Color(0xFF71A2FF)],
  ];
  final hash = id.codeUnits.fold<int>(0, (total, code) => total + code);
  return palettes[hash % palettes.length];
}

String _audioId(String title, String artist) {
  final raw = '${title}_$artist'.toLowerCase().trim();
  final id = raw.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  return id.replaceAll(RegExp(r'^_+|_+$'), '').isEmpty
      ? 'audio_${raw.hashCode.abs()}'
      : id.replaceAll(RegExp(r'^_+|_+$'), '');
}

Future<void> _upsertStoryAudioLibrary(_StoryAudio audio) async {
  await FirebaseFirestore.instance.collection('audioLibrary').doc(audio.id).set(
    {...audio.toMap(), 'usedCount': FieldValue.increment(1)},
    SetOptions(merge: true),
  );
}
