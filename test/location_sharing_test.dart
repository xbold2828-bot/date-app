import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dating_app/core/theme/app_theme.dart';
import 'package:dating_app/data/models/message_model.dart';
import 'package:dating_app/data/models/user_model.dart';
import 'package:dating_app/presentation/common/widgets/widgets.dart';
import 'package:dating_app/presentation/home/screens/location_audience_screen.dart';
import 'package:dating_app/presentation/home/screens/location_sharing_screen.dart';
import 'package:dating_app/presentation/home/widgets/location_sharing_card.dart';
import 'package:dating_app/providers/location_sharing_provider.dart';

/// Stands in for the real notifier so a test can start from any setting
/// without a server. Writes are recorded rather than sent.
class _FakeSharing extends LocationSharingNotifier {
  _FakeSharing(this.initial);

  final LocationSharing initial;
  final List<String> writes = [];

  @override
  Future<LocationSharing> build() async => initial;

  /// The screen confirms against the server on open. There is no server here,
  /// and the real one swallows the failure anyway.
  @override
  Future<void> reload() async {}

  @override
  Future<void> setEnabled(bool enabled) async {
    writes.add('enabled=$enabled');
    state = AsyncData((state.valueOrNull ?? initial).copyWith(enabled: enabled));
  }

  @override
  Future<void> setAudience(LocationAudience audience) async {
    writes.add('audience=${audience.wire}');
    state = AsyncData(
      (state.valueOrNull ?? initial)
          .copyWith(enabled: true, audience: audience),
    );
  }
}

Widget _host(Widget child, LocationSharing sharing,
        {List<ChatOtherUser> friends = const []}) =>
    ProviderScope(
      overrides: [
        locationSharingProvider.overrideWith(() => _FakeSharing(sharing)),
        sharingFriendsProvider.overrideWithValue(AsyncData(friends)),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: child),
      ),
    );

const _friend = ChatOtherUser(id: 'f1', displayName: 'Meera');
const _otherFriend = ChatOtherUser(id: 'f2', displayName: 'Karan');

