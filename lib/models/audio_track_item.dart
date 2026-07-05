import 'audio_track.dart';

class AudioTrackItem {
  final AudioTrack track;
  int startTimeMs;
  int durationMs;

  AudioTrackItem({
    required this.track,
    this.startTimeMs = 0,
    this.durationMs = 5000,
  });

  AudioTrackItem clone() {
    return AudioTrackItem(
      track: track,
      startTimeMs: startTimeMs,
      durationMs: durationMs,
    );
  }
}
