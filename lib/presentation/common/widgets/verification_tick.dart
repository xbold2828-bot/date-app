import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/// The verified mark that sits beside a name.
///
/// A scalloped seal — nine lobes around a disc — rather than the eight-point
/// starburst every other app uses. Drawn as a path so it stays crisp at any
/// size and takes its colour from the palette instead of from a baked-in asset.
///
/// ## It is shown to everyone
///
/// Unlike [PremiumAvatar], this deliberately takes no `isCurrentUser` flag.
/// Verification is a claim made *to other people* — a badge only its owner can
/// see would be pointless. It renders identically on the "Me" tab and on the
/// profile opened from the radar, and the only thing that decides whether it
/// appears is whether the backend actually marked the account verified.
class VerificationTick extends StatelessWidget {
  const VerificationTick({
    super.key,
    this.size = 18,
    this.color = AppColors.ok,
    this.semanticLabel = 'Verified account',
  });

  final double size;

  /// The seal's fill. Defaults to the palette's verified green — the same
  /// colour the account-verification card and the avatar ring already use, so
  /// the three marks read as one status rather than three.
  final Color color;

  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final tick = CustomPaint(
      size: Size.square(size),
      painter: _SealPainter(color),
    );

    if (semanticLabel == null) return tick;
    return Semantics(label: semanticLabel, child: tick);
  }
}

class _SealPainter extends CustomPainter {
  const _SealPainter(this.color);

  final Color color;

  /// Odd, so no lobe sits directly opposite another — that asymmetry is what
  /// keeps it from reading as a gear.
  static const int _lobes = 9;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Body radius, and the lobes riding on its edge. Together they fill the
    // full box: bodyRadius + lobeRadius == radius.
    final lobe = radius * 0.24;
    final body = radius - lobe;

    final seal = Path()
      ..addOval(Rect.fromCircle(center: centre, radius: body + lobe * 0.35));
    for (var i = 0; i < _lobes; i++) {
      final angle = (i / _lobes) * 2 * math.pi - math.pi / 2;
      seal.addOval(
        Rect.fromCircle(
          center: centre +
              Offset(math.cos(angle) * body, math.sin(angle) * body),
          radius: lobe,
        ),
      );
    }

    canvas.drawPath(
      seal,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(color, Colors.white, 0.22)!,
            color,
            Color.lerp(color, Colors.black, 0.22)!,
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(
          Rect.fromCircle(center: centre, radius: radius),
        )
        ..isAntiAlias = true,
    );

    // The check. Stroked with round joins so it stays legible once the whole
    // badge is 14 px wide next to a name.
    final check = Path()
      ..moveTo(size.width * 0.30, size.height * 0.52)
      ..lineTo(size.width * 0.44, size.height * 0.66)
      ..lineTo(size.width * 0.72, size.height * 0.36);

    canvas.drawPath(
      check,
      Paint()
        ..color = AppColors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.13
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(_SealPainter oldDelegate) => oldDelegate.color != color;
}

/// A name with its verified mark, laid out so the badge never wraps away from
/// the text or pushes it off screen.
///
/// The [Flexible] is the reason this exists as a widget rather than a `Row`
/// copy-pasted into each screen: a long display name at a large system font
/// scale overflowed the row on the profile sheet, taking the badge with it.
class NameWithTick extends StatelessWidget {
  const NameWithTick({
    super.key,
    required this.name,
    required this.isVerified,
    this.style,
    this.tickSize = 18,
    this.maxLines = 1,
    this.mainAxisAlignment = MainAxisAlignment.start,
  });

  final String name;
  final bool isVerified;
  final TextStyle? style;
  final double tickSize;
  final int maxLines;
  final MainAxisAlignment mainAxisAlignment;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: mainAxisAlignment,
      children: [
        Flexible(
          child: Text(
            name,
            style: style,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (isVerified) ...[
          const SizedBox(width: 6),
          VerificationTick(size: tickSize),
        ],
      ],
    );
  }
}
