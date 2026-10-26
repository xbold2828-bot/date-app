import 'dart:math' as math;

import 'package:dating_app/core/theme/app_motion.dart';
import 'package:dating_app/core/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(AppSpacing.reset);

  group('AppSpacing', () {
    test('is the design grid at the default text size', () {
      AppSpacing.update(textScaler: TextScaler.noScaling, width: 390);
      expect(AppSpacing.factor, 1);
      expect(AppSpacing.md, 16);
      expect(AppSpacing.scaled(10), 10);
    });

    test('grows at half the rate of the text, up to 1.5×', () {
      // The largest standard setting puts Body at 23pt — text at 135%.
      AppSpacing.update(textScaler: const TextScaler.linear(23 / 17), width: 390);
      expect(AppSpacing.factor, closeTo(1 + (23 / 17 - 1) / 2, 1e-9));

      AppSpacing.update(textScaler: const TextScaler.linear(3), width: 390);
      expect(AppSpacing.factor, 1.5);
    });

    test('never tightens below the design values', () {
      AppSpacing.update(textScaler: const TextScaler.linear(0.82), width: 390);
      expect(AppSpacing.factor, 1);
    });

    test('takes the wide margin from 414pt, not a fraction of the screen', () {
      AppSpacing.update(textScaler: TextScaler.noScaling, width: 390);
      expect(AppSpacing.screenMargin, 16);
      AppSpacing.update(textScaler: TextScaler.noScaling, width: 430);
      expect(AppSpacing.screenMargin, 20);
    });

    test('reports whether anything changed', () {
      AppSpacing.update(textScaler: TextScaler.noScaling, width: 390);
      expect(
        AppSpacing.update(textScaler: TextScaler.noScaling, width: 390),
        isFalse,
      );
      expect(
        AppSpacing.update(textScaler: const TextScaler.linear(1.3), width: 390),
        isTrue,
      );
    });
  });

  group('SpacingScope', () {
    testWidgets('rebuilds spacing when the text size changes with the app open',
        (tester) async {
      Widget app(double textScale) => MediaQuery(
            data: MediaQueryData(
              size: const Size(390, 844),
              textScaler: TextScaler.linear(textScale),
            ),
            child: const SpacingScope(
              child: Directionality(
                textDirection: TextDirection.ltr,
                // Reads the static and nothing else — no dependency for
                // Flutter to invalidate, which is the case the sweep exists for.
                child: _Gap(),
              ),
            ),
          );

      await tester.pumpWidget(app(1));
      expect(tester.getSize(find.byKey(_Gap.boxKey)).height, 16);

      await tester.pumpWidget(app(1.6));
      await tester.pump();
      expect(
        tester.getSize(find.byKey(_Gap.boxKey)).height,
        closeTo(16 * 1.3, 1e-9),
      );
    });
  });

  group('AppSprings', () {
    test("converts Apple's damping and response into physics", () {
      final spring = AppSprings.of(dampingRatio: 1, response: 0.4);
      final stiffness = math.pow(2 * math.pi / 0.4, 2);
      expect(spring.mass, 1);
      expect(spring.stiffness, closeTo(stiffness, 1e-9));
      // Critically damped: damping = 2√(k·m), i.e. 4π / response.
      expect(spring.damping, closeTo(4 * math.pi / 0.4, 1e-9));
    });

    test('projects a flick the way scrolling decelerates', () {
      expect(projectedOffset(0), 0);
      expect(projectedOffset(1000), closeTo(499, 1e-9));
      expect(projectedOffset(-1000), closeTo(-499, 1e-9));
    });

    test('rubber-bands: follows less the further past the edge', () {
      expect(rubberBand(0, 800), 0);
      final near = rubberBand(50, 800);
      final far = rubberBand(400, 800);
      expect(near, lessThan(50));
      expect(far, lessThan(400));
      expect(far / 400, lessThan(near / 50));
      expect(rubberBand(-50, 800), -near, reason: 'symmetric at either end');
    });
  });
}

class _Gap extends StatelessWidget {
  const _Gap();

  static const boxKey = Key('gap');

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topLeft,
        child: SizedBox(key: boxKey, width: 1, height: AppSpacing.md),
      );
}
