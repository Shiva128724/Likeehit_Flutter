class AudioTrack {
  final String id;
  final String title;
  final String artist;
  final String duration;
  final String url;
  final String thumbnailUrl;
  final String reelsCount;
  final bool isOriginal;
  bool isSaved;

  AudioTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.duration,
    required this.url,
    required this.thumbnailUrl,
    required this.reelsCount,
    this.isOriginal = false,
    this.isSaved = false,
  });

  // Mock Backend Service Data (This simulates Firestore metadata extraction)

  static List<AudioTrack> getForYou() {
    return [
      AudioTrack(
        id: 'fy_1',
        title: 'Sundari - Harjeet Deewana',
        artist: 'Harjeet Deewana',
        duration: '1:00',
        url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
        thumbnailUrl: 'https://picsum.photos/100?random=1',
        reelsCount: '1.2M reels',
        isSaved: true,
      ),
      AudioTrack(
        id: 'fy_2',
        title: 'Viral Dance Beat',
        artist: 'DJ Flow',
        duration: '0:30',
        url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
        thumbnailUrl: 'https://picsum.photos/100?random=2',
        reelsCount: '800K reels',
      ),
      AudioTrack(
        id: 'fy_3',
        title: 'Chill Vibes',
        artist: 'Lofi Beats',
        duration: '2:15',
        url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3',
        thumbnailUrl: 'https://picsum.photos/100?random=3',
        reelsCount: '2.1M reels',
      ),
    ];
  }

  static List<AudioTrack> getTrending() {
    return [
      AudioTrack(
        id: 'tr_1',
        title: 'Epic Transformation',
        artist: 'Creator XYZ',
        duration: '0:15',
        url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3',
        thumbnailUrl: 'https://picsum.photos/100?random=4',
        reelsCount: '3.3T reels', // as requested
      ),
      AudioTrack(
        id: 'tr_2',
        title: 'Lip Sync Battle 2026',
        artist: 'PopStar',
        duration: '0:45',
        url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-5.mp3',
        thumbnailUrl: 'https://picsum.photos/100?random=5',
        reelsCount: '1.5T reels',
        isSaved: true,
      ),
    ];
  }

  static List<AudioTrack> getSaved() {
    return [
      AudioTrack(
        id: 'fy_1',
        title: 'Sundari - Harjeet Deewana',
        artist: 'Harjeet Deewana',
        duration: '1:00',
        url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
        thumbnailUrl: 'https://picsum.photos/100?random=1',
        reelsCount: '1.2M reels',
        isSaved: true,
      ),
      AudioTrack(
        id: 'tr_2',
        title: 'Lip Sync Battle 2026',
        artist: 'PopStar',
        duration: '0:45',
        url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-5.mp3',
        thumbnailUrl: 'https://picsum.photos/100?random=5',
        reelsCount: '1.5T reels',
        isSaved: true,
      ),
    ];
  }

  static List<AudioTrack> getOriginalAudio() {
    return [
      AudioTrack(
        id: 'orig_1',
        title: 'Original audio - @user_123',
        artist: 'user_123',
        duration: '0:22',
        url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-6.mp3',
        thumbnailUrl: 'https://picsum.photos/100?random=6',
        reelsCount: '15 reels',
        isOriginal: true,
      ),
      AudioTrack(
        id: 'orig_2',
        title: 'Funny Voice Over',
        artist: 'comedy_king',
        duration: '0:10',
        url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-7.mp3',
        thumbnailUrl: 'https://picsum.photos/100?random=7',
        reelsCount: '2.2K reels',
        isOriginal: true,
      ),
    ];
  }
}