void main() {
  group('LocationSharing model', () {
    test('reads a missing setting as sharing with friends, never as off', () {
      // The dangerous default is the other one. Telling somebody they are
      // hidden while their friends can still see the pin is the error that
      // gets acted on.
      final sharing = LocationSharing.fromJson(const {});

      expect(sharing.enabled, isTrue);
      expect(sharing.audience, LocationAudience.friends);
      expect(sharing.allowedUserIds, isEmpty);
    });

    test('falls back to friends on an audience it does not know', () {
      final sharing = LocationSharing.fromJson(const {'audience': 'martians'});
      expect(sharing.audience, LocationAudience.friends);
    });

    test('parses a selected list', () {
      final sharing = LocationSharing.fromJson(const {
        'enabled': true,
        'audience': 'selected',
        'allowedUserIds': ['a', 'b'],
      });

      expect(sharing.audience, LocationAudience.selected);
      expect(sharing.allowedUserIds, ['a', 'b']);
      expect(sharing.selectedCount, 2);
    });

    test('counts "selected friends, nobody selected" as sharing with nobody',
        () {
      const sharing = LocationSharing(
        audience: LocationAudience.selected,
        allowedUserIds: [],
      );
      expect(sharing.isSharingWithAnyone, isFalse);
    });

    test('counts a switched-off account as sharing with nobody', () {
      const sharing = LocationSharing(enabled: false);
      expect(sharing.isSharingWithAnyone, isFalse);
    });

    test('toggleFriend adds then removes', () {
      const start = LocationSharing(allowedUserIds: ['a']);

      expect(start.toggleFriend('b').allowedUserIds, ['a', 'b']);
      expect(start.toggleFriend('a').allowedUserIds, isEmpty);
      // The original is untouched — the model is a value.
      expect(start.allowedUserIds, ['a']);
    });

    test('keeps the audience when switched off, so it can be restored', () {
      const start = LocationSharing(audience: LocationAudience.everyone);
      final off = start.copyWith(enabled: false);

      expect(off.audience, LocationAudience.everyone);
    });
  });

  group('LocationSharingCard', () {
    testWidgets('names the audience rather than just saying "location"',
        (tester) async {
      await tester.pumpWidget(
        _host(const LocationSharingCard(), const LocationSharing()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Shared with all friends'), findsOneWidget);
    });

    testWidgets('says nobody can see you when sharing is off', (tester) async {
      await tester.pumpWidget(
        _host(const LocationSharingCard(),
            const LocationSharing(enabled: false)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Not shared with anyone'), findsOneWidget);
    });

    testWidgets('does not claim to be sharing when nobody is picked',
        (tester) async {
      // "Shared with selected friends" over an empty list would be the
      // comfortable lie: it reads as on, and nobody can see a thing.
      await tester.pumpWidget(
        _host(
          const LocationSharingCard(),
          const LocationSharing(
            audience: LocationAudience.selected,
            allowedUserIds: [],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Not shared with anyone'), findsOneWidget);
    });

    testWidgets('counts the people who can see you', (tester) async {
      await tester.pumpWidget(
        _host(
          const LocationSharingCard(),
          const LocationSharing(
            audience: LocationAudience.selected,
            allowedUserIds: ['f1', 'f2'],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Shared with 2 friends'), findsOneWidget);
    });

    testWidgets('says "1 friend", not "1 friends"', (tester) async {
      await tester.pumpWidget(
        _host(
          const LocationSharingCard(),
          const LocationSharing(
            audience: LocationAudience.selected,
            allowedUserIds: ['f1'],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Shared with 1 friend'), findsOneWidget);
    });

    testWidgets('opens the setting screen when tapped', (tester) async {
      await tester.pumpWidget(
        _host(const LocationSharingCard(), const LocationSharing()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(LocationSharingCard));
      await tester.pumpAndSettle();

      expect(find.byType(LocationSharingScreen), findsOneWidget);
    });
  });

  group('LocationSharingScreen', () {
    /// Which of the four options is currently ticked.
    String? selectedTile(WidgetTester tester) {
      for (final tile in tester.widgetList<RadiusOptionTile>(
        find.byType(RadiusOptionTile),
      )) {
        if (tile.selected) return tile.title;
      }
      return null;
    }

    testWidgets('offers all four audiences', (tester) async {
      await tester.pumpWidget(
        _host(const LocationSharingScreen(), const LocationSharing()),
      );
      await tester.pumpAndSettle();

      for (final option in [
        'Everyone',
        'All friends',
        'Selected friends',
        'No one',
      ]) {
        expect(find.text(option), findsOneWidget);
      }
    });

    testWidgets('ticks "No one" when the master switch is off', (tester) async {
      // The switch and the radio group are the same setting. If they can
      // disagree, one of them is lying about who can see you.
      await tester.pumpWidget(
        _host(const LocationSharingScreen(),
            const LocationSharing(enabled: false)),
      );
      await tester.pumpAndSettle();

      expect(selectedTile(tester), 'No one');
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    });

    testWidgets('ticks exactly one option', (tester) async {
      await tester.pumpWidget(
        _host(
          const LocationSharingScreen(),
          const LocationSharing(audience: LocationAudience.everyone),
        ),
      );
      await tester.pumpAndSettle();

      final ticked = tester
          .widgetList<RadiusOptionTile>(find.byType(RadiusOptionTile))
          .where((tile) => tile.selected);
      expect(ticked, hasLength(1));
      expect(ticked.single.title, 'Everyone');
    });

    testWidgets('turning the switch off moves the tick to "No one"',
        (tester) async {
      await tester.pumpWidget(
        _host(const LocationSharingScreen(), const LocationSharing()),
      );
      await tester.pumpAndSettle();
      expect(selectedTile(tester), 'All friends');

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(selectedTile(tester), 'No one');
    });

    testWidgets('choosing an audience while off turns sharing back on',
        (tester) async {
      // One tap, not two. Somebody on this screen with sharing off is here to
      // turn it back on.
      await tester.pumpWidget(
        _host(const LocationSharingScreen(),
            const LocationSharing(enabled: false)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('All friends'));
      await tester.pumpAndSettle();

      expect(selectedTile(tester), 'All friends');
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    });

    testWidgets('warns that a selected list with nobody in it shows nobody',
        (tester) async {
      await tester.pumpWidget(
        _host(
          const LocationSharingScreen(),
          const LocationSharing(
            audience: LocationAudience.selected,
            allowedUserIds: [],
          ),
          friends: const [_friend, _otherFriend],
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('No one picked yet — nobody can see you'),
        findsOneWidget,
      );
    });

    testWidgets('counts the chosen friends under the option', (tester) async {
      await tester.pumpWidget(
        _host(
          const LocationSharingScreen(),
          const LocationSharing(
            audience: LocationAudience.selected,
            allowedUserIds: ['f1', 'f2'],
          ),
          friends: const [_friend, _otherFriend],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('2 friends can see you'), findsOneWidget);
    });

    testWidgets('says out loud that Radar is not covered by this setting',
        (tester) async {
      await tester.pumpWidget(
        _host(const LocationSharingScreen(), const LocationSharing()),
      );
      await tester.pumpAndSettle();

      final notice = tester.widget<NoticeBox>(find.byType(NoticeBox));
      expect(notice.text, contains('Radar'));
    });

    testWidgets('fits a narrow phone without overflowing', (tester) async {
      tester.view.physicalSize = const Size(320, 650);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _host(
          const LocationSharingScreen(),
          const LocationSharing(
            audience: LocationAudience.selected,
            allowedUserIds: ['f1', 'f2'],
          ),
          friends: const [_friend, _otherFriend],
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('LocationAudienceScreen', () {
    Widget picker(
      List<ChatOtherUser> friends, {
      List<String> selection = const [],
    }) =>
        ProviderScope(
          overrides: [
            sharingFriendsProvider.overrideWithValue(AsyncData(friends)),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: LocationAudienceScreen(initialSelection: selection),
          ),
        );

    testWidgets('lists the people I am vibing with', (tester) async {
      await tester.pumpWidget(picker(const [_friend, _otherFriend]));
      await tester.pumpAndSettle();

      expect(find.text('Meera'), findsOneWidget);
      expect(find.text('Karan'), findsOneWidget);
    });

    testWidgets('the footer is a footer, not the whole screen', (tester) async {
      // What went wrong: RadiusButton ends in a Container with an alignment,
      // which expands to fill bounded constraints — and a Scaffold gives its
      // bottomNavigationBar the height of the entire screen. The button grew
      // to 2000 px and buried the list of friends underneath it, so a screen
      // that was working looked like one that had loaded nobody.
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(picker(const [_friend, _otherFriend]));
      await tester.pumpAndSettle();

      final button = tester.getSize(find.byType(RadiusButton));
      expect(button.height, lessThan(120));

      // And the list is genuinely on screen, not merely in the tree behind it.
      final screen = tester.view.physicalSize.height / tester.view.devicePixelRatio;
      expect(tester.getTopLeft(find.text('Meera')).dy, lessThan(screen));
      expect(
        tester.getTopLeft(find.text('Meera')).dy,
        lessThan(tester.getTopLeft(find.byType(RadiusButton)).dy),
      );
    });

    testWidgets('opens with the already-chosen friends ticked', (tester) async {
      await tester.pumpWidget(
        picker(const [_friend, _otherFriend], selection: const ['f1']),
      );
      await tester.pumpAndSettle();

      expect(find.text('Save (1)'), findsOneWidget);
    });

    testWidgets('ticking somebody moves the count', (tester) async {
      await tester.pumpWidget(picker(const [_friend, _otherFriend]));
      await tester.pumpAndSettle();
      expect(find.text('Save (nobody)'), findsOneWidget);

      await tester.tap(find.text('Meera'));
      await tester.pumpAndSettle();

      expect(find.text('Save (1)'), findsOneWidget);
    });

    testWidgets('narrows to a search', (tester) async {
      await tester.pumpWidget(picker(const [_friend, _otherFriend]));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'kar');
      await tester.pumpAndSettle();

      expect(find.text('Karan'), findsOneWidget);
      expect(find.text('Meera'), findsNothing);
    });

    testWidgets('offers no footer when there is nobody to pick', (tester) async {
      await tester.pumpWidget(picker(const []));
      await tester.pumpAndSettle();

      expect(find.byType(RadiusButton), findsNothing);
      expect(find.text('No friends yet'), findsOneWidget);
    });

    testWidgets('keeps a friend it cannot see on this page', (tester) async {
      // The list is one page of the inbox. Somebody picked earlier who is not
      // on this page must survive a Save, or the picker quietly revokes them.
      await tester.pumpWidget(
        picker(const [_friend], selection: const ['f1', 'off-page']),
      );
      await tester.pumpAndSettle();

      expect(find.text('Save (2)'), findsOneWidget);
    });
  });

  group('MeUser', () {
    test('carries the setting off the self-view', () {
      final me = MeUser.fromJson(const {
        'id': 'u1',
        'supabaseId': 'sb-1',
        'status': 'active',
        'premium': {'isActive': false},
        'profile': {'displayName': 'Tarun'},
        'onboarding': {'isComplete': true, 'completedSteps': []},
        'locationSharing': {
          'enabled': true,
          'audience': 'selected',
          'allowedUserIds': ['f1'],
        },
      });

      expect(me.locationSharing.audience, LocationAudience.selected);
      expect(me.locationSharing.allowedUserIds, ['f1']);
    });

    test('defaults the setting on a payload without one', () {
      final me = MeUser.fromJson(const {
        'id': 'u1',
        'supabaseId': 'sb-1',
        'status': 'active',
        'premium': {'isActive': false},
        'profile': {'displayName': 'Tarun'},
        'onboarding': {'isComplete': true, 'completedSteps': []},
      });

      expect(me.locationSharing.enabled, isTrue);
      expect(me.locationSharing.audience, LocationAudience.friends);
    });
  });
}
