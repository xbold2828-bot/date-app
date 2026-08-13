import 'package:dating_app/core/theme/app_theme.dart';
import 'package:dating_app/data/models/match_model.dart';
import 'package:dating_app/data/models/profile_model.dart';
import 'package:dating_app/data/repositories/match_repository.dart';
import 'package:dating_app/presentation/home/screens/profile_detail_sheet.dart';
import 'package:dating_app/providers/core_providers.dart';
import 'package:dating_app/providers/profile_provider.dart';
import 'package:dating_app/providers/realtime_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The profile sheet is where a person decides whether to reach out, so it has
/// to show everything they chose during onboarding — and the like has to feel
/// like it happened.

const _id = 'u1';

PublicProfile _profile({
  List<String> photos = const [],
  List<String> intent = const [],
  List<String> pronouns = const [],
  List<String> personalityTags = const [],
  List<String>? preferenceTags,
  bool desiresLocked = false,
  String? gender,
  String? relationshipStatus,
  String? bio,
  bool hasLiked = false,
  bool isMatch = false,
}) =>
    PublicProfile(
      id: _id,
      displayName: 'Ava',
      age: 27,
      gender: gender,
      pronouns: pronouns,
      intent: intent,
      relationshipStatus: relationshipStatus,
      bio: bio,
      personalityTags: personalityTags,
      preferenceTags: preferenceTags,
      desiresLocked: desiresLocked,
      distanceBand: '<2 km',
      photos: photos,
      hasLiked: hasLiked,
      isMatch: isMatch,
    );

/// Stops [presenceProvider] opening a real socket in a test.
class _StillPresence extends PresenceNotifier {
  @override
  Map<String, bool> build() => const {};
}

class _FakeMatchRepository implements MatchRepository {
  int likes = 0;
  int unlikes = 0;

  @override
  Future<LikeResult> react(String toUserId, String type) async {
    likes++;
    return const LikeResult(liked: true, type: 'like', isMatch: false);
  }

  @override
  Future<void> unreact(String userId) async => unlikes++;

