import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dating_app/presentation/auth/screens/basics_screen4.dart';

/// Layout guarantees for the onboarding photo grid.
///
/// The five upload slots sit on one 3-column grid with the primary spanning
/// 2×2. The old layout mixed flex ratios (5:4 on the top row, 1:1 below) with
/// hardcoded heights (220 / 105 / 100), so the column edges never lined up and
/// the tiles distorted on narrow screens. These assert the edges by measuring
/// the rendered rectangles.
void main() {
  const gap = 10.0;

  Future<Map<int, Rect>> pumpGrid(WidgetTester tester, Size screen) async {
    tester.view.physicalSize = screen;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: BasicsScreen4()),
      ),
    );
    await tester.pump();

    return {
      for (var i = 0; i < 5; i++)
        i: tester.getRect(find.byKey(BasicsScreen4.photoSlotKey(i))),
    };
  }

  /// Rects are computed in floating point; a sub-pixel difference is not a
  /// misalignment.
  void expectAligned(double a, double b, String what) {
    expect(a, closeTo(b, 0.5), reason: what);
  }

  testWidgets('all five slots render', (tester) async {
    final rects = await pumpGrid(tester, const Size(375, 1400));
    expect(rects.length, 5);
    for (final rect in rects.values) {
      expect(rect.width, greaterThan(0));
      expect(rect.height, greaterThan(0));
    }
  });

  testWidgets('column edges line up down the whole grid', (tester) async {
    final r = await pumpGrid(tester, const Size(375, 1400));

    // Left edge: primary and the bottom-left slot start at the same x.
    expectAligned(r[3]!.left, r[0]!.left, 'slot 3 starts under the primary');

    // Right edge: the primary spans two columns, so the second bottom slot
    // must finish exactly where the primary does.
    expectAligned(r[4]!.right, r[0]!.right,
        'slot 4 ends flush with the primary');

    // The stacked right-hand column shares one x.
    expectAligned(r[2]!.left, r[1]!.left, 'stacked slots share a left edge');
    expectAligned(r[2]!.right, r[1]!.right, 'stacked slots share a right edge');

    // One consistent gutter between the primary and the stacked column.
    expectAligned(r[1]!.left - r[0]!.right, gap, 'gutter beside the primary');
    expectAligned(r[4]!.left - r[3]!.right, gap, 'gutter on the bottom row');
  });

  testWidgets('the primary spans exactly two columns and two rows',
      (tester) async {
    final r = await pumpGrid(tester, const Size(375, 1400));
    final cell = r[1]!; // a single-cell slot

    expectAligned(r[0]!.width, cell.width * 2 + gap, 'primary is two cells wide');
    expectAligned(
        r[0]!.height, cell.height * 2 + gap, 'primary is two cells tall');
  });

  testWidgets('every single-cell slot is the same size', (tester) async {
    final r = await pumpGrid(tester, const Size(375, 1400));

    for (final i in [2, 3, 4]) {
      expectAligned(r[i]!.width, r[1]!.width, 'slot $i width matches slot 1');
      expectAligned(r[i]!.height, r[1]!.height, 'slot $i height matches slot 1');
    }
  });

  testWidgets('rows sit on shared baselines', (tester) async {
    final r = await pumpGrid(tester, const Size(375, 1400));

    expectAligned(r[0]!.top, r[1]!.top, 'top row starts level');
    expectAligned(r[3]!.top, r[4]!.top, 'bottom row starts level');
    // The stacked pair fills the primary's height exactly.
    expectAligned(r[2]!.bottom, r[0]!.bottom, 'stacked column ends level');
    // And the bottom row hangs one gutter below.
    expectAligned(r[3]!.top - r[0]!.bottom, gap, 'gutter above the bottom row');
  });

  testWidgets('tiles keep their proportions on a narrow screen',
      (tester) async {
    final wide = await pumpGrid(tester, const Size(430, 1400));
    final narrow = await pumpGrid(tester, const Size(320, 1400));

    // Narrower screen ⇒ narrower cells (the old hardcoded heights did not
    // shrink, which is what distorted them).
    expect(narrow[1]!.width, lessThan(wide[1]!.width));

    // ...but the same aspect ratio, and still aligned.
    final wideRatio = wide[1]!.height / wide[1]!.width;
    final narrowRatio = narrow[1]!.height / narrow[1]!.width;
    expect(narrowRatio, closeTo(wideRatio, 0.01));

    expectAligned(narrow[4]!.right, narrow[0]!.right,
        'still flush at 320 px wide');
  });
}
