import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dating_app/core/errors/app_exceptions.dart';
import 'package:dating_app/data/models/message_model.dart';
import 'package:dating_app/data/repositories/chat_repository.dart';
import 'package:dating_app/data/services/chat_service.dart';
import 'package:dating_app/presentation/home/screens/chat_detail_screen.dart';
import 'package:dating_app/providers/core_providers.dart';
import 'package:dating_app/providers/realtime_provider.dart';

/// A thread whose sends are refused the way the server refuses them.
///
/// These are the three silent failures that were reported: a message that
/// moderation stopped, the fourth unanswered New Energy message, and a fourth
/// new conversation in a day. Each one used to leave the composer empty with
/// nothing on screen; each must now say what happened.
class _RefusingChatRepository implements ChatRepository {
  _RefusingChatRepository({this.onSend, this.onOpen});

  final AppException? onSend;
  final AppException? onOpen;

  @override
  Future<MessagesPage> messages(
    String conversationId, {
    int page = 1,
    int limit = 30,
  }) async => MessagesPage.fromJson({
    'conversation': {'id': conversationId, 'state': 'new_energy'},
    'page': 1,
    'limit': limit,
    'total': 3,
    'items': [
      for (var i = 3; i >= 1; i--)
        {'id': 'm$i', 'body': 'message $i', 'fromMe': true},
    ],
  });

  @override
  Future<SendResult> send(String conversationId, String body) async =>
      throw onSend!;

  @override
  Future<SendResult> open(String toUserId, String body) async => throw onOpen!;

  @override
  Future<ConversationSummary?> conversationWith(String userId) async => null;

  @override
  Future<void> markRead(String conversationId) async {}

  @override
  Future<int> unreadCount() async => 0;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not stubbed');
}

class _StillPresence extends PresenceNotifier {
  @override
  Map<String, bool> build() => const {};
}

void main() {
  Future<void> pumpChat(
    WidgetTester tester,
    _RefusingChatRepository repo, {
    String? conversationId = 'c1',
  }) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatRepositoryProvider.overrideWithValue(repo),
          chatServiceProvider.overrideWithValue(
            ChatService(tokenGetter: () => null),
          ),
          presenceProvider.overrideWith(_StillPresence.new),
        ],
        child: MaterialApp(
          home: ChatDetailScreen(
            conversationId: conversationId,
            userId: 'u2',
            userName: 'Ava',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> send(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// The screen releases its active-conversation claim on a zero-delay
  /// future when it is disposed; unmount and let that run before the test
  /// ends, the way the other chat tests pop and settle.
  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    // A bare pump() never advances the fake clock, so even a zero-delay
    // timer would still be waiting.
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('a moderated message says why, and keeps the draft', (
    tester,
  ) async {
    await pumpChat(
      tester,
      _RefusingChatRepository(
        onSend: const ContentRejectedException(
          "This message doesn't meet our content guidelines. Please rephrase it.",
          details: {'reason': 'CONTENT_REJECTED', 'surface': 'message'},
        ),
      ),
    );

    await send(tester, 'something rude');

    expect(find.text('Message not sent'), findsOneWidget);
    expect(find.textContaining('Offensive or abusive words'), findsOneWidget);
    // The words come back so they can be reworded, not retyped.
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'something rude',
    );
    expect(tester.takeException(), isNull);
    await finish(tester);
  });

  testWidgets('the fourth unanswered message says to wait for a reply', (
    tester,
  ) async {
    await pumpChat(
      tester,
      _RefusingChatRepository(
        onSend: const RateLimitedException(
          'Wait for a reply before sending more (max 3 in New Energy)',
          details: {'reason': 'NEW_ENERGY_CAP', 'limit': 3},
        ),
      ),
    );

    await send(tester, 'hello again?');

    expect(find.text('Wait for Ava to reply'), findsOneWidget);
    expect(find.textContaining("You've sent 3 messages"), findsOneWidget);
    // And the composer keeps saying so after the notice has gone.
    expect(
      find.text('Your move is made — waiting for Ava to reply.'),
      findsOneWidget,
    );

    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Wait for Ava to reply'), findsNothing);
    expect(
      find.text('Your move is made — waiting for Ava to reply.'),
      findsOneWidget,
    );
    await finish(tester);
  });

  testWidgets('a fourth new conversation opens the paywall', (tester) async {
    await pumpChat(
      tester,
      _RefusingChatRepository(
        onOpen: const EntitlementRequiredException(
          'Premium or ad credits are required to continue',
          details: {
            'reason': 'CONVERSATIONS_LIMIT_REACHED',
            'action': 'open_conversation',
            'cost': 1,
            'balance': 0,
            'options': ['premium', 'watch_ad'],
          },
        ),
      ),
      conversationId: null,
    );

    await send(tester, 'hey!');
    await tester.pumpAndSettle();

    expect(find.text('Unlimited new chats with Premium'), findsOneWidget);
    expect(find.textContaining('always free'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await finish(tester);
  });
}
