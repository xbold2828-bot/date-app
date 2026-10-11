import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dating_app/core/constants/app_constants.dart';
import 'package:dating_app/core/constants/app_text_styles.dart';
import 'package:dating_app/core/theme/app_colors.dart';
import 'package:dating_app/core/utils/utils.dart';
import '../../../../providers/auth/login_provider/login_provider.dart';

class LoginTerms extends ConsumerStatefulWidget {
  const LoginTerms({super.key});

  @override
  ConsumerState<LoginTerms> createState() => _LoginTermsState();
}

class _LoginTermsState extends ConsumerState<LoginTerms> {
  late final TapGestureRecognizer _termsRecognizer;
  late final TapGestureRecognizer _privacyRecognizer;

  @override
  void initState() {
    super.initState();
    _termsRecognizer = TapGestureRecognizer()
      ..onTap = () =>
          openUrl(url: AppConstants.termsAndCondition, isExternal: true);
    _privacyRecognizer = TapGestureRecognizer()
      ..onTap =
          () => openUrl(url: AppConstants.privacyPolicy, isExternal: true);
  }

  @override
  void dispose() {
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accepted = ref.watch(termsAcceptedProvider);

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
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: SizedBox(
                width: 15,
                height: 15,
                child: Checkbox(
                  value: accepted,
                  activeColor: AppColors.primary,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  onChanged: (value) => ref
                      .read(termsAcceptedProvider.notifier)
                      .state = value ?? false,
                ),
              ),
            ),
            WidgetSpan(child: spacerW(10)),
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