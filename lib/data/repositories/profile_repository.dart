import 'package:dating_app/core/logger/app_logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/api_constants.dart';
import '../../providers/is_user_have_premium_provider.dart';
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
  Future<MeUser> me(Ref ref) async {
    final data = await _api.get(ApiConstants.usersMe);
   final response= MeUser.fromJson(Map<String, dynamic>.from(data as Map));
    ref.read(isUserHavePremiumProvider.notifier).state = response.premium.isActive;
    AppLogger.d("Is user premium: ${ref.read(isUserHavePremiumProvider)}");

    return response;
  }

  /// `PATCH /users/me/profile` — edit bio and "My vibe" (personality) tags.
  Future<MeUser> updateProfile({
    String? bio,
    List<String>? personalityTags,
  }) async {
    final body = <String, dynamic>{
      'bio': ?bio,
      'personalityTags': ?personalityTags,
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

  /// `GET /profiles/me/stats` — my visit and like counts.
  Future<ProfileStats> myStats() async {
    final data = await _api.get(ApiConstants.myProfileStats);
    return ProfileStats.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// `POST /profiles/:id/view` — count a visit to someone's profile.
  ///
  /// Deliberately swallows every failure. This is fired from a card tap that is
  /// already opening a sheet; a counter that could not be incremented is not
  /// worth an error in front of the person who tapped, and the server
  /// deduplicates repeats anyway.
  Future<void> recordView(String userId) async {
    try {
      await _api.post(ApiConstants.profileView(userId));
    } catch (_) {
      // Counted or not, the profile still opens.
    }
  }
}
