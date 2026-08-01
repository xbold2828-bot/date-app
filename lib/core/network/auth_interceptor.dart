import 'package:dio/dio.dart';

/// Reads the current access token (may be null when logged out).
typedef TokenReader = Future<String?> Function();

/// Forces a token refresh and returns the new token (or null on failure).
typedef TokenRefresher = Future<String?> Function();

/// Attaches the Supabase access token to every request and transparently
/// refreshes it once on a 401 before retrying.
///
/// Implemented as a plain [Interceptor] (not [QueuedInterceptor]) so the retry
/// `dio.fetch` doesn't deadlock against a serialized queue. Concurrent 401s
/// share a single in-flight refresh via [_refreshing].
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this.dio,
    required this.getToken,
    required this.refreshToken,
  });

  final Dio dio;
  final TokenReader getToken;
  final TokenRefresher refreshToken;

  static const String _retriedKey = 'auth_retried';

  Future<String?>? _refreshing;

  Future<String?> _refreshOnce() =>
      _refreshing ??= refreshToken().whenComplete(() => _refreshing = null);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Public endpoints (health, tags) tolerate a token; attach it whenever a
    // session exists so we never accidentally send unauthenticated calls.
    final token = await getToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final is401 = err.response?.statusCode == 401;
    final alreadyRetried = err.requestOptions.extra[_retriedKey] == true;

    if (!is401 || alreadyRetried) {
      handler.next(err);
      return;
    }

    try {
      final newToken = await _refreshOnce();
      if (newToken == null || newToken.isEmpty) {
        handler.next(err);
        return;
      }

      final options = err.requestOptions
        ..headers['Authorization'] = 'Bearer $newToken'
        ..extra[_retriedKey] = true;

      // Retried request runs the full interceptor chain again (envelope unwrap
      // included), so resolve with its already-processed response.
      final response = await dio.fetch<dynamic>(options);
      handler.resolve(response);
    } catch (_) {
      handler.next(err);
    }
  }
}
