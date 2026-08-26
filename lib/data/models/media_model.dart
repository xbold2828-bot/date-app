/// Gallery cap, mirroring `MediaService.MAX_PUBLIC_PHOTOS`. The server rejects
/// the 6th upload, so the UI stops offering one and points at deleting instead.
const int kMaxPublicPhotos = 5;

/// Media kinds the backend accepts (`MediaType` on the API).
class MediaKind {
  MediaKind._();

  /// Checked against the verification provider; never shown publicly.
  static const String verifiedSelfie = 'verified_selfie';

  /// Public gallery photo (SFW).
  static const String publicPhoto = 'public_photo';

  /// Spicier media, unlocked for another user only after they reply.
  static const String privatePhoto = 'private_photo';
}

/// A presigned upload slot from `POST /media/upload-url`.
class UploadSlot {
  final String mediaId;
  final String uploadUrl;
  final String key;
  final Map<String, String> headers;
  final int expiresIn;

  const UploadSlot({
    required this.mediaId,
    required this.uploadUrl,
    required this.key,
    this.headers = const {},
    this.expiresIn = 0,
  });

  factory UploadSlot.fromJson(Map<String, dynamic> json) => UploadSlot(
        mediaId: json['mediaId'] as String? ?? '',
        uploadUrl: json['uploadUrl'] as String? ?? '',
        key: json['key'] as String? ?? '',
        headers: (json['headers'] as Map?)?.map(
              (k, v) => MapEntry(k.toString(), v.toString()),
            ) ??
            const {},
        expiresIn: (json['expiresIn'] as num?)?.toInt() ?? 0,
      );
}

/// A stored media asset as returned by `GET /media`.
class MediaAsset {
  final String id;
  final String type;
  final String visibility;
  final String status;
  final String url;
  final String contentType;

  const MediaAsset({
    required this.id,
    required this.type,
    required this.visibility,
    required this.status,
    required this.url,
    required this.contentType,
  });

  bool get isPublicPhoto => type == MediaKind.publicPhoto;
  bool get isApproved => status == 'approved';
  bool get isPending => status == 'pending';

  factory MediaAsset.fromJson(Map<String, dynamic> json) => MediaAsset(
        id: json['id'] as String? ?? '',
        type: json['type'] as String? ?? '',
        visibility: json['visibility'] as String? ?? '',
        status: json['status'] as String? ?? '',
        url: json['url'] as String? ?? '',
        contentType: json['contentType'] as String? ?? '',
      );

  static List<MediaAsset> listFrom(dynamic data) => (data as List? ?? const [])
      .whereType<Map>()
      .map((e) => MediaAsset.fromJson(Map<String, dynamic>.from(e)))
      .toList();
}

/// Outcome of one upload attempt.
///
/// Uploads are deliberately non-fatal during onboarding: object storage may be
/// unreachable from the client (presigned URLs can point at a host the device
/// can't resolve), and that must never block the funnel. [failureReason] is set
/// when the binary didn't make it, so the UI can say so without throwing.
class UploadResult {
  final bool succeeded;
  final String? mediaId;
  final String? failureReason;

  const UploadResult.success(this.mediaId)
      : succeeded = true,
        failureReason = null;

  const UploadResult.failure(this.failureReason)
      : succeeded = false,
        mediaId = null;
}
