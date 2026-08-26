import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/api_constants.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/network/auth_interceptor.dart';
import '../../core/network/envelope_interceptor.dart';
import '../../core/network/error_interceptor.dart';

/// The single HTTP entry point to the backend.
///
/// Wraps Dio and wires the cross-cutting interceptors (auth token, envelope
/// unwrap, error mapping). Every method returns the already-unwrapped payload
/// and throws a typed [AppException] on failure — repositories never see a raw
/// [DioException].
class ApiClient {
  ApiClient({Dio? dio, SupabaseClient? supabase})
      : _dio = dio ?? Dio(),
        _supabase = supabase ?? Supabase.instance.client {
    _dio.options
      ..baseUrl = ApiConstants.baseUrl
      ..connectTimeout = ApiConstants.connectTimeout
      ..receiveTimeout = ApiConstants.receiveTimeout
      ..sendTimeout = ApiConstants.sendTimeout
      ..headers['content-type'] = 'application/json; charset=utf-8'
      ..responseType = ResponseType.json;

    _dio.interceptors.addAll([
      AuthInterceptor(
        dio: _dio,
        getToken: () async => _supabase.auth.currentSession?.accessToken,
        refreshToken: () async {
          final res = await _supabase.auth.refreshSession();
          return res.session?.accessToken;
        },
      ),
      EnvelopeInterceptor(),
      ErrorInterceptor(),
    ]);
  }

  final Dio _dio;
  final SupabaseClient _supabase;

  /// Escape hatch for callers that need the raw Dio (e.g. presigned uploads).
  Dio get raw => _dio;

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => _dio.get<dynamic>(path, queryParameters: query));

  Future<dynamic> post(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) =>
      _send(() => _dio.post<dynamic>(path, data: body, queryParameters: query));

  Future<dynamic> patch(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) =>
      _send(() => _dio.patch<dynamic>(path, data: body, queryParameters: query));

  Future<dynamic> delete(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) =>
      _send(() => _dio.delete<dynamic>(path, data: body, queryParameters: query));

  Future<dynamic> _send(Future<Response<dynamic>> Function() run) async {
    try {
      final res = await run();
      return res.data;
    } on DioException catch (e) {
      final err = e.error;
      if (err is AppException) throw err;
      throw UnknownApiException(e.message ?? 'Request failed. Please try again.');
    }
  }
}
