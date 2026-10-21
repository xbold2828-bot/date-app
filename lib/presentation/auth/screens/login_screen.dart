import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform; // ADDED
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sms_autofill/sms_autofill.dart'; // ADDED
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

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();

  // ADDED: the SIM-number picker is offered once per visit to this screen, so
  // it does not pop up again when the user comes back from the OTP screen.
  bool _hintRequested = false;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(() {
      ref.read(loginProvider.notifier).setPhone(_phoneController.text.trim());
    });

    // ADDED: pick the starting country (US only if the phone is in the US,
    // otherwise India), then offer the SIM-number suggestion. After the first
    // frame, because a provider must not be changed while the widget tree is
    // being built.
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

  // ───────────────────────────────────────────────────────────────────────────
  // ADDED: starting country
  //
  // US (+1) only when the phone is in the US. Every other case — India, an
  // unknown place, anything — is India (+91).
  //
  // "In the US" means the phone's clock is on a US time zone: UTC-4 to UTC-10
  // in whole hours (Eastern through Hawaii, with and without daylight saving).
  // India is UTC+5:30, so it can never match.
  //
  // The phone's language / region setting is deliberately NOT used: many phones
  // in India are set to "English (US)", which wrongly picked +1.
  // Needs no permission and no package. (On web it is the browser's time zone.)
  // ───────────────────────────────────────────────────────────────────────────
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
      ref.read(loginProvider.notifier).setCountry(country); // also clears phone
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // ADDED: SIM / phone-number suggestion
  //
  // Android only. On web (including Chrome on an Android phone, where
  // defaultTargetPlatform still reads "android") and on iOS there is no such
  // API, so the feature switches itself off and the screen behaves as before.
  // Dismissing the sheet also changes nothing.
  // ───────────────────────────────────────────────────────────────────────────

  /// True only in a native Android app. `kIsWeb` is checked FIRST because web
  /// on an Android phone would otherwise pass the platform test.
  bool get _phoneHintSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> _requestPhoneHint() async {
    if (_hintRequested) return;
    _hintRequested = true;

    if (!_phoneHintSupported) return; // web / iOS / desktop: do nothing

    try {
      final hint = await SmsAutoFill().hint;
      if (!mounted || hint == null || hint.trim().isEmpty) return;
      _applyPhoneHint(hint.trim());
    } catch (e) {
      // No Google Play Services, no SIM, plugin missing, etc.
      debugPrint('Phone hint unavailable: $e');
    }
  }

  /// Works out which country a number belongs to, from the digits alone.
  /// A match needs the right dial code AND the right total length, using the
  /// countries in [kCountries] — so adding a country there adds it here.
  ///   India: "91" + 10 digits     US: "1" + 10 digits
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

  /// Fills the field from the picked SIM number — country first, then the
  /// local digits only (never the dial code) — and continues if it is complete.
  void _applyPhoneHint(String rawHint) {
    final digits = rawHint.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return;

    final notifier = ref.read(loginProvider.notifier);

    // 1) Which country? From the number itself when it carries a dial code,
    //    otherwise whatever is selected now.
    Country country = _countryFromDigits(digits) ?? ref.read(loginProvider).country;

    // 2) Local digits only: drop the dial code, or keep the last N digits.
    final dial = country.code.replaceAll('+', '');
    String nsn;
    if (_countryFromDigits(digits) == country) {
      nsn = digits.substring(dial.length);
    } else if (digits.length > country.digits) {
      nsn = digits.substring(digits.length - country.digits);
    } else {
      nsn = digits;
    }

    // 3) Switch country first (this clears the phone), then set the digits.
    if (ref.read(loginProvider).country != country) {
      notifier.setCountry(country);
    }
    _phoneController.text = nsn;
    _phoneController.selection = TextSelection.collapsed(offset: nsn.length);

    // 4) A complete number goes straight to OTP, through the same path as the
    //    Continue button — so the Terms check still applies.
    if (nsn.length == country.digits) {
      _onContinue();
    }
  }

  Future<void> _onContinue() async {
    removeFocus();

    if (!ref.read(termsAcceptedProvider)) {
      AppSnackBar.showWarningSnackBar(
        message: 'Please accept the Terms and Privacy Policy to continue.',
      );
      return;
    }

    try {
      final fullPhone = await ref.read(loginProvider.notifier).sendOtp();
      if (mounted) context.push(AppRoutes.signInOtp, extra: fullPhone);
    } catch (_) {
      if (mounted) showRadiusToast(context, "Couldn't send the code. Try again.");
    }
  }

  Future<void> _onGoogleSignIn() async {
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
      return "Couldn't sign in with Google. Try again.";
    }

    final status = int.tryParse(
      RegExp(r'\b(\d+)\b').firstMatch(error.message ?? '')?.group(1) ?? '',
    );

    switch (status) {
      case 10:
        return 'Google sign-in not configured for this build (DEVELOPER_ERROR 10).';
      case 12501:
        return 'Sign-in cancelled.';
      case 12500:
        return 'Google sign-in failed (12500) — check the Play Services account.';
      case 7:
        return 'Network error reaching Google. Check the connection.';
      default:
        return 'Google sign-in failed: ${error.code}';
    }
  }

  void _pickCountry() {
    final selectedCode = ref.read(loginProvider).country.code;

    showRadiusSheet<void>(
      context: context,
      builder: (sheetContext) => RadiusSheet(
        title: 'Country',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: kCountries.map((country) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: RadiusOptionTile(
                title: country.name,
                subtitle: '${country.code} · ${country.digits} digits',
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
    // Scroll only while the keyboard is open; otherwise the page is fixed.
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
                    const SectionLabel('Phone number', topSpacing: 0),
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