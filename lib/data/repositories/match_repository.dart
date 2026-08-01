import '../../core/constants/api_constants.dart';
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

  /// `GET /likes/liked-you` — gated grid of people who liked me.
  Future<LikedYouPage> likedYou({int page = 1, int limit = 20}) async {
    final data = await _api.get(
      ApiConstants.likedYou,
      query: {'page': page, 'limit': limit},
    );
    return LikedYouPage.fromJson(Map<String, dynamic>.from(data as Map));
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
}
