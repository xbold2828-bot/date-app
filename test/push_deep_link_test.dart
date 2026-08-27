import 'package:dating_app/core/notification/push_deep_link.dart';
import 'package:flutter_test/flutter_test.dart';

/// A push `data` map as the backend actually sends it. Every value is a string
/// — FCM rejects anything else — so the parser must never assume otherwise.
Map<String, dynamic> data({
  required String action,
  String? userId,
  String? conversationId,
  String? url,
}) =>
    {
      'fcm_type': 'normal',
      'target_app': 'cozune',
      'action': action,
      'channel_id': 'cozune_messages',
      'notification_id': 'n1',
      'sent_at': '2026-08-27T18:30:00.000Z',
      if (userId != null) 'userId': userId,
      if (conversationId != null) 'conversationId': conversationId,
      if (url != null) 'url': url,
    };

void main() {
  group('PushDeepLink.fromData', () {
    test('routes a chat message to the conversation', () {
      final link = PushDeepLink.fromData(
        data(
          action: 'open_conversation',
          userId: 'u1',
          conversationId: 'c1',
        ),
      );

      expect(link, isNotNull);
      expect(link!.destination, PushDestination.conversation);
      expect(link.userId, 'u1');
      expect(link.conversationId, 'c1');
    });

    test('routes a match with no conversation yet', () {
      // A match is made before anyone has said anything, so there is no
      // conversation id to carry. The thread is keyed on the person.
      final link = PushDeepLink.fromData(
        data(action: 'open_conversation', userId: 'u1'),
      );

      expect(link!.destination, PushDestination.conversation);
      expect(link.userId, 'u1');
      expect(link.conversationId, isNull);
    });

    test('routes the tab actions', () {
      expect(
        PushDeepLink.fromData(data(action: 'open_matches'))!.destination,
        PushDestination.matches,
      );
      expect(
        PushDeepLink.fromData(data(action: 'open_likes'))!.destination,
        PushDestination.likes,
      );
    });

    test('routes a profile', () {
      final link = PushDeepLink.fromData(
        data(action: 'open_profile', userId: 'u9'),
      );
      expect(link!.destination, PushDestination.profile);
      expect(link.userId, 'u9');
    });

    test('routes an announcement url', () {
      final link = PushDeepLink.fromData(
        data(action: 'open_url', url: 'https://cozune.app/whats-new'),
      );
      expect(link!.destination, PushDestination.url);
      expect(link.url, 'https://cozune.app/whats-new');
    });
  });

  group('PushDeepLink degrades instead of throwing', () {
    // This map is written by a server that ships independently of the build in
    // somebody's pocket. Anything unexpected has to mean "just open the app",
    // because an exception inside a tap handler is invisible — the tap simply
    // appears to do nothing.

    test('an action from a newer server', () {
      expect(PushDeepLink.fromData(data(action: 'open_the_pod_bay_doors')),
          isNull);
    });

    test('no action at all', () {
      expect(PushDeepLink.fromData(const {'fcm_type': 'normal'}), isNull);
    });

    test('an explicit none', () {
      expect(PushDeepLink.fromData(data(action: 'none')), isNull);
    });

    test('a conversation with no one to open it with', () {
      // conversationId alone is not enough: the chat screen is keyed on the
      // other person, so a payload missing userId cannot be acted on.
      expect(
        PushDeepLink.fromData(
          data(action: 'open_conversation', conversationId: 'c1'),
        ),
        isNull,
      );
    });

    test('empty strings count as missing', () {
      expect(
        PushDeepLink.fromData(data(action: 'open_profile', userId: '')),
        isNull,
      );
      expect(
        PushDeepLink.fromData(data(action: 'open_url', url: '')),
        isNull,
      );
    });
  });

  group('PushDeepLinks inbox', () {
    setUp(() => PushDeepLinks.pending.value = null);

    test('holds a tap that arrives before any screen exists', () {
      // The cold-start case, and the one that matters most: that person opened
      // the app *because* of the notification.
      PushDeepLinks.receive(data(action: 'open_likes'));

      expect(PushDeepLinks.pending.value, isNotNull);
      expect(PushDeepLinks.pending.value!.destination, PushDestination.likes);
    });

    test('consume reads once and clears', () {
      // What makes it safe to call from a widget that rebuilds: a second read
      // must not navigate again.
      PushDeepLinks.receive(data(action: 'open_matches'));

      expect(PushDeepLinks.consume()!.destination, PushDestination.matches);
      expect(PushDeepLinks.consume(), isNull);
      expect(PushDeepLinks.pending.value, isNull);
    });

    test('ignores a payload with nowhere to go', () {
      PushDeepLinks.receive(data(action: 'none'));
      expect(PushDeepLinks.pending.value, isNull);
    });

    test('the newest tap wins', () {
      // Two notifications tapped in quick succession: the second is the one the
      // user is waiting to see.
      PushDeepLinks.receive(data(action: 'open_likes'));
      PushDeepLinks.receive(data(action: 'open_matches'));

      expect(PushDeepLinks.consume()!.destination, PushDestination.matches);
    });
  });
}
