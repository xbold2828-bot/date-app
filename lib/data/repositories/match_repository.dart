import 'package:dating_app/core/logger/app_logger.dart';

import '../../core/constants/api_constants.dart';
import '../../presentation/home/models/like_quota_model.dart';
import '../../presentation/home/models/unlike_result_model.dart';
import '../models/match_model.dart';
import '../models/paginated.dart';
import '../services/api_service.dart';

/// Likes / favorites / "liked you".
class MatchRepository {
  MatchRepository(this._api);

  final ApiClient _api;

  /// `POST /likes` — like / favorite / pass. [type]: like | favorite | pass.
  Future<LikeResult> react(String toUserId, String type) async {
    final data = await _api.post(
      ApiConstants.likes,
      body: {'toUserId': toUserId, 'type': type},
    );
    return LikeResult.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// `DELETE /likes/:userId` — remove my reaction.
  Future<void> unreact(String userId) =>
      _api.delete(ApiConstants.likeUser(userId));

  /// `POST /likes/:userId/unlike` — remove my reaction and get the freshly
  /// recalculated quota back in the same response.
  ///
  /// Prefer this over [unreact] anywhere the UI also needs to know whether
  /// the removed reaction had formed a match, or needs the updated daily
  /// allowance without a second `GET /likes/quota` call.
  Future<UnlikeResult> unlike(String userId) async {
    final data = await _api.post(ApiConstants.unlikeUser(userId));
    return UnlikeResult.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// `GET /likes/liked-you` — gated grid of people who liked me.
  /// `GET /likes/liked-you` — gated grid of people who liked me.
  Future<LikedYouPage> likedYou({int page = 1, int limit = 20}) async {
    final data = await _api.get(
      ApiConstants.likedYou,
      query: {'page': page, 'limit': limit},
    );

    final map = Map<String, dynamic>.from(data as Map);
    final result = LikedYouPage.fromJson(map);

    _logLikedYou(page: page, limit: limit, raw: map, result: result);

    return result;
  }

  /// Chunked debug log for [likedYou] — split into separate calls because a
  /// single long multi-line log gets truncated by Android's logcat line limit
  /// (~4000 chars), which would silently hide items on a fuller page.
  void _logLikedYou({
    required int page,
    required int limit,
    required Map<String, dynamic> raw,
    required LikedYouPage result,
  }) {
    AppLogger.d('📥 likedYou(page: $page, limit: $limit) — raw response:');
    AppLogger.d('$raw');

    AppLogger.d('📥 likedYou → parsed summary:');
    AppLogger.d('  total: ${result.total}, locked: ${result.locked}, '
        'source: ${result.source}');
    AppLogger.d('  page: ${result.page}, limit: ${result.limit}, '
        'isEmpty: ${result.isEmpty}');
    AppLogger.d('  freeVisible: ${result.freeVisible}, '
        'lockedCount: ${result.lockedCount}');

    final unlocks = result.unlocks;
    if (unlocks == null) {
      AppLogger.d('  unlocks: null');
    } else {
      AppLogger.d('  unlocks.freeTotal: ${unlocks.freeTotal}, '
          'freeUsed: ${unlocks.freeUsed}, freeRemaining: ${unlocks.freeRemaining}');
      AppLogger.d('  unlocks.creditCost: ${unlocks.creditCost}, '
          'creditBalance: ${unlocks.creditBalance}, '
          'canAffordUnlock: ${unlocks.canAffordUnlock}');
    }

    AppLogger.d('  items (${result.items.length}):');
    for (final entry in result.items.asMap().entries) {
      final i = entry.key;
      final c = entry.value;
      AppLogger.d('    [$i] id: "${c.id}", displayName: ${c.displayName}, '
          'age: ${c.age}, locked: ${c.locked}');
      AppLogger.d('    [$i] isOnline: ${c.isOnline}, isVerified: ${c.isVerified}, '
          'distanceMeters: ${c.distanceMeters}, lastActiveAt: ${c.lastActiveAt}');
    }
  }

  /// `POST /likes/liked-you/:userId/unlock` — reveal one blurred
  /// "liked you" card. Spends credits server-side.
  Future<(String, bool)> unlockLikedYou(String userId) async {
    AppLogger.d('unlockLikedYou → userId: "$userId"');
    final data = await _api.post(ApiConstants.likedYouUnlock(userId));

    // `message` / `success` may be missing if the client already unwrapped the
    // envelope, so don't hard-cast or a good response throws.
    final map =
    data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
    return (
    map['message'] as String? ?? 'Unlocked',
    map['success'] as bool? ?? true,
    );
  }

  /// `GET /likes/mutual` — matches.
  ///
  /// No entitlement, no redaction, no paywall: both people already chose this.
  Future<PageResult<MutualCard>> mutual({int page = 1, int limit = 20}) async {
    final data = await _api.get(
      ApiConstants.mutualLikes,
      query: {'page': page, 'limit': limit},
    );
    return PageResult<MutualCard>.fromJson(
      Map<String, dynamic>.from(data as Map),
      MutualCard.fromJson,
    );
  }

  /// `GET /likes/favorites` — people I favourited.
  Future<PageResult<LikeCard>> favorites({int page = 1, int limit = 20}) async {
    final data = await _api.get(
      ApiConstants.favorites,
      query: {'page': page, 'limit': limit},
    );
    return PageResult<LikeCard>.fromJson(
      Map<String, dynamic>.from(data as Map),
      LikeCard.fromJson,
    );
  }

  /// `GET /likes/quota` — my daily like allowance/usage.
  Future<LikeQuota> quota() async {
    final data = await _api.get(ApiConstants.likesQuota);
    return LikeQuota.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// `POST /likes/quota/unlock` — spends an ad credit for more likes.
  /// Returns the updated quota so callers don't need a separate refetch.
  Future<LikeQuota> unlockQuota() async {
    final data = await _api.post(ApiConstants.likesQuotaUnlock);
    return LikeQuota.fromJson(Map<String, dynamic>.from(data as Map));
  }
}