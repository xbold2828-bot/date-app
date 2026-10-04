import 'package:flutter/foundation.dart';
import '../../../data/models/auth/country.dart';

@immutable
class LoginState {
  const LoginState({
    this.country = Country.india,
    this.phone = '',
    this.isPhoneLoading = false,
    this.isGoogleLoading = false,
  });

  final Country country;
  final String phone;
  final bool isPhoneLoading;
  final bool isGoogleLoading;

  /// Valid only when the number has exactly the digits the country needs.
  bool get isPhoneValid => phone.length == country.digits;

  /// Continue is enabled only for a full number and while nothing else is busy.
  bool get canContinue => isPhoneValid && !isGoogleLoading && !isPhoneLoading;

  bool get canUseGoogle => !isPhoneLoading;

  String get fullPhone => '${country.code}$phone';

  LoginState copyWith({
    Country? country,
    String? phone,
    bool? isPhoneLoading,
    bool? isGoogleLoading,
  }) {
    return LoginState(
      country: country ?? this.country,
      phone: phone ?? this.phone,
      isPhoneLoading: isPhoneLoading ?? this.isPhoneLoading,
      isGoogleLoading: isGoogleLoading ?? this.isGoogleLoading,
    );
  }
}