import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../core/constants/api_constants.dart';
import '../models/message_model.dart';
import 'presence_service.dart' show TokenGetter;

/// A message pushed live over the `/chat` socket.
class IncomingChatMessage {
  final String conversationId;
  final String state;
  final Message message;
  const IncomingChatMessage({
    required this.conversationId,
    required this.state,
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

/// Manages the `/chat` Socket.io namespace: authenticates the handshake, streams
/// live messages / read receipts / typing, and relays this user's typing state.
/// Sends and reads remain authoritative over REST — this is the push layer.
class ChatService {
  ChatService({required this.tokenGetter});

  final TokenGetter tokenGetter;

  io.Socket? _socket;
  final _messages = StreamController<IncomingChatMessage>.broadcast();
  final _reads = StreamController<ReadReceipt>.broadcast();
  final _typing = StreamController<TypingEvent>.broadcast();

  Stream<IncomingChatMessage> get messages => _messages.stream;
  Stream<ReadReceipt> get reads => _reads.stream;
  Stream<TypingEvent> get typing => _typing.stream;
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
    _reads.close();
    _typing.close();
  }
}
