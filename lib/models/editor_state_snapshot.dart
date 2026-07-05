import 'audio_track_item.dart';
import 'text_overlay_item.dart';
import 'sticker_overlay_item.dart';

class ClipStateSnapshot {
  final String filePath;
  final double trimStart;
  final double trimEnd;

  ClipStateSnapshot({
    required this.filePath,
    required this.trimStart,
    required this.trimEnd,
  });
}

class EditorStateSnapshot {
  final List<ClipStateSnapshot> clips;
  final List<AudioTrackItem> audioOverlays;
  final List<TextOverlayItem> textOverlays;
  final List<StickerOverlayItem> stickerOverlays;

  EditorStateSnapshot({
    required this.clips,
    required this.audioOverlays,
    required this.textOverlays,
    required this.stickerOverlays,
  });
}
