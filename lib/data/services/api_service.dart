import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    hide Headers, MultipartFile;

import '../../core/constants/api_constants.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/logger/app_logger.dart';
import '../../core/network/auth_interceptor.dart';
import '../../core/network/envelope_interceptor.dart';
import '../../core/network/error_interceptor.dart';

enum _MultipartMethod { post, patch, put }

/// The single HTTP entry point to the backend.
///
/// Wraps Dio and wires the cross-cutting interceptors (logging, auth token,
/// envelope unwrap, error mapping). Every method returns the already-unwrapped
/// payload and throws a typed [AppException] on failure — repositories never
/// see a raw [DioException].
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
      ..responseType = ResponseType.json
    // We want to inspect every status code ourselves (via ErrorInterceptor)
    // rather than have Dio throw before we've had a chance to log/map it.
      ..validateStatus = (_) => true;

    _dio.interceptors.addAll([
      // Logging goes first so it captures the request exactly as sent and
      // the response exactly as received, before envelope/error touch it.
      _LoggingInterceptor(),
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

  // ============================================================
  // CORE VERBS — JSON in / JSON out
  // ============================================================

  Future<dynamic> get(
      String path, {
        Map<String, dynamic>? query,
        Map<String, dynamic>? headers,
        bool forceRefresh = false,
      }) =>
      _send(
            () => _dio.get<dynamic>(
          path,
          queryParameters: query,
          options: Options(
            headers: {
              if (forceRefresh) 'Cache-Control': 'no-cache',
              ...?headers,
            },
          ),
        ),
      );

  Future<dynamic> post(
      String path, {
        Object? body,
        Map<String, dynamic>? query,
        Map<String, dynamic>? headers,
      }) =>
      _send(
            () => _dio.post<dynamic>(
          path,
          data: body,
          queryParameters: query,
          options: Options(headers: headers),
        ),
      );

  Future<dynamic> put(
      String path, {
        Object? body,
        Map<String, dynamic>? query,
        Map<String, dynamic>? headers,
      }) =>
      _send(
            () => _dio.put<dynamic>(
          path,
          data: body,
          queryParameters: query,
          options: Options(headers: headers),
        ),
      );

  Future<dynamic> patch(
      String path, {
        Object? body,
        Map<String, dynamic>? query,
        Map<String, dynamic>? headers,
      }) =>
      _send(
            () => _dio.patch<dynamic>(
          path,
          data: body,
          queryParameters: query,
          options: Options(headers: headers),
        ),
      );

  Future<dynamic> delete(
      String path, {
        Object? body,
        Map<String, dynamic>? query,
        Map<String, dynamic>? headers,
      }) =>
      _send(
            () => _dio.delete<dynamic>(
          path,
          data: body,
          queryParameters: query,
          options: Options(headers: headers),
        ),
      );

  Future<dynamic> head(
      String path, {
        Map<String, dynamic>? query,
        Map<String, dynamic>? headers,
      }) =>
      _send(
            () => _dio.head<dynamic>(
          path,
          queryParameters: query,
          options: Options(headers: headers),
        ),
      );

  Future<dynamic> options(
      String path, {
        Map<String, dynamic>? query,
        Map<String, dynamic>? headers,
      }) =>
      _send(
            () => _dio.request<dynamic>(
          path,
          queryParameters: query,
          options: Options(method: 'OPTIONS', headers: headers),
        ),
      );

  // ============================================================
  // FORM-URLENCODED POST
  // ============================================================

  Future<dynamic> postFormUrlEncoded(
      String path, {
        required Map<String, dynamic> fields,
        Map<String, dynamic>? headers,
      }) =>
      _send(
            () => _dio.post<dynamic>(
          path,
          data: fields,
          options: Options(
            contentType: Headers.formUrlEncodedContentType,
            headers: headers,
          ),
        ),
      );

  // ============================================================
  // GRAPHQL
  // ============================================================

  Future<dynamic> graphql(
      String path, {
        required String query,
        Map<String, dynamic>? variables,
        Map<String, dynamic>? headers,
      }) =>
      _send(
            () => _dio.post<dynamic>(
          path,
          data: {
            'query': query,
            'variables': ?variables,
          },
          options: Options(
            contentType: Headers.jsonContentType,
            headers: {'Accept': 'application/json', ...?headers},
          ),
        ),
      );

  // ============================================================
  // MULTIPART — dynamic (accepts File on disk or in-memory bytes,
  // so it works on native platforms and Flutter Web alike)
  // ============================================================

  Future<dynamic> postMultipart(
      String path, {
        Map<String, dynamic> fields = const {},
        Map<String, File> files = const {},
        Map<String, MapEntry<Uint8List, String>> fileBytes = const {},
        ProgressCallback? onSendProgress,
        CancelToken? cancelToken,
        Map<String, dynamic>? headers,
      }) =>
      _multipart(
        method: _MultipartMethod.post,
        path: path,
        fields: fields,
        files: files,
        fileBytes: fileBytes,
        onSendProgress: onSendProgress,
        cancelToken: cancelToken,
        headers: headers,
      );

  Future<dynamic> patchMultipart(
      String path, {
        Map<String, dynamic> fields = const {},
        Map<String, File> files = const {},
        Map<String, MapEntry<Uint8List, String>> fileBytes = const {},
        ProgressCallback? onSendProgress,
        CancelToken? cancelToken,
        Map<String, dynamic>? headers,
      }) =>
      _multipart(
        method: _MultipartMethod.patch,
        path: path,
        fields: fields,
        files: files,
        fileBytes: fileBytes,
        onSendProgress: onSendProgress,
        cancelToken: cancelToken,
        headers: headers,
      );

  Future<dynamic> putMultipart(
      String path, {
        Map<String, dynamic> fields = const {},
        Map<String, File> files = const {},
        Map<String, MapEntry<Uint8List, String>> fileBytes = const {},
        ProgressCallback? onSendProgress,
        CancelToken? cancelToken,
        Map<String, dynamic>? headers,
      }) =>
      _multipart(
        method: _MultipartMethod.put,
        path: path,
        fields: fields,
        files: files,
        fileBytes: fileBytes,
        onSendProgress: onSendProgress,
        cancelToken: cancelToken,
        headers: headers,
      );

  Future<dynamic> _multipart({
    required _MultipartMethod method,
    required String path,
    required Map<String, dynamic> fields,
    required Map<String, File> files,
    required Map<String, MapEntry<Uint8List, String>> fileBytes,
    ProgressCallback? onSendProgress,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
  }) async {
    final Map<String, dynamic> data = {...fields};

    for (final entry in files.entries) {
      data[entry.key] = await MultipartFile.fromFile(
        entry.value.path,
        filename: entry.value.path.split('/').last,
      );
    }
    for (final entry in fileBytes.entries) {
      data[entry.key] = MultipartFile.fromBytes(
        entry.value.key,
        filename: entry.value.value,
      );
    }

    final formData = FormData.fromMap(data);
    final opts = Options(
      contentType: 'multipart/form-data',
      headers: headers,
    );

    return _send(() {
      return switch (method) {
        _MultipartMethod.post => _dio.post<dynamic>(
          path,
          data: formData,
          options: opts,
          onSendProgress: onSendProgress,
          cancelToken: cancelToken,
        ),
        _MultipartMethod.patch => _dio.patch<dynamic>(
          path,
          data: formData,
          options: opts,
          onSendProgress: onSendProgress,
          cancelToken: cancelToken,
        ),
        _MultipartMethod.put => _dio.put<dynamic>(
          path,
          data: formData,
          options: opts,
          onSendProgress: onSendProgress,
          cancelToken: cancelToken,
        ),
      };
    });
  }

  // ============================================================
  // DOWNLOAD FILE
  // ============================================================

  Future<void> downloadFile(
      String path, {
        required String savePath,
        Map<String, dynamic>? query,
        ProgressCallback? onReceiveProgress,
        CancelToken? cancelToken,
      }) async {
    try {
      await _dio.download(
        path,
        savePath,
        queryParameters: query,
        onReceiveProgress: onReceiveProgress,
        cancelToken: cancelToken,
        options: Options(responseType: ResponseType.bytes),
      );
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  // ============================================================
  // RAW BYTES
  // ============================================================

  Future<List<int>> getRawBytes(
      String path, {
        Map<String, dynamic>? query,
        CancelToken? cancelToken,
      }) async {
    try {
      final res = await _dio.get<List<int>>(
        path,
        queryParameters: query,
        cancelToken: cancelToken,
        options: Options(responseType: ResponseType.bytes),
      );
      return res.data ?? const [];
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  // ============================================================
  // PLAIN TEXT / HTML / XML
  // ============================================================

  Future<String> getPlainText(
      String path, {
        Map<String, dynamic>? query,
        Map<String, dynamic>? headers,
      }) async {
    try {
      final res = await _dio.get<String>(
        path,
        queryParameters: query,
        options: Options(responseType: ResponseType.plain, headers: headers),
      );
      return res.data ?? '';
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  // ============================================================
  // STREAM (SSE / large payloads)
  // ============================================================

  Future<ResponseBody> getStream(
      String path, {
        Map<String, dynamic>? query,
        CancelToken? cancelToken,
      }) async {
    try {
      final res = await _dio.get<ResponseBody>(
        path,
        queryParameters: query,
        cancelToken: cancelToken,
        options: Options(responseType: ResponseType.stream),
      );
      if (res.data == null) {
        throw const UnknownApiException('Empty stream response');
      }
      return res.data!;
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  // ============================================================
  // CANCELLATION
  // ============================================================

  void cancelRequest(CancelToken token, {String reason = 'Cancelled by user'}) {
    token.cancel(reason);
  }

  // ============================================================
  // RETRY with optional exponential back-off
  // ============================================================

  Future<T> retry<T>(
      Future<T> Function() requestFn, {
        int maxAttempts = 3,
        Duration delay = const Duration(seconds: 2),
        bool exponentialBackoff = true,
        bool Function(Object error)? retryIf,
      }) async {
    int attempt = 0;
    while (true) {
      try {
        return await requestFn();
      } catch (e) {
        attempt++;
        final shouldRetry = retryIf?.call(e) ?? true;
        if (attempt >= maxAttempts || !shouldRetry) rethrow;

        final wait = exponentialBackoff
            ? Duration(
            milliseconds: delay.inMilliseconds * (1 << (attempt - 1)))
            : delay;
        AppLogger.d(
          '🔄 Retry attempt $attempt after ${wait.inMilliseconds}ms',
        );
        await Future.delayed(wait);
      }
    }
  }

  // ============================================================
  // BATCH / CONCURRENT
  // ============================================================

  Future<List<T>> batch<T>(List<Future<T> Function()> requestFns) {
    return Future.wait(requestFns.map((fn) => fn()));
  }

  // ============================================================
  // SEND — runs the request, unwraps errors into AppException
  // ============================================================

  Future<dynamic> _send(Future<Response<dynamic>> Function() run) async {
    try {
      final res = await run();
      return res.data;
    } on DioException catch (e) {
      throw _unwrap(e);
    } on SocketException {
      throw const NetworkException('No internet connection.');
    } on TimeoutException {
      throw const RequestTimeoutException();
    }
  }

  /// [ErrorInterceptor] is expected to have already mapped `e.error` to a
  /// typed [AppException] (that's what `handler.reject(...)` in that
  /// interceptor should set, using the `error` machine code from the
  /// backend envelope). This is the final safety net in case a
  /// [DioException] slips through unmapped — e.g. a call that bypasses
  /// `_send` (download/stream), or a transport failure before the
  /// interceptor chain runs.
  AppException _unwrap(DioException e) {
    final err = e.error;
    if (err is AppException) return err;
    return _fallbackMap(e);
  }

  AppException _fallbackMap(DioException e) {
    final response = e.response;
    if (response != null) {
      final status = response.statusCode;
      final data = response.data;

      // Prefer the backend's machine code / envelope shape when present —
      // mirrors what ErrorInterceptor does on the happy path.
      if (data is Map) {
        final code = data['error']?.toString();
        final message = data['message']?.toString();
        final details = data['details'] is Map
            ? Map<String, dynamic>.from(data['details'] as Map)
            : null;

        switch (code) {
          case 'EntitlementRequired':
            return EntitlementRequiredException(
              message ?? 'This action requires Premium or ad credits.',
              details: details,
            );
          case 'VerificationRequired':
            return VerificationRequiredException(
              message ??
                  'Identity verification is required for this action.',
              details,
            );
          case 'PremiumRequired':
            return PremiumRequiredException(
              message ?? 'This feature requires Premium.',
              details,
            );
          case 'ContentRejected':
            return ContentRejectedException(
              message ?? 'That content was not accepted.',
              details: details,
            );
          case 'TooManyRequests':
            return RateLimitedException(
              message ?? 'Too many requests. Please slow down.',
              details: details,
            );
        }

        final flatMessage = message ??
            data['error']?.toString() ??
            data['detail']?.toString() ??
            'Server error ($status)';

        return switch (status) {
          400 => BadRequestException(flatMessage, error: code, details: details),
          401 => const UnauthorizedException(),
          403 => ForbiddenException(flatMessage, error: code, details: details),
          404 => const NotFoundException(),
          405 => UnknownApiException('Method not allowed.', statusCode: 405, error: code),
          408 => const RequestTimeoutException(),
          409 => ConflictException(flatMessage),
          410 => const NotFoundException('Resource no longer available.'),
          413 => UnknownApiException('Payload too large.', statusCode: 413, error: code),
          415 => UnknownApiException('Unsupported media type.', statusCode: 415, error: code),
          422 => ValidationException(flatMessage, details: details),
          429 => RateLimitedException(flatMessage, details: details),
          500 => const ServerException(),
          501 => const ServerException('Feature not implemented on server.', 501),
          502 => const ServerException('Bad gateway. Server is down.', 502),
          503 => const ServerException('Service temporarily unavailable.', 503),
          504 => const ServerException('Gateway timeout.', 504),
          _ => UnknownApiException(flatMessage, statusCode: status, error: code),
        };
      }

      final fallback = data is String && data.isNotEmpty
          ? data
          : 'Server error ($status)';
      return UnknownApiException(fallback, statusCode: status);
    }

    return switch (e.type) {
      DioExceptionType.connectionTimeout => const NetworkException(
        'Connection timed out. Check your network.',
      ),
      DioExceptionType.receiveTimeout => const RequestTimeoutException(
        'Server took too long to respond.',
      ),
      DioExceptionType.sendTimeout => const RequestTimeoutException(
        'Upload timed out. Check your network.',
      ),
      DioExceptionType.connectionError => const NetworkException(),
      DioExceptionType.cancel => const UnknownApiException(
        'Request was cancelled.',
      ),
      DioExceptionType.badCertificate => const NetworkException(
        'SSL certificate error. Connection not secure.',
      ),
      DioExceptionType.badResponse => const UnknownApiException(
        'Received an invalid response from server.',
      ),
      DioExceptionType.unknown => UnknownApiException(
        e.message ?? 'An unknown error occurred.',
      ),
      DioExceptionType.transformTimeout => const RequestTimeoutException(
        'Transform timed out.',
      ),
    };
  }
}

// ============================================================
// LOGGING INTERCEPTOR
// Prints method, full URL, headers, query and body on every request,
// and status + payload on every response/error, via AppLogger — chunked
// so long bodies don't get truncated by the log line-length limit.
// ============================================================
class _LoggingInterceptor extends Interceptor {
  static const int _chunkSize = 1000;

  void _log(String message) {
    for (var i = 0; i < message.length; i += _chunkSize) {
      final end =
      (i + _chunkSize < message.length) ? i + _chunkSize : message.length;
      AppLogger.d(message.substring(i, end));
    }
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _log('➡️ ${options.method} ${options.uri}');
    _log('Headers → ${options.headers}');
    _log('Query   → ${options.queryParameters}');
    _log('Body    → ${_describeBody(options.data)}');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _log(
      '✅ STATUS → ${response.statusCode} ${response.requestOptions.method} ${response.requestOptions.uri}',
    );
    _log('Response → ${response.data}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _log(
      '❌ ERROR    → ${err.requestOptions.method} ${err.requestOptions.uri} :: ${err.message}',
    );
    _log('❌ RESPONSE → ${err.response?.data}');
    handler.next(err);
  }

  String _describeBody(dynamic data) {
    if (data is FormData) {
      final fields = {for (final f in data.fields) f.key: f.value};
      final files = {
        for (final f in data.files)
          f.key:
          'File(filename: ${f.value.filename}, size: ${f.value.length} bytes)',
      };
      return 'FormData(fields: $fields, files: $files)';
    }
    return '$data';
  }
}