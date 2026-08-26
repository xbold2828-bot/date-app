import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/user_model.dart';
import '../../../data/services/auth_service.dart';
import '../../../providers/profile_provider.dart';
import '../../home/screens/home_screen.dart';
import 'age_screen.dart';
import 'basics_screen1.dart';
import 'basics_screen2.dart';
import 'basics_screen3.dart';
import 'basics_screen4.dart';
import 'basics_screen5.dart';
import 'basics_screen7.dart';
import 'login_screen.dart';
import 'status_screen.dart';

/// Entry point once a Supabase session exists: loads the domain user
/// (`GET /users/me`, which also provisions it on first call) and routes to home
/// or back into the funnel at the exact step the backend says is outstanding.
class AuthedBootstrap extends ConsumerWidget {
  const AuthedBootstrap({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider);
    return me.when(
      loading: () => const _Splash(),
      error: (err, _) => _ErrorRetry(
        message: err.toString(),
        onRetry: () => ref.invalidate(meProvider),
      ),
      data: (user) => user.onboarding.isComplete
          ? const HomeScreen()
          : _resumeAt(user.onboarding.nextStep),
    );
  }

  /// Maps the backend's outstanding step to the screen that satisfies it, so a
  /// refresh mid-funnel picks up where the user left off instead of restarting
  /// from the age gate.
  ///
  /// Two screens each save a pair of steps (intent+personality,
  /// preferences+hard-no's), so both of those steps route to the same screen.
  Widget _resumeAt(String? nextStep) {
    switch (nextStep) {
      case OnboardingSteps.ageVerification:
        return const AgeScreen();
      case OnboardingSteps.basics:
        return const BasicsScreen();
      case OnboardingSteps.intent:
      case OnboardingSteps.personality:
        return const BasicsScreen2();
      case OnboardingSteps.status:
        return const StatusScreen();
      case OnboardingSteps.preferences:
      case OnboardingSteps.hardNos:
        return const BasicsScreen3();
      case OnboardingSteps.photo:
        return const BasicsScreen4();
      case OnboardingSteps.location:
        return const BasicsScreen5();
      case OnboardingSteps.agreement:
        return const BasicsScreen7();
      default:
        // No step named (or an unknown one from a newer backend): start over
        // rather than guess. Completed steps are skipped by the funnel anyway.
        return const AgeScreen();
    }
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  const _ErrorRetry({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off, size: 48, color: AppColors.textGrey),
              const SizedBox(height: 16),
              Text(
                "Couldn't reach Radius",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textGrey),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: onRetry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Retry',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onAccent,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () async {
                  await AuthService().signOut();
                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  }
                },
                child: Text(
                  'Sign out',
                  style: TextStyle(color: AppColors.textGrey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
