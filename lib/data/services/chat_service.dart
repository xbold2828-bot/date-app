import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../core/constants/api_constants.dart';
import '../models/match_model.dart';
import '../models/message_model.dart';
import 'presence_service.dart' show TokenGetter;

/// A message pushed live over the `/chat` socket.
class IncomingChatMessage {
  final String conversationId;
  final String state;
  final Message message;

  /// Whether *I* muted this thread.
  ///
  /// The server sends it because it has already decided not to count this
  /// message in the badge total — without it the live badge and the fetched
  /// one would disagree until the next refresh.
  final bool muted;

  const IncomingChatMessage({
    required this.conversationId,
    required this.state,
    required this.message,
    this.muted = false,
  });
}

/// A message the sender edited or took back, pushed to the other side.
///
/// Carries the whole replacement rather than a diff, so the receiving client
/// swaps the row by id and never has to work out what changed.
class ChatMessageUpdate {
  final String conversationId;
  final Message message;
  const ChatMessageUpdate({
    required this.conversationId,
    required this.message,
  });
}

/// A read receipt: the other participant read up to [at].
class ReadReceipt {
  final String conversationId;
  final String by;
  final DateTime? at;
  const ReadReceipt({required this.conversationId, required this.by, this.at});
}

/// The other participant is typing.
class TypingEvent {
  final String conversationId;
  final String fromUserId;
  const TypingEvent({required this.conversationId, required this.fromUserId});
}

/// Somebody liked me back, just now.
///
/// This is the half of a match the person did not perform themselves: they are
/// somewhere else in the app entirely, and without this would not find out
/// until they next opened the Mutual tab.
class MatchEvent {
  final LikeCard user;
  final DateTime? matchedAt;
  const MatchEvent({required this.user, this.matchedAt});
}

/// Manages the `/chat` Socket.io namespace: authenticates the handshake, streams
/// live messages / read receipts / typing, and relays this user's typing state.
/// Sends and reads remain authoritative over REST — this is the push layer.
class ChatService {
  ChatService({required this.tokenGetter});

  final TokenGetter tokenGetter;

  io.Socket? _socket;
  final _messages = StreamController<IncomingChatMessage>.broadcast();
  final _updates = StreamController<ChatMessageUpdate>.broadcast();
  final _reads = StreamController<ReadReceipt>.broadcast();
  final _typing = StreamController<TypingEvent>.broadcast();
  final _matches = StreamController<MatchEvent>.broadcast();

  Stream<IncomingChatMessage> get messages => _messages.stream;

  /// Edits and deletes made by the other participant.
  Stream<ChatMessageUpdate> get updates => _updates.stream;

  Stream<ReadReceipt> get reads => _reads.stream;
  Stream<TypingEvent> get typing => _typing.stream;
  Stream<MatchEvent> get matches => _matches.stream;
  bool get isConnected => _socket?.connected ?? false;

  void connect() {
    final token = tokenGetter();
    if (token == null || token.isEmpty) return;

    if (_socket != null) {
      _socket!.connect();
      return;
    }

    final socket = io.io(
      '${ApiConstants.socketUrl}${SocketConstants.chatNamespace}',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );

    socket.on(SocketConstants.chatMessage, (data) {
      if (data is! Map) return;
      final rawMessage = data['message'];
      if (rawMessage is! Map) return;
      _messages.add(
        IncomingChatMessage(
          conversationId: data['conversationId']?.toString() ?? '',
          state: data['state']?.toString() ?? 'new_energy',
          message: Message.fromJson(Map<String, dynamic>.from(rawMessage)),
          muted: data['muted'] == true,
        ),
      );
    });

    socket.on(SocketConstants.chatMessageUpdated, (data) {
      if (data is! Map) return;
      final rawMessage = data['message'];
      if (rawMessage is! Map) return;
      _updates.add(
        ChatMessageUpdate(
          conversationId: data['conversationId']?.toString() ?? '',
          message: Message.fromJson(Map<String, dynamic>.from(rawMessage)),
        ),
      );
    });

    socket.on(SocketConstants.chatRead, (data) {
      if (data is! Map) return;
      _reads.add(
        ReadReceipt(
          conversationId: data['conversationId']?.toString() ?? '',
          by: data['by']?.toString() ?? '',
          at: DateTime.tryParse(data['at']?.toString() ?? ''),
        ),
      );
    });

    socket.on(SocketConstants.chatTyping, (data) {
      if (data is! Map) return;
      _typing.add(
        TypingEvent(
          conversationId: data['conversationId']?.toString() ?? '',
          fromUserId: data['fromUserId']?.toString() ?? '',
        ),
      );
    });

    socket.on(SocketConstants.matchNew, (data) {
      if (data is! Map) return;
      final user = data['user'];
      if (user is! Map) return;
      _matches.add(
        MatchEvent(
          user: LikeCard.fromJson(Map<String, dynamic>.from(user)),
          matchedAt: DateTime.tryParse(data['matchedAt']?.toString() ?? ''),
        ),
      );
    });

    _socket = socket;
    socket.connect();
  }

  /// Tell the other participant we're typing.
  void sendTyping({required String toUserId, required String conversationId}) {
    _socket?.emit(SocketConstants.chatTyping, {
      'toUserId': toUserId,
      'conversationId': conversationId,
    });
  }

  void dispose() {
    _socket?.dispose();
    _socket = null;
    _messages.close();
    _updates.close();
    _reads.close();
    _typing.close();
    _matches.close();
  }
}
