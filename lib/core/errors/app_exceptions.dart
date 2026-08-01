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

/// Fallback for anything not otherwise classified.
class UnknownApiException extends AppException {
  const UnknownApiException(
    String message, {
    int? statusCode,
    String? error,
    Map<String, dynamic>? details,
  }) : super(message, statusCode: statusCode, error: error, details: details);
}
