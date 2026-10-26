import 'dart:math' as math;

import 'package:flutter/physics.dart';

/// Springs, described the way Apple describes them.
///
/// Mass, stiffness and damping are hard to reason about. Apple's two
/// parameters are not:
///
/// - **Damping ratio** — whether it overshoots. `1` is critically damped: it
///   settles without a bounce. Below `1` it bounces, more as it drops.
/// - **Response** — roughly how long, in seconds, the value takes to get where
///   it is going. Lower is snappier. It is not a duration: a spring has none,
///   which is exactly what lets it be interrupted and redirected mid-flight.
///
/// [of] converts the pair into the [SpringDescription] a [SpringSimulation]
/// needs, with the formula from Apple's *Designing Fluid Interfaces* sample
/// code: stiffness `(2π / response)²`, damping `4π · ratio / response`.
///
/// Start every spring from the value currently on screen and the velocity it
/// already has. That is what makes a grabbed-and-reversed animation continue
/// instead of jumping.
abstract final class AppSprings {
  static SpringDescription of({
    required double dampingRatio,
    required double response,
  }) {
    return SpringDescription.withDampingRatio(
      mass: 1,
      stiffness: math.pow(2 * math.pi / response, 2).toDouble(),
      ratio: dampingRatio,
    );
  }

  /// The default for anything moving into place. No overshoot: graceful,
  /// and never distracting.
  static final SpringDescription settle = of(dampingRatio: 1, response: 0.4);

  /// Only after a flick or a drag release. The gesture carried momentum, so
  /// a little overshoot reads as the thing having been thrown — the same
  /// bounce on a menu that merely appeared would feel wrong.
  static final SpringDescription flick = of(dampingRatio: 0.85, response: 0.35);

  /// A pressed control letting go.
  static final SpringDescription release = of(dampingRatio: 1, response: 0.3);
}

/// Where a flick would come to rest if nothing caught it.
///
/// Apple's projection, from the same sample code — an exponential decay like
/// scroll deceleration, not the textbook `v² / 2a`. Choose the snap target
/// nearest this point rather than nearest the release point, and a small,
/// fast flick travels as far as it feels like it should.
///
/// [velocity] is in logical pixels per second. A [decelerationRate] of
/// `0.998` matches normal scrolling; `0.99` stops sooner.
double projectedOffset(double velocity, {double decelerationRate = 0.998}) {
  return (velocity / 1000) * decelerationRate / (1 - decelerationRate);
}

/// Resistance past an edge: the further someone drags beyond a bound, the
/// less the content follows — so it reads as "there is nothing more here"
/// rather than as frozen.
///
/// [overshoot] is how far past the bound the finger has gone; [dimension] is
/// the size of the scrolling area along that axis.
double rubberBand(double overshoot, double dimension, {double constant = 0.55}) {
  if (dimension <= 0) return 0;
  return (overshoot * dimension * constant) /
      (dimension + constant * overshoot.abs());
}
