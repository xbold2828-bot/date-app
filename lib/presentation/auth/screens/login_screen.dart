import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/static_assets/app_vectors.dart';
import '../../../core/extensions/global_back_extension.dart';
import '../../../core/extensions/unfocus_on_tap_extension.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/input_formatters.dart';
import '../../../core/utils/utils.dart';
import '../../../data/services/auth_service.dart';
import '../../common/widgets/widgets.dart';

/// A dialling code the phone field accepts, and how its numbers are written.
class _Country {
  const _Country({
    required this.name,
    required this.code,
    required this.flag,
    required this.groups,
  });

  final String name;
  final String code;
  final String flag;

  /// Digit grouping as people write it locally: 98765 43210, 555 123 4567.
  final List<int> groups;

  int get digits => groups.fold(0, (sum, g) => sum + g);

  /// An example number in the local grouping, for the empty field.
  String get example => switch (code) {
    '+91' => '98765 43210',
    _ => '555 123 4567',
  };
}

const _countries = [
  _Country(name: 'India', code: '+91', flag: '🇮🇳', groups: [5, 5]),
  _Country(name: 'United States', code: '+1', flag: '🇺🇸', groups: [3, 3, 4]),
];

/// The first screen without a session.
///
/// One question and one field. The phone number is the whole form, so it gets
/// the room: the dialling code lives inside the field rather than in a box of
/// its own, the digits are set large and grouped the way people say them, and
/// "Send code" stays greyed until the number is the right length — there is no
/// error to show because there is no way to send a short one.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final FocusNode _phoneFocus = FocusNode();
  final AuthService _authService = AuthService();

  late final TapGestureRecognizer _termsTap = TapGestureRecognizer()
    ..onTap = () => openUrl(url: AppConstants.termsAndCondition);
  late final TapGestureRecognizer _privacyTap = TapGestureRecognizer()
    ..onTap = () => openUrl(url: AppConstants.privacyPolicy);

  _Country _country = _countries.first;
  bool _sendingCode = false;
  bool _googleBusy = false;

  bool get _busy => _sendingCode || _googleBusy;

  String get _digits => DigitGroupsFormatter.digitsOf(_phoneController.text);

  bool get _numberComplete => _digits.length == _country.digits;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_onNumberChanged);
    _phoneFocus.addListener(_onNumberChanged);
  }

  void _onNumberChanged() => setState(() {});

  @override
  void dispose() {
    _phoneController.dispose();
    _phoneFocus.dispose();
    _termsTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  Future<void> _onContinue() async {
    final phone = _digits;

    // The button is disabled until the number is complete; this guards the
    // keyboard's own "done" action, which is not.
    if (phone.length != _country.digits) {
      showRadiusToast(
        context,
        '${_country.name} numbers are ${_country.digits} digits',
      );
      return;
    }

    setState(() => _sendingCode = true);

    removeFocus();
    try {
      final fullPhone = '${_country.code}$phone';
      await _authService.sendOtp(fullPhone);

      if (mounted) context.push(AppRoutes.signInOtp, extra: fullPhone);
    } catch (e) {
      if (mounted) {
        showRadiusToast(context, "Couldn't send the code. Try again.");
      }
    } finally {
      if (mounted) setState(() => _sendingCode = false);
    }
  }

  Future<void> _onGoogleSignIn() async {
    setState(() => _googleBusy = true);

    try {
      final response = await _authService.signInWithGoogle();

      // Null means the user cancelled.
      if (response == null) return;

      // The splash screen decides between onboarding and home now that a
      // session exists.
      if (response.user != null && mounted) {
        context.go(AppRoutes.splash, extra: true);
      }
    } catch (e, stack) {
      debugPrint('Google sign-in failed: $e');
      debugPrintStack(stackTrace: stack);

      if (mounted) showRadiusToast(context, _googleSignInMessage(e));
    } finally {
      if (mounted) setState(() => _googleBusy = false);
    }
  }

  /// Names the cause of a Google sign-in failure. The status code is the first
  /// integer in the platform exception message.
  String _googleSignInMessage(Object error) {
    if (error is! PlatformException) {
      return "Couldn't sign in with Google. Try again.";
    }

    final status = int.tryParse(
      RegExp(r'\b(\d+)\b').firstMatch(error.message ?? '')?.group(1) ?? '',
    );

    switch (status) {
      case 10:
        return 'Google sign-in not configured for this build '
            '(DEVELOPER_ERROR 10) — the package name and signing SHA-1 are '
            'not registered as an Android OAuth client.';
      case 12501:
        return 'Sign-in cancelled.';
      case 12500:
        return 'Google sign-in failed (12500) — check the Play Services '
            'account on this device.';
      case 7:
        return 'Network error reaching Google. Check the connection.';
      default:
        return 'Google sign-in failed: ${error.code} — ${error.message}';
    }
  }

  void _pickCountry() {
    showRadiusSheet<void>(
      context: context,
      builder: (sheetContext) => RadiusSheet(
        title: 'Country',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final country in _countries)
              _CountryRow(
                country: country,
                selected: country.code == _country.code,
                onTap: () {
                  setState(() => _country = country);
                  // Digit counts differ per country, so a number typed for the
                  // previous one would fail validation for no visible reason.
                  _phoneController.clear();
                  Navigator.pop(sheetContext);
                  _phoneFocus.requestFocus();
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardUp = MediaQuery.viewInsetsOf(context).bottom > 0;
    // A 568pt phone cannot hold the full-size headline, the field and the
    // footer at once; it gets the same layout, tightened.
    final compact = MediaQuery.sizeOf(context).height < 700;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // The question at the top, the answer at the thumb: the field
            // sits right over "Send code", and whatever height is left over
            // opens up between the two halves. With the keyboard up (or on a
            // short phone) that gap closes and the page scrolls instead.
            Expanded(
              child: LayoutBuilder(
                builder: (context, viewport) => SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: viewport.maxHeight),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          24,
                          compact ? 12 : 18,
                          24,
                          compact ? 16 : 24,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Wordmark(size: 22),
                            SizedBox(height: compact ? 24 : 52),
                            Semantics(
                              header: true,
                              child: Text(
                                "Who's around\nyou tonight?",
                                style: compact
                                    ? AppTextStyles.question.copyWith(
                                        fontSize: 30,
                                      )
                                    : AppTextStyles.question,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Real, verified people nearby who want the '
                              'same thing you do. No endless swiping.',
                              style: AppTextStyles.bodyMuted.copyWith(
                                fontSize: 15,
                              ),
                            ),
                            SizedBox(height: compact ? 24 : 40),
                            const Spacer(),
                            _PhoneField(
                              controller: _phoneController,
                              focusNode: _phoneFocus,
                              country: _country,
                              enabled: !_busy,
                              onPickCountry: _pickCountry,
                              onSubmitted: _numberComplete ? _onContinue : null,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              "We'll text you a 6-digit code to sign in.",
                              style: AppTextStyles.caption.copyWith(
                                fontSize: 13,
                              ),
                            ),
                            // A short phone cannot pin three things under
                            // the field; the small print scrolls instead.
                            if (compact) ...[
                              const SizedBox(height: 14),
                              _legal(TextAlign.start),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                0,
                24,
                keyboardUp || compact ? 12 : 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  RadiusButton(
                    label: 'Send code',
                    isLoading: _sendingCode,
                    onPressed: _numberComplete && !_googleBusy
                        ? _onContinue
                        : null,
                  ),
                  // With the keyboard up the only thing worth the space is
                  // the action for the number being typed.
                  if (!keyboardUp) ...[
                    const SizedBox(height: 10),
                    _GoogleButton(
                      busy: _googleBusy,
                      onPressed: _busy ? null : _onGoogleSignIn,
                    ),
                    if (!compact) ...[
                      const SizedBox(height: 18),
                      _legal(TextAlign.center),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ).unfocusOnTap().withGlobalBackHandler(context);
  }

  Widget _legal(TextAlign align) => Text.rich(
    TextSpan(
      style: AppTextStyles.caption.copyWith(fontSize: 12, height: 1.5),
      children: [
        const TextSpan(
          text:
              "By continuing you confirm you're 18 or older and agree to "
              'our ',
        ),
        TextSpan(text: 'Terms', style: _linkStyle, recognizer: _termsTap),
        const TextSpan(text: ' and '),
        TextSpan(
          text: 'Privacy Policy',
          style: _linkStyle,
          recognizer: _privacyTap,
        ),
        const TextSpan(text: '.'),
      ],
    ),
    textAlign: align,
  );

  TextStyle get _linkStyle => TextStyle(
    color: AppColors.textDark,
    fontWeight: FontWeight.w600,
    fontVariations: const [FontVariation('wght', 600)],
    decoration: TextDecoration.underline,
    decorationColor: AppColors.iconMuted,
  );
}

/// The dialling code and the number, in one field.
class _PhoneField extends StatelessWidget {
  const _PhoneField({
    required this.controller,
    required this.focusNode,
    required this.country,
    required this.enabled,
    required this.onPickCountry,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final _Country country;
  final bool enabled;
  final VoidCallback onPickCountry;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final focused = focusNode.hasFocus;
    final digitStyle = AppTextStyles.bodyStrong.copyWith(
      fontSize: 20,
      height: 1.3,
      letterSpacing: 0.4,
      fontWeight: FontWeight.w600,
      fontVariations: const [FontVariation('wght', 600)],
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your phone number',
          style: AppTextStyles.bodyStrong.copyWith(
            fontSize: 13.5,
            color: AppColors.textGrey,
          ),
        ),
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: const Cubic(0.23, 1, 0.32, 1),
          height: 60,
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: focused ? AppColors.primary : AppColors.inputBorder,
              width: focused ? 2 : 1.5,
            ),
          ),
          // Transparent Material so the country button's ripple paints over
          // the field's fill instead of underneath it.
          child: Material(
            type: MaterialType.transparency,
            child: Row(
              children: [
                Semantics(
                  button: true,
                  label: 'Country: ${country.name}, ${country.code}. Change',
                  excludeSemantics: true,
                  child: InkWell(
                    onTap: enabled ? onPickCountry : null,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(14),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 10, 0),
                      child: Row(
                        children: [
                          Text(
                            country.flag,
                            style: const TextStyle(fontSize: 20),
                          ),
                          const SizedBox(width: 8),
                          Text(country.code, style: digitStyle),
                          const SizedBox(width: 2),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 20,
                            color: AppColors.iconMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Container(width: 1, height: 28, color: AppColors.inputBorder),
                Expanded(
                  child: Semantics(
                    label: 'Phone number',
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      enabled: enabled,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [
                        AutofillHints.telephoneNumberNational,
                      ],
                      inputFormatters: [DigitGroupsFormatter(country.groups)],
                      onSubmitted: (_) => onSubmitted?.call(),
                      cursorColor: AppColors.primary,
                      style: digitStyle,
                      decoration: InputDecoration(
                        hintText: country.example,
                        hintStyle: digitStyle.copyWith(
                          color: AppColors.iconMuted,
                          fontWeight: FontWeight.w500,
                          fontVariations: const [FontVariation('wght', 500)],
                        ),
                        filled: false,
                        isDense: true,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Google's sign-in button: the multicolour G and plain ink, as their
/// branding asks — the same outline as the app's ghost buttons.
class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;

    return Semantics(
      button: true,
      enabled: enabled,
      label: busy ? 'Continue with Google, working' : 'Continue with Google',
      excludeSemantics: true,
      child: Opacity(
        opacity: enabled || busy ? 1 : 0.55,
        child: Material(
          color: AppColors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppColors.inputBorder, width: 1.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 54),
              child: Center(
                child: busy
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: AppColors.textDark,
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SvgPicture.asset(
                            AppVectors.googleG,
                            width: 18,
                            height: 18,
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              'Continue with Google',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.button.copyWith(
                                color: AppColors.textDark,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One country in the picker: flag, name, code, and a tick on the current one.
class _CountryRow extends StatelessWidget {
  const _CountryRow({
    required this.country,
    required this.selected,
    required this.onTap,
  });

  final _Country country;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${country.name}, ${country.code}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
          child: Row(
            children: [
              Text(country.flag, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  country.name,
                  style: AppTextStyles.bodyStrong.copyWith(fontSize: 16),
                ),
              ),
              Text(
                country.code,
                style: AppTextStyles.body.copyWith(color: AppColors.textGrey),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 22,
                child: selected
                    ? Icon(
                        Icons.check_rounded,
                        size: 22,
                        color: AppColors.primary,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
