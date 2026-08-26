/// Typed exceptions mapped from the backend error envelope
/// `{ statusCode, error, message, details?, path, requestId, timestamp }`
/// by the [ErrorInterceptor]. UI layers catch these to render the right state
/// (paywall, verify gate, retry countdown, etc.).
class AppException implements Exception {
  /// Human-readable message (already flattened if the backend sent a list).
  final String message;

  /// HTTP status code, when the failure came from a server response.
  final int? statusCode;

  /// Backend machine code, e.g. `EntitlementRequired`, `VerificationRequired`.
  final String? error;

  /// Optional structured payload (paywall options, retry seconds, …).
  final Map<String, dynamic>? details;

  const AppException(
    this.message, {
    this.statusCode,
    this.error,
    this.details,
  });

  @override
  String toString() =>
      'AppException(${statusCode ?? '-'} ${error ?? ''}): $message';
}

/// No response reached us (offline, DNS, connection refused, cleartext blocked).
class NetworkException extends AppException {
  const NetworkException([
    String message = 'Network error. Please check your connection.',
  ]) : super(message);
}

/// The request exceeded its timeout. (Named to avoid clashing with
/// `dart:async`'s `TimeoutException`.)
class RequestTimeoutException extends AppException {
  const RequestTimeoutException([
    String message = 'The request timed out. Please try again.',
  ]) : super(message);
}

/// 400 — malformed request (bad slug, missing conditional field, no location).
class BadRequestException extends AppException {
  const BadRequestException(
    String message, {
    String? error,
    Map<String, dynamic>? details,
  }) : super(message, statusCode: 400, error: error, details: details);
}

/// 401 — missing/invalid/expired Supabase token.
class UnauthorizedException extends AppException {
  const UnauthorizedException([
    String message = 'Your session has expired. Please sign in again.',
    Map<String, dynamic>? details,
  ]) : super(message, statusCode: 401, error: 'Unauthorized', details: details);
}

/// 402 — premium or ad credits required. [details] carries
/// `{ reason, action, cost, balance, options: ['premium'|'watch_ad'] }`.
class EntitlementRequiredException extends AppException {
  const EntitlementRequiredException(
    String message, {
    Map<String, dynamic>? details,
  }) : super(
          message,
          statusCode: 402,
          error: 'EntitlementRequired',
          details: details,
        );

  /// `['premium', 'watch_ad']` etc.
  List<String> get options =>
      (details?['options'] as List?)?.cast<String>() ?? const [];

  int get cost => (details?['cost'] as num?)?.toInt() ?? 0;
  int get balance => (details?['balance'] as num?)?.toInt() ?? 0;
  String? get reason => details?['reason'] as String?;
}

/// 403 — identity verification required to message / set the adult layer.
class VerificationRequiredException extends AppException {
  const VerificationRequiredException([
    String message = 'Identity verification is required for this action.',
    Map<String, dynamic>? details,
  ]) : super(
          message,
          statusCode: 403,
          error: 'VerificationRequired',
          details: details,
        );
}

/// 403 — a premium-only feature (advanced discovery filters).
class PremiumRequiredException extends AppException {
  const PremiumRequiredException([
    String message = 'This feature requires Premium.',
    Map<String, dynamic>? details,
  ]) : super(
          message,
          statusCode: 403,
          error: 'PremiumRequired',
          details: details,
        );
}

/// 403 — any other forbidden case (admin route, etc.).
class ForbiddenException extends AppException {
  const ForbiddenException(
    String message, {
    String? error,
    Map<String, dynamic>? details,
  }) : super(message, statusCode: 403, error: error, details: details);
}

/// 404 — not found, or hidden because blocked/inactive.
class NotFoundException extends AppException {
  const NotFoundException([String message = 'Not found.'])
      : super(message, statusCode: 404, error: 'NotFound');
}

/// 409 — duplicate key / conflicting state.
class ConflictException extends AppException {
  const ConflictException([String message = 'This already exists.'])
      : super(message, statusCode: 409, error: 'Conflict');
}

/// 422 — DTO validation failure.
class ValidationException extends AppException {
  const ValidationException(
    String message, {
    Map<String, dynamic>? details,
  }) : super(message, statusCode: 422, error: 'ValidationError', details: details);
}

/// 422 `ContentRejected` — automated moderation refused a photo, bio or
/// message.
///
/// Distinct from [ValidationException] because the two need different words:
/// a validation failure is "you typed it wrong", this is "we won't publish
/// that". [message] is already the user-facing sentence — the server picks it
/// per surface and it should be shown as-is.
///
/// [details] carries `{ reason: 'CONTENT_REJECTED', surface }` and nothing
/// more. The categories that tripped are deliberately withheld server-side, so
/// there is no per-category breakdown to render and no way to probe for one.
class ContentRejectedException extends AppException {
  const ContentRejectedException(
    String message, {
    Map<String, dynamic>? details,
  }) : super(
          message,
          statusCode: 422,
          error: 'ContentRejected',
          details: details,
        );

  /// `public_photo` | `private_photo` | `verified_selfie` | `bio` | `message`.
  String? get surface => details?['surface'] as String?;

  bool get isPhoto => surface?.contains('photo') == true || surface == 'verified_selfie';
}

/// 429 — rate limit, ad daily cap, or New-Energy message cap.
class RateLimitedException extends AppException {
  const RateLimitedException(
    String message, {
    Map<String, dynamic>? details,
  }) : super(
          message,
          statusCode: 429,
          error: 'TooManyRequests',
          details: details,
        );

  /// Seconds to wait before retrying, when the server supplied it.
  int? get retryAfterSeconds =>
      (details?['retryAfterSeconds'] as num?)?.toInt();

  /// e.g. `AD_DAILY_LIMIT_REACHED`, `NEW_ENERGY_CAP`.
  String? get reason => details?['reason'] as String?;
}

/// 5xx — server fault.
class ServerException extends AppException {
  const ServerException([
    String message = 'Something went wrong on our end. Please try again.',
    int statusCode = 500,
  ]) : super(message, statusCode: statusCode, error: 'ServerError');
}

/// Why the device could not give us a position.
///
/// Kept separate from the message so a screen can offer the right way out —
/// "open settings" reads as nonsense when the user simply hasn't been asked yet.
enum LocationFailure {
  /// The OS location toggle is off. Nothing to prompt for.
  serviceDisabled,

  /// Asked, and declined this time.
  denied,

  /// Declined permanently — only Settings can undo it.
  deniedForever,

  /// Permission granted, but the fix failed or timed out.
  unavailable,
}

/// The device refused, or failed, to produce a position.
///
/// Not an API failure, so it deliberately carries no status code — but it
/// extends [AppException] so the screens that already `on AppException catch`
/// keep working without a second catch clause.
class LocationUnavailableException extends AppException {
  const LocationUnavailableException(this.reason, String message)
      : super(message, error: 'LocationUnavailable');

  final LocationFailure reason;

  /// Whether asking again could plausibly succeed.
  bool get isRetryable => reason != LocationFailure.deniedForever;
}

/// Fallback for anything not otherwise classified.
class UnknownApiException extends AppException {
  const UnknownApiException(
    String message, {
    int? statusCode,
    String? error,
    Map<String, dynamic>? details,
  }) : super(message, statusCode: statusCode, error: error, details: details);
}
