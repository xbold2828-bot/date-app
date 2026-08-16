import 'package:dating_app/core/theme/app_theme.dart';
import 'package:dating_app/data/models/discovery_user_model.dart';
import 'package:dating_app/data/models/map_user_model.dart';
import 'package:dating_app/presentation/explore/widgets/explore_people_grid.dart';
import 'package:dating_app/presentation/common/widgets/radius_sheet.dart';
import 'package:dating_app/presentation/explore/widgets/explore_people_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The strip and the grid are the two ways to pick somebody without hunting for
/// their marker. Both feed the same selection, so the rules about ordering and
/// about what "All" means have to hold in both.
MapUser _person(String name, {bool online = false}) => MapUser(
      card: DiscoveryCard(
        id: name.toLowerCase(),
        displayName: name,
        isOnline: online,
      ),
      latitude: 13.6,
      longitude: 79.4,
    );

/// Overrides the text scale while keeping everything else the view reports.
///
/// A bare `MediaQueryData` would also hand the child a zero-sized screen, and
/// the grid sizes itself to a fraction of the screen height — so it would build
/// nothing at all and every assertion below would fail for the wrong reason.
Widget _host(Widget child, {double textScale = 1.0}) => MaterialApp(
      theme: AppTheme.light,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
          ),
          child: Scaffold(body: child),
        ),
      ),
    );

