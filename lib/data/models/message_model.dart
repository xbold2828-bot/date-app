/// Lightweight conversation reference `{ id, state }` returned alongside
/// message operations. `state`: new_energy | vibing | archived | blocked.
class ConversationRef {
  final String id;
  final String state;

  const ConversationRef({required this.id, required this.state});

  factory ConversationRef.fromJson(Map<String, dynamic> json) => ConversationRef(
        id: json['id'] as String? ?? '',
        state: json['state'] as String? ?? 'new_energy',
      );
}

/// A single message (backend `MessageView`).
class Message {
  final String id;
  final String body;
  final String type; // text | opener | system
  final String senderId;
  final bool fromMe;
  final DateTime? sentAt;
  final bool read;

  /// The sender changed this after sending it.
  ///
  /// Shown, always. An edit nobody can see is a way to make somebody doubt
  /// what they read.
  final bool edited;

  /// The sender took it back. [body] is the server's tombstone text — the
  /// original never leaves the backend.
  final bool deleted;

  const Message({
    required this.id,
    required this.body,
    required this.type,
    required this.senderId,
    required this.fromMe,
    this.sentAt,
    this.read = false,
    this.edited = false,
    this.deleted = false,
  });

  Message copyWith({bool? read}) => Message(
        id: id,
        body: body,
        type: type,
        senderId: senderId,
        fromMe: fromMe,
        sentAt: sentAt,
        read: read ?? this.read,
        edited: edited,
        deleted: deleted,
      );

  factory Message.fromJson(Map<String, dynamic> json) => Message(
        id: json['id'] as String? ?? '',
        body: json['body'] as String? ?? '',
        type: json['type'] as String? ?? 'text',
        senderId: json['senderId'] as String? ?? '',
        fromMe: json['fromMe'] as bool? ?? false,
        sentAt: DateTime.tryParse(json['sentAt'] as String? ?? ''),
        read: json['read'] as bool? ?? false,
        edited: json['edited'] as bool? ?? false,
        deleted: json['deleted'] as bool? ?? false,
      );
}

/// The other participant summary embedded in a conversation.
class ChatOtherUser {
  final String id;
  final String? displayName;
  final int? age;
  final String? primaryPhotoUrl;
  final bool isOnline;
  final bool isVerified;

  /// Coarse location for the chat header. Never a distance — a thread outlives
  /// the proximity that started it.
  final String? city;

  final DateTime? lastActiveAt;

  /// Their account is gone or suspended. The thread stays readable; the header
  /// says so, rather than leaving someone talking to nobody.
  final bool isDeactivated;

  const ChatOtherUser({
    required this.id,
    this.displayName,
    this.age,
    this.primaryPhotoUrl,
    this.isOnline = false,
    this.isVerified = false,
    this.city,
    this.lastActiveAt,
    this.isDeactivated = false,
  });

  factory ChatOtherUser.fromJson(Map<String, dynamic> json) => ChatOtherUser(
        id: json['id'] as String? ?? '',
        displayName: json['displayName'] as String?,
        age: (json['age'] as num?)?.toInt(),
        primaryPhotoUrl: json['primaryPhotoUrl'] as String?,
        isOnline: json['isOnline'] as bool? ?? false,
        isVerified: json['isVerified'] as bool? ?? false,
        city: json['city'] as String?,
        lastActiveAt: DateTime.tryParse(json['lastActiveAt'] as String? ?? ''),
        isDeactivated: json['isDeactivated'] as bool? ?? false,
      );

  /// "Active now" / "Active 3h ago" / null when there is nothing to say.
  String? get activityLabel {
    if (isDeactivated) return null;
    if (isOnline) return 'Active now';
    final at = lastActiveAt;
    if (at == null) return null;
    final d = DateTime.now().difference(at.toLocal());
    if (d.inMinutes < 5) return 'Active now';
    if (d.inMinutes < 60) return 'Active ${d.inMinutes}m ago';
    if (d.inHours < 24) return 'Active ${d.inHours}h ago';
    if (d.inDays < 7) return 'Active ${d.inDays}d ago';
    return null;
  }
}

