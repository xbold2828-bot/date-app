import 'package:dating_app/core/theme/app_theme.dart';
import 'package:dating_app/data/repositories/safety_repository.dart';
import 'package:dating_app/presentation/home/screens/blocked_accounts_screen.dart';
import 'package:dating_app/providers/chat_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The row packs an avatar, a name, a "blocked when" line and an action onto
/// one line, so it is the most likely place on the screen to overflow — which
/// it did: the action was a full-size footer button squeezed into a fixed 96px,
/// and its label broke across two lines as "Unblo / ck".
Widget _host(List<BlockedUser> blocked) => ProviderScope(
      overrides: [
        blockedUsersProvider.overrideWith((ref) async => blocked),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const BlockedAccountsScreen(),
      ),
    );

const _tarun = BlockedUser(id: 'u1', displayName: 'Tarun');

void main() {
  testWidgets('keeps the action label on one line', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host(const [_tarun]));
    await tester.pumpAndSettle();

    final label = tester.widget<Text>(find.text('Unblock'));
    expect(label.maxLines, 1);

    // One rendered line, not two.
    final rendered = tester.renderObject<RenderParagraph>(find.text('Unblock'));
    expect(rendered.size.height, lessThan(24));
  });

  testWidgets('fits a narrow phone without overflowing', (tester) async {
    tester.view.physicalSize = const Size(320, 650);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host(const [_tarun]));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  // A long name is what pushes the action against the edge.
  testWidgets('survives a long display name', (tester) async {
    tester.view.physicalSize = const Size(320, 650);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _host(const [BlockedUser(id: 'u1', displayName: 'Bartholomew Fitzgerald')]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Unblock'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('offers the way back out of an empty list too', (tester) async {
    await tester.pumpWidget(_host(const []));
    await tester.pumpAndSettle();

    expect(find.text('Nobody blocked'), findsOneWidget);
    expect(find.text('Unblock'), findsNothing);
  });
}
