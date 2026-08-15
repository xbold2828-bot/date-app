import 'package:dating_app/core/theme/app_theme.dart';
import 'package:dating_app/data/models/discovery_user_model.dart';
import 'package:dating_app/data/models/map_user_model.dart';
import 'package:dating_app/presentation/common/widgets/widgets.dart';
import 'package:dating_app/presentation/explore/widgets/explore_people_grid.dart';
import 'package:dating_app/presentation/explore/widgets/explore_people_strip.dart';
import 'package:dating_app/providers/explore_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Picking somebody has to work from all three doors — the strip, the grid and
/// a marker — and all three have to end in the same place: that person selected,
/// and the composer pointed at them.
///
/// The map itself needs a platform view, so the marker route is covered by
/// `explore_map_tap_test.dart` against the resolution logic instead. This file
/// covers the two Flutter-side doors and the plumbing between them.
MapUser _person(String name) => MapUser(
      card: DiscoveryCard(id: name.toLowerCase(), displayName: name),
      latitude: 13.6,
      longitude: 79.4,
    );

/// Stands in for ExploreScreen: the same wiring — strip, "All" opening the grid
/// as a sheet, and a readout of who the composer would be pointed at — without
/// the map that cannot be mounted in a test.
class _Harness extends ConsumerWidget {
  const _Harness({required this.people});

  final List<MapUser> people;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedId = ref.watch(exploreSelectionProvider);
    final selected =
        people.where((person) => person.id == selectedId).firstOrNull;

    void select(MapUser person) =>
        ref.read(exploreSelectionProvider.notifier).state = person.id;

    Future<void> openGrid() => showRadiusSheet<void>(
          context: context,
          builder: (sheetContext) => ExplorePeopleGrid(
            people: people,
            selectedId: ref.read(exploreSelectionProvider),
            onClose: () => Navigator.pop(sheetContext),
            onSelect: (person) {
              select(person);
              Navigator.pop(sheetContext);
            },
            onShowAll: () {
              ref.read(exploreSelectionProvider.notifier).state = null;
              Navigator.pop(sheetContext);
            },
          ),
        );

    return Column(
      children: [
        ExplorePeopleStrip(
          people: people,
          selectedId: selectedId,
          onSelect: select,
          onShowAll: openGrid,
        ),
        const Spacer(),
        // What the composer would address.
        Text(
          selected == null
              ? 'composer: nobody'
              : 'composer: ${selected.displayName}',
        ),
      ],
    );
  }
}

Widget _host(List<MapUser> people) => ProviderScope(
      child: MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: _Harness(people: people)),
      ),
    );

/// The strip stays mounted under the sheet, so a bare text finder matches the
/// same name twice. Every grid assertion is scoped to the grid.
Finder _inGrid(String label) => find.descendant(
      of: find.byType(ExplorePeopleGrid),
      matching: find.text(label),
    );

void main() {
  final people = [_person('Emma'), _person('Jason'), _person('Olivia')];

  testWidgets('the strip points the composer at whoever was tapped',
      (tester) async {
    await tester.pumpWidget(_host(people));
    expect(find.text('composer: nobody'), findsOneWidget);

    await tester.tap(find.text('Jason'));
    await tester.pump();

    expect(find.text('composer: Jason'), findsOneWidget);
  });

  testWidgets('picking from the All grid selects and closes onto them',
      (tester) async {
    // The reported bug: the grid opened, a face was tapped, and nothing was
    // selected — so there was nobody to message.
    await tester.pumpWidget(_host(people));

    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    expect(find.text('All people (3)'), findsOneWidget);

    await tester.tap(_inGrid('Olivia'));
    await tester.pumpAndSettle();

    expect(
      find.text('All people (3)'),
      findsNothing,
      reason: 'grid should close',
    );
    expect(find.text('composer: Olivia'), findsOneWidget);
  });

  testWidgets('picking a searched face works the same way', (tester) async {
    // Search shifts the grid's item indices, which is exactly where an
    // off-by-one would send the tap to the wrong person.
    await tester.pumpWidget(_host(people));

    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'oli');
    await tester.pumpAndSettle();

    await tester.tap(_inGrid('Olivia'));
    await tester.pumpAndSettle();

    expect(find.text('composer: Olivia'), findsOneWidget);
  });

  testWidgets("the grid's All tile puts everyone back and clears the composer",
      (tester) async {
    await tester.pumpWidget(_host(people));

    await tester.tap(find.text('Emma'));
    await tester.pump();
    expect(find.text('composer: Emma'), findsOneWidget);

    // Reached from the strip's All, which now opens the grid rather than
    // clearing — so the grid is the only route back, and it must work.
    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    await tester.tap(_inGrid('All'));
    await tester.pumpAndSettle();

    expect(find.text('composer: nobody'), findsOneWidget);
  });

  testWidgets('the grid opens with the current pick already marked',
      (tester) async {
    await tester.pumpWidget(_host(people));

    await tester.tap(find.text('Jason'));
    await tester.pump();
    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();

    // Selected in the strip, so selected in the grid: one selection, two views.
    final tile = tester.widget<ExplorePeopleGrid>(
      find.byType(ExplorePeopleGrid),
    );
    expect(tile.selectedId, 'jason');
  });
}
