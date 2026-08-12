import 'package:dating_app/core/constants/app_colors.dart';
import 'package:dating_app/core/theme/app_theme.dart';
import 'package:dating_app/presentation/common/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wraps a component in the real theme, so a test never passes against
/// defaults the app does not actually use.
Widget host(Widget child, {bool disableAnimations = false, Size? size}) {
  return MaterialApp(
    theme: AppTheme.light,
    home: MediaQuery(
      data: MediaQueryData(
        disableAnimations: disableAnimations,
        size: size ?? const Size(390, 844),
      ),
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  group('RadiusChip', () {
    testWidgets('reports its selected state to assistive tech', (tester) async {
      await tester.pumpWidget(host(
        RadiusChip(label: 'Dating', selected: true, onTap: () {}),
      ));

      final node = tester.getSemantics(find.bySemanticsLabel('Dating'));
      expect(node.hasFlag(SemanticsFlag.isSelected), isTrue);
      expect(node.hasFlag(SemanticsFlag.isButton), isTrue);
    });

    testWidgets('selection changes more than the border', (tester) async {
      // The palette is low-contrast, so a border-only signal would be
      // invisible in bright light and gone entirely in greyscale.
      Future<BoxDecoration> decorationFor(bool selected) async {
        await tester.pumpWidget(host(
          RadiusChip(label: 'Foodie', selected: selected, onTap: () {}),
        ));
        final container = tester.widget<Container>(
          find
              .descendant(
                of: find.byType(RadiusChip),
                matching: find.byType(Container),
              )
              .first,
        );
        return container.decoration! as BoxDecoration;
      }

      final off = await decorationFor(false);
      final on = await decorationFor(true);

      expect(off.color, AppColors.white);
      expect(on.color, AppColors.primaryTint);
      expect(
        (off.border! as Border).top.color,
        isNot((on.border! as Border).top.color),
      );
    });

    testWidgets('a locked chip still fires, so the gate can be explained',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(host(
        RadiusChip(
          label: 'Online now',
          selected: false,
          locked: true,
          onTap: () => taps++,
        ),
      ));

      await tester.tap(find.byType(RadiusChip));
      expect(taps, 1, reason: 'a locked chip that silently ignores taps '
          'leaves people with no idea why it did nothing');
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    });

    testWidgets('gives descenders room to render', (tester) async {
      // "Open to anything" and "Just chatting" were being sliced along the
      // bottom: the row holding the chips had a fixed height smaller than the
      // chips needed. Assert the chip is at least as tall as its own text plus
      // its padding and border, so a squeezing parent shows up here.
      await tester.pumpWidget(host(
        RadiusChip(
          label: 'Open to anything',
          selected: false,
          onTap: () {},
        ),
      ));

      final textHeight = tester.getSize(find.text('Open to anything')).height;
      final chipHeight = tester.getSize(find.byType(RadiusChip)).height;

      // vertical padding (10 × 2) + border (1.5 × 2)
      expect(chipHeight, greaterThanOrEqualTo(textHeight + 23));
    });

    testWidgets('a locked chip never reads as selected', (tester) async {
      await tester.pumpWidget(host(
        RadiusChip(
          label: 'Verified',
          selected: true,
          locked: true,
          onTap: () {},
        ),
      ));
      final node = tester.getSemantics(find.bySemanticsLabel('Verified, locked'));
      expect(node.hasFlag(SemanticsFlag.isSelected), isFalse);
    });
  });

  group('RadiusButton', () {
    testWidgets('a null handler disables it', (tester) async {
      await tester.pumpWidget(host(
        const RadiusButton(label: 'Continue', onPressed: null),
      ));
      final node = tester.getSemantics(find.bySemanticsLabel('Continue'));
      expect(node.hasFlag(SemanticsFlag.isEnabled), isFalse);
    });

    testWidgets('swallows taps while loading', (tester) async {
      // Double-firing a purchase or a report is worse than a slow button.
      var taps = 0;
      await tester.pumpWidget(host(
        RadiusButton(
          label: 'Continue',
          isLoading: true,
          onPressed: () => taps++,
        ),
      ));

      await tester.tap(find.byType(RadiusButton));
      await tester.pump();
      expect(taps, 0);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('fires once when enabled', (tester) async {
      var taps = 0;
      await tester.pumpWidget(host(
        RadiusButton(label: 'Save changes', onPressed: () => taps++),
      ));
      await tester.tap(find.byType(RadiusButton));
      expect(taps, 1);
    });

    testWidgets('each kind renders', (tester) async {
      for (final kind in RadiusButtonKind.values) {
        await tester.pumpWidget(host(
          RadiusButton(label: 'Go', kind: kind, onPressed: () {}),
        ));
        expect(find.text('Go'), findsOneWidget);
      }
    });
  });

  group('RadiusOptionTile', () {
    testWidgets('exposes title and subtitle as one label', (tester) async {
      await tester.pumpWidget(host(
        RadiusOptionTile(
          title: 'Local',
          subtitle: '2 - 5 km',
          selected: true,
          onTap: () {},
        ),
      ));

      final node = tester.getSemantics(
        find.bySemanticsLabel('Local. 2 - 5 km'),
      );
      expect(node.hasFlag(SemanticsFlag.isSelected), isTrue);
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('a navigation tile does not claim to be selectable',
        (tester) async {
      await tester.pumpWidget(host(
        RadiusOptionTile(
          title: 'Safety centre',
          selected: false,
          showRadio: false,
          onTap: () {},
        ),
      ));
      final node = tester.getSemantics(find.bySemanticsLabel('Safety centre'));
      expect(node.hasFlag(SemanticsFlag.hasSelectedState), isFalse);
    });
  });

  group('RadarMark', () {
    testWidgets('honours reduced motion', (tester) async {
      await tester.pumpWidget(host(
        const RadarMark(size: 190, animate: true),
        disableAnimations: true,
      ));

      // A repeating controller never settles, so pumpAndSettle timing out is
      // exactly how an ignored reduced-motion setting shows up.
      await tester.pumpAndSettle();
      expect(find.byType(RadarMark), findsOneWidget);
    });

    testWidgets('animates when motion is allowed', (tester) async {
      await tester.pumpWidget(host(
        const RadarMark(size: 190, animate: true),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.hasRunningAnimations, isTrue);

      // Leaves nothing running behind it.
      await tester.pumpWidget(host(const SizedBox()));
    });

    testWidgets('is static by default', (tester) async {
      await tester.pumpWidget(host(const RadarMark(size: 34)));
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('announces the band it is showing', (tester) async {
      await tester.pumpWidget(host(
        const RadarMark(size: 34, activeBand: DistanceRing.local),
      ));
      expect(
        find.bySemanticsLabel('Distance radar, set to Local'),
        findsOneWidget,
      );
    });
  });

  group('DistanceRing', () {
    test('parses the bands the API actually sends', () {
      expect(DistanceRing.fromBand('<2 km'), DistanceRing.immediate);
      expect(DistanceRing.fromBand('2-5 km'), DistanceRing.local);
      expect(DistanceRing.fromBand('5-10 km'), DistanceRing.extended);
      expect(DistanceRing.fromBand('10 km+'), DistanceRing.regional);
    });

    test('tolerates the en-dash and spacing used in copy', () {
      // Designers write "2–5 km"; the API sends "2-5 km". Both must land.
      expect(DistanceRing.fromBand('2–5 km'), DistanceRing.local);
      expect(DistanceRing.fromBand('5 - 10 km'), DistanceRing.extended);
    });

    test('returns null rather than guessing', () {
      expect(DistanceRing.fromBand(null), isNull);
      expect(DistanceRing.fromBand(''), isNull);
      expect(DistanceRing.fromBand('somewhere'), isNull);
    });
  });

  group('ProfileGridCard', () {
    testWidgets('reads out name, presence and band together', (tester) async {
      await tester.pumpWidget(host(
        SizedBox(
          width: 120,
          height: 160,
          child: ProfileGridCard(
            name: 'Ananya',
            age: 23,
            distanceBand: '2-5 km',
            colorIndex: 0,
            isOnline: true,
            isVerified: true,
            onTap: () {},
          ),
        ),
      ));

      expect(
        find.bySemanticsLabel('Ananya, 23, verified, online now, 2-5 km away'),
        findsOneWidget,
      );
    });

    testWidgets('falls back to an initial with no photo', (tester) async {
      await tester.pumpWidget(host(
        SizedBox(
          width: 120,
          height: 160,
          child: ProfileGridCard(
            name: 'meera',
            colorIndex: 1,
            onTap: () {},
          ),
        ),
      ));
      expect(find.text('M'), findsOneWidget);
    });

    testWidgets('a blurred card gives away neither name nor age',
        (tester) async {
      await tester.pumpWidget(host(
        SizedBox(
          width: 120,
          height: 160,
          child: ProfileGridCard(
            name: 'Tarun',
            age: 35,
            distanceBand: '<2 km',
            colorIndex: 0,
            blurred: true,
            onTap: () {},
          ),
        ),
      ));

      // Blurring pixels but leaving the name in the widget tree would defeat
      // the point, and a screen reader would read it straight out.
      expect(find.text('Tarun, 35'), findsNothing);
      expect(find.text('T'), findsNothing);
      expect(
        find.bySemanticsLabel('Hidden profile, unlock to see who this is'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    });

    testWidgets('survives a narrow phone without overflowing', (tester) async {
      await tester.pumpWidget(host(
        SizedBox(
          width: 92, // a third of a 320pt screen, less gutters
          height: 128,
          child: ProfileGridCard(
            name: 'Kritika',
            age: 24,
            distanceBand: '5-10 km',
            colorIndex: 2,
            isOnline: true,
            onTap: () {},
          ),
        ),
        size: const Size(320, 640),
      ));
      expect(tester.takeException(), isNull);
    });
  });

  group('StepHeader', () {
    testWidgets('progress matches the step number', (tester) async {
      await tester.pumpWidget(host(
        const SizedBox(
          width: 390,
          child: StepHeader(step: 5, label: 'Live check'),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('STEP 5 OF 10'), findsOneWidget);
      expect(find.text('LIVE CHECK'), findsOneWidget);

      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(bar.value, closeTo(0.5, 0.001));
    });

    testWidgets('the wordmark is one semantic unit', (tester) async {
      await tester.pumpWidget(host(const Wordmark()));
      // "Radius" and its oxblood period must not be read as two things.
      expect(find.bySemanticsLabel('Radius'), findsOneWidget);
    });
  });

  group('RadiusSheet', () {
    testWidgets('shows its title and fires the trailing action',
        (tester) async {
      var reset = 0;
      await tester.pumpWidget(host(
        RadiusSheet(
          title: 'Filters',
          actionLabel: 'Reset',
          onAction: () => reset++,
          child: const SizedBox(height: 200),
        ),
      ));

      expect(find.text('Filters'), findsOneWidget);
      await tester.tap(find.text('Reset'));
      expect(reset, 1);
    });

    testWidgets('never grows past most of the screen', (tester) async {
      await tester.pumpWidget(host(
        RadiusSheet(
          title: 'Filters',
          child: Column(
            children: List.generate(
              60,
              (i) => SizedBox(height: 40, child: Text('row $i')),
            ),
          ),
        ),
      ));

      final height = tester.getSize(find.byType(RadiusSheet)).height;
      expect(height, lessThanOrEqualTo(844 * 0.88 + 1));
      expect(tester.takeException(), isNull);
    });
  });
}
