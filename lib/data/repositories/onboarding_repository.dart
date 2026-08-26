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

  /// Step 8 — `PATCH /onboarding/photo`.
  ///
  /// A successful media upload already completes this step server-side; call
  /// this when the user skipped or the upload failed, so the funnel can finish
  /// and photos can be added later from the profile screen.
  Future<MeUser> completePhotoStep({bool skipped = false}) async =>
      _me(await _api.patch(ApiConstants.onboardingPhoto,
          body: {'skipped': skipped}));

  /// Step 9 — `PATCH /location`.
  ///
  /// The endpoint also takes a `preferredBand`, which this app no longer
  /// sends: the search radius is not something anyone is asked to choose, so
  /// there is no value to put there. See [BasicsScreen5].
  Future<MeUser> updateLocation({
    required double latitude,
    required double longitude,
    String? city,
  }) async {
    final body = <String, dynamic>{
      'latitude': latitude,
      'longitude': longitude,
      if (city != null) 'city': city,
    };
    return _me(await _api.patch(ApiConstants.location, body: body));
  }

  /// Step 10 — `POST /onboarding/agreement`.
  ///
  /// All four must be true; the API rejects anything else, and the screen keeps
  /// its button disabled until they are. What is sent is what the person
  /// actually ticked rather than four hard-coded `true`s — the acceptance is
  /// stored as a consent record, and a record that cannot say no is not
  /// evidence that anyone said yes.
  ///
  /// The server stamps the timestamp and the policy version; neither is sent
  /// from here.
  Future<MeUser> acceptAgreement({
    required bool isAdult,
    required bool willBeRespectful,
    required bool noHarassment,
    required bool consentMatters,
  }) async =>
      _me(
        await _api.post(
          ApiConstants.onboardingAgreement,
          body: {
            'isAdult': isAdult,
            'willBeRespectful': willBeRespectful,
            'noHarassment': noHarassment,
            'consentMatters': consentMatters,
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
