import 'package:dating_app/core/theme/app_theme.dart';
import 'package:dating_app/presentation/home/models/like_quota_model.dart';
import 'package:dating_app/presentation/home/providers/like_quota_provider/like_quota_provider.dart';
import 'package:dating_app/presentation/home/screens/dashboard_screen.dart';
import 'package:dating_app/presentation/home/widgets/likes_meter.dart';
import 'package:dating_app/presentation/notifications/viewmodel/providers/notification_provider/notification_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Radar header packs five things onto one line: the mark, the
/// greeting, the likes meter, notifications and Filters. All but the greeting
/// are fixed-width, so the greeting is the only thing that can give — which
/// makes this the most likely place in the app to overflow.
LikeQuota _quota({
  int remaining = 2,
  int allowance = 3,
  bool unlimited = false,
}) => LikeQuota(
  isPremium: unlimited,
  unlimited: unlimited,
  dailyLimit: 3,
  bonusFromAds: 0,
  allowance: allowance,
  used: allowance - remaining,
  remaining: remaining,
  maxPerDay: 10,
  canEarnMore: true,
  likesPerAd: 1,
  resetsAt: null,
);

class _FixedQuota extends LikeQuotaNotifier {
  _FixedQuota(this.quota);
  final LikeQuota quota;

  @override
  Future<LikeQuota> build() async => quota;
}

Widget _host(Widget child, {double textScale = 1.0, LikeQuota? quota}) =>
    ProviderScope(
      overrides: [
        likeQuotaProvider.overrideWith(() => _FixedQuota(quota ?? _quota())),
        unreadNotificationCountProvider.overrideWith((ref) async => 3),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(body: child),
        ),
      ),
    );

void main() {
  testWidgets('fits a narrow phone with a long name', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _host(
        const RadarHeader(
          name: 'Bartholomew Fitzgerald',
          city: 'Visakhapatnam',
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('fits at 1.3x text scale', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _host(
        const RadarHeader(name: 'M Tarun', city: 'Hyderabad'),
        textScale: 1.3,
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('Filters is reachable, and nothing sells Premium here', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _host(const RadarHeader(name: 'M Tarun', city: 'Hyderabad')),
    );
    await tester.pump();

    // Filters moved here precisely so it is not buried behind eight intent
    // chips in a horizontal scroller.
    expect(find.bySemanticsLabel('Filters'), findsOneWidget);
    // The Premium pill used to sit beside it, squeezing the greeting into an
    // ellipsis to advertise on the screen people open the app to use.
    expect(find.bySemanticsLabel('Radius Premium'), findsNothing);
  });

  testWidgets('survives having no name or city yet', (tester) async {
    await tester.pumpWidget(_host(const RadarHeader()));
    await tester.pump();
    expect(find.text('Your Cozune'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('likes meter', () {
    testWidgets('says how many likes are left', (tester) async {
      await tester.pumpWidget(
        _host(
          const RadarHeader(name: 'Maya', city: 'Mumbai'),
          quota: _quota(remaining: 2, allowance: 3),
        ),
      );
      await tester.pump();

      expect(find.bySemanticsLabel('Likes today: 2 left'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('a Premium account reads as unlimited', (tester) async {
      await tester.pumpWidget(
        _host(
          const RadarHeader(name: 'Maya', city: 'Mumbai'),
          quota: _quota(unlimited: true),
        ),
      );
      await tester.pump();

      expect(find.bySemanticsLabel('Likes today: unlimited'), findsOneWidget);
    });

    test('the heart drains in proportion to what is spent', () {
      expect(LikesMeter.fillOf(_quota(remaining: 3, allowance: 3)), 1);
      expect(
        LikesMeter.fillOf(_quota(remaining: 1, allowance: 3)),
        closeTo(1 / 3, 0.001),
      );
      expect(LikesMeter.fillOf(_quota(remaining: 0, allowance: 3)), 0);
      expect(LikesMeter.fillOf(_quota(unlimited: true)), 1);
    });

    testWidgets('tapping it opens the day\'s likes', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _host(
          const RadarHeader(name: 'Maya', city: 'Mumbai'),
          quota: _quota(remaining: 1, allowance: 3),
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(LikesMeter));
      await tester.pumpAndSettle();

      expect(find.text('Likes today'), findsOneWidget);
      expect(find.text('1 of 3 left'), findsOneWidget);
      expect(find.text('Unlimited likes with Premium'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
