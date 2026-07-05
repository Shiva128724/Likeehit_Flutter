import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'services/post_service.dart';

class PublishPostScreen extends StatefulWidget {
  final String videoPath;

  const PublishPostScreen({super.key, required this.videoPath});

  @override
  State<PublishPostScreen> createState() => _PublishPostScreenState();
}

class _PublishPostScreenState extends State<PublishPostScreen> {
  late VideoPlayerController _videoController;
  final TextEditingController _captionController = TextEditingController();

  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String _privacySetting = 'Everyone'; // Everyone, Friends, Private

  bool _isLocationOn = false;
  String _locationName = '';
  String? _attachedLink;
  final List<String> _taggedUsers = [];
  bool _uploadHighQuality = true;
  bool _allowComments = true;

  @override
  void initState() {
    super.initState();
    _videoController = VideoPlayerController.file(File(widget.videoPath))
      ..initialize().then((_) {
        _videoController.setLooping(true);
        _videoController.setVolume(0); // Silent looping thumbnail
        _videoController.play();
        setState(() {});
      });
  }

  @override
  void dispose() {
    _videoController.dispose();
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _togglePrivacy() async {
    _showPrivacySheet();
  }

  Future<void> _handlePost() async {
    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    try {
      await PostService.instance.uploadVideo(
        file: File(widget.videoPath),
        caption: _captionController.text.trim(),
        privacy: _privacySetting,
        location: _locationName,
        attachedLink: _attachedLink,
        taggedUsers: _taggedUsers,
        allowComments: _allowComments,
        isHighQuality: _uploadHighQuality,
        onProgress: (progress) {
          if (mounted) {
            setState(() => _uploadProgress = progress);
          }
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Video posted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    String? trailingText,
    VoidCallback? onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      leading: Icon(icon, color: Colors.white, size: 28),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingText != null)
            Text(
              trailingText,
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, color: Colors.white54, size: 24),
        ],
      ),
      onTap: onTap,
    );
  }

