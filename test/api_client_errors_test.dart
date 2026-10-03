import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthClientOptions, AuthFlowType, SupabaseClient;

import 'package:dating_app/core/errors/app_exceptions.dart';
import 'package:dating_app/data/repositories/chat_repository.dart';
import 'package:dating_app/data/services/api_service.dart';

/// The real [ApiClient], wired exactly as the app wires it, against stubbed
/// backend responses.
///
/// `network_test.dart` exercises the interceptors on a bare Dio, which is why
/// it never noticed that the client itself was configured to treat every status
/// code as a success: a refused message came back as an "envelope" with no
/// `conversation` or `message` in it, parsed into an empty [SendResult], and the
/// chat screen had nothing to catch — no toast for moderation, none for the New
/// Energy cap, and no paywall for the daily opener limit.
void main() {
  late Dio dio;
  late DioAdapter adapter;
  late ChatRepository chat;

  setUpAll(
    () => dotenv.loadFromString(envString: 'API_BASE_URL=https://test.local'),
  );

  setUp(() {
    dio = Dio();
    final api = ApiClient(
      dio: dio,
      // Implicit flow: PKCE wants a storage backend, and nothing here signs in.
      supabase: SupabaseClient(
        'https://example.supabase.co',
        'anon-key',
        authOptions: const AuthClientOptions(
          authFlowType: AuthFlowType.implicit,
          autoRefreshToken: false,
        ),
      ),
    );
    adapter = DioAdapter(dio: dio);
    chat = ChatRepository(api);
  });

  Map<String, dynamic> envelope(
    int status,
    String error,
    String message, [
    Map<String, dynamic>? details,
  ]) => {
    'statusCode': status,
    'error': error,
    'message': message,
    'details': ?details,
    'path': '/x',
    'timestamp': '2026-10-03T00:00:00.000Z',
  };

  test('a moderated opener surfaces as ContentRejectedException', () async {
    adapter.onPost(
      '/messaging/open',
      (server) => server.reply(
        422,
        envelope(
          422,
          'ContentRejected',
          "This message doesn't meet our content guidelines. Please rephrase it.",
          {'reason': 'CONTENT_REJECTED', 'surface': 'message'},
        ),
      ),
      data: Matchers.any,
    );

    await expectLater(
      chat.open('u2', 'something rude'),
      throwsA(
        isA<ContentRejectedException>().having(
          (e) => e.surface,
          'surface',
          'message',
        ),
      ),
    );
  });

  test('the fourth unanswered message surfaces the New Energy cap', () async {
    adapter.onPost(
      '/messaging/conversations/c1/messages',
      (server) => server.reply(
        429,
        envelope(
          429,
          'NewEnergyLimit',
          'Wait for a reply before sending more (max 3 in New Energy)',
          {'reason': 'NEW_ENERGY_CAP', 'limit': 3},
        ),
      ),
      data: Matchers.any,
    );

    await expectLater(
      chat.send('c1', 'one more'),
      throwsA(
        isA<RateLimitedException>().having(
          (e) => e.reason,
          'reason',
          'NEW_ENERGY_CAP',
        ),
      ),
    );
  });

  test('a fourth new conversation today is a paywall, not a success', () async {
    adapter.onPost(
      '/messaging/open',
      (server) => server.reply(
        402,
        envelope(
          402,
          'EntitlementRequired',
          'Premium or ad credits are required to continue',
          {
            'reason': 'CONVERSATIONS_LIMIT_REACHED',
            'action': 'open_conversation',
            'cost': 1,
            'balance': 0,
            'options': ['premium', 'watch_ad'],
          },
        ),
      ),
      data: Matchers.any,
    );

    await expectLater(
      chat.open('u3', 'hey'),
      throwsA(
        isA<EntitlementRequiredException>().having(
          (e) => e.reason,
          'reason',
          'CONVERSATIONS_LIMIT_REACHED',
        ),
      ),
    );
  });

  test('an expired session still maps to UnauthorizedException', () async {
    adapter.onGet(
      '/messaging/unread-count',
      (server) => server.reply(
        401,
        envelope(401, 'Unauthorized', 'Invalid or expired token'),
      ),
    );

    await expectLater(
      chat.unreadCount(),
      throwsA(isA<UnauthorizedException>()),
    );
  });

  test('a successful send is still unwrapped to its payload', () async {
    adapter.onPost(
      '/messaging/conversations/c1/messages',
      (server) => server.reply(201, {
        'success': true,
        'data': {
          'conversation': {'id': 'c1', 'state': 'new_energy'},
          'message': {'id': 'm9', 'body': 'hi', 'fromMe': true},
        },
      }),
      data: Matchers.any,
    );

    final result = await chat.send('c1', 'hi');
    expect(result.conversation.id, 'c1');
    expect(result.message.id, 'm9');
  });
}
