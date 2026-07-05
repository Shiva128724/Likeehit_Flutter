import 'package:flutter/material.dart';

class TextOverlayItem {
  String text;
  double dx;
  double dy;
  double fontSize;
  Color color;
  String fontFamily;
  int bgType; // 0 = Transparent, 1 = Filled Block, 2 = Inverted
  TextAlign alignment;
  String effect; // 'None', 'Hard Shadow', 'Block Offset'
  int startTimeMs;
  int durationMs;

  TextOverlayItem({
    required this.text,
    required this.dx,
    required this.dy,
    this.fontSize = 28.0,
    this.color = Colors.white,
    this.fontFamily = 'Modern',
    this.bgType = 0,
    this.alignment = TextAlign.center,
    this.effect = 'None',
    this.startTimeMs = 0,
    this.durationMs = 5000,
  });

  TextOverlayItem clone() {
    return TextOverlayItem(
      text: text,
      dx: dx,
      dy: dy,
      fontSize: fontSize,
      color: color,
      fontFamily: fontFamily,
      bgType: bgType,
      alignment: alignment,
      effect: effect,
      startTimeMs: startTimeMs,
      durationMs: durationMs,
    );
  }
}
