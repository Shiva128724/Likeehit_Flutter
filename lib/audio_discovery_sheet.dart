import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'models/audio_track.dart';

class AudioDiscoverySheet extends StatefulWidget {
  const AudioDiscoverySheet({super.key});

  @override
  State<AudioDiscoverySheet> createState() => _AudioDiscoverySheetState();
}

class _AudioDiscoverySheetState extends State<AudioDiscoverySheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AudioPlayer _previewPlayer = AudioPlayer();

  AudioTrack? _currentlyPlayingTrack;
  bool _isPlaying = false;

  final TextEditingController _searchController = TextEditingController();

  late List<AudioTrack> _forYouTracks;
  late List<AudioTrack> _trendingTracks;
  late List<AudioTrack> _savedTracks;
  late List<AudioTrack> _originalTracks;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _forYouTracks = AudioTrack.getForYou();
    _trendingTracks = AudioTrack.getTrending();
    _savedTracks = AudioTrack.getSaved();
    _originalTracks = AudioTrack.getOriginalAudio();

    _previewPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _previewPlayer.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _playTrack(AudioTrack track) async {
    if (_currentlyPlayingTrack?.id == track.id && _isPlaying) {
      await _previewPlayer.pause();
    } else {
      setState(() {
        _currentlyPlayingTrack = track;
      });
      await _previewPlayer.play(UrlSource(track.url));
    }
  }

  Future<void> _importAudio() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Audio import is temporarily unavailable.')),
    );
  }

  void _toggleSave(AudioTrack track) {
    setState(() {
      track.isSaved = !track.isSaved;

      // Mock Firestore Backend Sync
      if (track.isSaved) {
        if (!_savedTracks.any((t) => t.id == track.id)) {
          _savedTracks.add(track);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Added to Saved',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.black87,
            duration: Duration(seconds: 1),
          ),
        );
      } else {
        _savedTracks.removeWhere((t) => t.id == track.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Removed from Saved',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.black87,
            duration: Duration(seconds: 1),
          ),
        );
      }
    });
  }

  Widget _buildTrackList(List<AudioTrack> tracks) {
    if (tracks.isEmpty) {
      return const Center(
        child: Text('No tracks found', style: TextStyle(color: Colors.white54)),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.only(
        bottom: _currentlyPlayingTrack != null ? 80 : 16,
        top: 8,
      ),
      itemCount: tracks.length,
      itemBuilder: (context, index) {
        final track = tracks[index];
        final isPlayingThis =
            _currentlyPlayingTrack?.id == track.id && _isPlaying;

        return ListTile(
          onTap: () => _playTrack(track),
          leading: Stack(
            alignment: Alignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  track.thumbnailUrl,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 50,
                    height: 50,
                    color: Colors.white12,
                    child: const Icon(Icons.music_note, color: Colors.white54),
                  ),
                ),
              ),
              if (isPlayingThis)
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.pause, color: Colors.white),
                ),
            ],
          ),
          title: Text(
            track.title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              '${track.artist} • ${track.duration}\n${track.reelsCount}',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
          isThreeLine: true,
          trailing: IconButton(
            icon: Icon(
              track.isSaved ? Icons.bookmark : Icons.bookmark_border,
              color: track.isSaved ? Colors.white : Colors.white54,
            ),
            onPressed: () => _toggleSave(track),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E), // Dark modal background
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Stack(
        children: [
          Column(
            children: [
              // Top Drag Handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Search & Import Bar
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: 'Search songs, creators...',
                            hintStyle: TextStyle(
                              color: Colors.white54,
                              fontSize: 14,
                            ),
                            prefixIcon: Icon(
                              Icons.search,
                              color: Colors.white54,
                              size: 20,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: _importAudio,
                      child: Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.file_upload_outlined,
                              color: Colors.white,
                              size: 18,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Import',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Tabs
              TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white54,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                tabs: const [
                  Tab(text: 'For you'),
                  Tab(text: 'Trending'),
                  Tab(text: 'Saved'),
                  Tab(text: 'Original'),
                ],
              ),
              const Divider(color: Colors.white12, height: 1),

              // Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTrackList(_forYouTracks),
                    _buildTrackList(_trendingTracks),
                    _buildTrackList(_savedTracks),
                    _buildTrackList(_originalTracks),
                  ],
                ),
              ),
            ],
          ),

          // Persistent Bottom Mini-Player
          if (_currentlyPlayingTrack != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 1.0, end: 0.0),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return Transform.translate(
                    offset: Offset(0, value * 100),
                    child: child,
                  );
                },
                child: Container(
                  height: 70,
                  decoration: const BoxDecoration(
                    color: Color(0xFF8B0000), // Dark red
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      // Thumbnail
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          _currentlyPlayingTrack!.thumbnailUrl,
                          width: 46,
                          height: 46,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                width: 46,
                                height: 46,
                                color: Colors.black26,
                                child: const Icon(
                                  Icons.music_note,
                                  color: Colors.white54,
                                ),
                              ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Title & Artist
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _currentlyPlayingTrack!.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _currentlyPlayingTrack!.artist,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                      // Controls
                      IconButton(
                        icon: Icon(
                          _isPlaying
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_fill,
                          color: Colors.white,
                          size: 36,
                        ),
                        onPressed: () => _playTrack(_currentlyPlayingTrack!),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          // Return selected track to the camera screen
                          Navigator.pop(context, _currentlyPlayingTrack);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_forward_ios,
                            color: Color(0xFF8B0000),
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
