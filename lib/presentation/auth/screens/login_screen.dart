import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../common/widgets/widgets.dart';
import 'otp_screen.dart';
import '../../../data/services/auth_service.dart';
import 'authed_bootstrap.dart';

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
    _selectedCountry = _countryCodes[0]; // India by default
  }

  Future<void> _onContinue() async {
    final phone = _phoneController.text.trim();
    final requiredLength = int.parse(_selectedCountry['digits']!);

    if (phone.isEmpty || phone.length != requiredLength) {
      // Names the country, because the required length depends on it.
      showRadiusToast(
        context,
        '${_selectedCountry['name']} numbers are $requiredLength digits',
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final fullPhone = '${_selectedCountry['code']}$phone';
      await _authService.sendOtp(fullPhone);

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtpScreen(phoneNumber: fullPhone),
          ),
        );
      }
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

      if (response == null) {
        // user cancelled — do nothing
        return;
      }

      if (response.user != null && mounted) {
        // Real onboarding-vs-home routing happens in AuthedBootstrap once the
        // domain user (/users/me) is loaded.
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const AuthedBootstrap()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        showRadiusToast(context, "Couldn't sign in with Google. Try again.");
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  /// Lets someone pick the dialling code. A sheet rather than a dropdown
  /// because each row carries a flag and a name, not just a number.
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
                  // The digit count differs per country, so a number typed for
                  // the previous one would fail validation with no visible
                  // reason.
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
            // Scrolls only when it must: on a short screen, or once the
            // keyboard is up. On a normal phone the layout still fills.
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 40,
              ),
              // The scroll view offers unbounded height, and `ConstrainedBox`
              // only raises the floor — so without this the Column below is
              // shrink-wrapping while its `Spacer` is asking to fill, which is
              // a layout assertion rather than a warning. IntrinsicHeight
              // measures the content and hands the Column a tight height of
              // `max(content, minHeight)`, which keeps both readings of the
              // layout true: it fills a tall screen and scrolls a short one.
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Wordmark(size: 22),
                    const SizedBox(height: 30),

                    // The brand moment: proximity, drawn. Four rings, one per
                    // distance band — none active, because nobody has a location
                    // yet and the mark should not pretend otherwise.
                    const Center(child: RadarMark(size: 104, animate: true)),
                    const SizedBox(height: 30),

                    Text('18+ · Verified people only',
                        style: AppTextStyles.eyebrow),
                    const SizedBox(height: 10),
                    Text("Who's around you\ntonight?",
                        style: AppTextStyles.display),
                    const SizedBox(height: 12),
                    Text(
                      'Real, verified people nearby who want the same thing you '
                      'do. No endless swiping.',
                      style: AppTextStyles.bodyMuted,
                    ),

                    const SizedBox(height: 30),

                    const SectionLabel('Phone number', topSpacing: 0),
                    Row(
                      children: [
                        _CountryButton(
                          country: _selectedCountry,
                          onTap: _pickCountry,
                        ),
                        const SizedBox(width: 10),
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

                    const SizedBox(height: 18),

                    RadiusButton(
                      // Says exactly what pressing it does; the next screen then
                      // asks for the code it just sent.
                      label: 'Send code',
                      isLoading: _isLoading,
                      onPressed: _onContinue,
                    ),

                    const SizedBox(height: 20),
                    const _OrDivider(),
                    const SizedBox(height: 20),

                    RadiusButton(
                      label: 'Continue with Google',
                      kind: RadiusButtonKind.ghost,
                      onPressed: _isLoading ? null : _onGoogleSignIn,
                    ),

                    const SizedBox(height: 28),
                    const Spacer(),

                    Center(
                      child: Text(
                        "By continuing you confirm you're 18 or older and agree "
                        'to our Terms and Privacy Policy.',
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
    );
  }
}

/// The dialling-code control sitting left of the phone field.
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
        color: AppColors.white,
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
                const SizedBox(width: 6),
                Text(country['code']!, style: AppTextStyles.bodyStrong),
                const Icon(
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
        const Expanded(child: Divider(color: AppColors.inputBorder)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text('OR', style: AppTextStyles.label),
        ),
        const Expanded(child: Divider(color: AppColors.inputBorder)),
      ],
    );
  }
}
