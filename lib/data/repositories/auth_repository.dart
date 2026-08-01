import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';

/// Authentication actions. Auth itself is Supabase (Google / phone OTP); the
/// backend simply trusts the resulting access token. Domain-user provisioning
/// happens on the first authenticated call to `GET /users/me` (see
/// [ProfileRepository.me]).
class AuthRepository {
  AuthRepository(this._auth);

  final AuthService _auth;

  Session? get session => _auth.currentSession;
  User? get supabaseUser => _auth.currentUser;
  bool get isLoggedIn => _auth.isLoggedIn;
  String? get accessToken => _auth.currentSession?.accessToken;

  Future<void> sendOtp(String phone) => _auth.sendOtp(phone);

  Future<AuthResponse> verifyOtp({
    required String phone,
    required String token,
  }) =>
      _auth.verifyOtp(phone: phone, token: token);

  Future<AuthResponse?> signInWithGoogle() => _auth.signInWithGoogle();

  Future<void> signOut() => _auth.signOut();
}
