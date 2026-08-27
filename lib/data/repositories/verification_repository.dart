import '../../core/constants/api_constants.dart';
import '../models/verification_model.dart';
import '../services/api_service.dart';

/// Identity ("live check") verification, which unlocks messaging.
///
/// Verification is never required to finish onboarding — it gates the sensitive
/// preference tags and is offered as its own step the user may skip.
class VerificationRepository {
  VerificationRepository(this._api);

  final ApiClient _api;

  VerificationStatus _status(dynamic data) =>
      VerificationStatus.fromJson(Map<String, dynamic>.from(data as Map));

  /// `POST /verification/session` — begin a live check (no-op if verified).
  Future<VerificationStatus> startSession() async =>
      _status(await _api.post(ApiConstants.verificationSession));

  /// `GET /verification/me` — current status + latest session.
  Future<VerificationStatus> status() async =>
      _status(await _api.get(ApiConstants.verificationMe));

  /// `POST /verification/session/:id/complete` — approve the check.
  ///
  /// Only the mock provider accepts this; a real provider decides via webhook,
  /// which returns 403 here. Callers should treat that as "pending", not an
  /// error, since the check itself already happened on the device.
  Future<VerificationStatus> completeSession(String sessionId) async =>
      _status(await _api.post(ApiConstants.verificationComplete(sessionId)));
}
