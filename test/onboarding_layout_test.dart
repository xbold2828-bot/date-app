import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dating_app/core/constants/tag_categories.dart';
import 'package:dating_app/core/theme/app_theme.dart';
import 'package:dating_app/data/models/tag_model.dart';
import 'package:dating_app/data/models/user_model.dart';
import 'package:dating_app/data/repositories/onboarding_repository.dart';
import 'package:dating_app/data/repositories/profile_repository.dart';
import 'package:dating_app/presentation/auth/screens/age_screen.dart';
import 'package:dating_app/presentation/auth/screens/basics_screen1.dart';
import 'package:dating_app/presentation/auth/screens/basics_screen2.dart';
import 'package:dating_app/presentation/auth/screens/basics_screen3.dart';
import 'package:dating_app/presentation/auth/screens/basics_screen4.dart';
import 'package:dating_app/presentation/auth/screens/basics_screen5.dart';
import 'package:dating_app/presentation/auth/screens/basics_screen7.dart';
import 'package:dating_app/presentation/auth/screens/status_screen.dart';
import 'package:dating_app/presentation/auth/widgets/onboarding_widgets.dart';
import 'package:dating_app/providers/core_providers.dart';

/// Every onboarding step, at the sizes that break layouts: the smallest phone
/// still in use, a common one, and both again with the text size turned up.
/// Overflow is thrown as an error during layout, so `takeException` is the
/// whole check.
MeUser _me() => MeUser.fromJson({
  'id': 'u1',
  'supabaseId': 'sb-1',
  'status': 'active',
  'age': 24,
  'verified': false,
  'premium': {'isActive': false},
  'profile': {
    'displayName': 'Maximiliana Montgomery-Fairweather',
    'gender': 'woman',
    'intent': ['dating'],
    'relationshipStatus': 'seeing_someone',
    'personalityTags': ['night_owl'],
  },
  'onboarding': {'isComplete': false, 'completedSteps': []},
});

class _FakeProfileRepository implements ProfileRepository {
  @override
  Future<MeUser> me(ref) async => _me();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not stubbed');
}

/// Long, real-world tag labels in every category the steps render.
class _FakeOnboardingRepository implements OnboardingRepository {
  @override
  Future<List<Tag>> tags({String? category}) async => [
    for (final c in [
      TagCategories.personality,
      ...TagCategories.preferences,
      TagCategories.hardNo,
    ])
      for (var i = 0; i < 7; i++)
        Tag(
          slug: '${c}_$i',
          label: i.isEven ? 'Spontaneous late-night adventures' : 'Quiet',
          category: c,
          sortOrder: i,
        ),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not stubbed');
}

void main() {
  final screens = <String, Widget Function()>{
    'name & birthday': () => const AgeScreen(),
    'basics': () => const BasicsScreen(displayName: 'Maya'),
    'out for': () => const BasicsScreen2(),
    'situation': () => const StatusScreen(),
    'your kind of night': () => const BasicsScreen3(),
    'photos': () => const BasicsScreen4(),
    'location': () => const BasicsScreen5(),
    'house rules': () => const BasicsScreen7(),
  };

  const sizes = [Size(320, 568), Size(375, 812)];
  const scales = [1.0, 1.3];

  Future<void> pump(
    WidgetTester tester,
    Widget screen, {
    required Size size,
    required double scale,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileRepositoryProvider.overrideWithValue(_FakeProfileRepository()),
          onboardingRepositoryProvider.overrideWithValue(
            _FakeOnboardingRepository(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: TextScaler.linear(scale),
            ),
            child: screen,
          ),
        ),
      ),
    );
    // Settle the async providers; the radar on the location step pulses
    // forever, so this cannot be pumpAndSettle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
  }

  for (final entry in screens.entries) {
    for (final size in sizes) {
      for (final scale in scales) {
        testWidgets(
          '${entry.key} fits ${size.width.toInt()}×${size.height.toInt()} '
          'at ${scale}x text',
          (tester) async {
            await pump(tester, entry.value(), size: size, scale: scale);
            expect(tester.takeException(), isNull);
            // The way forward is always on screen, whatever the content.
            expect(find.byType(OnboardingFooter), findsOneWidget);
          },
        );
      }
    }
  }

  group('behaviour', () {
    testWidgets('continue waits for a name and a real adult birthday', (
      tester,
    ) async {
      await pump(
        tester,
        const AgeScreen(),
        size: const Size(375, 812),
        scale: 1,
      );

      Finder action() => find.descendant(
        of: find.byType(OnboardingFooter),
        matching: find.byType(InkWell),
      );
      bool enabled() => tester.widget<InkWell>(action()).onTap != null;

      expect(enabled(), isFalse);
      expect(find.text('Add your first name to continue'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'Maya');
      await tester.pump();
      expect(find.text('Add your birthday to continue'), findsOneWidget);

      final boxes = find.byType(TextField);
      await tester.enterText(boxes.at(1), '30');
      await tester.enterText(boxes.at(2), '02');
      await tester.enterText(boxes.at(3), '2001');
      await tester.pump();
      // 30 February is not a day.
      expect(find.text("That date doesn't look right."), findsOneWidget);
      expect(enabled(), isFalse);

      await tester.enterText(boxes.at(1), '14');
      await tester.pump();
      expect(find.textContaining("You're "), findsOneWidget);
      expect(enabled(), isTrue);

      final thisYear = DateTime.now().year;
      await tester.enterText(boxes.at(3), '${thisYear - 10}');
      await tester.pump();
      expect(find.text('cozune is for people 18 and over.'), findsOneWidget);
      expect(enabled(), isFalse);
    });

    test('age counts birthdays, not days divided by 365', () {
      final dob = DateTime(2001, 10, 4);
      expect(DobInput.ageOn(dob, DateTime(2026, 10, 3)), 24);
      expect(DobInput.ageOn(dob, DateTime(2026, 10, 4)), 25);
      expect(DobInput.parse('29', '02', '2001'), isNull);
      expect(DobInput.parse('29', '02', '2004'), DateTime(2004, 2, 29));
    });

    testWidgets('the house rules unlock only when all four are agreed', (
      tester,
    ) async {
      await pump(
        tester,
        const BasicsScreen7(),
        size: const Size(375, 812),
        scale: 1,
      );

      expect(find.textContaining('0 of 4'), findsOneWidget);
      for (final rule in [
        "I'm 18 or older",
        "I'll be respectful",
        'No harassment',
        'Consent always matters',
      ]) {
        await tester.tap(find.text(rule));
        await tester.pump();
      }
      expect(find.textContaining('of 4'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a chosen situation fills, and only one at a time', (
      tester,
    ) async {
      await pump(
        tester,
        const StatusScreen(),
        size: const Size(375, 812),
        scale: 1,
      );

      // Restored from the saved answer.
      bool selected(String label) => tester
          .widget<ChoiceRow>(find.widgetWithText(ChoiceRow, label))
          .selected;
      expect(selected('Seeing someone'), isTrue);

      await tester.tap(find.text('Single'));
      await tester.pump();
      expect(selected('Single'), isTrue);
      expect(selected('Seeing someone'), isFalse);
    });
  });
}
