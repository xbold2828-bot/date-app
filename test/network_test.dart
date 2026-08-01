import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

import 'package:dating_app/core/errors/app_exceptions.dart';
import 'package:dating_app/core/network/envelope_interceptor.dart';
import 'package:dating_app/core/network/error_interceptor.dart';

/// Exercises the envelope-unwrap and error-mapping interceptors against stubbed
/// backend responses (no live server, no Supabase).
void main() {
  late Dio dio;
  late DioAdapter adapter;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://test.local'));
    dio.interceptors.add(EnvelopeInterceptor());
    dio.interceptors.add(ErrorInterceptor());
    adapter = DioAdapter(dio: dio);
  });

  Future<AppException> expectError(String path) async {
    try {
      await dio.get<dynamic>(path);
      fail('expected the request to throw');
    } on DioException catch (e) {
      return e.error as AppException;
    }
  }

  test('unwraps the success envelope to the payload', () async {
    adapter.onGet(
      '/me',
      (server) => server.reply(200, {
        'success': true,
        'data': {'id': 'u1'},
        'timestamp': 't',
      }),
    );
    final res = await dio.get<dynamic>('/me');
    expect(res.data, {'id': 'u1'});
  });

  test('maps 402 → EntitlementRequiredException with unlock options', () async {
    adapter.onGet(
      '/discovery/nearby',
      (server) => server.reply(402, {
        'statusCode': 402,
        'error': 'EntitlementRequired',
        'message': 'Premium or ad credits are required to continue',
        'details': {
          'reason': 'NEARBY_LIMIT_REACHED',
          'cost': 1,
          'balance': 0,
          'options': ['premium', 'watch_ad'],
        },
      }),
    );
    final err = await expectError('/discovery/nearby');
    expect(err, isA<EntitlementRequiredException>());
    final e = err as EntitlementRequiredException;
    expect(e.options, ['premium', 'watch_ad']);
    expect(e.reason, 'NEARBY_LIMIT_REACHED');
  });

  test('maps 403 VerificationRequired', () async {
    adapter.onGet(
      '/messaging/open',
      (server) => server.reply(403, {
        'statusCode': 403,
        'error': 'VerificationRequired',
        'message': 'Verify your identity to send messages',
        'details': {'reason': 'VERIFICATION_REQUIRED', 'options': ['verify']},
      }),
    );
    expect(await expectError('/messaging/open'),
        isA<VerificationRequiredException>());
  });

  test('maps 403 PremiumRequired', () async {
    adapter.onGet(
      '/discovery/nearby',
      (server) => server.reply(403, {
        'statusCode': 403,
        'error': 'PremiumRequired',
        'message': 'This feature requires Premium.',
      }),
    );
    expect(
        await expectError('/discovery/nearby'), isA<PremiumRequiredException>());
  });

  test('maps 429 with retryAfterSeconds', () async {
    adapter.onGet(
      '/likes',
      (server) => server.reply(429, {
        'statusCode': 429,
        'error': 'TooManyRequests',
        'message': 'Slow down',
        'details': {'retryAfterSeconds': 30},
      }),
    );
    final err = await expectError('/likes');
    expect(err, isA<RateLimitedException>());
    expect((err as RateLimitedException).retryAfterSeconds, 30);
  });

  test('flattens array validation messages (422)', () async {
    adapter.onGet(
      '/onboarding/basics',
      (server) => server.reply(422, {
        'statusCode': 422,
        'error': 'ValidationError',
        'message': ['displayName too short', 'gender is required'],
      }),
    );
    final err = await expectError('/onboarding/basics');
    expect(err, isA<ValidationException>());
    expect(err.message, 'displayName too short\ngender is required');
  });

  test('maps 5xx → ServerException', () async {
    adapter.onGet(
      '/boom',
      (server) => server.reply(500, {
        'statusCode': 500,
        'error': 'InternalServerError',
        'message': 'Something went wrong',
      }),
    );
    expect(await expectError('/boom'), isA<ServerException>());
  });
}