  Widget _buildChip(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white12,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  void _showHashtagSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final hashtags = [
          '#likeehit',
          '#viral',
          '#trending2026',
          '#foryou',
          '#dance',
          '#comedy',
        ];
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Trending Hashtags',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: hashtags.length,
                  itemBuilder: (context, index) => ListTile(
                    leading: const Icon(Icons.tag, color: Colors.white54),
                    title: Text(
                      hashtags[index],
                      style: const TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      final currentText = _captionController.text;
                      _captionController.text = currentText.isEmpty
                          ? hashtags[index]
                          : '$currentText ${hashtags[index]}';
                      Navigator.pop(context);
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showTagPeopleSheet({bool appendToCaption = false}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final friends = ['Zohan', 'Priya', 'Rahul', 'Anita', 'Kabir'];
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Tag Friends',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: TextField(
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search friends...',
                      hintStyle: const TextStyle(color: Colors.white54),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Colors.white54,
                      ),
                      filled: true,
                      fillColor: Colors.white12,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: friends.length,
                    itemBuilder: (context, index) {
                      final friend = friends[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              Colors.primaries[index % Colors.primaries.length],
                          child: Text(friend[0]),
                        ),
                        title: Text(
                          friend,
                          style: const TextStyle(color: Colors.white),
                        ),
                        onTap: () {
                          if (appendToCaption) {
                            final currentText = _captionController.text;
                            _captionController.text = currentText.isEmpty
                                ? '@$friend'
                                : '$currentText @$friend';
                          } else {
                            setState(() {
                              if (!_taggedUsers.contains(friend)) {
                                _taggedUsers.add(friend);
                              }
                            });
                          }
                          Navigator.pop(context);
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

  Widget _buildLocationTile() {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      leading: const Icon(
        Icons.location_on_outlined,
        color: Colors.white,
        size: 28,
      ),
      title: const Text(
        'Location',
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: _locationName.isNotEmpty
          ? Text(
              _locationName,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            )
          : null,
      trailing: Switch(
        value: _isLocationOn,
        activeThumbColor: const Color(0xFFFF0050),
        onChanged: (val) async {
          setState(() => _isLocationOn = val);
          if (val) {
            // Simulate fetching location
            await Future.delayed(const Duration(milliseconds: 500));
            setState(() => _locationName = 'Mumbai, India');
          } else {
            setState(() => _locationName = '');
          }
        },
      ),
    );
  }

  void _showAddLinkDialog() {
    final linkController = TextEditingController(text: _attachedLink);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black87,
        title: const Text('Add Link', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: linkController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'https://...',
            hintStyle: TextStyle(color: Colors.white54),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white38),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.blueAccent),
            ),
          ),
        ),
        actions: [
          TextButton(
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text(
              'Save',
              style: TextStyle(
                color: Colors.blueAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
            onPressed: () {
              setState(() => _attachedLink = linkController.text.trim());
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  void _showPrivacySheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Who can watch this video',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _buildPrivacyOption('Everyone', Icons.public),
              _buildPrivacyOption('Friends', Icons.people),
              _buildPrivacyOption('Private', Icons.lock),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPrivacyOption(String value, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(value, style: const TextStyle(color: Colors.white)),
      trailing: _privacySetting == value
          ? const Icon(Icons.check, color: Color(0xFFFF0050))
          : null,
      onTap: () {
        setState(() => _privacySetting = value);
        Navigator.pop(context);
      },
    );
  }

  void _showMoreOptionsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'More options',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SwitchListTile(
                    title: const Text(
                      'Allow comments',
                      style: TextStyle(color: Colors.white),
                    ),
                    activeThumbColor: const Color(0xFFFF0050),
                    value: _allowComments,
                    onChanged: (val) {
                      setModalState(() => _allowComments = val);
                      setState(() => _allowComments = val);
                    },
                  ),
                  SwitchListTile(
                    title: const Text(
                      'Upload at highest quality',
                      style: TextStyle(color: Colors.white),
                    ),
                    activeThumbColor: const Color(0xFFFF0050),
                    value: _uploadHighQuality,
                    onChanged: (val) {
                      setModalState(() => _uploadHighQuality = val);
                      setState(() => _uploadHighQuality = val);
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Post',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Section: Caption and Thumbnail
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Caption Input
                            Expanded(
                              child: TextField(
                                controller: _captionController,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                                maxLines: 5,
                                decoration: const InputDecoration(
                                  hintText:
                                      'Describe your video (add #hashtags or @friends)',
                                  hintStyle: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 16,
                                  ),
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Video Thumbnail
                            Container(
                              width: 100,
                              height: 140,
                              decoration: BoxDecoration(
                                color: Colors.white12,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  if (_videoController.value.isInitialized)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: VideoPlayer(_videoController),
                                    ),
                                  // Edit Cover overlay
                                  Positioned(
                                    bottom: 0,
                                    left: 0,
                                    right: 0,
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius: BorderRadius.vertical(
                                          bottom: Radius.circular(8),
                                        ),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 4,
                                      ),
                                      child: const Text(
                                        'Select cover',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Shortcut Chips
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          children: [
                            _buildChip('# Hashtags', _showHashtagSheet),
                            const SizedBox(width: 8),
                            _buildChip(
                              '@ Mention',
                              () => _showTagPeopleSheet(appendToCaption: true),
                            ),
                            const SizedBox(width: 8),
                            _buildChip('Videos', () {}),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),
                      const Divider(color: Colors.white12, height: 1),

                      // Options List
                      _buildOptionTile(
                        icon: Icons.person_add_alt_1,
                        title: 'Tag people',
                        trailingText: _taggedUsers.isNotEmpty
                            ? '${_taggedUsers.length} tagged'
                            : null,
                        onTap: () =>
                            _showTagPeopleSheet(appendToCaption: false),
                      ),
                      _buildLocationTile(),
                      _buildOptionTile(
                        icon: Icons.link,
                        title: 'Add link',
                        trailingText:
                            _attachedLink != null && _attachedLink!.isNotEmpty
                            ? 'Link added'
                            : null,
                        onTap: _showAddLinkDialog,
                      ),
                      _buildOptionTile(
                        icon: Icons.public,
                        title: 'Everyone can view this post',
                        trailingText: _privacySetting,
                        onTap: _togglePrivacy,
                      ),
                      _buildOptionTile(
                        icon: Icons.more_horiz,
                        title: 'More options',
                        onTap: _showMoreOptionsSheet,
                      ),

                      const Divider(color: Colors.white12, height: 1),

                      // Extra spacing for bottom bar
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),

              // Sticky Action Buttons
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: const BoxDecoration(
                  color: Colors.black,
                  border: Border(
                    top: BorderSide(color: Colors.white12, width: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white12,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () {
                          // Save draft locally
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Draft saved locally'),
                            ),
                          );
                          Navigator.popUntil(context, (route) => route.isFirst);
                        },
                        child: const Text(
                          'Drafts',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF0050), Color(0xFF00F2FE)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: _handlePost,
                          child: const Text(
                            'Post',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Full-Screen Upload Overlay
          if (_isUploading)
            Container(
              color: Colors.black87,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFFFF0050),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Uploading... ${(_uploadProgress * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
