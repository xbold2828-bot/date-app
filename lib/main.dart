import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/constants/app_colors.dart';
import 'core/constants/env.dart';
import 'presentation/auth/screens/authed_bootstrap.dart';
import 'presentation/auth/screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
      home: Env.hasSupabaseAnonKey ? const AuthGate() : const _MissingConfig(),
    );
  }
}

/// Decides the launch route: an existing session boots into the app (loading
/// the domain user), otherwise the login screen. Post-login navigation is
/// handled by the auth screens pushing [AuthedBootstrap].
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final session = supabase.auth.currentSession;
    if (session != null) return const AuthedBootstrap();
    return const LoginScreen();
  }
}

/// Shown when the Supabase anon key hasn't been configured yet, so the failure
/// is obvious instead of a cryptic auth error.
class _MissingConfig extends StatelessWidget {
  const _MissingConfig();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.key_off, size: 48, color: AppColors.textGrey),
                SizedBox(height: 16),
                Text(
                  'Supabase not configured',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Set the Supabase anon key in lib/core/constants/env.dart '
                  '(or pass --dart-define=SUPABASE_ANON_KEY=...) and restart.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppColors.textGrey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
