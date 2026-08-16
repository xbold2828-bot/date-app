import 'package:flutter_test/flutter_test.dart';

import 'package:dating_app/data/models/discovery_user_model.dart';
import 'package:dating_app/data/models/entitlements_model.dart';
import 'package:dating_app/data/models/match_model.dart';
import 'package:dating_app/data/models/message_model.dart';
import 'package:dating_app/data/models/paginated.dart';
import 'package:dating_app/data/models/tag_model.dart';
import 'package:dating_app/data/models/user_model.dart';

/// These test the model layer against the exact JSON shapes the NestJS backend
/// returns (the `data` payload, after the envelope is unwrapped).
void main() {
  group('MeUser.fromJson', () {
    test('parses the full self-view', () {
      final me = MeUser.fromJson(const {
        'id': 'u1',
        'supabaseId': 'sb1',
        'phone': '+1555',
        'status': 'active',
        'age': 28,
        'verified': true,
        'verificationStatus': 'verified',
        'premium': {'isActive': true, 'plan': 'monthly'},
        'profile': {
          'displayName': 'Elena',
          'bio': 'hi',
          'gender': 'woman',
          'pronouns': ['she/her'],
          'showMe': ['men'],
          'intent': ['dating'],
          'personalityTags': ['night_owl'],
        },
        'location': {'city': 'NYC', 'preferredBand': '2-5 km'},
        'onboarding': {
          'completedSteps': ['age', 'basics'],
          'isComplete': false,
          'nextStep': 'intent',
          'progress': 0.2,
        },
      });

      expect(me.id, 'u1');
      expect(me.age, 28);
      expect(me.verified, isTrue);
      expect(me.premium.isActive, isTrue);
      expect(me.displayName, 'Elena');
      expect(me.profile.pronouns, ['she/her']);
      expect(me.location?.city, 'NYC');
      expect(me.onboarding.isComplete, isFalse);
      expect(me.onboarding.nextStep, 'intent');
    });

    test('tolerates missing optional blocks', () {
      final me = MeUser.fromJson(const {
        'id': 'u1',
        'supabaseId': 'sb1',
        'status': 'active',
        'age': null,
        'premium': {},
        'profile': {},
        'onboarding': {},
      });
      expect(me.age, isNull);
      expect(me.premium.isActive, isFalse);
      expect(me.profile.showMe, isEmpty);
      expect(me.location, isNull);
      expect(me.onboarding.progress, 0);
    });
  });

  test('DiscoveryCard exposes a distance band, never coordinates', () {
    final card = DiscoveryCard.fromJson(const {
      'id': 'u2',
      'displayName': 'Maya',
      'age': 26,
      'distanceBand': '<2 km',
      'isOnline': true,
      'isVerified': false,
      'personalityTags': ['foodie'],
    });
    expect(card.distanceBand, '<2 km');
    expect(card.isOnline, isTrue);
    expect(card.personalityTags, ['foodie']);
  });

  group('NearbyPage', () {
    test('takes the server at its word about another page', () {
      final page = NearbyPage.fromJson(const {
        'page': 1,
        'limit': 30,
        'total': 75,
        'hasMore': true,
        'source': 'free',
        'items': <Map<String, dynamic>>[],
      });
      expect(page.limit, 30);
      expect(page.total, 75);
      expect(page.hasMore, isTrue);
    });

    // A full last page used to offer "Show more people" and then deliver
    // nothing, because the only signal was `items.length >= limit`.
    test('a full page that is the last page says so', () {
      final page = NearbyPage.fromJson({
        'page': 1,
        'limit': 2,
        'total': 2,
        'hasMore': false,
        'source': 'premium',
        'items': [
          {'id': 'a'},
          {'id': 'b'},
        ],
      });
      expect(page.items, hasLength(2));
      expect(page.hasMore, isFalse);
    });

    // The app has to keep paging against a server deployed before `hasMore`.
    test('falls back to the old inference when the field is absent', () {
      final page = NearbyPage.fromJson({
        'page': 1,
        'limit': 2,
        'source': 'free',
        'items': [
          {'id': 'a'},
          {'id': 'b'},
        ],
      });
      expect(page.hasMore, isTrue);
      expect(page.total, 2);
    });
  });

  test('LikeResult reports matches', () {
    final r = LikeResult.fromJson(const {
      'liked': true,
      'type': 'like',
      'isMatch': true,
    });
    expect(r.liked, isTrue);
    expect(r.isMatch, isTrue);
  });

  test('LikedYouPage free preview: two people in full, the rest redacted', () {
    final page = LikedYouPage.fromJson(const {
      'total': 12,
      'locked': true,
      'source': null,
      'page': 1,
      'limit': 20,
      'freeVisible': 2,
      'lockedCount': 10,
      'items': [
        {'id': 'a', 'displayName': 'Ava', 'age': 27, 'primaryPhotoUrl': 'u'},
        {'id': 'b', 'displayName': 'Nia', 'age': 24, 'primaryPhotoUrl': 'u'},
        {'id': '', 'isOnline': true, 'locked': true},
      ],
    });

    expect(page.total, 12);
    expect(page.freeVisible, 2);
    expect(page.lockedCount, 10);
    expect(page.isEmpty, isFalse);

    expect(page.items.take(2).every((c) => !c.locked), isTrue);
    expect(page.items.first.displayName, 'Ava');

    // A redacted card must arrive with nothing on it — including no id, which
    // is what stops the tile being tapped through to the full profile.
    final hidden = page.items.last;
    expect(hidden.locked, isTrue);
    expect(hidden.id, isEmpty);
    expect(hidden.displayName, isNull);
    expect(hidden.primaryPhotoUrl, isNull);
    expect(hidden.age, isNull);
    // Presence survives: it is the reason to unlock and identifies nobody.
    expect(hidden.isOnline, isTrue);
  });

  test('LikedYouPage unlocked: everyone intact, nothing left to unlock', () {
    final page = LikedYouPage.fromJson(const {
      'total': 2,
      'locked': false,
      'source': 'premium',
      'page': 1,
      'limit': 20,
      'freeVisible': 0,
      'lockedCount': 0,
      'items': [
        {'id': 'a', 'displayName': 'Ava'},
        {'id': 'b', 'displayName': 'Nia'},
      ],
    });
    expect(page.locked, isFalse);
    expect(page.source, 'premium');
    expect(page.lockedCount, 0);
    expect(page.items.any((c) => c.locked), isFalse);
  });

  test('LikedYouPage tells "nobody yet" apart from "nobody unlocked"', () {
    final empty = LikedYouPage.fromJson(const {
      'total': 0,
      'locked': false,
      'page': 1,
      'limit': 20,
      'items': [],
    });
    expect(empty.isEmpty, isTrue);

    // Locked people are not an empty state — showing "No likes yet" here would
    // be a lie that costs a sale.
    final gated = LikedYouPage.fromJson(const {
      'total': 5,
      'locked': true,
      'page': 1,
      'limit': 20,
      'lockedCount': 3,
      'items': [
        {'id': 'a', 'displayName': 'Ava'},
        {'id': '', 'locked': true},
      ],
    });
    expect(gated.isEmpty, isFalse);
  });

  test('Message + ConversationSummary parse', () {
    final msg = Message.fromJson(const {
      'id': 'm1',
      'body': 'hey',
      'type': 'text',
      'senderId': 'u1',
      'fromMe': true,
      'read': false,
    });
    expect(msg.fromMe, isTrue);
    expect(msg.read, isFalse);
    expect(msg.copyWith(read: true).read, isTrue);

    final conv = ConversationSummary.fromJson(const {
      'id': 'c1',
      'state': 'vibing',
      'otherUser': {'id': 'u2', 'displayName': 'Julian', 'age': 29},
      'lastMessage': {'snippet': 'hi', 'senderId': 'u2', 'fromMe': false},
      'unread': 2,
    });
    expect(conv.state, 'vibing');
    expect(conv.otherUser.displayName, 'Julian');
    expect(conv.unread, 2);
    expect(conv.lastMessage?.snippet, 'hi');
    expect(conv.muted, isFalse);
  });

  group('edited and deleted messages', () {
    test('an edit is carried through, because it is always shown', () {
      final msg = Message.fromJson(const {
        'id': 'm1',
        'body': 'the new text',
        'type': 'text',
        'senderId': 'u1',
        'fromMe': true,
        'edited': true,
      });
      expect(msg.edited, isTrue);
      expect(msg.deleted, isFalse);
      // Marking it read must not quietly drop the flag — that would erase the
      // "edited" label the moment the other side opened the thread.
      expect(msg.copyWith(read: true).edited, isTrue);
    });

    test('a deleted message arrives as the tombstone, not the original', () {
      final msg = Message.fromJson(const {
        'id': 'm1',
        'body': 'This message was deleted',
        'type': 'text',
        'senderId': 'u1',
        'fromMe': true,
        'deleted': true,
      });
      expect(msg.deleted, isTrue);
      expect(msg.copyWith(read: true).deleted, isTrue);
    });

    // The fields are absent on a backend deployed before this shipped, and an
    // older message that predates them has no flags at all.
    test('a message with neither flag is neither', () {
      final msg = Message.fromJson(const {
        'id': 'm1',
        'body': 'hey',
        'type': 'text',
        'senderId': 'u1',
        'fromMe': false,
      });
      expect(msg.edited, isFalse);
      expect(msg.deleted, isFalse);
    });

    test('a muted conversation says so', () {
      final conv = ConversationSummary.fromJson(const {
        'id': 'c1',
        'state': 'vibing',
        'otherUser': {'id': 'u2'},
        'unread': 4,
        'muted': true,
      });
      // Muting does not zero the row's own count — it only leaves the badge.
      expect(conv.muted, isTrue);
      expect(conv.unread, 4);
      expect(conv.copyWith(unread: 0).muted, isTrue);
    });
  });

  test('MessagesPage derives hasMore from total', () {
    final page = MessagesPage.fromJson(const {
      'conversation': {'id': 'c1', 'state': 'vibing'},
      'page': 1,
      'limit': 30,
      'total': 45,
      'items': [
        {'id': 'm1', 'body': 'a', 'type': 'text', 'senderId': 'u1', 'fromMe': false},
      ],
    });
    expect(page.hasMore, isTrue);
    expect(page.items.single.body, 'a');
  });

  test('Entitlements parse allowances map', () {
    final e = Entitlements.fromJson(const {
      'isPremium': false,
      'creditBalance': 5,
      'allowances': {
        'nearby': {'limit': 10, 'used': 3, 'remaining': 7},
      },
    });
    expect(e.isPremium, isFalse);
    expect(e.creditBalance, 5);
    expect(e.nearby?.remaining, 7);
  });

  test('Tag.listFrom parses a catalogue array', () {
    final tags = Tag.listFrom(const [
      {'slug': 'night_owl', 'label': 'Night owl', 'category': 'personality'},
      {'slug': 'foodie', 'label': 'Foodie', 'category': 'personality'},
    ]);
    expect(tags, hasLength(2));
    expect(tags.first.slug, 'night_owl');
  });

  test('PageResult.fromJson + merge', () {
    final p1 = PageResult<LikeCard>.fromJson(const {
      'total': 3,
      'page': 1,
      'limit': 2,
      'items': [
        {'id': 'a'},
        {'id': 'b'},
      ],
    }, LikeCard.fromJson);
    expect(p1.items, hasLength(2));
    expect(p1.hasMore, isTrue);

    final p2 = PageResult<LikeCard>.fromJson(const {
      'total': 3,
      'page': 2,
      'limit': 2,
      'items': [
        {'id': 'c'},
      ],
    }, LikeCard.fromJson);
    final merged = p1.merge(p2);
    expect(merged.items.map((c) => c.id), ['a', 'b', 'c']);
    expect(merged.hasMore, isFalse);
  });
}
