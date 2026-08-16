import '../../core/constants/api_constants.dart';
import '../models/map_user_model.dart';
import '../models/message_model.dart';
import '../models/paginated.dart';
import '../services/api_service.dart';

/// Messaging REST surface (New Energy → Vibing). The `/chat` socket is the
/// push layer; sends/reads remain authoritative here.
class ChatRepository {
  ChatRepository(this._api);

  final ApiClient _api;

  /// `POST /messaging/open` — open a conversation / send an opener.
  /// Requires verification (403) and consumes the messaging entitlement (402).
  Future<SendResult> open(String toUserId, String body) async {
    final data = await _api.post(
      ApiConstants.messagingOpen,
      body: {'toUserId': toUserId, 'body': body},
    );
    return SendResult.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// `GET /messaging/map` — the people I am vibing with, with generalized map
  /// positions. Backs the Explore tab.
  ///
  /// Vibing only: a New Energy thread is somebody who reached out and has not
  /// been answered, and putting them on a map would hand an unanswered sender a
  /// location before the other person agreed to anything. Costs no entitlement
  /// — these are conversations the user already has.
  Future<List<MapUser>> mapPeople() async {
    final data = await _api.get(ApiConstants.messagingMap);
    return ((data as List?) ?? const [])
        .whereType<Map>()
        .map((e) => MapUser.fromJson(Map<String, dynamic>.from(e)))
        .whereType<MapUser>()
        .toList(growable: false);
  }

  /// `GET /messaging/conversations` — inbox, filtered by [state] (new_energy /
  /// vibing) or [archived].
  Future<PageResult<ConversationSummary>> conversations({
    String? state,
    bool? archived,
    int page = 1,
    int limit = 20,
  }) async {
    final query = <String, dynamic>{
      'page': page,
      'limit': limit,
      if (state != null) 'state': state,
      if (archived == true) 'archived': true,
    };
    final data = await _api.get(ApiConstants.conversations, query: query);
    return PageResult<ConversationSummary>.fromJson(
      Map<String, dynamic>.from(data as Map),
      ConversationSummary.fromJson,
    );
  }

  /// `GET /messaging/unread-count` — inbox badge.
  Future<int> unreadCount() async {
    final data = await _api.get(ApiConstants.unreadCount);
    return ((data as Map)['unread'] as num?)?.toInt() ?? 0;
  }

  /// `GET /messaging/conversations/:id/messages` — history (newest first).
  Future<MessagesPage> messages(
    String conversationId, {
    int page = 1,
    int limit = 30,
  }) async {
    final data = await _api.get(
      ApiConstants.conversationMessages(conversationId),
      query: {'page': page, 'limit': limit},
    );
    return MessagesPage.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// `POST /messaging/conversations/:id/messages` — send into an existing thread.
  Future<SendResult> send(String conversationId, String body) async {
    final data = await _api.post(
      ApiConstants.conversationMessages(conversationId),
      body: {'body': body},
    );
    return SendResult.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// `POST /messaging/conversations/:id/read` — mark read (emits a receipt).
  Future<void> markRead(String conversationId) =>
      _api.post(ApiConstants.conversationRead(conversationId));

  /// `POST /messaging/conversations/:id/archive` — archive (per-user).
  Future<void> archive(String conversationId) =>
      _api.post(ApiConstants.conversationArchive(conversationId));

  /// `POST /messaging/conversations/:id/unarchive` — back to the inbox.
  Future<void> unarchive(String conversationId) =>
      _api.post(ApiConstants.conversationUnarchive(conversationId));

  /// `POST /messaging/conversations/:id/mute` — stop this thread counting
  /// towards the Chats badge.
  ///
  /// Per-user and invisible to the other person. Messages keep arriving and
  /// the row keeps its own unread count; muting is about the badge, which is
  /// the part that actually interrupts anyone.
  Future<void> mute(String conversationId) =>
      _api.post(ApiConstants.conversationMute(conversationId));

  /// `POST /messaging/conversations/:id/unmute`.
  Future<void> unmute(String conversationId) =>
      _api.post(ApiConstants.conversationUnmute(conversationId));

  /// `PATCH /messaging/messages/:id` — rewrite one of my own messages.
  ///
  /// Premium (403 otherwise) and sender-only (404 otherwise). The result is
  /// marked `edited`, which both sides see.
  Future<Message> editMessage(String messageId, String body) async {
    final data = await _api.patch(
      ApiConstants.message(messageId),
      body: {'body': body},
    );
    return Message.fromJson(
      Map<String, dynamic>.from((data as Map)['message'] as Map),
    );
  }

  /// `DELETE /messaging/messages/:id` — take a message back, for both sides.
  ///
  /// Premium and sender-only. Returns the tombstone that replaces it: the row
  /// stays in the thread saying it was deleted, rather than vanishing and
  /// leaving the other person's reply answering nothing.
  Future<Message> deleteMessage(String messageId) async {
    final data = await _api.delete(ApiConstants.message(messageId));
    return Message.fromJson(
      Map<String, dynamic>.from((data as Map)['message'] as Map),
    );
  }

  /// `DELETE /messaging/conversations/:id` — remove from MY inbox.
  ///
  /// Per-user: the other person keeps their copy, and a new message from them
  /// brings the thread back. Nothing is destroyed server-side.
  Future<void> deleteConversation(String conversationId) =>
      _api.delete(ApiConstants.conversation(conversationId));
}
