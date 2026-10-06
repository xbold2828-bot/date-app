import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:dating_app/core/constants/app_constants.dart';
import 'package:dating_app/core/constants/app_text_styles.dart';
import 'package:dating_app/core/theme/app_colors.dart';
import 'package:dating_app/core/utils/utils.dart'; // Ensure openUrl is imported

class LoginTerms extends StatefulWidget {
  const LoginTerms({super.key});

  @override
  State<LoginTerms> createState() => _LoginTermsState();
}

class _LoginTermsState extends State<LoginTerms> {
  late final TapGestureRecognizer _termsRecognizer;
  late final TapGestureRecognizer _privacyRecognizer;

  @override
  void initState() {
    super.initState();
    _termsRecognizer = TapGestureRecognizer()
      ..onTap = () => openUrl(url: AppConstants.termsAndCondition,isExternal: true);
    _privacyRecognizer = TapGestureRecognizer()
      ..onTap = () => openUrl(url: AppConstants.privacyPolicy,isExternal: true);
  }

  @override
  void dispose() {
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseStyle = AppTextStyles.caption.copyWith(
      fontSize: 12,
      height: 1.4,
      color: AppColors.textGrey.withValues(alpha: 0.8),
    );

    final linkStyle = baseStyle.copyWith(
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
      color: AppColors.primary,
    );

    return Center(
      child: Text.rich(
        TextSpan(
          style: baseStyle,
          children: [
            const TextSpan(text: 'By continuing you agree to our '),
            TextSpan(
              text: 'Terms',
              style: linkStyle,
              recognizer: _termsRecognizer,
            ),
            const TextSpan(text: '\nand '),
            TextSpan(
              text: 'Privacy Policy',
              style: linkStyle,
              recognizer: _privacyRecognizer,
            ),
            const TextSpan(text: '.'),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}