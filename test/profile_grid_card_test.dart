import 'package:dating_app/core/theme/app_theme.dart';
import 'package:dating_app/data/models/discovery_user_model.dart';
import 'package:dating_app/data/models/match_model.dart';
import 'package:dating_app/presentation/common/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The line under a name on a grid card.
///
/// It carries the two things a browsing decision actually turns on — how far,
/// how recently — in the width of a third of a phone. What it must never do is
/// claim precision or freshness the payload does not support.
void main() {
  Widget host(Widget card) => MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SizedBox(width: 120, height: 170, child: card),
        ),
      );

  DateTime ago(Duration d) => DateTime.now().subtract(d);

  group('distance', () {
    testWidgets('prints a number when the server sent one', (tester) async {
      await tester.pumpWidget(host(ProfileGridCard(
        name: 'Aman',
        age: 30,
        colorIndex: 0,
        distanceBand: '<2 km',
        distanceMeters: 450,
        onTap: () {},
      )));

      // The number, not the band it also came with.
      expect(find.textContaining('450 m'), findsOneWidget);
      expect(find.textContaining('<2 km'), findsNothing);
    });

    testWidgets('falls back to the band when there is no number',
        (tester) async {
      // An older server, or a locked card the server stripped.
      await tester.pumpWidget(host(ProfileGridCard(
        name: 'Aman',
        age: 30,
        colorIndex: 0,
        distanceBand: '5-10 km',
        onTap: () {},
      )));

      expect(find.textContaining('5-10 km'), findsOneWidget);
    });

    testWidgets('uses feet up close and miles far out', (tester) async {
      await tester.pumpWidget(host(ProfileGridCard(
        name: 'A',
        colorIndex: 0,
        distanceMeters: 60,
        onTap: () {},
      )));
      expect(find.textContaining('ft'), findsOneWidget);

      await tester.pumpWidget(host(ProfileGridCard(
        name: 'B',
        colorIndex: 0,
        distanceMeters: 4000,
        onTap: () {},
      )));
      expect(find.textContaining('mi'), findsOneWidget);
    });

    testWidgets('says nothing when the viewer has no location', (tester) async {
      await tester.pumpWidget(host(ProfileGridCard(
        name: 'Aman',
        age: 30,
        colorIndex: 0,
        onTap: () {},
      )));

      expect(find.text('Aman, 30'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('last seen', () {
    testWidgets('sits beside the distance', (tester) async {
      await tester.pumpWidget(host(ProfileGridCard(
        name: 'Aman',
        colorIndex: 0,
        distanceMeters: 450,
        lastActiveAt: ago(const Duration(hours: 2)),
        onTap: () {},
      )));

      expect(find.text('450 m · 2h ago'), findsOneWidget);
    });

    testWidgets('drops out entirely while they are online', (tester) async {
      // The green dot already says it, and on a card this narrow the second
      // statement is the one that gets truncated.
      await tester.pumpWidget(host(ProfileGridCard(
        name: 'Aman',
        colorIndex: 0,
        distanceMeters: 450,
        lastActiveAt: ago(const Duration(hours: 2)),
        isOnline: true,
        onTap: () {},
      )));

      expect(find.text('450 m'), findsOneWidget);
      expect(find.textContaining('ago'), findsNothing);
    });

    testWidgets('stands alone when there is no distance', (tester) async {
      await tester.pumpWidget(host(ProfileGridCard(
        name: 'Aman',
        colorIndex: 0,
        lastActiveAt: ago(const Duration(days: 1, hours: 3)),
        onTap: () {},
      )));

      expect(find.text('Yesterday'), findsOneWidget);
    });
  });

  group('locked cards', () {
    testWidgets('give away neither distance nor last seen', (tester) async {
      // Belt and braces over the server's redaction: a blurred stranger who
      // still printed "450 m" would be placeable without being named.
      await tester.pumpWidget(host(ProfileGridCard(
        name: '',
        colorIndex: 0,
        blurred: true,
        isOnline: true,
        onTap: () {},
      )));

      expect(find.textContaining('m'), findsNothing);
      expect(find.textContaining('ago'), findsNothing);
    });
  });

  group('layout', () {
    testWidgets('keeps the meta line to one line on a narrow card',
        (tester) async {
      await tester.pumpWidget(host(ProfileGridCard(
        name: 'Bartholomew',
        age: 41,
        colorIndex: 0,
        distanceMeters: 12450,
        lastActiveAt: ago(const Duration(days: 15)),
        onTap: () {},
      )));

      final meta = tester.widget<Text>(find.text('7.7 mi · 2w ago'));
      expect(meta.maxLines, 1);
      expect(meta.overflow, TextOverflow.ellipsis);
      expect(tester.takeException(), isNull);
    });
  });

  group('the models carry the fields', () {
    test('DiscoveryCard reads them off the payload', () {
      final card = DiscoveryCard.fromJson(const {
        'id': 'u1',
        'displayName': 'Aman',
        'distanceBand': '<2 km',
        'distanceMeters': 450,
        'lastActiveAt': '2026-08-16T09:00:00.000Z',
      });

      expect(card.distanceMeters, 450);
      expect(card.lastActiveAt, isNotNull);
    });

    test('DiscoveryCard survives a payload without them', () {
      final card = DiscoveryCard.fromJson(const {
        'id': 'u1',
        'distanceBand': '<2 km',
      });

      expect(card.distanceMeters, isNull);
      expect(card.lastActiveAt, isNull);
    });

    test('withOnline keeps them', () {
      // It rebuilds the card field by field, so a new field is exactly the
      // kind of thing it silently drops.
      final card = DiscoveryCard.fromJson(const {
        'id': 'u1',
        'distanceMeters': 450,
        'lastActiveAt': '2026-08-16T09:00:00.000Z',
      }).withOnline(true);

      expect(card.distanceMeters, 450);
      expect(card.lastActiveAt, isNotNull);
      expect(card.isOnline, isTrue);
    });

    test('LikeCard reads them off the payload', () {
      final card = LikeCard.fromJson(const {
        'id': 'u1',
        'displayName': 'Aman',
        'distanceMeters': 1200,
        'lastActiveAt': '2026-08-16T09:00:00.000Z',
      });

      expect(card.distanceMeters, 1200);
      expect(card.lastActiveAt, isNotNull);
    });

    test('a redacted LikeCard has neither', () {
      final card = LikeCard.fromJson(const {
        'id': '',
        'locked': true,
        'isOnline': true,
      });

      expect(card.locked, isTrue);
      expect(card.distanceMeters, isNull);
      expect(card.lastActiveAt, isNull);
    });
  });
}
