import '../../core/constants/api_constants.dart';
import '../models/paginated.dart';
import '../services/api_service.dart';

/// Somebody I blocked, from `GET /safety/blocks`.
class BlockedUser {
  final String id;
  final String? displayName;
  final String? primaryPhotoUrl;
  final DateTime? blockedAt;

  const BlockedUser({
    required this.id,
    this.displayName,
    this.primaryPhotoUrl,
    this.blockedAt,
  });

  factory BlockedUser.fromJson(Map<String, dynamic> json) => BlockedUser(
        id: json['id'] as String? ?? '',
        displayName: json['displayName'] as String?,
        primaryPhotoUrl: json['primaryPhotoUrl'] as String?,
        blockedAt: DateTime.tryParse(json['blockedAt'] as String? ?? ''),
      );
}

/// Why a profile was reported. These map exactly onto the backend
/// `ReportReason` enum — anything else is rejected at the DTO.
class ReportReason {
  ReportReason._();

  static const String harassment = 'harassment';
  static const String spam = 'spam';
  static const String inappropriate = 'inappropriate';
  static const String fakeProfile = 'fake_profile';
  static const String underage = 'underage';
  static const String other = 'other';

  /// Label → value, in the order they should be offered. "Underage" leads
  /// nothing and sits mid-list deliberately: it is the most serious option and
  /// putting it first invites mis-taps.
  static const List<MapEntry<String, String>> options = [
    MapEntry('Harassment or abuse', harassment),
    MapEntry('Spam or scam', spam),
    MapEntry('Inappropriate content', inappropriate),
    MapEntry('Fake profile', fakeProfile),
    MapEntry('They appear to be underage', underage),
    MapEntry('Something else', other),
  ];
}

/// Block and report.
///
/// A block is mutual invisibility: the backend consults it from discovery,
/// profiles, likes and messaging, in both directions. Nothing here is a UI
/// convenience — every call changes what the other person can reach.
class SafetyRepository {
  SafetyRepository(this._api);

  final ApiClient _api;

  /// `POST /safety/block`
  Future<void> block(String userId) =>
      _api.post(ApiConstants.safetyBlock, body: {'targetUserId': userId});

  /// `DELETE /safety/block/:userId`
  Future<void> unblock(String userId) =>
      _api.delete(ApiConstants.safetyUnblock(userId));

  /// `GET /safety/blocks` — people I blocked, and the only way back to them.
  Future<PageResult<BlockedUser>> blocks({
    int page = 1,
    int limit = 50,
  }) async {
    final data = await _api.get(
      ApiConstants.safetyBlocks,
      query: {'page': page, 'limit': limit},
    );
    return PageResult<BlockedUser>.fromJson(
      Map<String, dynamic>.from(data as Map),
      BlockedUser.fromJson,
    );
  }

  /// `POST /safety/report` — logged for moderation. [context] is the reporter's
  /// own words, and is optional.
  Future<void> report(
    String userId, {
    required String reason,
    String? context,
  }) =>
      _api.post(
        ApiConstants.safetyReport,
        body: {
          'targetUserId': userId,
          'reason': reason,
          if (context != null && context.trim().isNotEmpty)
            'context': context.trim(),
        },
      );
}
