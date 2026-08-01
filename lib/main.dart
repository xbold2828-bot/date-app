import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'presentation/auth/screens/login_screen.dart';
import 'presentation/home/screens/home_screen.dart';
import 'presentation/auth/screens/age_screen.dart';
import 'core/constants/env.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,
  );

  runApp(const MyApp());
}

final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Radius',
      debugShowCheckedModeBanner: false,
      home: const AuthGate(),
    );
  }
}

// Checks session on app launch
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    // Listen for auth changes and navigate accordingly
    supabase.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      final event = data.event;

      if (session != null && mounted) {
        if (event == AuthChangeEvent.signedIn ||
            event == AuthChangeEvent.tokenRefreshed) {
          // Check if new or existing user
          final createdAt = session.user.createdAt;
          final updatedAt = session.user.updatedAt;
          final isNewUser = createdAt == updatedAt;

          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => isNewUser
                  ? const AgeScreen()   // new user → onboarding
                  : const HomeScreen(), // existing user → home
            ),
            (route) => false,
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Check existing session on app launch
    final session = supabase.auth.currentSession;
    if (session != null) {
      return const HomeScreen();
    }
    return const LoginScreen();
  }
}