/// The last-message preview on a conversation row.
class LastMessage {
  final String snippet;
  final String senderId;
  final DateTime? sentAt;
  final bool fromMe;

  const LastMessage({
    required this.snippet,
    required this.senderId,
    this.sentAt,
    this.fromMe = false,
  });

  factory LastMessage.fromJson(Map<String, dynamic> json) => LastMessage(
        snippet: json['snippet'] as String? ?? '',
        senderId: json['senderId'] as String? ?? '',
        sentAt: DateTime.tryParse(json['sentAt'] as String? ?? ''),
        fromMe: json['fromMe'] as bool? ?? false,
      );
}

/// An inbox row (backend `ConversationSummary`).
class ConversationSummary {
  final String id;
  final String state;
  final ChatOtherUser otherUser;
  final LastMessage? lastMessage;
  final int unread;

  /// I muted this thread. Messages still arrive and this row still counts
  /// them — what stops is the badge on the Chats tab.
  final bool muted;

  final DateTime? lastMessageAt;

  const ConversationSummary({
    required this.id,
    required this.state,
    required this.otherUser,
    this.lastMessage,
    this.unread = 0,
    this.muted = false,
    this.lastMessageAt,
  });

  ConversationSummary copyWith({
    String? state,
    LastMessage? lastMessage,
    int? unread,
    bool? muted,
    DateTime? lastMessageAt,
  }) =>
      ConversationSummary(
        id: id,
        state: state ?? this.state,
        otherUser: otherUser,
        lastMessage: lastMessage ?? this.lastMessage,
        unread: unread ?? this.unread,
        muted: muted ?? this.muted,
        lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      );

  factory ConversationSummary.fromJson(Map<String, dynamic> json) =>
      ConversationSummary(
        id: json['id'] as String? ?? '',
        state: json['state'] as String? ?? 'new_energy',
        otherUser: ChatOtherUser.fromJson(
          Map<String, dynamic>.from(json['otherUser'] as Map? ?? const {}),
        ),
        lastMessage: json['lastMessage'] == null
            ? null
            : LastMessage.fromJson(
                Map<String, dynamic>.from(json['lastMessage'] as Map),
              ),
        unread: (json['unread'] as num?)?.toInt() ?? 0,
        muted: json['muted'] as bool? ?? false,
        lastMessageAt: DateTime.tryParse(json['lastMessageAt'] as String? ?? ''),
      );
}

/// Result of `POST /messaging/open` and `.../messages` (send).
class SendResult {
  final ConversationRef conversation;
  final Message message;

  const SendResult({required this.conversation, required this.message});

  factory SendResult.fromJson(Map<String, dynamic> json) => SendResult(
        conversation: ConversationRef.fromJson(
          Map<String, dynamic>.from(json['conversation'] as Map? ?? const {}),
        ),
        message: Message.fromJson(
          Map<String, dynamic>.from(json['message'] as Map? ?? const {}),
        ),
      );
}

/// Result of `GET /messaging/conversations/:id/messages` (newest first).
class MessagesPage {
  final ConversationRef conversation;
  final int page;
  final int limit;
  final int total;
  final List<Message> items;

  const MessagesPage({
    required this.conversation,
    required this.page,
    required this.limit,
    required this.total,
    required this.items,
  });

  bool get hasMore => page * limit < total;

  factory MessagesPage.fromJson(Map<String, dynamic> json) => MessagesPage(
        conversation: ConversationRef.fromJson(
          Map<String, dynamic>.from(json['conversation'] as Map? ?? const {}),
        ),
        page: (json['page'] as num?)?.toInt() ?? 1,
        limit: (json['limit'] as num?)?.toInt() ?? 30,
        total: (json['total'] as num?)?.toInt() ?? 0,
        items: ((json['items'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => Message.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}
