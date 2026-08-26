import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../core/constants/api_constants.dart';
import '../models/media_model.dart';
import '../services/api_service.dart';

/// Photo/selfie upload and gallery management.
///
/// Upload is the backend's two-phase, direct-to-storage flow:
///   1. `POST /media/upload-url` mints a pending record + presigned PUT URL,
///   2. the client PUTs the bytes straight at storage,
///   3. `POST /media/:id/complete` confirms it and kicks off moderation.
///
/// Phase 2 is the fragile link: the presigned URL is signed for whatever host
/// the API is configured with, which is not always reachable from the device.
/// [uploadPhoto] therefore reports failure as a value rather than throwing, so
/// onboarding can continue and the user can add photos later.
class MediaRepository {
  MediaRepository(this._api);

  final ApiClient _api;

  /// Runs all three phases. Never throws for a storage-side failure — inspect
  /// [UploadResult.succeeded]. Only a failure to mint the slot propagates.
  Future<UploadResult> uploadPhoto({
    required Uint8List bytes,
    required String contentType,
    String type = MediaKind.publicPhoto,
  }) async {
    final UploadSlot slot;
    try {
      final data = await _api.post(
        ApiConstants.mediaUploadUrl,
        body: {'type': type, 'contentType': contentType},
      );
      slot = UploadSlot.fromJson(Map<String, dynamic>.from(data as Map));
    } catch (e) {
      return UploadResult.failure('Could not start the upload: $e');
    }

    try {
      // Straight to storage — deliberately a bare Dio call: our interceptors
      // would attach the API bearer token and try to unwrap an API envelope,
      // and a presigned URL wants neither.
      await Dio().put<void>(
        slot.uploadUrl,
        data: Stream<List<int>>.value(bytes),
        options: Options(
          headers: {
            ...slot.headers,
            Headers.contentLengthHeader: bytes.length,
          },
          contentType: contentType,
        ),
      );
    } catch (e) {
      return UploadResult.failure('Storage did not accept the upload: $e');
    }

    try {
      await _api.post(ApiConstants.mediaComplete(slot.mediaId));
    } catch (e) {
      return UploadResult.failure('Could not confirm the upload: $e');
    }

    return UploadResult.success(slot.mediaId);
  }

  /// `GET /media` — my assets, each with a viewable URL.
  Future<List<MediaAsset>> listMine() async =>
      MediaAsset.listFrom(await _api.get(ApiConstants.media));

  /// `PATCH /media/:id/primary` — set my main card photo.
  Future<MediaAsset> setPrimary(String id) async {
    final data = await _api.patch(ApiConstants.mediaPrimary(id));
    return MediaAsset.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// `DELETE /media/:id`.
  Future<void> delete(String id) => _api.delete(ApiConstants.mediaItem(id));
}
