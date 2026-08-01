import '../../core/constants/api_constants.dart';
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
}
