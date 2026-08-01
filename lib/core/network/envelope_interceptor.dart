import 'package:dio/dio.dart';

/// Unwraps the backend success envelope so callers work with the payload
/// directly.
///
/// The API wraps every 2xx body as
/// `{ success: true, data: <payload>, requestId, timestamp }`. After this
/// interceptor, `response.data == <payload>`. Bodies that don't match the
/// envelope shape (e.g. a raw S3 upload response) are left untouched.
class EnvelopeInterceptor extends Interceptor {
  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    final body = response.data;
    if (body is Map && body['success'] == true && body.containsKey('data')) {
      response.data = body['data'];
    }
    handler.next(response);
  }
}
