import '../../core/constants/api_constants.dart';
import '../models/profile_model.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';

/// Reads/writes the authenticated user's own account and views other users'
/// public profiles. The first call to [me] provisions the domain user.
class ProfileRepository {
  ProfileRepository(this._api);

  final ApiClient _api;

  /// `GET /users/me` — the full self-view (also provisions the user server-side
  /// on first call).
  Future<MeUser> me() async {
    final data = await _api.get(ApiConstants.usersMe);
    return MeUser.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// `PATCH /users/me/profile` — edit bio and "My vibe" (personality) tags.
  Future<MeUser> updateProfile({
    String? bio,
    List<String>? personalityTags,
  }) async {
    final body = <String, dynamic>{
      if (bio != null) 'bio': bio,
      if (personalityTags != null) 'personalityTags': personalityTags,
    };
    final data = await _api.patch(ApiConstants.usersMeProfile, body: body);
    return MeUser.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// `DELETE /users/me` — soft-delete + PII scrub.
  Future<void> deleteAccount() => _api.delete(ApiConstants.usersMe);

  /// `GET /profiles/:id` — another user's tap-through profile.
  Future<PublicProfile> profile(String userId) async {
    final data = await _api.get(ApiConstants.profile(userId));
    return PublicProfile.fromJson(Map<String, dynamic>.from(data as Map));
  }
}
