import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../core/constants/api_constants.dart';
import '../models/verification_model.dart';
import '../services/api_service.dart';

/// The live face check: start one, upload its four photos, submit.
///
/// Verification is never required to finish onboarding. It earns the tick,
/// and — when the server turns the gate on — unlocks messaging and the step-6
/// tags.
class VerificationRepository {
  VerificationRepository(this._api, {Dio? storage})
    : _storage = storage ?? Dio();

  final ApiClient _api;

  /// For the presigned PUTs. A bare client on purpose, as with media uploads:
  /// our interceptors would attach the API bearer token and try to unwrap an
  /// API envelope, and a presigned URL wants neither.
  final Dio _storage;

  Map<String, dynamic> _map(dynamic data) =>
      Map<String, dynamic>.from(data as Map);

  /// `GET /verification/me`.
  Future<VerificationStatus> status() async =>
      VerificationStatus.fromJson(_map(await _api.get(ApiConstants.verificationMe)));

  /// `POST /verification/session` — the order of actions and the upload slots.
  ///
  /// Call it only from the tap that agrees to the check: the server records
  /// this request as the person's consent, and refuses one without it.
  Future<VerificationStart> start() async => VerificationStart.fromJson(
    _map(
      await _api.post(
        ApiConstants.verificationSession,
        body: const {'consent': true},
      ),
    ),
  );

  /// PUT one JPEG straight to storage, with the headers the URL was signed for.
  Future<void> upload(FrameUpload slot, Uint8List jpeg) => _storage.put<void>(
    slot.url,
    data: Stream<List<int>>.value(jpeg),
    options: Options(
      headers: {...slot.headers, Headers.contentLengthHeader: jpeg.length},
      contentType: slot.headers['Content-Type'] ?? 'image/jpeg',
    ),
  );

  /// `POST /verification/session/:id/submit`. Safe to repeat: a decided
  /// session gives the same answer, and one still being checked answers 409.
  Future<VerificationResult> submit(String sessionId) async =>
      VerificationResult.fromJson(
        _map(await _api.post(ApiConstants.verificationSubmit(sessionId))),
      );
}
