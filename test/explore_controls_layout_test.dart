import 'package:dating_app/core/theme/app_theme.dart';
import 'package:dating_app/presentation/explore/widgets/explore_controls.dart';
import 'package:dating_app/presentation/explore/widgets/explore_states.dart';
import 'package:dating_app/providers/explore_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Explore's chrome floats over a map rather than sitting in a column, so
/// nothing below it absorbs a widget that grew. The header carries a title, a
/// live subtitle and a button on one line; the radius bar carries four pills.
/// Both are laid out at fixed offsets over the map, which makes a narrow phone
/// at a large text scale the case most likely to overflow.
Widget _host(Widget child, {double textScale = 1.0}) => MaterialApp(
      theme: AppTheme.light,
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(body: child),
      ),
    );

void main() {
  group('ExploreHeader', () {
    testWidgets('fits a narrow phone with a long city name', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_host(
        ExploreHeader(
          count: 128,
          isLoading: false,
          city: 'Thiruvananthapuram',
          onFilters: () {},
        ),
      ));

      expect(tester.takeException(), isNull);
      expect(find.text('Explore'), findsOneWidget);
    });

    testWidgets('fits at 1.3x text scale', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_host(
        ExploreHeader(count: 24, isLoading: false, onFilters: () {}),
        textScale: 1.3,
      ));

      expect(tester.takeException(), isNull);
    });

    testWidgets('counts people rather than announcing a number', (tester) async {
      await tester.pumpWidget(
        _host(ExploreHeader(count: 24, isLoading: false, onFilters: () {})),
      );
      expect(find.text('24 people around you'), findsOneWidget);

      // Singular, because "1 people around you" is the kind of thing that
      // makes a product feel unfinished.
      await tester.pumpWidget(
        _host(ExploreHeader(count: 1, isLoading: false, onFilters: () {})),
      );
      expect(find.text('1 person around you'), findsOneWidget);
    });

    testWidgets('says it is searching rather than claiming nobody is there',
        (tester) async {
      // Zero people while a request is still in flight is not an answer, and
      // rendering it as one is how a slow network reads as an empty city.
      await tester.pumpWidget(
        _host(ExploreHeader(count: 0, isLoading: true, onFilters: () {})),
      );

      expect(find.text('Finding people around you…'), findsOneWidget);
      expect(find.text('No one nearby yet'), findsNothing);
    });

    testWidgets('names the city when there is genuinely nobody in it',
        (tester) async {
      await tester.pumpWidget(_host(
        ExploreHeader(
          count: 0,
          isLoading: false,
          city: 'Kochi',
          onFilters: () {},
        ),
      ));
      expect(find.text('No one in Kochi yet'), findsOneWidget);
    });

    testWidgets('the filter button reaches the existing sheet', (tester) async {
      var opened = 0;
      await tester.pumpWidget(_host(
        ExploreHeader(
          count: 3,
          isLoading: false,
          onFilters: () => opened++,
        ),
      ));

      await tester.tap(find.byIcon(Icons.tune));
      expect(opened, 1);
    });
  });

  group('ExploreViewToggle', () {
    testWidgets('offers both modes and reports only changes', (tester) async {
      final changes = <ExploreViewMode>[];
      await tester.pumpWidget(_host(
        ExploreViewToggle(
          mode: ExploreViewMode.tilted,
          onChanged: changes.add,
        ),
      ));

      expect(find.text('2D'), findsOneWidget);
      expect(find.text('3D'), findsOneWidget);

      // Re-selecting the active mode would animate the camera to where it
      // already is.
      await tester.tap(find.text('3D'));
      expect(changes, isEmpty);

      await tester.tap(find.text('2D'));
      expect(changes, [ExploreViewMode.flat]);
    });
  });

  group('ExploreRadiusBar', () {
    testWidgets('sends the backend band value, not the label', (tester) async {
      // The API validates against the DistanceBand enum, so the en-dash in the
      // label must never reach the wire.
      final chosen = <String>[];
      await tester.pumpWidget(_host(
        ExploreRadiusBar(
          selected: null,
          fallback: '<2 km',
          onChanged: chosen.add,
        ),
      ));

      await tester.tap(find.text('2–5 km'));
      expect(chosen, ['2-5 km']);
    });

    testWidgets('shows the saved default as active when nothing overrides it',
        (tester) async {
      final chosen = <String>[];
      await tester.pumpWidget(_host(
        ExploreRadiusBar(
          selected: null,
          fallback: '5-10 km',
          onChanged: chosen.add,
        ),
      ));

      // Tapping the already-active band is inert — otherwise the map reloads,
      // and spends a reveal, to arrive at the state it was already in.
      await tester.tap(find.text('5–10 km'));
      expect(chosen, isEmpty);
    });

    testWidgets('an explicit choice beats the saved default', (tester) async {
      final chosen = <String>[];
      await tester.pumpWidget(_host(
        ExploreRadiusBar(
          selected: '10 km+',
          fallback: '<2 km',
          onChanged: chosen.add,
        ),
      ));

      await tester.tap(find.text('<2 km'));
      expect(chosen, ['<2 km']);
    });

    testWidgets('scrolls rather than overflowing a narrow phone',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_host(
        ExploreRadiusBar(
          selected: null,
          fallback: null,
          onChanged: (_) {},
        ),
        textScale: 1.3,
      ));

      expect(tester.takeException(), isNull);
    });
  });

  group('ExploreNoticeCard', () {
    testWidgets('always carries a way forward', (tester) async {
      var acted = 0;
      await tester.pumpWidget(_host(
        Center(
          child: ExploreNoticeCard(
            icon: Icons.favorite_border,
            title: 'No one nearby yet',
            body: 'Widen the circle.',
            primaryLabel: 'Increase radius',
            onPrimary: () => acted++,
          ),
        ),
      ));

      await tester.tap(find.text('Increase radius'));
      expect(acted, 1);
    });

    testWidgets('fits a narrow phone with both actions', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_host(
        Center(
          child: ExploreNoticeCard(
            icon: Icons.auto_awesome,
            tone: ExploreNoticeTone.warning,
            title: 'You have seen everyone for now',
            body: 'Premium keeps the map full, with no daily limit.',
            primaryLabel: 'See everyone with Premium',
            onPrimary: () {},
            secondaryLabel: 'Watch an ad',
            onSecondary: () {},
          ),
        ),
      ));

      expect(tester.takeException(), isNull);
    });
  });
}
