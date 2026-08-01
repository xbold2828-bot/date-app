import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/message_model.dart';
import 'core_providers.dart';

/// Inbox list for a given state tab (null = all, 'new_energy', 'vibing').
class ConversationsNotifier
    extends FamilyAsyncNotifier<List<ConversationSummary>, String?> {
  @override
  Future<List<ConversationSummary>> build(String? state) async {
    final page = await ref
        .watch(chatRepositoryProvider)
        .conversations(state: state, limit: 50);
    return page.items;
  }

  Future<void> refresh() async {
    state = const AsyncLoading<List<ConversationSummary>>()
        .copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      final page = await ref
          .read(chatRepositoryProvider)
          .conversations(state: arg, limit: 50);
      return page.items;
    });
  }
}

final conversationsProvider = AsyncNotifierProvider.family<
    ConversationsNotifier, List<ConversationSummary>, String?>(
  ConversationsNotifier.new,
);

/// Inbox unread badge. Kept as a notifier so the chat socket can bump it live.
class UnreadCountNotifier extends AsyncNotifier<int> {
  @override
  Future<int> build() => ref.watch(chatRepositoryProvider).unreadCount();

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(chatRepositoryProvider).unreadCount(),
    );
  }

  void bump([int by = 1]) {
    final current = state.valueOrNull ?? 0;
    state = AsyncData(current + by);
  }

  void clear() => state = const AsyncData(0);
}

final unreadCountProvider =
    AsyncNotifierProvider<UnreadCountNotifier, int>(UnreadCountNotifier.new);

/// Message history for one conversation, oldest → newest (the backend returns
/// newest-first; we reverse for display). The chat socket appends live messages
/// via [addIncoming].
class MessagesNotifier extends FamilyAsyncNotifier<List<Message>, String> {
  @override
  Future<List<Message>> build(String conversationId) async {
    final page = await ref
        .watch(chatRepositoryProvider)
        .messages(conversationId, limit: 30);
    return page.items.reversed.toList();
  }

  /// Append a message we just sent (already persisted server-side).
  void appendSent(Message message) => _append(message);

  /// Append a message pushed over the socket (dedup by id).
  void addIncoming(Message message) => _append(message);

  void _append(Message message) {
    final current = state.valueOrNull ?? const [];
    if (current.any((m) => m.id == message.id)) return;
    state = AsyncData([...current, message]);
  }

  /// Mark my sent messages read once the other side's read receipt arrives.
  void markMineRead() {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData([
      for (final m in current) m.fromMe ? m.copyWith(read: true) : m,
    ]);
  }
}

final messagesProvider =
    AsyncNotifierProvider.family<MessagesNotifier, List<Message>, String>(
  MessagesNotifier.new,
);

/// Imperative messaging actions used by the profile "message" CTA and the chat
/// detail composer.
class ChatActions {
  ChatActions(this.ref);
  final Ref ref;

  /// Open a NEW conversation (verification + entitlement gated).
  Future<SendResult> open(String toUserId, String body) async {
    final result = await ref.read(chatRepositoryProvider).open(toUserId, body);
    ref.read(messagesProvider(result.conversation.id).notifier)
        .appendSent(result.message);
    return result;
  }

  /// Send into an existing conversation (free).
  Future<SendResult> send(String conversationId, String body) async {
    final result =
        await ref.read(chatRepositoryProvider).send(conversationId, body);
    ref.read(messagesProvider(conversationId).notifier)
        .appendSent(result.message);
    return result;
  }

  Future<void> markRead(String conversationId) async {
    await ref.read(chatRepositoryProvider).markRead(conversationId);
    ref.read(unreadCountProvider.notifier).refresh();
  }

  Future<void> archive(String conversationId) =>
      ref.read(chatRepositoryProvider).archive(conversationId);
}

final chatActionsProvider = Provider<ChatActions>((ref) => ChatActions(ref));
