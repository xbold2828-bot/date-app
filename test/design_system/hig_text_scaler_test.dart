import 'package:dating_app/core/theme/hig_text_scaler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The platform reports text size as Body's ratio to 17pt; these are the
/// ratios iOS reports for its own settings.
HigTextScaler atBodySize(double body) =>
    HigTextScaler(TextScaler.linear(body / 17));

void main() {
  group('HigTextScaler', () {
    test('is exactly the identity at the default setting', () {
      const scaler = HigTextScaler(TextScaler.noScaling);
      for (final size in [11.0, 13.0, 17.0, 22.0, 34.0]) {
        expect(scaler.scale(size), size);
      }
    });

    test('adds points, not percent, through the standard settings', () {
      // Apple's ramp at the largest standard setting: every style gains the
      // 6pt Body does. Multiplying would have made Large Title 46.
      final scaler = atBodySize(23);
      expect(scaler.scale(17), closeTo(23, 0.01));
      expect(scaler.scale(34), closeTo(40, 0.01));
      expect(scaler.scale(28), closeTo(34, 0.01));
      expect(scaler.scale(12), closeTo(18, 0.01));
      expect(scaler.scale(11), closeTo(17, 0.01));
    });

    test('converges sizes at the accessibility settings, as iOS does', () {
      // The largest accessibility size: Body 53, Large Title 60, Caption 2 40.
      final scaler = atBodySize(53);
      expect(scaler.scale(17), closeTo(53, 0.01));
      expect(scaler.scale(34), closeTo(60, 2));
      expect(scaler.scale(11), closeTo(40, 3));
      // Headlines still lead: the ramp's order survives.
      expect(scaler.scale(34), greaterThan(scaler.scale(17)));
      expect(scaler.scale(17), greaterThan(scaler.scale(11)));
    });

    test('shrinks for smaller settings, but never below 11pt', () {
      final scaler = atBodySize(14);
      expect(scaler.scale(17), closeTo(14, 0.01));
      expect(scaler.scale(34), closeTo(31, 0.01));
      expect(scaler.scale(12), 11);
      expect(scaler.scale(11), 11, reason: 'already at the floor');
      expect(scaler.scale(9), 9, reason: 'never shrinks what is under it');
    });

    test('still clamps, for the widgets that cap their own text', () {
      final clamped = atBodySize(34).clamp(maxScaleFactor: 1.15);
      expect(clamped.scale(17), closeTo(17 * 1.15, 0.01));
    });

    test('compares by the platform scaler it wraps', () {
      expect(atBodySize(23), atBodySize(23));
      expect(atBodySize(23), isNot(atBodySize(21)));
    });
  });
}
