class StickerOverlayItem {
  String assetUrl;
  bool isLottie;
  double dx;
  double dy;
  double scale;
  double rotation;
  double baseScale;
  double baseRotation;

  StickerOverlayItem({
    required this.assetUrl,
    required this.isLottie,
    required this.dx,
    required this.dy,
    this.scale = 1.0,
    this.rotation = 0.0,
    this.baseScale = 1.0,
    this.baseRotation = 0.0,
  });

  StickerOverlayItem clone() {
    return StickerOverlayItem(
      assetUrl: assetUrl,
      isLottie: isLottie,
      dx: dx,
      dy: dy,
      scale: scale,
      rotation: rotation,
      baseScale: baseScale,
      baseRotation: baseRotation,
    );
  }
}
