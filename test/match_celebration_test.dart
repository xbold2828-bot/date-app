import 'package:dating_app/core/theme/app_theme.dart';
import 'package:dating_app/data/models/match_model.dart';
import 'package:dating_app/presentation/home/widgets/match_celebration.dart';
import 'package:dating_app/presentation/home/providers/match_provider/match_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The celebration interrupts whatever someone was doing, so it has to be
/// correct about when it appears and trivially easy to leave.
///
/// Fixed pumps rather than `pumpAndSettle`, so the tests also prove the
/// sequence finishes inside the time it claims.
const _past = Duration(milliseconds: 1600);

Widget _host(ProviderContainer container) => UncontrolledProviderScope(
  container: container,
  child: MaterialApp(
    theme: AppTheme.light,
    home: const MatchCelebrationHost(
      child: Scaffold(body: Center(child: Text('radar'))),
    ),
  ),
);

const _ava = LikeCard(id: 'u1', displayName: 'Ava', distanceMeters: 1200);

void main() {
  late ProviderContainer container;

  setUp(
    () => container = ProviderContainer(
      // My own cover photo comes from the account and the gallery, neither of
      // which exists here; the card falls back to a monogram either way.
      overrides: [myCoverPhotoProvider.overrideWith((ref) => null)],
    ),
  );
  tearDown(() => container.dispose());

  testWidgets('stays out of the way until there is a match', (tester) async {
    await tester.pumpWidget(_host(container));

    expect(find.text('radar'), findsOneWidget);
    expect(find.text("It's mutual."), findsNothing);
  });

  testWidgets('takes over the screen when a match arrives', (tester) async {
    await tester.pumpWidget(_host(container));

    container.read(matchCelebrationProvider.notifier).show(_ava);
    await tester.pump();
    await tester.pump(_past);

    expect(find.text("It's mutual."), findsOneWidget);
    expect(find.textContaining('You and Ava both said yes.'), findsOneWidget);
    expect(find.text('Send a message'), findsOneWidget);
    expect(find.text('Keep browsing'), findsOneWidget);
    // Proximity is the product: the distance is part of the news.
    expect(find.textContaining('Ava is'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('lets people out again', (tester) async {
    await tester.pumpWidget(_host(container));
    container.read(matchCelebrationProvider.notifier).show(_ava);
    await tester.pump();
    await tester.pump(_past);

    await tester.tap(find.text('Keep browsing'));
    await tester.pump();
    await tester.pump(_past);

    expect(find.text("It's mutual."), findsNothing);
    expect(container.read(matchCelebrationProvider), isNull);
  });

  testWidgets('offers openers, and one of them names the match', (
    tester,
  ) async {
    await tester.pumpWidget(_host(container));
    container.read(matchCelebrationProvider.notifier).show(_ava);
    await tester.pump();
    await tester.pump(_past);

    expect(find.text('Out tonight?'), findsOneWidget);
    expect(find.text('Hey Ava'), findsOneWidget);
  });

  // A redacted card has no id and nothing to show. Better to skip the
  // celebration than to open a fullscreen takeover around a blank hero.
  testWidgets('ignores a match with no identity behind it', (tester) async {
    await tester.pumpWidget(_host(container));

    container
        .read(matchCelebrationProvider.notifier)
        .show(const LikeCard(id: ''));
    await tester.pump();
    await tester.pump(_past);

    expect(find.text("It's mutual."), findsNothing);
    expect(container.read(matchCelebrationProvider), isNull);
  });

  testWidgets('survives a match with no name or photo', (tester) async {
    await tester.pumpWidget(_host(container));

    container
        .read(matchCelebrationProvider.notifier)
        .show(const LikeCard(id: 'u9'));
    await tester.pump();
    await tester.pump(_past);

    expect(find.text('You and Someone both said yes.'), findsOneWidget);
    // No name, so no "Hey …" opener built from it.
    expect(find.textContaining('Hey '), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fits a small phone at a large text size', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          home: const MediaQuery(
            data: MediaQueryData(
              size: Size(320, 568),
              textScaler: TextScaler.linear(1.3),
            ),
            child: MatchCelebrationHost(
              child: Scaffold(body: SizedBox.expand()),
            ),
          ),
        ),
      ),
    );
    container.read(matchCelebrationProvider.notifier).show(_ava);
    await tester.pump();
    await tester.pump(_past);

    expect(tester.takeException(), isNull);
  });

  testWidgets('with reduced motion it is simply there', (tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          home: const MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: MatchCelebrationHost(
              child: Scaffold(body: SizedBox.expand()),
            ),
          ),
        ),
      ),
    );
    container.read(matchCelebrationProvider.notifier).show(_ava);
    await tester.pump();
    // Only the 260 ms backdrop fade runs; the composition is already landed.
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text("It's mutual."), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
