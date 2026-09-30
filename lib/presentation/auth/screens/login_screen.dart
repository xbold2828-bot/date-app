import 'package:dating_app/core/utils/utils.dart';
import 'package:dating_app/shared/widgets/buttons/common_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/extensions/global_back_extension.dart';
import '../../../core/extensions/unfocus_on_tap_extension.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/auth_service.dart';
import '../../common/widgets/widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final AuthService _authService = AuthService();

  final List<Map<String, String>> _countryCodes = [
    {'name': 'India', 'code': '+91', 'flag': '🇮🇳', 'digits': '10'},
    {'name': 'US', 'code': '+1', 'flag': '🇺🇸', 'digits': '10'},
  ];
  late Map<String, String> _selectedCountry;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedCountry = _countryCodes[0];
  }

  Future<void> _onContinue() async {
    final phone = _phoneController.text.trim();
    final requiredLength = int.parse(_selectedCountry['digits']!);

    if (phone.isEmpty || phone.length != requiredLength) {
      showRadiusToast(
        context,
        '${_selectedCountry['name']} numbers are $requiredLength digits',
      );
      return;
    }

    setState(() => _isLoading = true);

    removeFocus();
    try {
      final fullPhone = '${_selectedCountry['code']}$phone';
      await _authService.sendOtp(fullPhone);

      if (mounted) context.push(AppRoutes.signInOtp, extra: fullPhone);
    } catch (e) {
      if (mounted) {
        showRadiusToast(context, "Couldn't send the code. Try again.");
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onGoogleSignIn() async {
    setState(() => _isLoading = true);

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
      if (mounted) setState(() => _isLoading = false);
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

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _pickCountry() {
    showRadiusSheet<void>(
      context: context,
      builder: (sheetContext) => RadiusSheet(
        title: 'Country',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _countryCodes.map((country) {
            final isSelected = _selectedCountry['code'] == country['code'];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: RadiusOptionTile(
                title: country['name']!,
                subtitle: '${country['code']} · ${country['digits']} digits',
                selected: isSelected,
                leading: Text(
                  country['flag']!,
                  style: const TextStyle(fontSize: 24),
                ),
                onTap: () {
                  setState(() => _selectedCountry = country);
                  // Digit counts differ per country, so a number typed for the
                  // previous one would fail validation for no visible reason.
                  _phoneController.clear();
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight - 40),
              // IntrinsicHeight lets the Spacer fill a tall screen while the
              // scroll view still scrolls on a short one.
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Wordmark(size: 22),
                    spacerH(30),
                    const Center(child: RadarMark(size: 104, animate: true)),
                    spacerH(30),
                    Text(
                      '18+ · Verified people only',
                      style: AppTextStyles.eyebrow,
                    ),
                    spacerH(10),
                    Text(
                      "Who's around you\ntonight?",
                      style: AppTextStyles.display,
                    ),
                    spacerH(12),
                    Text(
                      'Real, verified people nearby who want the same thing '
                          'you do. No endless swiping.',
                      style: AppTextStyles.bodyMuted,
                    ),
                    spacerH(30),
                    const SectionLabel('Phone number', topSpacing: 0),
                    Row(
                      children: [
                        _CountryButton(
                          country: _selectedCountry,
                          onTap: _pickCountry,
                        ),
                        spacerW(10),
                        Expanded(
                          child: TextField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(
                                int.parse(_selectedCountry['digits']!),
                              ),
                            ],
                            style: AppTextStyles.body,
                            decoration: const InputDecoration(
                              hintText: '000 000 0000',
                            ),
                          ),
                        ),
                      ],
                    ),
                    spacerH(18),
                    CommonButton(
                      text: 'Send code',
                      isLoading: _isLoading,
                      onClick: _onContinue,
                    ),
                    spacerH(20),
                    const _OrDivider(),
                    spacerH(20),
                    RadiusButton(
                      label: 'Continue with Google',
                      kind: RadiusButtonKind.ghost,
                      onPressed: _isLoading ? null : _onGoogleSignIn,
                    ),
                    spacerH(28),
                    const Spacer(),
                    Center(
                      child: Text(
                        "By continuing you confirm you're 18 or older and "
                            'agree to our Terms and Privacy Policy.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.caption.copyWith(fontSize: 11.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ).unfocusOnTap().withGlobalBackHandler(context);;
  }
}

/// The dialling-code control left of the phone field.
class _CountryButton extends StatelessWidget {
  const _CountryButton({required this.country, required this.onTap});

  final Map<String, String> country;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Country: ${country['name']}, ${country['code']}',
      excludeSemantics: true,
      child: Material(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.inputBorder, width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(country['flag']!, style: const TextStyle(fontSize: 18)),
                spacerW(6),
                Text(country['code']!, style: AppTextStyles.bodyStrong),
                Icon(
                  Icons.keyboard_arrow_down,
                  size: 18,
                  color: AppColors.textGrey,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: AppColors.inputBorder)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text('OR', style: AppTextStyles.label),
        ),
        Expanded(child: Divider(color: AppColors.inputBorder)),
      ],
    );
  }
}