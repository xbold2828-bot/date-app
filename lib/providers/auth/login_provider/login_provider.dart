import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dating_app/data/services/auth_service.dart';
import '../../../data/models/auth/country.dart';
import 'login_state.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final termsAcceptedProvider = StateProvider.autoDispose<bool>((ref) => true);

// Riverpod 2.x. On Riverpod 3.x change AutoDisposeNotifier -> Notifier.
final loginProvider =
NotifierProvider.autoDispose<LoginNotifier, LoginState>(LoginNotifier.new);

class LoginNotifier extends AutoDisposeNotifier<LoginState> {
  bool _alive = true;

  @override
  LoginState build() {
    _alive = true;
    ref.onDispose(() => _alive = false);
    return const LoginState();
  }

  AuthService get _auth => ref.read(authServiceProvider);

  void setPhone(String value) {
    if (value == state.phone) return;
    state = state.copyWith(phone: value);
  }

  void setCountry(Country country) {
    state = state.copyWith(country: country, phone: '');
  }

  /// Sends the OTP. Returns the full phone number on success, throws on error.
  Future<String> sendOtp() async {
    if (!state.canContinue) throw StateError('Invalid phone number');

    final fullPhone = state.fullPhone;
    state = state.copyWith(isPhoneLoading: true);
    try {
      await _auth.sendOtp(fullPhone);
      return fullPhone;
    } finally {
      if (_alive) state = state.copyWith(isPhoneLoading: false);
    }
  }

  /// Returns true when signed in, false when cancelled.
  Future<bool> signInWithGoogle() async {
    if (state.isGoogleLoading || state.isPhoneLoading) return false;

    state = state.copyWith(isGoogleLoading: true);
    try {
      final response = await _auth.signInWithGoogle();
      return response?.user != null;
    } finally {
      if (_alive) state = state.copyWith(isGoogleLoading: false);
    }
  }
}