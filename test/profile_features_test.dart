import 'package:dating_app/core/constants/selection_limits.dart';
import 'package:dating_app/core/constants/tag_categories.dart';
import 'package:dating_app/core/theme/app_theme.dart';
import 'package:dating_app/presentation/common/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The four rules this batch of work rests on:
///
/// * premium decoration is the owner's alone,
/// * verification is everybody's,
/// * a capped question refuses the tap past its cap (and a one-of question
///   swaps instead),
/// * a metric with no number says so rather than claiming zero.

Widget host(Widget child, {Size size = const Size(390, 844)}) => MaterialApp(
      theme: AppTheme.light,
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: Scaffold(body: Center(child: child)),
      ),
    );

void main() {
  group('PremiumAvatar', () {
    testWidgets('crowns the owner of a premium account', (tester) async {
      await tester.pumpWidget(host(
        const PremiumAvatar(
          isPremium: true,
          isCurrentUser: true,
          child: SizedBox(),
        ),
      ));

      expect(find.bySemanticsLabel('Premium member'), findsOneWidget);
    });

    // The privacy rule. Premium buys reach, not a badge announcing what you
    // spend to everyone who opens your profile from the radar.
    testWidgets('shows nothing premium to anybody else', (tester) async {
      await tester.pumpWidget(host(
        const PremiumAvatar(
          isPremium: true,
          isCurrentUser: false,
          child: SizedBox(),
        ),
      ));

      expect(find.bySemanticsLabel('Premium member'), findsNothing);
    });

    testWidgets('a free account gets no gold on its own profile',
        (tester) async {
      await tester.pumpWidget(host(
        const PremiumAvatar(
          isPremium: false,
          isCurrentUser: true,
          child: SizedBox(),
        ),
      ));

      expect(find.bySemanticsLabel('Premium member'), findsNothing);
    });

    // A ticker left running behind a hidden decoration is the expensive
    // version of this bug: invisible, and paid for on every frame.
    testWidgets('runs no animation when there is no premium to draw',
        (tester) async {
      await tester.pumpWidget(host(
        const PremiumAvatar(
          isPremium: true,
          isCurrentUser: false,
          child: SizedBox(),
        ),
      ));

      // pumpAndSettle throws if anything is still animating. On the owner's
      // own avatar the ring repeats forever, which is exactly why it may only
      // be built there.
      await tester.pumpAndSettle();
    });
  });

  group('VerificationTick', () {
    testWidgets('rides beside the name when the account is verified',
        (tester) async {
      await tester.pumpWidget(host(
        const NameWithTick(name: 'Tarun, 35', isVerified: true),
      ));

      expect(find.byType(VerificationTick), findsOneWidget);
      expect(find.bySemanticsLabel('Verified account'), findsOneWidget);
    });

    testWidgets('stays away from an unverified one', (tester) async {
      await tester.pumpWidget(host(
        const NameWithTick(name: 'Tarun, 35', isVerified: false),
      ));

      expect(find.byType(VerificationTick), findsNothing);
    });

    // A long name at a large font scale used to push the badge off the row.
    testWidgets('keeps the badge on screen next to a very long name',
        (tester) async {
      await tester.pumpWidget(host(
        const NameWithTick(
          name: 'Bartholomew Fitzgerald-Montgomery, 35',
          isVerified: true,
        ),
        size: const Size(320, 640),
      ));

      expect(tester.takeException(), isNull);
      expect(find.byType(VerificationTick), findsOneWidget);
    });
  });

  group('selection limits', () {
    test('a one-of question swaps rather than refusing', () {
      final next = applySelectionLimit({'casual'}, 'dating', 1);
      expect(next, {'dating'});
    });

    test('a three-of question refuses the fourth', () {
      final full = {'a', 'b', 'c'};
      expect(applySelectionLimit(full, 'd', 3), isNull);
    });

    test('deselecting always works, full or not', () {
      expect(applySelectionLimit({'a', 'b', 'c'}, 'b', 3), {'a', 'c'});
      expect(applySelectionLimit({'a'}, 'a', 1), isEmpty);
    });

    test('a null cap never refuses — hard no\'s are boundaries', () {
      var selected = <String>{};
      for (final slug in ['a', 'b', 'c', 'd', 'e', 'f']) {
        selected = applySelectionLimit(selected, slug, SelectionLimits.hardNos)!;
      }
      expect(selected, hasLength(6));
    });

    test('the product limits are 1 / 1 / 3 / unlimited', () {
      expect(SelectionLimits.intent, 1);
      expect(SelectionLimits.situation, 1);
      expect(SelectionLimits.vibes, 3);
      expect(SelectionLimits.hardNos, isNull);
    });

    // Desires are capped per section, not as one budget across the step —
    // three picks in "role & energy" must not close "scenario".
    test('every desires category carries its own cap', () {
      for (final category in TagCategories.preferences) {
        expect(
          SelectionLimits.intoByCategory.containsKey(category),
          isTrue,
          reason: '$category has no cap',
        );
      }
      expect(SelectionLimits.intoIn(TagCategories.roleEnergy), 3);
      expect(SelectionLimits.intoIn(TagCategories.into), 3);
      expect(SelectionLimits.intoIn(TagCategories.scenario), 3);
      expect(SelectionLimits.intoIn(TagCategories.intensity), 3);
      expect(SelectionLimits.intoIn(TagCategories.fantasySetting), 3);
      // Experience is a fact, not a preference: exactly one.
      expect(SelectionLimits.intoIn(TagCategories.experience), 1);
    });

    // Experience is capped at one, and a one-of question swaps rather than
    // refusing — so the second tap must never be a dead end.
    test('picking a second experience swaps the first', () {
      final next = applySelectionLimit(
        {'new_and_curious'},
        'experienced',
        SelectionLimits.intoIn(TagCategories.experience),
      );
      expect(next, {'experienced'});
    });
  });

  group('ProfileMetricsRow', () {
    testWidgets('prints the three numbers', (tester) async {
      await tester.pumpWidget(host(
        const ProfileMetricsRow(visits: 42, likes: 7, friends: 3),
      ));

      expect(find.text('42'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    // "We could not load your visits" and "nobody has visited you" are
    // different statements. Printing zero for the first is a lie.
    testWidgets('dashes a number it does not have', (tester) async {
      await tester.pumpWidget(host(
        const ProfileMetricsRow(visits: null, likes: 2, friends: null),
      ));

      expect(find.text('—'), findsNWidgets(2));
    });

    testWidgets('shortens a crowd', (tester) async {
      await tester.pumpWidget(host(
        const ProfileMetricsRow(visits: 1200, likes: 12400, friends: 999),
      ));

      expect(find.text('1.2k'), findsOneWidget);
      expect(find.text('12k'), findsOneWidget);
      expect(find.text('999'), findsOneWidget);
    });

    // On somebody else's profile "friends" is not missing, it is unknowable —
    // it is counted from the viewer's own inbox.
    testWidgets('omits a tile that could never have a value', (tester) async {
      await tester.pumpWidget(host(
        const ProfileMetricsRow(
          visits: 5,
          likes: 5,
          friends: null,
          omitUnknown: true,
        ),
      ));

      expect(find.text('FRIENDS'), findsNothing);
      expect(find.text('—'), findsNothing);
      expect(find.text('VISITS'), findsOneWidget);
    });
  });
}
