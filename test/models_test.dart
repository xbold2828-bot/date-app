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

  test('LikeResult reports matches', () {
    final r = LikeResult.fromJson(const {
      'liked': true,
      'type': 'like',
      'isMatch': true,
    });
    expect(r.liked, isTrue);
    expect(r.isMatch, isTrue);
  });

  test('LikedYouPage locked state carries a total but no identities', () {
    final page = LikedYouPage.fromJson(const {
      'total': 12,
      'locked': true,
      'source': null,
      'page': 1,
      'limit': 20,
      'items': [],
    });
    expect(page.locked, isTrue);
    expect(page.total, 12);
    expect(page.items, isEmpty);
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
