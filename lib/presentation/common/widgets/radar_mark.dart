import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/// The four distance bands, in order, exactly as the backend spells them.
///
/// Discovery cards carry the band as a raw string; [DistanceRing.fromBand]
/// parses it. The order here is the order the rings render, innermost first.
enum DistanceRing {
  immediate('<2 km', 'Immediate'),
  local('2-5 km', 'Local'),
  extended('5-10 km', 'Extended'),
  regional('10 km+', 'Regional');

  const DistanceRing(this.wireValue, this.label);

  /// The exact string the API uses.
  final String wireValue;

  /// How it reads in the interface.
  final String label;

  /// Tolerant of the en-dash and spacing variants that appear in copy.
  static DistanceRing? fromBand(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final v = raw.toLowerCase().replaceAll('–', '-').replaceAll(' ', '');
    for (final ring in DistanceRing.values) {
      if (ring.wireValue.toLowerCase().replaceAll(' ', '') == v) return ring;
    }
    return null;
  }
}

/// The Radius signature: four concentric rings, one per distance band, filling
/// outward to the viewer's current setting.
///
/// The rings are not decoration. The product's whole premise is proximity and
/// its privacy promise is that distance is always a *band* and never a number,
/// so the mark shows how wide someone's circle is set without spending a word
/// on it.
///
/// ## It displays; it never controls
///
/// Tappable rings would make a good screenshot and a poor target for a thumb
/// or a screen reader. Band selection stays a labelled option list; this mark
/// sits alongside and reflects the choice.
class RadarMark extends StatefulWidget {
  const RadarMark({
    super.key,
    this.size = 34,
    this.activeBand,
    this.animate = false,
    this.color,
  });

  /// Width and height. The ring spacing scales with it.
  final double size;

  /// Rings up to and including this one render filled. Null fills none, which
  /// is the honest state before a location is set.
  final DistanceRing? activeBand;

  /// Whether the outward pulse runs. Ignored when the platform asks for
  /// reduced motion.
  final bool animate;

  /// Defaults to [AppColors.primary]. Not a default *value* — the tokens are
  /// getters now, and a getter cannot sit in a const constructor's parameter
  /// list — so the fallback is applied where the mark is painted.
  final Color? color;

  @override
  State<RadarMark> createState() => _RadarMarkState();
}

class _RadarMarkState extends State<RadarMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Reduced motion is read from the platform every build, because it can be
  /// toggled while the app is open.
  bool _shouldAnimate(BuildContext context) =>
      widget.animate && !MediaQuery.disableAnimationsOf(context);

  @override
  Widget build(BuildContext context) {
    final animating = _shouldAnimate(context);

    if (animating && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!animating && _controller.isAnimating) {
      _controller.stop();
    }

    final semanticLabel = widget.activeBand == null
        ? 'Distance radar'
        : 'Distance radar, set to ${widget.activeBand!.label}';

    return Semantics(
      label: semanticLabel,
      excludeSemantics: true,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(
            painter: _RadarPainter(
              activeIndex: widget.activeBand?.index,
              color: widget.color ?? AppColors.primary,
              // A stopped controller sits at 0, which the painter reads as
              // "draw the static state" — the reduced-motion fallback.
              pulse: animating ? _controller.value : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({
    required this.activeIndex,
    required this.color,
    required this.pulse,
  });

  /// Index into [DistanceRing.values]; rings at or below it read as active.
  final int? activeIndex;
  final Color color;

  /// 0..1 pulse phase, or null when motion is off.
  final double? pulse;

  static const _ringCount = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxRadius = size.shortestSide / 2;

    // The core is the viewer. It scales with the mark so the proportions hold
    // from the 34px header badge up to the 190px splash.
    final coreRadius = maxRadius * 0.18;
    final stroke = (size.shortestSide * 0.045).clamp(1.0, 2.0);

    for (var i = 0; i < _ringCount; i++) {
      // Rings sit between the core and the edge, evenly spaced.
      final t = (i + 1) / _ringCount;
      final radius = coreRadius + (maxRadius - coreRadius) * t;
      final isActive = activeIndex != null && i <= activeIndex!;

      canvas.drawCircle(
        center,
        radius - stroke / 2,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = isActive ? stroke : stroke * 0.7
          ..color = isActive
              ? color.withValues(alpha: 1 - (i * 0.14))
              // Inactive rings are a mark, not text, so the decorative grey is
              // the right choice here.
              : AppColors.iconMuted.withValues(alpha: 0.35),
      );
    }

    // The outward sweep. One ring expanding from the core to the edge and
    // fading — the same gesture as the reference's CSS pulse.
    if (pulse != null) {
      final p = pulse!;
      canvas.drawCircle(
        center,
        coreRadius + (maxRadius - coreRadius) * p,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = color.withValues(alpha: (1 - p) * 0.55),
      );
    }

    canvas.drawCircle(center, coreRadius, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_RadarPainter old) =>
      old.pulse != pulse ||
      old.activeIndex != activeIndex ||
      old.color != color;
}
