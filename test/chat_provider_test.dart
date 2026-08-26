import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dating_app/data/models/message_model.dart';
import 'package:dating_app/data/repositories/chat_repository.dart';
import 'package:dating_app/providers/chat_provider.dart';
import 'package:dating_app/providers/core_providers.dart';

/// A ChatRepository that serves a fixed thread without touching the network.
class _FakeChatRepository implements ChatRepository {
  _FakeChatRepository(this._messages);

  List<Message> _messages;
  int messageFetches = 0;

  void replaceThread(List<Message> messages) => _messages = messages;

  @override
  Future<MessagesPage> messages(
    String conversationId, {
    int page = 1,
    int limit = 30,
  }) async {
    messageFetches++;
    // The API returns newest-first; the notifier reverses for display.
    return MessagesPage.fromJson({
      'conversation': {'id': conversationId, 'state': 'vibing'},
      'page': page,
      'limit': limit,
      'total': _messages.length,
      'items': _messages.reversed.map(_toJson).toList(),
    });
  }

  static Map<String, dynamic> _toJson(Message m) => {
        'id': m.id,
        'body': m.body,
        'fromMe': m.fromMe,
        'read': m.read,
      };

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not stubbed');
}

Message _msg(String id, {bool fromMe = true, bool read = false}) =>
    Message.fromJson({'id': id, 'body': id, 'fromMe': fromMe, 'read': read});

/// Riverpod schedules autoDispose teardown rather than running it inline, so
/// tests must let the loop turn before asserting on a disposed provider. In the
/// app this always elapses — the user reopens a chat many frames later.
Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  late _FakeChatRepository repo;
  late ProviderContainer container;

  setUp(() {
    repo = _FakeChatRepository([_msg('m1')]);
    // Overriding the repository keeps ApiClient (and therefore Supabase) out of
    // the graph entirely — these tests never touch the network.
    container = ProviderContainer(
      overrides: [chatRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
  });

  test('reads a thread newest-last for display', () async {
    repo.replaceThread([_msg('m1'), _msg('m2')]);
    final messages = await container.read(messagesProvider('c1').future);
    expect(messages.map((m) => m.id), ['m1', 'm2']);
  });

  /// The bug behind "the message shows in the inbox but not inside the chat":
  /// the thread used to be cached for the app's lifetime, so a reply that
  /// arrived while the screen was closed was never picked up on reopen.
  test('refetches the thread after the last listener goes away', () async {
    final sub = container.listen(messagesProvider('c1'), (_, __) {});
    await container.read(messagesProvider('c1').future);
    expect(repo.messageFetches, 1);

    // Closing the screen drops the last listener → autoDispose tears it down.
    sub.close();
    await _settle();
    // A reply lands while nothing is watching.
    repo.replaceThread([_msg('m1'), _msg('m2', fromMe: false)]);

    final reopened = await container.read(messagesProvider('c1').future);
    expect(repo.messageFetches, 2, reason: 'reopening must hit the server');
    expect(reopened.map((m) => m.id), ['m1', 'm2']);
  });

  test('dedupes a socket message already in the thread', () async {
    final sub = container.listen(messagesProvider('c1'), (_, __) {});
    addTearDown(sub.close);
    await container.read(messagesProvider('c1').future);

    final notifier = container.read(messagesProvider('c1').notifier);
    notifier.addIncoming(_msg('m1'));
    expect(container.read(messagesProvider('c1')).value!.length, 1);

    notifier.addIncoming(_msg('m2', fromMe: false));
    expect(container.read(messagesProvider('c1')).value!.map((m) => m.id),
        ['m1', 'm2']);
  });

  test('markMineRead flips only my own messages', () async {
    repo.replaceThread([_msg('mine'), _msg('theirs', fromMe: false)]);
    final sub = container.listen(messagesProvider('c1'), (_, __) {});
    addTearDown(sub.close);
    await container.read(messagesProvider('c1').future);

    container.read(messagesProvider('c1').notifier).markMineRead();

    final messages = container.read(messagesProvider('c1')).value!;
    expect(messages.firstWhere((m) => m.id == 'mine').read, isTrue);
    expect(messages.firstWhere((m) => m.id == 'theirs').read, isFalse);
  });

  /// The console crash: a read receipt buffered on the chat socket is delivered
  /// in a microtask after the screen closed, so the notifier is already torn
  /// down. Writing `state` then throws — it must be a no-op instead.
  test('a late socket callback after disposal is a no-op, not a crash',
      () async {
    final sub = container.listen(messagesProvider('c1'), (_, __) {});
    await container.read(messagesProvider('c1').future);
    final notifier = container.read(messagesProvider('c1').notifier);

    sub.close(); // screen popped → autoDispose runs
    await _settle();

    expect(() => notifier.markMineRead(), returnsNormally);
    expect(() => notifier.addIncoming(_msg('late', fromMe: false)),
        returnsNormally);
  });
}
