import 'package:dating_app/core/errors/app_exceptions.dart';
import 'package:dating_app/data/models/user_model.dart';
import 'package:dating_app/data/models/map_user_model.dart';
import 'package:dating_app/data/repositories/chat_repository.dart';
import 'package:dating_app/data/repositories/onboarding_repository.dart';
import 'package:dating_app/data/repositories/profile_repository.dart';
import 'package:dating_app/data/services/location_service.dart';
import 'package:dating_app/providers/core_providers.dart';
import 'package:dating_app/providers/explore_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

/// The anchor is the point the server measures everybody's distance from, and
/// the point the map draws "you are here" at. These are the same number by
/// construction, and this file is what keeps them that way.
///
/// The bug being pinned down: `PATCH /location` was called from exactly one
/// place — onboarding step 5 — so the anchor froze at signup while the map's
/// marker tracked the live device. Move, and the map drew you on one street
/// while presenting people selected and distance-banded from another.

Position _fix(double latitude, double longitude) => Position(
      latitude: latitude,
      longitude: longitude,
      timestamp: DateTime.now(),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

Map<String, dynamic> _meJson({
  double? latitude,
  double? longitude,
  String? preferredBand = '2-5 km',
  DateTime? updatedAt,
}) =>
    {
      'id': 'me',
      'supabaseId': 'sb',
      'status': 'active',
      'age': 28,
      'ageVerified': true,
      'hasVerifiedSelfie': false,
      'verified': true,
      'verificationStatus': 'verified',
      'premium': {'isActive': false},
      'profile': const <String, dynamic>{},
      'location': {
        'city': 'Tirupati',
        'preferredBand': ?preferredBand,
        'updatedAt': (updatedAt ?? DateTime.now()).toIso8601String(),
        'latitude': ?latitude,
        'longitude': ?longitude,
      },
      'onboarding': {
        'completedSteps': <String>[],
        'isComplete': true,
        'nextStep': null,
        'progress': 1.0,
        'photoSkipped': false,
      },
    };

class _FakeLocationService implements LocationService {
  _FakeLocationService(this._position);

  Position? _position;
  Object? failure;
  int reads = 0;

  set position(Position value) => _position = value;

  @override
  Future<Position> current({
    LocationAccuracy accuracy = LocationAccuracy.high,
    Duration timeLimit = const Duration(seconds: 20),
  }) async {
    reads++;
    final error = failure;
    if (error != null) throw error;
    return _position!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not stubbed');
}

class _FakeOnboardingRepository implements OnboardingRepository {
  _FakeOnboardingRepository(this._response);

  Map<String, dynamic> _response;
  final List<Map<String, dynamic>> writes = [];
  Object? failure;

  set response(Map<String, dynamic> value) => _response = value;

  @override
  Future<MeUser> updateLocation({
    required double latitude,
    required double longitude,
    String? preferredBand,
    String? city,
  }) async {
    writes.add({
      'latitude': latitude,
      'longitude': longitude,
      'preferredBand': preferredBand,
    });
    final error = failure;
    if (error != null) throw error;
    return MeUser.fromJson(_response);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not stubbed');
}

class _FakeProfileRepository implements ProfileRepository {
  _FakeProfileRepository(this.json);

  Map<String, dynamic> json;

  @override
  Future<MeUser> me() async => MeUser.fromJson(json);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not stubbed');
}

/// Explore is never asserted on here — the anchor resolves first — but the
/// notifier refreshes it after a write, so it must not reach the network.
class _FakeChatRepository implements ChatRepository {
  int loads = 0;

  @override
  Future<List<MapUser>> mapPeople() async {
    loads++;
    return const [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not stubbed');
}
void main() {
  late _FakeLocationService location;
  late _FakeOnboardingRepository onboarding;
  late _FakeProfileRepository profile;
  late _FakeChatRepository chat;

  ProviderContainer containerWith(Map<String, dynamic> me) {
    profile = _FakeProfileRepository(me);
    final container = ProviderContainer(
      overrides: [
        locationServiceProvider.overrideWithValue(location),
        onboardingRepositoryProvider.overrideWithValue(onboarding),
        profileRepositoryProvider.overrideWithValue(profile),
        chatRepositoryProvider.overrideWithValue(chat),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(() {
    location = _FakeLocationService(_fix(13.6288, 79.4192));
    onboarding = _FakeOnboardingRepository(
      _meJson(latitude: 13.6288, longitude: 79.4192),
    );
    chat = _FakeChatRepository();
  });

  test('re-anchors when the device has moved away from the stored point',
      () async {
    // Stored in one town, standing in another — the case that made the map
    // draw the user in the wrong place relative to everyone on it.
    final container = containerWith(
      _meJson(latitude: 17.3850, longitude: 78.4867),
    );
    location.position = _fix(13.6288, 79.4192);
    onboarding.response = _meJson(latitude: 13.6288, longitude: 79.4192);

    final anchor = await container.read(myLocationProvider.future);

    expect(onboarding.writes, hasLength(1));
    expect(onboarding.writes.single['latitude'], 13.6288);
    expect(onboarding.writes.single['longitude'], 79.4192);
    // And the marker is drawn at the freshly written anchor, not the old one.
    expect(anchor!.latitude, closeTo(13.6288, 1e-6));
    expect(anchor.longitude, closeTo(79.4192, 1e-6));
  });

  test('carries the saved radius through the write', () async {
    // The server no longer clears an omitted band, but sending it back means a
    // client outliving a rollback cannot silently widen somebody's discovery.
    final container = containerWith(
      _meJson(
        latitude: 17.3850,
        longitude: 78.4867,
        preferredBand: '5-10 km',
      ),
    );
    await container.read(myLocationProvider.future);

    expect(onboarding.writes.single['preferredBand'], '5-10 km');
  });

  test('does not write for GPS jitter', () async {
    // Consumer GPS wanders tens of metres while sitting still. Rewriting on
    // that would invalidate the discovery cache on every open for nothing.
    final container = containerWith(
      _meJson(latitude: 13.6288, longitude: 79.4192),
    );
    location.position = _fix(13.62885, 79.41925); // ~7 m

    final anchor = await container.read(myLocationProvider.future);

    expect(onboarding.writes, isEmpty);
    expect(anchor!.latitude, closeTo(13.6288, 1e-6));
  });

  test('re-anchors anyway once the stored point is stale', () async {
    // Closed the app in one city, opened it in another: the fix may land close
    // to the stored point by chance, but a day-old anchor is not evidence of
    // anything.
    final container = containerWith(
      _meJson(
        latitude: 13.6288,
        longitude: 79.4192,
        updatedAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
    );
    location.position = _fix(13.6288, 79.4192);

    await container.read(myLocationProvider.future);

    expect(onboarding.writes, hasLength(1));
  });

  test('anchors an account that has never had a point', () async {
    final container = containerWith(_meJson());
    location.position = _fix(13.6288, 79.4192);

    final anchor = await container.read(myLocationProvider.future);

    expect(onboarding.writes, hasLength(1));
    expect(anchor, isNotNull);
  });

  test('falls back to the stored anchor when location is refused', () async {
    // Refusing permission should not blank the map for somebody who finished
    // onboarding: the anchor is what their results were computed from anyway.
    final container = containerWith(
      _meJson(latitude: 13.6288, longitude: 79.4192),
    );
    location.failure = const LocationUnavailableException(
      LocationFailure.deniedForever,
      'nope',
    );

    final anchor = await container.read(myLocationProvider.future);

    expect(anchor!.latitude, closeTo(13.6288, 1e-6));
    expect(onboarding.writes, isEmpty);
  });

  test('surfaces the refusal when there is no anchor to fall back on',
      () async {
    final container = containerWith(_meJson());
    location.failure = const LocationUnavailableException(
      LocationFailure.denied,
      'nope',
    );

    await expectLater(
      container.read(myLocationProvider.future),
      throwsA(isA<LocationUnavailableException>()),
    );
  });

  test('keeps drawing the old anchor when the write fails', () async {
    // Offline. Better a slightly stale marker than no map.
    final container = containerWith(
      _meJson(latitude: 17.3850, longitude: 78.4867),
    );
    location.position = _fix(13.6288, 79.4192);
    onboarding.failure = const NetworkException();

    final anchor = await container.read(myLocationProvider.future);

    expect(anchor!.latitude, closeTo(17.3850, 1e-6));
  });

  test('MeLocation reports whether there is a point at all', () {
    expect(
      MeUser.fromJson(_meJson(latitude: 13.6, longitude: 79.4))
          .location!
          .hasPoint,
      isTrue,
    );
    expect(MeUser.fromJson(_meJson()).location!.hasPoint, isFalse);
  });
}