/// Reading order of the tiles, by their visible caption.
///
/// Single characters are dropped: with no photo an avatar paints the person's
/// initial, which is a [Text] sitting inside the tile whose caption we are
/// actually after.
List<String> _captions(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((text) => text.data ?? '')
    .where((label) => label.length > 1)
    .toList();

void main() {
  group('ExplorePeopleStrip', () {
    testWidgets('leads with All when nobody is picked', (tester) async {
      await tester.pumpWidget(_host(
        ExplorePeopleStrip(
          people: [_person('Emma'), _person('Jason'), _person('Olivia')],
          selectedId: null,
          onSelect: (_) {},
          onShowAll: () {},
        ),
      ));

      expect(_captions(tester).first, 'All');
    });

    testWidgets('moves the picked person to the front, All to second',
        (tester) async {
      // The current subject stays under the thumb and the way back is always
      // the next tile along.
      await tester.pumpWidget(_host(
        ExplorePeopleStrip(
          people: [_person('Emma'), _person('Jason'), _person('Olivia')],
          selectedId: 'olivia',
          onSelect: (_) {},
          onShowAll: () {},
        ),
      ));

      final captions = _captions(tester);
      expect(captions[0], 'Olivia');
      expect(captions[1], 'All');
    });

    testWidgets('keeps the rest in the order the API ranked them',
        (tester) async {
      // Nearest-first. Re-sorting on every selection would make people hunt for
      // a face they were just looking at.
      await tester.pumpWidget(_host(
        ExplorePeopleStrip(
          people: [_person('Emma'), _person('Jason'), _person('Olivia')],
          selectedId: 'olivia',
          onSelect: (_) {},
          onShowAll: () {},
        ),
      ));

      final captions = _captions(tester);
      expect(captions.sublist(0, 4), ['Olivia', 'All', 'Emma', 'Jason']);
    });

    testWidgets('All opens the grid rather than selecting anybody',
        (tester) async {
      var opened = 0;
      var selected = 0;
      await tester.pumpWidget(_host(
        ExplorePeopleStrip(
          people: [_person('Emma')],
          selectedId: 'emma',
          onSelect: (_) => selected++,
          onShowAll: () => opened++,
        ),
      ));

      // The grid is where the map gets repopulated, via its own All tile.
      await tester.tap(find.text('All'));
      expect(opened, 1);
      expect(selected, 0);
    });

    testWidgets('tapping a face selects that person', (tester) async {
      MapUser? picked;
      await tester.pumpWidget(_host(
        ExplorePeopleStrip(
          people: [_person('Emma'), _person('Jason')],
          selectedId: null,
          onSelect: (person) => picked = person,
          onShowAll: () {},
        ),
      ));

      await tester.tap(find.text('Jason'));
      expect(picked?.id, 'jason');
    });

    testWidgets('offers the grid only once scrolling stops being reasonable',
        (tester) async {
      await tester.pumpWidget(_host(
        ExplorePeopleStrip(
          people: [for (var i = 0; i < 4; i++) _person('P$i')],
          selectedId: null,
          onSelect: (_) {},
          onShowAll: () {},
        ),
      ));
      expect(find.text('See all'), findsNothing);

      await tester.pumpWidget(_host(
        ExplorePeopleStrip(
          people: [
            for (var i = 0; i < ExplorePeopleStrip.gridThreshold + 1; i++)
              _person('P$i'),
          ],
          selectedId: null,
          onSelect: (_) {},
          onShowAll: () {},
        ),
      ));
      // It is at the end of a long row, so scroll to it rather than assuming
      // it was built.
      await tester.dragUntilVisible(
        find.text('See all'),
        find.byType(ListView),
        const Offset(-120, 0),
      );
      expect(find.text('See all'), findsOneWidget);
    });

    testWidgets('collapses to nothing when there is nobody', (tester) async {
      // An empty 82 px band above the map reads as a row that failed to load.
      await tester.pumpWidget(_host(
        ExplorePeopleStrip(
          people: const [],
          selectedId: null,
          onSelect: (_) {},
          onShowAll: () {},
        ),
      ));

      final box = tester.getSize(find.byType(ExplorePeopleStrip));
      expect(box.height, 0);
    });

    testWidgets('fits a narrow phone at a large text scale', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_host(
        ExplorePeopleStrip(
          people: [
            _person('Bartholomew'),
            _person('Emma', online: true),
            _person('Jason'),
          ],
          selectedId: 'emma',
          onSelect: (_) {},
          onShowAll: () {},
        ),
        textScale: 1.3,
      ));

      expect(tester.takeException(), isNull);
    });
  });

  group('ExplorePeopleGrid', () {
    testWidgets('counts everybody, and picking closes onto them',
        (tester) async {
      MapUser? picked;
      await tester.pumpWidget(_host(
        ExplorePeopleGrid(
          people: [_person('Emma'), _person('Jason'), _person('Olivia')],
          selectedId: null,
          onSelect: (person) => picked = person,
          onClose: () {},
          onShowAll: () {},
        ),
      ));

      expect(find.text('All people (3)'), findsOneWidget);
      await tester.tap(find.text('Olivia'));
      expect(picked?.id, 'olivia');
    });

    // Fixed, not content-sized, and the SAME fixed height a profile opens at.
    // With four people it used to be a strip at the bottom of the screen that
    // read as a toast rather than a destination, and with forty it was almost
    // full-screen — the same sheet, two shapes. Asserted against the shared
    // constant so the two sheets cannot drift apart again.
    testWidgets('opens at the profile sheet height whatever it contains',
        (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      Future<double> heightWith(int count) async {
        await tester.pumpWidget(_host(
          ExplorePeopleGrid(
            people: [
              for (var i = 0; i < count; i++) _person('Person$i'),
            ],
            selectedId: null,
            onSelect: (_) {},
            onClose: () {},
            onShowAll: () {},
          ),
        ));
        return tester.getSize(find.byType(ExplorePeopleGrid)).height;
      }

      const expected = 800 * kSheetHeightFraction;
      expect(await heightWith(2), closeTo(expected, 1));
      expect(await heightWith(40), closeTo(expected, 1));
    });

    testWidgets('search narrows the grid and reports the fraction',
        (tester) async {
      await tester.pumpWidget(_host(
        ExplorePeopleGrid(
          people: [_person('Emma'), _person('Jason'), _person('Emily')],
          selectedId: null,
          onSelect: (_) {},
          onClose: () {},
          onShowAll: () {},
        ),
      ));

      await tester.enterText(find.byType(TextField), 'em');
      await tester.pump();

      // "2 of 3" is the useful reading while filtering — a bare "2" hides how
      // much was left out.
      expect(find.text('2 of 3'), findsOneWidget);
      expect(find.text('Jason'), findsNothing);
      expect(find.text('Emma'), findsOneWidget);
      expect(find.text('Emily'), findsOneWidget);
    });

    testWidgets('search is case-insensitive', (tester) async {
      await tester.pumpWidget(_host(
        ExplorePeopleGrid(
          people: [_person('Emma'), _person('Jason')],
          selectedId: null,
          onSelect: (_) {},
          onClose: () {},
          onShowAll: () {},
        ),
      ));

      await tester.enterText(find.byType(TextField), 'EMMA');
      await tester.pump();
      expect(find.text('Emma'), findsOneWidget);
    });

    testWidgets('says so when a search matches nobody', (tester) async {
      await tester.pumpWidget(_host(
        ExplorePeopleGrid(
          people: [_person('Emma')],
          selectedId: null,
          onSelect: (_) {},
          onClose: () {},
          onShowAll: () {},
        ),
      ));

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pump();
      expect(find.text('Nobody here by that name'), findsOneWidget);
    });
  });
}
