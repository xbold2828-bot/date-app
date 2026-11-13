import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sms_autofill/sms_autofill.dart';
import 'package:dating_app/core/extensions/global_back_extension.dart';
import 'package:dating_app/core/extensions/unfocus_on_tap_extension.dart';
import 'package:dating_app/core/router/app_router.dart';
import 'package:dating_app/core/theme/app_colors.dart';
import 'package:dating_app/core/utils/utils.dart';
import '../../../core/utils/app_snack_bar.dart';
import '../../../data/models/auth/country.dart';
import '../../../providers/auth/login_provider/login_provider.dart';
import '../../common/widgets/radius_option_tile.dart';
import '../../common/widgets/radius_sheet.dart';
import '../../common/widgets/radius_surfaces.dart';
import '../../common/widgets/radius_toast.dart';
import '../widgets/login/buttons/continue_button.dart';
import '../widgets/login/buttons/country_button.dart';
import '../widgets/login/buttons/google_button.dart';
import '../widgets/login/login_header.dart';
import '../widgets/login/login_terms.dart';
import '../widgets/login/or_divider.dart';
import '../widgets/login/phone_field.dart';
import 'package:dating_app/core/constants/app_string.dart';


class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();

  bool _hintRequested = false;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(() {
      ref.read(loginProvider.notifier).setPhone(_phoneController.text.trim());
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyDefaultCountry();
      _requestPhoneHint();
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  bool get _phoneIsInUs {
    final minutes = DateTime.now().timeZoneOffset.inMinutes;
    final wholeHours = minutes % 60 == 0;
    final hours = minutes / 60;
    return wholeHours && hours <= -4 && hours >= -10;
  }

  void _applyDefaultCountry() {
    if (!mounted) return;
    final country = _phoneIsInUs ? Country.us : Country.india;

    if (ref.read(loginProvider).country != country) {
      ref.read(loginProvider.notifier).setCountry(country);
    }
  }

  bool get _phoneHintSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> _requestPhoneHint() async {
    if (_hintRequested) return;
    _hintRequested = true;

    if (!_phoneHintSupported) return;

    try {
      final hint = await SmsAutoFill().hint;
      if (!mounted || hint == null || hint.trim().isEmpty) return;
      _applyPhoneHint(hint.trim());
    } catch (e) {
      debugPrint('Phone hint unavailable: $e');
    }
  }

  Country? _countryFromDigits(String digits) {
    for (final country in kCountries) {
      final dial = country.code.replaceAll('+', '');
      if (digits.startsWith(dial) &&
          digits.length == dial.length + country.digits) {
        return country;
      }
    }
    return null;
  }

  void _applyPhoneHint(String rawHint) {
    final digits = rawHint.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return;

    final notifier = ref.read(loginProvider.notifier);

    Country country = _countryFromDigits(digits) ?? ref.read(loginProvider).country;

    final dial = country.code.replaceAll('+', '');
    String nsn;
    if (_countryFromDigits(digits) == country) {
      nsn = digits.substring(dial.length);
    } else if (digits.length > country.digits) {
      nsn = digits.substring(digits.length - country.digits);
    } else {
      nsn = digits;
    }

    if (ref.read(loginProvider).country != country) {
      notifier.setCountry(country);
    }
    _phoneController.text = nsn;
    _phoneController.selection = TextSelection.collapsed(offset: nsn.length);

    if (nsn.length == country.digits) {
      _onContinue();
    }
  }

  bool _ensureTermsAccepted() {
    if (ref.read(termsAcceptedProvider)) return true;

    AppSnackBar.showWarningSnackBar(
      message: AppString.loginAcceptTermsWarning,
    );
    return false;
  }

  Future<void> _onContinue() async {
    removeFocus();

    if (!_ensureTermsAccepted()) return;

    try {
      final fullPhone = await ref.read(loginProvider.notifier).sendOtp();
      if (mounted) context.push(AppRoutes.signInOtp, extra: fullPhone);
    } catch (_) {
      if (mounted) showRadiusToast(context, AppString.couldntSendTheCodeTry);
    }
  }

  Future<void> _onGoogleSignIn() async {
    removeFocus();

    if (!_ensureTermsAccepted()) return;

    try {
      final success = await ref.read(loginProvider.notifier).signInWithGoogle();
      if (success && mounted) context.go(AppRoutes.splash, extra: true);
    } catch (e, stack) {
      debugPrint('Google sign-in failed: $e');
      debugPrintStack(stackTrace: stack);
      if (mounted) showRadiusToast(context, _googleSignInMessage(e));
    }
  }

  String _googleSignInMessage(Object error) {
    if (error is! PlatformException) {
      return AppString.googleFailed;
    }

    final status = int.tryParse(
      RegExp(r'\b(\d+)\b').firstMatch(error.message ?? '')?.group(1) ?? '',
    );

    switch (status) {
      case 10:
        return AppString.googleNotConfigured;
      case 12501:
        return AppString.googleCancelled;
      case 12500:
        return AppString.googlePlayServices;
      case 7:
        return AppString.googleNetwork;
      default:
        return AppString.googleUnknown(error.code, error.message);
    }
  }

  void _pickCountry() {
    final selectedCode = ref.read(loginProvider).country.code;

    showRadiusSheet<void>(
      context: context,
      builder: (sheetContext) => RadiusSheet(
        title: AppString.country,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: kCountries.map((country) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: RadiusOptionTile(
                title: country.name,
                subtitle: AppString.countryOptionSubtitle(country.code, country.digits.toString()),
                selected: selectedCode == country.code,
                leading: Text(
                  country.flag,
                  style: const TextStyle(fontSize: 24),
                ),
                onTap: () {
                  if (country.code != selectedCode) {
                    _phoneController.clear();
                    ref.read(loginProvider.notifier).setCountry(country);
                  }
                  Navigator.pop(sheetContext);
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: keyboardOpen
                ? const ClampingScrollPhysics()
                : const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: ConstrainedBox(
              constraints:
              BoxConstraints(minHeight: constraints.maxHeight - 56),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const LoginHeader(),
                    SectionLabel(AppString.phoneNumberLabel, topSpacing: 0),
                    Row(
                      children: [
                        CountryButton(onTap: _pickCountry),
                        spacerW(12),
                        Expanded(
                          child: PhoneField(controller: _phoneController),
                        ),
                      ],
                    ),
                    spacerH(15),
                    ContinueButton(onContinue: _onContinue),
                    spacerH(10),
                    const OrDivider(),
                    spacerH(10),
                    GoogleButton(onPressed: _onGoogleSignIn),
                    spacerH(15),
                    const LoginTerms(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ).unfocusOnTap().withGlobalBackHandler(context);
  }
}
