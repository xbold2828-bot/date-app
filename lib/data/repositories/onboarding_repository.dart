import '../../core/constants/api_constants.dart';
import '../models/tag_model.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';

/// The onboarding funnel + location + tag catalogue. Every mutating step
/// returns the updated self-view ([MeUser]) with fresh progress, so callers can
/// push it straight into `meProvider`.
class OnboardingRepository {
  OnboardingRepository(this._api);

  final ApiClient _api;

  MeUser _me(dynamic data) => MeUser.fromJson(Map<String, dynamic>.from(data as Map));

  /// `GET /onboarding/status` — resume progress.
  Future<OnboardingProgress> status() async {
    final data = await _api.get(ApiConstants.onboardingStatus);
    return OnboardingProgress.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// Step 1 — `PATCH /onboarding/age`. [dob] is an ISO date (e.g. 1996-07-14).
  Future<MeUser> updateAge(String dob) async =>
      _me(await _api.patch(ApiConstants.onboardingAge, body: {'dob': dob}));

  /// Step 2 — `PATCH /onboarding/basics`.
  Future<MeUser> updateBasics({
    required String displayName,
    required String gender,
    String? genderSelfDescribe,
    required List<String> pronouns,
    String? pronounsCustom,
    required List<String> showMe,
    String? bio,
  }) async {
    final body = <String, dynamic>{
      'displayName': displayName,
      'gender': gender,
      'pronouns': pronouns,
      'showMe': showMe,
      if (genderSelfDescribe != null) 'genderSelfDescribe': genderSelfDescribe,
      if (pronounsCustom != null) 'pronounsCustom': pronounsCustom,
      if (bio != null) 'bio': bio,
    };
    return _me(await _api.patch(ApiConstants.onboardingBasics, body: body));
  }

  /// Step 3 — `PATCH /onboarding/intent`.
  Future<MeUser> updateIntent(List<String> intent) async =>
      _me(await _api.patch(ApiConstants.onboardingIntent, body: {'intent': intent}));

  /// Step 4 — `PATCH /onboarding/status`.
  Future<MeUser> updateRelationshipStatus(String relationshipStatus) async => _me(
        await _api.patch(
          ApiConstants.onboardingStatus,
          body: {'relationshipStatus': relationshipStatus},
        ),
      );

  /// Step 5 — `PATCH /onboarding/personality`.
  Future<MeUser> updatePersonality(List<String> tags) async =>
      _me(await _api.patch(ApiConstants.onboardingPersonality, body: {'tags': tags}));

  /// Step 6 — `PATCH /onboarding/preferences` (sensitive tags require verification).
  Future<MeUser> updatePreferences(List<String> tags) async =>
      _me(await _api.patch(ApiConstants.onboardingPreferences, body: {'tags': tags}));

  /// Step 7 — `PATCH /onboarding/hard-nos`.
  Future<MeUser> updateHardNos(List<String> tags, {bool? showOnProfile}) async {
    final body = <String, dynamic>{
      'tags': tags,
      if (showOnProfile != null) 'showOnProfile': showOnProfile,
    };
    return _me(await _api.patch(ApiConstants.onboardingHardNos, body: body));
  }

  /// Step 9 — `PATCH /location`.
  Future<MeUser> updateLocation({
    required double latitude,
    required double longitude,
    String? preferredBand,
    String? city,
  }) async {
    final body = <String, dynamic>{
      'latitude': latitude,
      'longitude': longitude,
      if (preferredBand != null) 'preferredBand': preferredBand,
      if (city != null) 'city': city,
    };
    return _me(await _api.patch(ApiConstants.location, body: body));
  }

  /// Step 10 — `POST /onboarding/agreement` (all four must be true).
  Future<MeUser> acceptAgreement() async => _me(
        await _api.post(
          ApiConstants.onboardingAgreement,
          body: {
            'isAdult': true,
            'willBeRespectful': true,
            'noHarassment': true,
            'consentMatters': true,
          },
        ),
      );

  /// `GET /tags` — the tag catalogue (optionally filtered by category).
  Future<List<Tag>> tags({String? category}) async {
    final data = await _api.get(
      ApiConstants.tags,
      query: category == null ? null : {'category': category},
    );
    return Tag.listFrom(data);
  }
}
