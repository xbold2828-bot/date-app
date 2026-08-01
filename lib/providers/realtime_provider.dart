import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/services/chat_service.dart';
import '../data/services/presence_service.dart';
import 'chat_provider.dart';
import 'core_providers.dart';

/// The live `/presence` socket, connected with the current Supabase token and
/// torn down when no longer needed.
final presenceServiceProvider = Provider<PresenceService>((ref) {
  final service = PresenceService(
    tokenGetter: () => ref.read(authRepositoryProvider).accessToken,
  );
  ref.onDispose(service.dispose);
  service.connect();
  return service;
});

/// A live map of userId → online. Screens read `presence[userId]` and fall back
/// to the card's own `isOnline` when absent.
class PresenceNotifier extends Notifier<Map<String, bool>> {
  StreamSubscription<PresenceEvent>? _sub;

  @override
  Map<String, bool> build() {
    final service = ref.watch(presenceServiceProvider);
    _sub = service.updates.listen((e) {
      if (e.userId.isEmpty) return;
      state = {...state, e.userId: e.online};
    });
    ref.onDispose(() => _sub?.cancel());
    return const {};
  }

  bool? isOnline(String userId) => state[userId];
}

final presenceProvider =
    NotifierProvider<PresenceNotifier, Map<String, bool>>(PresenceNotifier.new);

/// The live `/chat` socket.
final chatServiceProvider = Provider<ChatService>((ref) {
  final service = ChatService(
    tokenGetter: () => ref.read(authRepositoryProvider).accessToken,
  );
  ref.onDispose(service.dispose);
  service.connect();
  return service;
});

/// Global chat realtime side-effects: bump the unread badge and refresh the
/// inbox when a message arrives anywhere. Watch this once high in the tree
/// (HomeScreen) to activate it. The active chat screen listens to
/// [chatServiceProvider] directly for the open conversation.
final chatRealtimeProvider = Provider<void>((ref) {
  final service = ref.watch(chatServiceProvider);
  final sub = service.messages.listen((_) {
    ref.read(unreadCountProvider.notifier).bump();
    ref.invalidate(conversationsProvider);
  });
  ref.onDispose(sub.cancel);
});
