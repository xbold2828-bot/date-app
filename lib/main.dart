import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/constants/app_colors.dart';
import 'core/constants/app_text_styles.dart';
import 'core/constants/env.dart';
import 'core/theme/app_theme.dart';
import 'presentation/auth/screens/authed_bootstrap.dart';
import 'presentation/auth/screens/login_screen.dart';
import 'providers/core_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Env has no fallbacks, so bail out here with a readable screen instead of
  // letting Supabase.initialize throw on an empty URL.
  if (!Env.isConfigured) {
    runApp(MissingConfigApp(missingKeys: Env.missingKeys));
    return;
  }

  await Supabase.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,
  );

  runApp(const ProviderScope(child: MyApp()));
}

final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Radius',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const AuthGate(),
    );
  }
}

/// Decides the launch route: an existing session boots into the app (loading
/// the domain user), otherwise the login screen.
///
/// Watching the auth stream — rather than reading `currentSession` once — is
/// what makes sign-out and token expiry land the user back on login instead of
/// leaving a dead screen behind.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Rebuilds on every sign-in / sign-out / token refresh.
    ref.watch(authStateProvider);
    final session = Supabase.instance.client.auth.currentSession;
    return session != null ? const AuthedBootstrap() : const LoginScreen();
  }
}

/// Stands in for the whole app when `.env` wasn't supplied, so the failure is
/// an obvious screen naming the missing keys instead of a cryptic crash.
class MissingConfigApp extends StatelessWidget {
  const MissingConfigApp({super.key, required this.missingKeys});

  final List<String> missingKeys;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Radius',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.key_off, size: 48, color: AppColors.iconMuted),
                  const SizedBox(height: 16),
                  Text('Environment not configured',
                      style: AppTextStyles.title),
                  const SizedBox(height: 12),
                  Text(
                    'Missing: ${missingKeys.join(', ')}',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyStrong,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Copy .env.example to .env, fill it in, then relaunch with\n'
                    'flutter run --dart-define-from-file=.env',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
