/// What the server asks for after the straight-on photo
/// (`challenge` in `POST /verification/session`), in its order.
enum ChallengeAction {
  turn,
  blink,
  smile;

  static ChallengeAction? fromWire(String value) =>
      values.where((a) => a.name == value).firstOrNull;
}

/// The four photos the server checks, by the names it uploads them under.
enum FramePose {
  straight('straight'),
  turn1('turn_1'),
  turn2('turn_2'),
  smile('smile');

  const FramePose(this.wire);

  final String wire;

  static FramePose? fromWire(String value) =>
      values.where((p) => p.wire == value).firstOrNull;
}

/// My verification state from `GET /verification/me`.
class VerificationStatus {
  final bool verified;
  final String verificationStatus;

  /// False when the server can't run checks right now (not configured) —
  /// starting one would only answer 503.
  final bool available;

  /// When the current verification was granted.
  final DateTime? verifiedAt;

  /// When it lapses unless renewed — the photos are kept 12 months at most.
  final DateTime? verifiedUntil;

  const VerificationStatus({
    required this.verified,
    required this.verificationStatus,
    this.available = true,
    this.verifiedAt,
    this.verifiedUntil,
  });

  factory VerificationStatus.fromJson(Map<String, dynamic> json) =>
      VerificationStatus(
        verified: json['verified'] as bool? ?? false,
        verificationStatus:
            json['verificationStatus'] as String? ?? 'unverified',
        available: json['available'] as bool? ?? true,
        verifiedAt: DateTime.tryParse(json['verifiedAt'] as String? ?? ''),
        verifiedUntil: DateTime.tryParse(
          json['verifiedUntil'] as String? ?? '',
        ),
      );
}

/// Where to PUT one photo, and the headers the presigned URL was signed with.
class FrameUpload {
  final FramePose pose;
  final String url;
  final Map<String, String> headers;

  const FrameUpload({
    required this.pose,
    required this.url,
    this.headers = const {},
  });
}

/// A started check from `POST /verification/session`.
class VerificationStart {
  final String sessionId;

  /// What to ask for after the straight-on photo, in this order.
  final List<ChallengeAction> challenge;
  final List<FrameUpload> uploads;

  const VerificationStart({
    required this.sessionId,
    required this.challenge,
    required this.uploads,
  });

  /// Unknown actions and poses are dropped rather than guessed at. If that
  /// leaves the challenge short, [FaceChallenge] falls back to a full order;
  /// a missing upload slot fails the submit with a clear message.
  factory VerificationStart.fromJson(Map<String, dynamic> json) =>
      VerificationStart(
        sessionId: json['sessionId'] as String? ?? '',
        challenge: [
          for (final action in json['challenge'] as List? ?? const [])
            ?ChallengeAction.fromWire('$action'),
        ],
        uploads: [
          for (final raw in (json['uploads'] as List? ?? const []).whereType<Map>())
            if (FramePose.fromWire('${raw['pose']}') case final pose?)
              FrameUpload(
                pose: pose,
                url: raw['url'] as String? ?? '',
                headers: {
                  for (final MapEntry(:key, :value)
                      in (raw['headers'] as Map? ?? const {}).entries)
                    '$key': '$value',
                },
              ),
        ],
      );
}

/// How a submitted check came out.
enum VerificationOutcome {
  verified,
  rejected,

  /// The photos passed, but some profile photos don't show this person.
  photosBlocking;

  static VerificationOutcome fromWire(String? value) => switch (value) {
    'verified' => verified,
    'photos_blocking' => photosBlocking,
    _ => rejected,
  };
}

/// A profile photo standing between the person and the tick.
class BlockingPhoto {
  final String mediaId;

  /// `not_you` or `unreadable`.
  final String reason;

  const BlockingPhoto({required this.mediaId, required this.reason});

  bool get isUnreadable => reason == 'unreadable';
}

/// The answer from `POST /verification/session/:id/submit`.
class VerificationResult {
  final VerificationOutcome outcome;
  final bool verified;

  /// What to tell the person when [outcome] isn't verified.
  final String? message;
  final List<BlockingPhoto> blockingPhotos;

  const VerificationResult({
    required this.outcome,
    required this.verified,
    this.message,
    this.blockingPhotos = const [],
  });

  factory VerificationResult.fromJson(Map<String, dynamic> json) =>
      VerificationResult(
        outcome: VerificationOutcome.fromWire(json['outcome'] as String?),
        verified: json['verified'] as bool? ?? false,
        message: json['message'] as String?,
        blockingPhotos: [
          for (final raw
              in (json['blockingPhotos'] as List? ?? const []).whereType<Map>())
            BlockingPhoto(
              mediaId: raw['mediaId'] as String? ?? '',
              reason: raw['reason'] as String? ?? 'not_you',
            ),
        ],
      );
}
