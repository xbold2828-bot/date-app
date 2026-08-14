import 'package:dating_app/data/models/map_user_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// The map's parsing rules exist to protect one thing: a marker must never be
/// drawn somewhere that is not where the backend said. A missing or malformed
/// position has to drop the person, not default them to (0, 0) — which is in
/// the Atlantic, and which on a dating map reads as "there is someone there".
void main() {
  Map<String, dynamic> payload({
    Object? mapPosition = const {'latitude': 12.97, 'longitude': 77.59},
    String id = 'u1',
  }) =>
      {
        'id': id,
        'displayName': 'Ananya',
        'age': 24,
        'distanceBand': '2-5 km',
        'isOnline': true,
        'isVerified': true,
        'personalityTags': ['night_owl'],
        'primaryPhotoUrl': 'https://cdn.example/a.jpg',
        'mapPosition': ?mapPosition,
      };

  group('MapUser.fromJson', () {
    test('reads the generalized position and reuses the discovery card', () {
      final user = MapUser.fromJson(payload())!;

      expect(user.id, 'u1');
      expect(user.latitude, 12.97);
      expect(user.longitude, 77.59);
      // The card is the existing model, not a re-declared copy of its fields.
      expect(user.displayName, 'Ananya');
      expect(user.age, 24);
      expect(user.distanceBand, '2-5 km');
      expect(user.isOnline, isTrue);
      expect(user.isVerified, isTrue);
      expect(user.personalityTags, ['night_owl']);
    });

    test('drops a person with no position at all', () {
      expect(MapUser.fromJson(payload(mapPosition: null)), isNull);
    });

    test('drops a position missing a coordinate', () {
      expect(
        MapUser.fromJson(payload(mapPosition: {'latitude': 12.97})),
        isNull,
      );
    });

    test('drops a position that is not a map', () {
      expect(MapUser.fromJson(payload(mapPosition: [12.97, 77.59])), isNull);
    });

    test('drops coordinates outside the world', () {
      expect(
        MapUser.fromJson(
          payload(mapPosition: {'latitude': 91.0, 'longitude': 10.0}),
        ),
        isNull,
      );
      expect(
        MapUser.fromJson(
          payload(mapPosition: {'latitude': 10.0, 'longitude': -181.0}),
        ),
        isNull,
      );
    });

    test('drops a person with no id, who could never be opened', () {
      expect(MapUser.fromJson(payload(id: '')), isNull);
    });

    test('accepts integer coordinates', () {
      final user = MapUser.fromJson(
        payload(mapPosition: {'latitude': 13, 'longitude': 77}),
      )!;
      expect(user.latitude, 13.0);
      expect(user.longitude, 77.0);
    });
  });

  group('presence overlay', () {
    test('changes only the online flag, never the rest of the card', () {
      final user = MapUser.fromJson(payload())!;
      final offline = user.card.withOnline(false);

      expect(offline.isOnline, isFalse);
      expect(offline.id, user.id);
      expect(offline.displayName, user.displayName);
      expect(offline.age, user.age);
      expect(offline.distanceBand, user.distanceBand);
      expect(offline.isVerified, user.isVerified);
      expect(offline.primaryPhotoUrl, user.primaryPhotoUrl);
      expect(offline.personalityTags, user.personalityTags);
    });
  });
}
