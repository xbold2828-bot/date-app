/// One instruction in the liveness check ("Turn your head to the left").
class VerificationStep {
  final int order;
  final String instruction;

  const VerificationStep({required this.order, required this.instruction});

  factory VerificationStep.fromJson(Map<String, dynamic> json) =>
      VerificationStep(
        order: (json['order'] as num?)?.toInt() ?? 0,
        instruction: json['instruction'] as String? ?? '',
      );
}

/// A live-check session from `POST /verification/session`.
class VerificationSession {
  final String sessionId;
  final String provider;
  final String status;
  final String? redirectUrl;
  final String? clientToken;
  final List<VerificationStep> steps;

  const VerificationSession({
    required this.sessionId,
    required this.provider,
    required this.status,
    this.redirectUrl,
    this.clientToken,
    this.steps = const [],
  });

  /// The mock provider is completed client-side via
  /// `POST /verification/session/:id/complete`; real providers decide by webhook.
  bool get isMock => provider == 'mock';

  factory VerificationSession.fromJson(Map<String, dynamic> json) =>
      VerificationSession(
        sessionId: json['sessionId'] as String? ?? '',
        provider: json['provider'] as String? ?? '',
        status: json['status'] as String? ?? '',
        redirectUrl: json['redirectUrl'] as String?,
        clientToken: json['clientToken'] as String?,
        steps: (json['steps'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => VerificationStep.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

/// My verification state from `GET /verification/me`.
class VerificationStatus {
  final bool verified;
  final String verificationStatus;
  final bool alreadyVerified;
  final VerificationSession? session;

  const VerificationStatus({
    required this.verified,
    required this.verificationStatus,
    this.alreadyVerified = false,
    this.session,
  });

  factory VerificationStatus.fromJson(Map<String, dynamic> json) =>
      VerificationStatus(
        verified: json['verified'] as bool? ?? false,
        verificationStatus: json['verificationStatus'] as String? ?? 'unverified',
        alreadyVerified: json['alreadyVerified'] as bool? ?? false,
        session: json['session'] == null
            ? null
            : VerificationSession.fromJson(
                Map<String, dynamic>.from(json['session'] as Map),
              ),
      );
}
