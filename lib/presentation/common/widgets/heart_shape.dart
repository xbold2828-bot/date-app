import 'package:flutter/painting.dart';

/// The app's one heart, as a path inside [rect].
///
/// Drawn rather than taken from the icon font so it can be filled to a level
/// (the likes meter) and stamped in ink (the match seal) — and so both of
/// those are the same heart.
Path heartPath(Rect rect) {
  final w = rect.width;
  final h = rect.height;
  final x = rect.left;
  final y = rect.top;
  return Path()
    ..moveTo(x + w * 0.5, y + h * 0.92)
    ..cubicTo(
      x + w * 0.18,
      y + h * 0.70,
      x + w * 0.02,
      y + h * 0.50,
      x + w * 0.06,
      y + h * 0.30,
    )
    ..cubicTo(
      x + w * 0.10,
      y + h * 0.10,
      x + w * 0.38,
      y + h * 0.04,
      x + w * 0.5,
      y + h * 0.24,
    )
    ..cubicTo(
      x + w * 0.62,
      y + h * 0.04,
      x + w * 0.90,
      y + h * 0.10,
      x + w * 0.94,
      y + h * 0.30,
    )
    ..cubicTo(
      x + w * 0.98,
      y + h * 0.50,
      x + w * 0.82,
      y + h * 0.70,
      x + w * 0.5,
      y + h * 0.92,
    )
    ..close();
}
