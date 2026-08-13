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

/// Serves one thread and swallows the read/unread calls the screen makes on
/// open. No network, no sockets, no Supabase.
class _FakeChatRepository implements ChatRepository {
  int markReadCalls = 0;

  @override
  Future<MessagesPage> messages(
    String conversationId, {
    int page = 1,
    int limit = 30,
  }) async =>
      MessagesPage.fromJson({
        'conversation': {'id': conversationId, 'state': 'vibing'},
        'page': page,
        'limit': limit,
        'total': 1,
        'items': [
          {'id': 'm1', 'body': 'hi', 'fromMe': false, 'read': false},
        ],
      });

  @override
  Future<void> markRead(String conversationId) async => markReadCalls++;

  @override
  Future<int> unreadCount() async => 0;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not stubbed');
}

/// Presence without a socket.
class _StillPresence extends PresenceNotifier {
  @override
  Map<String, bool> build() => const {};
}

void main() {
  late _FakeChatRepository repo;
  late GlobalKey<NavigatorState> nav;

  setUp(() {
    repo = _FakeChatRepository();
    nav = GlobalKey<NavigatorState>();
  });

  /// One stable ProviderScope for the whole test — swapping the scope itself
  /// is what Riverpod forbids, and it isn't what the app does. Navigation
  /// happens inside it, exactly like pushing/popping the chat route for real.
  Widget harness() => ProviderScope(
        overrides: [
          chatRepositoryProvider.overrideWithValue(repo),
          // The real provider opens a socket on creation; this one is inert but
          // exposes the same broadcast streams.
          chatServiceProvider.overrideWithValue(
            ChatService(tokenGetter: () => null),
          ),
          // The header shows "Active now" from live presence, and the real
          // presence provider connects a socket (and reaches for Supabase) the
          // moment it is read.
          presenceProvider.overrideWith(_StillPresence.new),
        ],
        child: MaterialApp(
          navigatorKey: nav,
          home: const Scaffold(body: SizedBox.shrink()),
        ),
      );

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));

  Future<void> openChat(WidgetTester tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();
    unawaitedPush(nav);
    await tester.pumpAndSettle();
  }

  testWidgets('opening a thread claims it as the active conversation',
      (tester) async {
    await openChat(tester);

    expect(find.byType(ChatDetailScreen), findsOneWidget);
    expect(containerOf(tester).read(activeConversationProvider), 'c1');
    expect(repo.markReadCalls, greaterThan(0));

    // Close the route so the deferred claim-release runs inside the test; the
    // binding fails the test if a timer is still pending at teardown.
    nav.currentState!.pop();
    await tester.pumpAndSettle();
  });

  /// The reported crash: "Bad state: Cannot use ref after the widget was
  /// disposed". Riverpod closes the WidgetRef in
  /// `ConsumerStatefulElement.unmount()` before `State.dispose()` runs, so any
  /// `ref` call inside dispose throws while the tree is being finalized.
  testWidgets('closing the thread disposes cleanly without touching ref',
      (tester) async {
    await openChat(tester);

    nav.currentState!.pop();
    await tester.pumpAndSettle();

    expect(find.byType(ChatDetailScreen), findsNothing);
    expect(
      tester.takeException(),
      isNull,
      reason: 'dispose() must not use ref after the widget was disposed',
    );
  });

  testWidgets('a disposed thread releases its active-conversation claim',
      (tester) async {
    await openChat(tester);
    expect(containerOf(tester).read(activeConversationProvider), 'c1');

    nav.currentState!.pop();
    await tester.pumpAndSettle();

    expect(containerOf(tester).read(activeConversationProvider), isNull);
    expect(tester.takeException(), isNull);
  });
}

/// Pushes the chat route without awaiting it — the future only completes when
/// the route is popped, which the tests do themselves.
void unawaitedPush(GlobalKey<NavigatorState> nav) {
  nav.currentState!.push<void>(
    MaterialPageRoute<void>(
      builder: (_) => const ChatDetailScreen(
        conversationId: 'c1',
        userId: 'u2',
        userName: 'Vinayak',
        userAge: 26,
      ),
    ),
  );
}
