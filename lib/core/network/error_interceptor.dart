import 'package:dio/dio.dart';

import '../errors/app_exceptions.dart';

/// Translates transport failures and the backend error envelope
/// `{ statusCode, error, message, details? }` into typed [AppException]s.
///
/// The mapped exception is attached as `DioException.error`; [ApiClient]
/// unwraps and rethrows it so repositories catch domain exceptions directly.
class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final mapped = _map(err);
    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        response: err.response,
        type: err.type,
        error: mapped,
        message: mapped.message,
      ),
    );
  }

  AppException _map(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const RequestTimeoutException();
      case DioExceptionType.connectionError:
        return const NetworkException();
      case DioExceptionType.badCertificate:
        return const NetworkException('Bad server certificate.');
      case DioExceptionType.cancel:
        return const NetworkException('Request cancelled.');
      case DioExceptionType.unknown:
        if (err.response == null) return const NetworkException();
        break;
      case DioExceptionType.badResponse:
        break;
      default:
        throw Exception('Unknown error');
    }

    final response = err.response;
    final status = response?.statusCode ?? 0;
    final body = response?.data;

    var message = 'Request failed. Please try again.';
    String? errorCode;
    Map<String, dynamic>? details;

    if (body is Map) {
      final rawMsg = body['message'];
      if (rawMsg is List && rawMsg.isNotEmpty) {
        message = rawMsg.map((e) => e.toString()).join('\n');
      } else if (rawMsg is String && rawMsg.isNotEmpty) {
        message = rawMsg;
      }
      errorCode = body['error'] as String?;
      final d = body['details'];
      if (d is Map) details = Map<String, dynamic>.from(d);
    }

    switch (status) {
      case 400:
        return BadRequestException(message, error: errorCode, details: details);
      case 401:
        return UnauthorizedException(message, details);
      case 402:
        return EntitlementRequiredException(message, details: details);
      case 403:
        if (errorCode == 'VerificationRequired') {
          return VerificationRequiredException(message, details);
        }
        if (errorCode == 'PremiumRequired') {
          return PremiumRequiredException(message, details);
        }
        return ForbiddenException(message, error: errorCode, details: details);
      case 404:
        return NotFoundException(message);
      case 409:
        return ConflictException(message);
      case 422:
        return ValidationException(message, details: details);
      case 429:
        return RateLimitedException(message, details: details);
      default:
        if (status >= 500) return ServerException(message, status);
        return UnknownApiException(
          message,
          statusCode: status == 0 ? null : status,
          error: errorCode,
          details: details,
        );
    }
  }
}
