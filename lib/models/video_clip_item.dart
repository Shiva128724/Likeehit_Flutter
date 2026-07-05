import 'package:video_player/video_player.dart';

class VideoClipItem {
  final String filePath;
  final VideoPlayerController controller;
  double trimStart; // 0.0 to 1.0
  double trimEnd; // 0.0 to 1.0

  VideoClipItem({
    required this.filePath,
    required this.controller,
    this.trimStart = 0.0,
    this.trimEnd = 1.0,
  });

  int get activeDurationMs {
    final int totalMs = controller.value.duration.inMilliseconds;
    return ((trimEnd - trimStart) * totalMs).toInt();
  }

  int get startMs {
    return (trimStart * controller.value.duration.inMilliseconds).toInt();
  }

  int get endMs {
    return (trimEnd * controller.value.duration.inMilliseconds).toInt();
  }
}
