import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dating_app/data/models/message_model.dart';
import 'package:dating_app/data/repositories/chat_repository.dart';
import 'package:dating_app/data/services/chat_service.dart';
import 'package:dating_app/presentation/home/screens/chat_detail_screen.dart';
import 'package:dating_app/providers/chat_provider.dart';
import 'package:dating_app/providers/core_providers.dart';
import 'package:dating_app/providers/realtime_provider.dart';

/// Opening a chat when only a user id is known.
///
/// The bug: the Mutual tab hands [ChatDetailScreen] a `conversationId` that is
/// a snapshot from when that page loaded, so a match you have been talking to
/// for days opened as a blank thread. Sending then called `open`, the server
/// matched the pair key and returned the conversation that had existed all
/// along, and the history appeared *after* the message — which reads as the
/// app having lost it and then found it.
///
/// The screen now asks the server whether a thread exists before drawing
/// itself as a new one.
class _FakeChatRepository implements ChatRepository {
  _FakeChatRepository({this.existing});

  /// What `GET /messaging/conversations/with/:userId` answers.
  final ConversationSummary? existing;

  int lookups = 0;
  final List<String> historyLoadedFor = [];
  int opens = 0;

  @override
  Future<ConversationSummary?> conversationWith(String userId) async {
    lookups++;
    return existing;
  }

  @override
  Future<MessagesPage> messages(
    String conversationId, {
    int page = 1,
    int limit = 30,
  }) async {
    historyLoadedFor.add(conversationId);
    return MessagesPage.fromJson({
      'conversation': {'id': conversationId, 'state': 'vibing'},
      'page': page,
      'limit': limit,
      'total': 1,
      'items': [
        {'id': 'm1', 'body': 'we spoke last week', 'fromMe': false},
      ],
    });
  }

  @override
  Future<SendResult> open(String toUserId, String body) async {
    opens++;
    return SendResult.fromJson({
      'conversation': {'id': 'c-existing', 'state': 'vibing'},
      'message': {'id': 'm2', 'body': body, 'fromMe': true},
    });
  }

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

ConversationSummary _summary(String id) => ConversationSummary.fromJson({
      'id': id,
      'state': 'vibing',
      'otherUser': {'id': 'u2', 'displayName': 'Vinayak'},
    });

void main() {
  late GlobalKey<NavigatorState> nav;

  setUp(() => nav = GlobalKey<NavigatorState>());

  Widget harness(_FakeChatRepository repo) => ProviderScope(
        overrides: [
          chatRepositoryProvider.overrideWithValue(repo),
          chatServiceProvider.overrideWithValue(
            ChatService(tokenGetter: () => null),
          ),
          presenceProvider.overrideWith(_StillPresence.new),
        ],
        child: MaterialApp(
          navigatorKey: nav,
          home: const Scaffold(body: SizedBox.shrink()),
        ),
      );

  /// Pushes the chat exactly as the Mutual tab does for a match it believes
  /// has no thread: a user id, and a null conversation id.
  Future<void> openFromMatch(WidgetTester tester) async {
    nav.currentState!.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const ChatDetailScreen(
          conversationId: null,
          userId: 'u2',
          userName: 'Vinayak',
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));

  testWidgets('shows the history of a thread the caller did not know about',
      (tester) async {
    // The regression, end to end: before the lookup existed this screen was
    // blank until the user sent something.
    final repo = _FakeChatRepository(existing: _summary('c-existing'));
    await tester.pumpWidget(harness(repo));
    await tester.pumpAndSettle();

    await openFromMatch(tester);

    expect(repo.lookups, 1, reason: 'it must ask before assuming');
    expect(repo.historyLoadedFor, contains('c-existing'));
    expect(find.text('we spoke last week'), findsOneWidget);

    nav.currentState!.pop();
    await tester.pumpAndSettle();
  });

  testWidgets('adopts the thread as the active conversation', (tester) async {
    // Which is what stops its messages counting towards the unread badge
    // while it is on screen.
    final repo = _FakeChatRepository(existing: _summary('c-existing'));
    await tester.pumpWidget(harness(repo));
    await tester.pumpAndSettle();

    await openFromMatch(tester);

    expect(containerOf(tester).read(activeConversationProvider), 'c-existing');

    nav.currentState!.pop();
    await tester.pumpAndSettle();
  });

  testWidgets('stays empty for a match nobody has written to', (tester) async {
    // Null is the normal answer, not an error — a fresh match really has no
    // thread, and the screen must still open ready to compose.
    final repo = _FakeChatRepository(existing: null);
    await tester.pumpWidget(harness(repo));
    await tester.pumpAndSettle();

    await openFromMatch(tester);

    expect(repo.lookups, 1);
    expect(repo.historyLoadedFor, isEmpty);
    expect(find.byType(ChatDetailScreen), findsOneWidget);
    expect(tester.takeException(), isNull);

    nav.currentState!.pop();
    await tester.pumpAndSettle();
  });

  testWidgets('skips the lookup when the caller already knows the thread',
      (tester) async {
    // The inbox always knows. Spending a request to re-learn it would be a
    // round-trip per row tapped.
    final repo = _FakeChatRepository(existing: _summary('c-existing'));
    await tester.pumpWidget(harness(repo));
    await tester.pumpAndSettle();

    nav.currentState!.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const ChatDetailScreen(
          conversationId: 'c-known',
          userId: 'u2',
          userName: 'Vinayak',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(repo.lookups, 0);
    expect(repo.historyLoadedFor, contains('c-known'));

    nav.currentState!.pop();
    await tester.pumpAndSettle();
  });

  testWidgets('a failed lookup leaves the screen usable', (tester) async {
    // No worse than before the lookup existed: start empty, and let the first
    // send adopt whatever `open` returns.
    final repo = _ThrowingLookupRepository();
    await tester.pumpWidget(harness(repo));
    await tester.pumpAndSettle();

    await openFromMatch(tester);

    expect(find.byType(ChatDetailScreen), findsOneWidget);
    expect(tester.takeException(), isNull);

    nav.currentState!.pop();
    await tester.pumpAndSettle();
  });
}

class _ThrowingLookupRepository extends _FakeChatRepository {
  @override
  Future<ConversationSummary?> conversationWith(String userId) async {
    throw Exception('offline');
  }
}
