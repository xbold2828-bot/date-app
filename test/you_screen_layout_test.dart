import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dating_app/data/models/media_model.dart';
import 'package:dating_app/data/models/user_model.dart';
import 'package:dating_app/data/repositories/media_repository.dart';
import 'package:dating_app/data/repositories/profile_repository.dart';
import 'package:dating_app/presentation/home/screens/you_screen.dart';
import 'package:dating_app/providers/core_providers.dart';

MeUser _me({bool premium = false, bool verified = false}) => MeUser.fromJson({
      'id': 'u1',
      'supabaseId': 'sb-1',
      'status': 'active',
      'primaryPhotoId': 'm1',
      'age': 25,
      'verified': verified,
      'premium': {'isActive': premium, 'plan': 'monthly'},
      'profile': {
        'displayName': 'Salaar',
        'bio': 'Here for good conversation and better coffee.',
        'personalityTags': ['gym', 'foodie', 'night_owl'],
      },
      'location': {'city': 'Tirupathi'},
      'onboarding': {'isComplete': true, 'completedSteps': []},
    });

class _FakeProfileRepository implements ProfileRepository {
  _FakeProfileRepository(this._user);
  final MeUser _user;

  @override
  Future<MeUser> me() async => _user;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not stubbed');
}

class _FakeMediaRepository implements MediaRepository {
  _FakeMediaRepository(this.count);
  final int count;

  @override
  Future<List<MediaAsset>> listMine() async => List.generate(
        count,
        (i) => MediaAsset.fromJson({
          'id': 'm${i + 1}',
          'type': MediaKind.publicPhoto,
          'visibility': 'public',
          'status': i.isEven ? 'approved' : 'pending',
          // Deliberately unreachable: the widget must fall back to its
          // errorBuilder rather than throwing or overflowing.
          'url': 'https://invalid.test/photo$i.jpg',
          'contentType': 'image/jpeg',
        }),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not stubbed');
}

/// Layout guarantees for the profile tab. Flutter reports overflow as a thrown
/// error during layout, so `tester.takeException()` catches the "RenderFlex
/// overflowed by N pixels" family without needing to read the console.
void main() {
  Future<void> pumpYou(
    WidgetTester tester, {
    required Size screen,
    int photos = 3,
    bool premium = false,
  }) async {
    tester.view.physicalSize = screen;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileRepositoryProvider
              .overrideWithValue(_FakeProfileRepository(_me(premium: premium))),
          mediaRepositoryProvider
              .overrideWithValue(_FakeMediaRepository(photos)),
        ],
        child: const MaterialApp(home: Scaffold(body: YouScreen())),
      ),
    );
    // Settle the two async providers; images stay unresolved by design.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('renders without overflowing at 375 px', (tester) async {
    await pumpYou(tester, screen: const Size(375, 3000));
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders without overflowing at 320 px', (tester) async {
    await pumpYou(tester, screen: const Size(320, 3000));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a full gallery still fits', (tester) async {
    await pumpYou(tester, screen: const Size(320, 3000), photos: 5);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the premium badge does not overflow', (tester) async {
    await pumpYou(tester, screen: const Size(320, 3000), premium: true);
    expect(tester.takeException(), isNull);
  });
}
