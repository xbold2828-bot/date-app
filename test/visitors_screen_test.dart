import 'package:dating_app/core/constants/app_string.dart';
import 'package:dating_app/core/theme/app_theme.dart';
import 'package:dating_app/data/models/match_model.dart';
import 'package:dating_app/data/models/visitor_model.dart';
import 'package:dating_app/presentation/common/widgets/widgets.dart';
import 'package:dating_app/presentation/home/screens/visitors_screen.dart';
import 'package:dating_app/providers/visitors_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every reveal a test asked for, instead of a server call. Reset per test.
final List<(String, bool)> _calls = [];

class _FakeActions extends VisitorActions {
  _FakeActions(super.ref);

  @override
  Future<VisitorCard> reveal(String visitId, {bool afterAd = false}) async {
    _calls.add((visitId, afterAd));
    return VisitorCard(
      visitId: visitId,
      user: const LikeCard(id: 'u-a', displayName: 'Asha'),
    );
  }
}

Map<String, dynamic> _locked(String visitId) => {
  'visitId': visitId,
  'id': '',
  'age': null,
  'isOnline': true,
  'isVerified': false,
  'locked': true,
};

VisitorsPage _page({
  required List<Map<String, dynamic>> items,
  int freeRemaining = 2,
  int creditBalance = 0,
  bool premium = false,
}) => VisitorsPage.fromJson({
  'total': items.length,
  'locked': items.any((i) => i['locked'] == true),
  'source': premium ? 'premium' : null,
  'page': 1,
  'limit': 30,
  'unlocks': premium
      ? null
      : {
          'freeTotal': 2,
          'freeUsed': 2 - freeRemaining,
          'freeRemaining': freeRemaining,
          'creditCost': 1,
          'creditBalance': creditBalance,
        },
  'items': items,
});

void main() {
  group('VisitorsPage', () {
    test('reads a locked visitor as a visit with nobody behind it', () {
      final page = _page(items: [_locked('v1')]);
      final visitor = page.items.single;

      expect(visitor.visitId, 'v1');
      expect(visitor.locked, isTrue);
      expect(visitor.user.id, isEmpty);
      expect(visitor.user.displayName, isNull);
      expect(visitor.visitedAt, isNull);
    });

    test('reads an unlocked visitor in full', () {
      final page = _page(
        items: [
          {
            'visitId': 'v2',
            'id': 'u2',
            'displayName': 'Asha',
            'age': 26,
            'isOnline': false,
            'isVerified': true,
            'visitedAt': '2026-10-28T10:00:00.000Z',
          },
        ],
      );
      final visitor = page.items.single;

      expect(visitor.locked, isFalse);
      expect(visitor.user.id, 'u2');
      expect(visitor.user.displayName, 'Asha');
      expect(visitor.visitedAt, DateTime.utc(2026, 10, 28, 10));
    });

    test('needs an ad only when free reveals and credits are both gone', () {
      expect(
        _page(items: [_locked('v1')], freeRemaining: 1).canRevealWithoutAd,
        isTrue,
      );
      expect(
        _page(
          items: [_locked('v1')],
          freeRemaining: 0,
          creditBalance: 1,
        ).canRevealWithoutAd,
        isTrue,
      );
      expect(
        _page(items: [_locked('v1')], freeRemaining: 0).canRevealWithoutAd,
        isFalse,
      );
    });
  });

  group('VisitorsScreen', () {
    setUp(_calls.clear);

    Widget host(VisitorsPage page) => ProviderScope(
      overrides: [
        visitorsProvider.overrideWith((ref) async => page),
        visitorActionsProvider.overrideWith(_FakeActions.new),
      ],
      child: MaterialApp(theme: AppTheme.light, home: const VisitorsScreen()),
    );

    testWidgets('says how many visited and what a reveal costs', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(_page(items: [_locked('v1'), _locked('v2')])),
      );
      await tester.pumpAndSettle();

      expect(find.text('2 people visited you'), findsOneWidget);
      expect(
        find.text('Tap a photo to reveal them. 2 free reveals left.'),
        findsOneWidget,
      );
      expect(find.byType(ProfileGridCard), findsNWidgets(2));
    });

    testWidgets('spends a free reveal on tap, with no ad', (tester) async {
      await tester.pumpWidget(host(_page(items: [_locked('v1')])));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(ProfileGridCard));
      await tester.pump();

      expect(_calls, [('v1', false)]);
      expect(find.text(AppString.seeWhoVisitedYouTitle), findsNothing);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('offers Premium or an ad once the free reveals are gone', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(_page(items: [_locked('v1')], freeRemaining: 0)),
      );
      await tester.pumpAndSettle();

      expect(find.text(AppString.visitorsAdEach), findsOneWidget);

      await tester.tap(find.byType(ProfileGridCard));
      await tester.pumpAndSettle();

      expect(find.text(AppString.seeWhoVisitedYouTitle), findsOneWidget);
      expect(_calls, isEmpty);
    });

    // Credits also pay for chats and the radar, so spending one is asked.
    testWidgets('asks before spending a credit', (tester) async {
      await tester.pumpWidget(
        host(_page(items: [_locked('v1')], freeRemaining: 0, creditBalance: 4)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(ProfileGridCard));
      await tester.pumpAndSettle();
      expect(find.text('Uses 1 credit. You have 4.'), findsOneWidget);
      expect(_calls, isEmpty);

      await tester.tap(find.text('Reveal'));
      await tester.pump();
      expect(_calls, [('v1', false)]);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('shows an empty state rather than a blank grid', (
      tester,
    ) async {
      await tester.pumpWidget(host(_page(items: const [])));
      await tester.pumpAndSettle();

      expect(find.text(AppString.visitorsEmptyTitle), findsOneWidget);
    });

    testWidgets('fits a narrow phone at large text', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: host(
            _page(items: [for (var i = 0; i < 7; i++) _locked('v$i')]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
