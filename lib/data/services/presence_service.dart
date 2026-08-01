import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../core/constants/api_constants.dart';

/// A single presence change broadcast by the server.
class PresenceEvent {
  final String userId;
  final bool online;
  const PresenceEvent(this.userId, this.online);
}

typedef TokenGetter = String? Function();

/// Manages the `/presence` Socket.io namespace: authenticates the handshake
/// with the Supabase token, emits a periodic heartbeat to stay "online", and
/// exposes a stream of other users' presence changes.
class PresenceService {
  PresenceService({required this.tokenGetter});

  final TokenGetter tokenGetter;

  io.Socket? _socket;
  Timer? _heartbeat;
  final StreamController<PresenceEvent> _controller =
      StreamController<PresenceEvent>.broadcast();

  Stream<PresenceEvent> get updates => _controller.stream;
  bool get isConnected => _socket?.connected ?? false;

  void connect() {
    final token = tokenGetter();
    if (token == null || token.isEmpty) return;

    if (_socket != null) {
      _socket!.connect();
      return;
    }

    final socket = io.io(
      '${ApiConstants.socketUrl}${SocketConstants.presenceNamespace}',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );

    socket.onConnect((_) => _startHeartbeat());
    socket.onDisconnect((_) => _stopHeartbeat());
    socket.on(SocketConstants.presenceUpdate, (data) {
      if (data is Map) {
        _controller.add(
          PresenceEvent(data['userId']?.toString() ?? '', data['online'] == true),
        );
      }
    });

    _socket = socket;
    socket.connect();
  }

  void _startHeartbeat() {
    _stopHeartbeat();
    _socket?.emit(SocketConstants.heartbeat);
    _heartbeat = Timer.periodic(
      const Duration(seconds: 25),
      (_) => _socket?.emit(SocketConstants.heartbeat),
    );
  }

  void _stopHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = null;
  }

  void dispose() {
    _stopHeartbeat();
    _socket?.dispose();
    _socket = null;
    _controller.close();
  }
}
