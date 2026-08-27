// =============================================================================
// fcm_sender.dart  (Hardcoded Service Account - Prototype Only)
// =============================================================================

import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:googleapis_auth/auth_io.dart';
import '../logger/app_logger.dart';

enum FcmNotificationType { normal, dataOnly }

enum FcmTargetApp { expert, client }

abstract final class FcmSender {
  static const _scopes = ['https://www.googleapis.com/auth/firebase.messaging'];
  static String? _projectId;
  static AuthClient? _authClient;
  static final _dio = Dio();

  // 🔴 HARDCODED SERVICE ACCOUNT CREDENTIALS
  static const String _serviceAccountJson = '''
{
  "type": "service_account",
  "project_id": "",
  "private_key_id": "",
  "private_key": "",
  "client_email": "",
  "client_id": "116810693115964428934",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
  "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
  "client_x509_cert_url": "",
  "universe_domain": "googleapis.com"
}
  ''';

  /// 1. INITIALIZE DIRECTLY FROM HARDCODED STRING
  static Future<void> init() async {
    try {
      // Decode the hardcoded string directly
      final credentialsJson = jsonDecode(_serviceAccountJson);

      // Auto-extract Project ID from the JSON
      _projectId = credentialsJson['project_id'];

      final accountCredentials = ServiceAccountCredentials.fromJson(
        credentialsJson,
      );

      // Creates an auto-refreshing AuthClient inside your Flutter App
      _authClient = await clientViaServiceAccount(accountCredentials, _scopes);

      AppLogger.d(
        '✅ FcmSender Initialized successfully for project: $_projectId',
      );
    } catch (e) {
      AppLogger.e('❌ FcmSender initialization failed: $e');
      rethrow;
    }
  }

  /// 2. SIMPLE SEND METHOD
  static Future<void> send({
    required String deviceToken,
    required String title,
    required String body,
    FcmNotificationType type = FcmNotificationType.normal,
    FcmTargetApp targetApp = FcmTargetApp.expert,
    Map<String, String> data = const {},
  }) async {
    if (_authClient == null || _projectId == null) {
      throw Exception(
        '❌ FcmSender not initialized. Call FcmSender.init() first.',
      );
    }

    final accessToken = _authClient!.credentials.accessToken.data;

    final url =
        'https://fcm.googleapis.com/v1/projects/$_projectId/messages:send';

    final enrichedData = {
      ...data,
      'fcm_type': type.name,
      'target_app': targetApp.name,
    };

    final Map<String, dynamic> message = {
      'token': deviceToken,
      'data': enrichedData,
      'android': _androidConfig(type),
      'apns': _apnsConfig(type),
      'webpush': _webPushConfig(type, title, body),
    };

    if (type == FcmNotificationType.normal) {
      message['notification'] = {'title': title, 'body': body};
    }

    final payload = {'message': message};

    final response = await _dio.post(
      url,
      data: payload,
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      ),
    );

    if (response.statusCode == 200) {
      AppLogger.d('✅ FCM [${type.name}] push sent successfully.');
    } else {
      AppLogger.d(
        '❌ FCM push failed [${response.statusCode}]: ${response.data}',
      );
    }
  }

  // --- Platform Configurations ---

  static Map<String, dynamic> _androidConfig(FcmNotificationType type) {
    return {
      'priority': 'high',
      if (type == FcmNotificationType.normal)
        'notification': {
          'channel_id': 'marksmann_high_importance',
          'sound': 'default',
          // 'priority': 'high',
          'default_vibrate_timings': true,
        },
    };
  }

  static Map<String, dynamic> _apnsConfig(FcmNotificationType type) {
    return {
      'headers': {
        'apns-priority': type == FcmNotificationType.normal ? '10' : '5',
      },
      'payload': {
        'aps': {
          if (type == FcmNotificationType.normal) ...{
            'sound': 'default',
            'badge': 1,
          },
          'content-available': 1,
        },
      },
    };
  }

  static Map<String, dynamic> _webPushConfig(
      FcmNotificationType type,
      String title,
      String body,
      ) {
    return {
      'headers': {
        'Urgency': type == FcmNotificationType.normal ? 'high' : 'low',
      },
      if (type == FcmNotificationType.normal)
        'notification': {
          'title': title,
          'body': body,
          'icon': '/icons/icon-192x192.png',
        },
    };
  }
}