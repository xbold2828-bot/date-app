import 'package:dating_app/data/models/match_model.dart';
import 'package:dating_app/data/models/message_model.dart';
import 'package:dating_app/data/models/paginated.dart';
import 'package:flutter_test/flutter_test.dart';

/// Matches are the one surface with no paywall, so the model has to make the
/// difference between "liked you" and "mutual" impossible to blur.
void main() {
  group('MutualCard', () {
    test('parses a match that already has a conversation', () {
      final card = MutualCard.fromJson(const {
        'id': 'u1',
        'displayName': 'Ava',
        'age': 27,
        'primaryPhotoUrl': 'https://cdn/a.jpg',
        'isOnline': true,
        'matchedAt': '2026-08-01T10:00:00.000Z',
        'conversationId': 'c1',
      });

      expect(card.user.displayName, 'Ava');
      expect(card.user.age, 27);
      expect(card.user.isOnline, isTrue);
      expect(card.conversationId, 'c1');
      expect(card.matchedAt, isNotNull);
    });

    // A match nobody has written to yet still opens a thread — the screen just
    // starts it empty rather than sending people back to the profile.
    test('leaves conversationId null when nothing has been said', () {
      final card = MutualCard.fromJson(const {
        'id': 'u2',
        'displayName': 'Nia',
      });
      expect(card.conversationId, isNull);
      expect(card.user.id, 'u2');
    });

    // Nothing is ever redacted here. If a locked card reached this tab it would
    // mean the paywall had leaked into the one place it must not.
    test('a match is never locked', () {
      final page = PageResult<MutualCard>.fromJson(const {
        'total': 2,
        'page': 1,
        'limit': 20,
        'items': [
          {'id': 'u1', 'displayName': 'Ava'},
          {'id': 'u2', 'displayName': 'Nia'},
        ],
      }, MutualCard.fromJson);

      expect(page.items, hasLength(2));
      expect(page.items.every((m) => !m.user.locked), isTrue);
      expect(page.items.every((m) => m.user.displayName != null), isTrue);
    });
  });

  group('LikeResult', () {
    test('carries the matched person so the celebration needs no second fetch',
        () {
      final result = LikeResult.fromJson(const {
        'liked': true,
        'type': 'like',
        'isMatch': true,
        'match': {
          'id': 'u1',
          'displayName': 'Ava',
          'primaryPhotoUrl': 'https://cdn/a.jpg',
        },
      });

      expect(result.isMatch, isTrue);
      expect(result.match?.displayName, 'Ava');
      expect(result.match?.primaryPhotoUrl, 'https://cdn/a.jpg');
    });

    test('an ordinary like carries nothing to celebrate', () {
      final result = LikeResult.fromJson(const {
        'liked': true,
        'type': 'like',
        'isMatch': false,
      });
      expect(result.isMatch, isFalse);
      expect(result.match, isNull);
    });
  });

  group('ChatOtherUser status flags', () {
    ChatOtherUser parse(Map<String, dynamic> json) =>
        ChatOtherUser.fromJson(json);

    test('reads location, activity and deactivation', () {
      final user = parse({
        'id': 'u1',
        'displayName': 'Ava',
        'city': 'Hyderabad',
        'isOnline': true,
        'lastActiveAt':
            DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
      });

      expect(user.city, 'Hyderabad');
      expect(user.isDeactivated, isFalse);
      expect(user.activityLabel, 'Active now');
    });

    test('falls back to how long ago they were around', () {
      final user = parse({
        'id': 'u1',
        'isOnline': false,
        'lastActiveAt':
            DateTime.now().subtract(const Duration(hours: 3)).toIso8601String(),
      });
      expect(user.activityLabel, 'Active 3h ago');
    });

    // Telling somebody their match was "active 2h ago" when the account is gone
    // would be worse than saying nothing at all.
    test('a deactivated account reports no activity', () {
      final user = parse({
        'id': 'u1',
        'isDeactivated': true,
        'isOnline': true,
        'lastActiveAt': DateTime.now().toIso8601String(),
      });
      expect(user.isDeactivated, isTrue);
      expect(user.activityLabel, isNull);
    });

    test('says nothing when there is nothing to say', () {
      final user = parse({'id': 'u1', 'isOnline': false});
      expect(user.activityLabel, isNull);
      expect(user.city, isNull);
    });

    test('goes quiet rather than reporting a stale week-old visit', () {
      final user = parse({
        'id': 'u1',
        'isOnline': false,
        'lastActiveAt': DateTime.now()
            .subtract(const Duration(days: 30))
            .toIso8601String(),
      });
      expect(user.activityLabel, isNull);
    });
  });
}
