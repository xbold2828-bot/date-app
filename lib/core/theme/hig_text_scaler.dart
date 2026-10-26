import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Scales text the way iOS Dynamic Type does, on every platform.
///
/// The system hands Flutter one ratio — "Body is 135% of normal" — and
/// Flutter's default multiplies every size by it. iOS does not. Through the
/// standard settings its text styles all gain roughly the same number of
/// *points*: at the largest one Body goes 17 → 23, Caption 12 → 18 and Large
/// Title 34 → 40. Multiplying instead blows a 34pt headline up to 46pt — where
/// layouts break — while captions stay small, which is exactly the text
/// people turned the setting up to read.
///
/// So this reads how many points the platform adds to Body and re-applies
/// them as an addition, following Apple's published ramp:
///
/// - **Up to the largest standard setting** (Body +6pt), every size gains
///   the same points Body does.
/// - **Beyond it**, the accessibility sizes, Body keeps all of its gain and
///   everything else gets a share that shrinks the further a size is from
///   Body, so headlines and captions converge rather than diverge.
/// - **Smaller settings** take the points away, but never below 11pt — Apple's
///   minimum — and never shrink a size that is already at or under it.
///
/// At the default setting it is exactly the identity.
///
/// Installed once, in `MaterialApp.builder`, over the platform's own scaler.
@immutable
class HigTextScaler extends TextScaler {
  const HigTextScaler(this.system);

  /// The platform's scaler, as `MediaQuery` provides it.
  final TextScaler system;

  static const double _body = 17;

  /// Apple's minimum legible size.
  static const double minimumSize = 11;

  /// The most points the standard (non-accessibility) settings add.
  static const double _standardGain = 6;

  @override
  double scale(double fontSize) {
    final gained = system.scale(_body) - _body;
    if (gained == 0 || fontSize <= 0) return fontSize;

    if (gained < 0) {
      if (fontSize <= minimumSize) return fontSize;
      return math.max(minimumSize, fontSize + gained);
    }

    final standard = math.min(gained, _standardGain);
    final accessibility = gained - standard;
    if (accessibility == 0) return fontSize + standard;

    final share = math
        .pow(math.min(fontSize, _body) / math.max(fontSize, _body), 0.6)
        .toDouble();
    return fontSize + standard + accessibility * share;
  }

  @override
  @Deprecated(
    'Use scale() instead. '
    'This feature was deprecated after v3.12.0-2.0.pre.',
  )
  double get textScaleFactor => system.scale(_body) / _body;

  @override
  bool operator ==(Object other) =>
      other is HigTextScaler && other.system == system;

  @override
  int get hashCode => Object.hash(HigTextScaler, system);

  @override
  String toString() => 'HigTextScaler($system)';
}
