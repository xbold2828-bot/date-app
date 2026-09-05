import 'package:dating_app/core/errors/app_exceptions.dart';
import 'package:dating_app/data/models/user_model.dart';
import 'package:dating_app/data/models/map_user_model.dart';
import 'package:dating_app/data/repositories/chat_repository.dart';
import 'package:dating_app/data/models/discovery_user_model.dart';
import 'package:dating_app/data/repositories/discovery_repository.dart';
import 'package:dating_app/data/repositories/onboarding_repository.dart';
import 'package:dating_app/data/repositories/profile_repository.dart';
import 'package:dating_app/data/services/location_service.dart';
import 'package:dating_app/providers/core_providers.dart';
import 'package:dating_app/providers/location_provider.dart';
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
    String? city,
  }) async {
    writes.add({
      'latitude': latitude,
      'longitude': longitude,
      'city': city,
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
  Future<MeUser> me(ref) async => MeUser.fromJson(json);

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

  test('the anchor write carries coordinates and nothing else', () async {
    // Re-anchoring used to resend the saved `preferredBand` so the radius the
    // user picked survived the write. Nobody picks a radius any more — the
    // screen that asked is gone — so the write is coordinates alone, and a
    // band left on an old account is not resurrected by moving.
    final container = containerWith(
      _meJson(
        latitude: 17.3850,
        longitude: 78.4867,
        preferredBand: '5-10 km',
      ),
    );
    await container.read(myLocationProvider.future);

    expect(onboarding.writes.single.keys, unorderedEquals(
      <String>['latitude', 'longitude', 'city'],
    ));
    expect(onboarding.writes.single['city'], isNull);
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

  _separationTests();

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

/// Radar and Explore are separate feeds and must stay that way.
///
/// `GET /discovery/nearby` spends a reveal from a ten-per-day free allowance.
/// The location sync used to refresh it on every re-anchor, which drained the
/// allowance in a handful of Explore visits — after which the endpoint answered
/// 402 and the Radar grid rendered the paywall with no profiles on it at all.
/// A background location sync has no business spending somebody's daily quota.
class _CountingDiscoveryRepository implements DiscoveryRepository {
  int nearbyCalls = 0;

  @override
  Future<NearbyPage> nearby({
    int page = 1,
    int limit = 20,
    String? intent,
    List<String>? genders,
    int? minAge,
    int? maxAge,
    bool? verifiedOnly,
    bool? onlineOnly,
    bool? recentlyActive,
    List<String>? relationshipStatus,
    List<String>? personalityTags,
    List<String>? preferenceTags,
  }) async {
    nearbyCalls++;
    return const NearbyPage(
      page: 1,
      limit: 30,
      total: 0,
      hasMore: false,
      source: 'free',
      items: <DiscoveryCard>[],
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not stubbed');
}

void _separationTests() {
  test('re-anchoring never spends a Radar reveal', () async {
    final location = _FakeLocationService(_fix(13.6288, 79.4192));
    final onboarding = _FakeOnboardingRepository(
      _meJson(latitude: 13.6288, longitude: 79.4192),
    );
    final discovery = _CountingDiscoveryRepository();
    final container = ProviderContainer(
      overrides: [
        locationServiceProvider.overrideWithValue(location),
        onboardingRepositoryProvider.overrideWithValue(onboarding),
        profileRepositoryProvider.overrideWithValue(
          _FakeProfileRepository(_meJson(latitude: 17.3850, longitude: 78.4867)),
        ),
        discoveryRepositoryProvider.overrideWithValue(discovery),
        chatRepositoryProvider.overrideWithValue(_FakeChatRepository()),
      ],
    );
    addTearDown(container.dispose);

    // A genuine move, so the anchor is rewritten.
    await container.read(myLocationProvider.future);
    await Future<void>.delayed(Duration.zero);

    expect(onboarding.writes, hasLength(1), reason: 'should have re-anchored');
    expect(
      discovery.nearbyCalls,
      0,
      reason: 'Radar must not be refetched by a location sync',
    );
  });

  test('a coarse browser fix does not relocate an existing anchor', () async {
    // A laptop with no GPS answers from the IP address and reports accuracy in
    // the thousands of metres. Moving a real anchor there silently relocates
    // the account, and Radar then searches a city the user has never been to —
    // which is how several accounts on one machine stopped seeing each other.
    final coarse = Position(
      latitude: 19.0760,
      longitude: 72.8777,
      timestamp: DateTime.now(),
      accuracy: 4000,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
    final location = _FakeLocationService(coarse);
    final onboarding = _FakeOnboardingRepository(_meJson());
    final container = ProviderContainer(
      overrides: [
        locationServiceProvider.overrideWithValue(location),
        onboardingRepositoryProvider.overrideWithValue(onboarding),
        profileRepositoryProvider.overrideWithValue(
          _FakeProfileRepository(_meJson(latitude: 13.6288, longitude: 79.4192)),
        ),
        chatRepositoryProvider.overrideWithValue(_FakeChatRepository()),
      ],
    );
    addTearDown(container.dispose);

    final anchor = await container.read(myLocationProvider.future);

    expect(onboarding.writes, isEmpty);
    expect(anchor!.latitude, closeTo(13.6288, 1e-6));
  });

  test('but a coarse fix is better than no anchor at all', () async {
    final coarse = Position(
      latitude: 19.0760,
      longitude: 72.8777,
      timestamp: DateTime.now(),
      accuracy: 4000,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
    final location = _FakeLocationService(coarse);
    final onboarding = _FakeOnboardingRepository(
      _meJson(latitude: 19.0760, longitude: 72.8777),
    );
    final container = ProviderContainer(
      overrides: [
        locationServiceProvider.overrideWithValue(location),
        onboardingRepositoryProvider.overrideWithValue(onboarding),
        // An account that never finished the location step.
        profileRepositoryProvider
            .overrideWithValue(_FakeProfileRepository(_meJson())),
        chatRepositoryProvider.overrideWithValue(_FakeChatRepository()),
      ],
    );
    addTearDown(container.dispose);

    await container.read(myLocationProvider.future);

    expect(onboarding.writes, hasLength(1));
  });
}
