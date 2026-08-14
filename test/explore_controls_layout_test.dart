import 'package:dating_app/core/theme/app_theme.dart';
import 'package:dating_app/presentation/explore/widgets/explore_controls.dart';
import 'package:dating_app/presentation/explore/widgets/explore_states.dart';
import 'package:dating_app/providers/explore_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Explore's chrome sits above a map that takes whatever height is left, so
/// nothing below it absorbs a widget that grew. A narrow phone at a large text
/// scale is the case most likely to overflow.
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
          onSearch: () {},
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
        ExploreHeader(count: 24, isLoading: false, onSearch: () {}),
        textScale: 1.3,
      ));

      expect(tester.takeException(), isNull);
    });

    testWidgets('counts people rather than announcing a number', (tester) async {
      await tester.pumpWidget(
        _host(ExploreHeader(count: 24, isLoading: false, onSearch: () {})),
      );
      expect(find.text('24 people you are vibing with'), findsOneWidget);

      // Singular, because "1 people around you" is the kind of thing that
      // makes a product feel unfinished.
      await tester.pumpWidget(
        _host(ExploreHeader(count: 1, isLoading: false, onSearch: () {})),
      );
      expect(find.text('1 person you are vibing with'), findsOneWidget);
    });

    testWidgets('says it is searching rather than claiming nobody is there',
        (tester) async {
      // Zero people while a request is still in flight is not an answer, and
      // rendering it as one is how a slow network reads as an empty city.
      await tester.pumpWidget(
        _host(ExploreHeader(count: 0, isLoading: true, onSearch: () {})),
      );

      expect(find.text('Finding your people…'), findsOneWidget);
      expect(find.text('Nobody on your map yet'), findsNothing);
    });

    testWidgets('says the map is empty when nobody has replied yet',
        (tester) async {
      await tester.pumpWidget(_host(
        ExploreHeader(count: 0, isLoading: false, onSearch: () {}),
      ));
      expect(find.text('Nobody on your map yet'), findsOneWidget);
    });

    testWidgets('the search button opens the grid', (tester) async {
      var opened = 0;
      await tester.pumpWidget(_host(
        ExploreHeader(
          count: 3,
          isLoading: false,
          onSearch: () => opened++,
        ),
      ));

      await tester.tap(find.byIcon(Icons.search));
      expect(opened, 1);
    });

    testWidgets('offers no filter control at all', (tester) async {
      // Filters parameterise a search for strangers. This map shows
      // conversations the user already has, so a filter button would be a
      // control that changes nothing.
      await tester.pumpWidget(_host(
        ExploreHeader(count: 3, isLoading: false, onSearch: () {}),
      ));

      expect(find.byIcon(Icons.tune), findsNothing);
    });
  });

  group('ExploreZoomButtons', () {
    testWidgets('steps in and out independently', (tester) async {
      var zoomIn = 0;
      var zoomOut = 0;
      await tester.pumpWidget(_host(
        Center(
          child: ExploreZoomButtons(
            onZoomIn: () => zoomIn++,
            onZoomOut: () => zoomOut++,
          ),
        ),
      ));

      await tester.tap(find.byIcon(Icons.add));
      await tester.tap(find.byIcon(Icons.remove));
      expect(zoomIn, 1);
      expect(zoomOut, 1);
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
