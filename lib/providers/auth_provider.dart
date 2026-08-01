import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/repositories/auth_repository.dart';
import 'core_providers.dart';

export 'core_providers.dart' show authRepositoryProvider, authStateProvider;

/// Whether a Supabase session currently exists (drives the AuthGate).
final isLoggedInProvider = Provider<bool>((ref) {
  // Recompute on every auth change.
  ref.watch(authStateProvider);
  return ref.watch(authRepositoryProvider).isLoggedIn;
});

/// The Supabase user id of the signed-in account (not the domain user id).
final supabaseUserIdProvider = Provider<String?>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(authRepositoryProvider).supabaseUser?.id;
});

/// Thin auth actions surface for the login/OTP screens.
class AuthController {
  AuthController(this._repo);
  final AuthRepository _repo;

  Future<void> sendOtp(String phone) => _repo.sendOtp(phone);

  Future<AuthResponse> verifyOtp({required String phone, required String token}) =>
      _repo.verifyOtp(phone: phone, token: token);

  Future<AuthResponse?> signInWithGoogle() => _repo.signInWithGoogle();

  Future<void> signOut() => _repo.signOut();
}

final authControllerProvider = Provider<AuthController>(
  (ref) => AuthController(ref.watch(authRepositoryProvider)),
);