  @override
  Future<LikedYouPage> likedYou({int page = 1, int limit = 20}) async =>
      throw UnimplementedError();

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Future<void> _pump(
  WidgetTester tester, {
  required PublicProfile profile,
  MatchRepository? matches,
  Map<String, String> tagLabels = const {},
}) async {
  // A phone, not the 800x600 default. The sheet is sized as a fraction of the
  // viewport and the toast floats a fixed distance off the bottom, so on a
  // short, wide window the two land on top of each other — which is a property
  // of the test window, not of any device.
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        publicProfileProvider(_id).overrideWith((ref) async => profile),
        tagLabelsProvider.overrideWith((ref) async => tagLabels),
        presenceProvider.overrideWith(_StillPresence.new),
        if (matches != null) matchRepositoryProvider.overrideWithValue(matches),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ProfileDetailSheet(
            userId: _id,
            seed: const ProfileSeed(name: 'Ava', colorIndex: 0, age: 27),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('photo carousel', () {
    testWidgets('pages through every photo the backend sent', (tester) async {
      await _pump(
        tester,
        profile: _profile(photos: const ['a.jpg', 'b.jpg', 'c.jpg']),
      );

      expect(find.byType(PageView), findsOneWidget);
      expect(find.bySemanticsLabel('Photo 1 of 3'), findsOneWidget);
      expect(find.bySemanticsLabel('Next photo'), findsOneWidget);
    });

    // A lone dot under a single photo reads as a carousel that failed to load
    // the rest of the set.
    testWidgets('shows no pager for a single photo', (tester) async {
      await _pump(tester, profile: _profile(photos: const ['only.jpg']));

      expect(find.bySemanticsLabel('Photo 1 of 1'), findsNothing);
      expect(find.bySemanticsLabel('Next photo'), findsNothing);
    });

    testWidgets('falls back to the initial when there are no photos',
        (tester) async {
      await _pump(tester, profile: _profile());

      expect(find.text('A'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('onboarding details', () {
    testWidgets('renders every selection, as words rather than slugs',
        (tester) async {
      await _pump(
        tester,
        profile: _profile(
          intent: const ['right_now', 'open_to_anything'],
          gender: 'non_binary',
          pronouns: const ['they/them'],
          relationshipStatus: 'open_relationship',
          personalityTags: const ['night_owl'],
          preferenceTags: const ['slow_burn'],
          bio: 'Here for the good coffee.',
        ),
        tagLabels: const {'night_owl': 'Night owl', 'slow_burn': 'Slow burn'},
      );

      expect(find.text('AVA, 27'), findsOneWidget);
      expect(find.text('Here for the good coffee.'), findsOneWidget);

      // Enum slugs resolved through the label maps.
      expect(find.text('Right now'), findsOneWidget);
      expect(find.text('Open to anything'), findsOneWidget);
      expect(find.text('Non-binary'), findsOneWidget);
      expect(find.text('They/Them'), findsOneWidget);
      expect(find.text('Open relationship'), findsOneWidget);

      // Tag slugs resolved through the catalogue.
      expect(find.text('Night owl'), findsOneWidget);
      expect(find.text('Slow burn'), findsOneWidget);
    });

    // An unknown value still has to read as words — a section that silently
    // drops it looks like the person left it blank.
    testWidgets('humanises a slug it has never seen', (tester) async {
      await _pump(tester, profile: _profile(personalityTags: const ['deep_sea_diver']));
      expect(find.text('Deep sea diver'), findsOneWidget);
    });

    testWidgets('hides sections the person left empty', (tester) async {
      await _pump(tester, profile: _profile());

      expect(find.text('HERE FOR'), findsNothing);
      expect(find.text('SITUATION'), findsNothing);
      expect(find.text('INTERESTS & VIBES'), findsNothing);
    });

    testWidgets('explains a locked desires section instead of hiding it',
        (tester) async {
      await _pump(tester, profile: _profile(desiresLocked: true));
      expect(find.textContaining('Verify your identity'), findsOneWidget);
    });
  });

  group('like', () {
    testWidgets('fills the heart and confirms, without waiting on the network',
        (tester) async {
      final matches = _FakeMatchRepository();
      await _pump(tester, profile: _profile(), matches: matches);

      expect(find.byIcon(Icons.favorite_border), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Like Ava'));
      // One frame: the animation has barely started, but the state is already
      // flipped — that is the whole point of doing it on tap.
      await tester.pump();
      expect(find.byIcon(Icons.favorite), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border), findsNothing);

      await tester.pumpAndSettle();
      expect(matches.likes, 1);
      expect(find.text('You liked Ava'), findsOneWidget);
    });

    // The bug: the heart was local state that started false on every open, so
    // a profile you had already liked came back looking un-liked and invited
    // you to like it again.
    testWidgets('renders filled when the server says it was already liked',
        (tester) async {
      await _pump(tester, profile: _profile(hasLiked: true));

      expect(find.byIcon(Icons.favorite), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border), findsNothing);
      expect(find.bySemanticsLabel('You liked Ava'), findsOneWidget);
    });

    testWidgets('names the state as a match when it is one', (tester) async {
      await _pump(tester, profile: _profile(hasLiked: true, isMatch: true));
      expect(find.bySemanticsLabel('You matched with Ava'), findsOneWidget);
    });

    // Every extra tap used to re-run the match engine and replay the
    // celebration on both devices.
    testWidgets('refuses a second like, so the match engine runs once',
        (tester) async {
      final matches = _FakeMatchRepository();
      await _pump(tester, profile: _profile(), matches: matches);

      await tester.tap(find.bySemanticsLabel('Like Ava'));
      await tester.pumpAndSettle();
      expect(matches.likes, 1);

      // The control is inert now — tapping it again must not reach the API.
      // Targeted by icon rather than label: the confirmation toast carries the
      // same words, and would make the finder ambiguous.
      await tester.tap(find.byIcon(Icons.favorite));
      await tester.pumpAndSettle();
      expect(matches.likes, 1);
    });

    testWidgets('an already-liked profile cannot be liked again at all',
        (tester) async {
      final matches = _FakeMatchRepository();
      await _pump(
        tester,
        profile: _profile(hasLiked: true),
        matches: matches,
      );

      await tester.tap(find.byIcon(Icons.favorite));
      await tester.pumpAndSettle();

      expect(matches.likes, 0);
    });

    // A like made days ago should not pop and glow every time the profile is
    // reopened — the animation marks the moment it happens.
    testWidgets('does not replay the animation on a pre-liked profile',
        (tester) async {
      await _pump(tester, profile: _profile(hasLiked: true));

      final scale = tester.widget<Transform>(
        find
            .ancestor(
              of: find.byIcon(Icons.favorite),
              matching: find.byType(Transform),
            )
            .first,
      );
      // Resting, not mid-pop.
      expect(scale.transform.getMaxScaleOnAxis(), closeTo(1.0, 0.001));
    });
  });
}
