import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(() {
      ref.read(loginProvider.notifier).setPhone(_phoneController.text.trim());
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
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