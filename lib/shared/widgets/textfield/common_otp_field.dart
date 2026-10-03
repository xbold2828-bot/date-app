import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pinput/pinput.dart';
import 'package:smart_auth/smart_auth.dart';

import '../../../core/constants/app_text_styles.dart';
import '../../../core/theme/app_colors.dart';

/// One box per digit, sized to the width it is given.
///
/// Flat boxes in the funnel's own style — the birthday boxes on the age step
/// are the same shape — with the focused box in accent blue, filled boxes in
/// ink, and every box red while [hasError].
class CommonOtpField extends StatelessWidget {
  final int length;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String> onCompleted;
  final TextStyle? textStyle;
  final bool autoFocus;
  final bool enabled;
  final bool hasError;
  final TextEditingController? controller;
  final FocusNode? focusNode;

  const CommonOtpField({
    super.key,
    this.length = 6,
    this.onChanged,
    required this.onCompleted,
    this.autoFocus = false,
    this.textStyle,
    this.enabled = true,
    this.hasError = false,
    this.controller,
    this.focusNode,
  });

  static const double _gap = 8;
  static const double _maxBoxWidth = 56;
  static const double _minBoxWidth = 38;

  static final SmsRetriever _smsRetriever = SmsRetrieverImpl(
    SmartAuth.instance,
  );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth - (_gap * (length - 1));
        final boxWidth = (available / length)
            .clamp(_minBoxWidth, _maxBoxWidth)
            .toDouble();
        final boxHeight = boxWidth * 1.18;

        BoxDecoration box(Color border, double width) => BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border, width: width),
        );

        final defaultPinTheme = PinTheme(
          width: boxWidth,
          height: boxHeight,
          textStyle:
              textStyle ??
              AppTextStyles.bodyStrong.copyWith(
                fontSize: 24,
                height: 1.2,
                fontWeight: FontWeight.w700,
                fontVariations: const [FontVariation('wght', 700)],
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
          decoration: box(AppColors.inputBorder, 1.5),
        );

        return Opacity(
          opacity: enabled ? 1 : 0.55,
          child: Pinput(
            controller: controller,
            focusNode: focusNode,
            length: length,
            autofocus: autoFocus,
            enabled: enabled,
            keyboardType: TextInputType.number,
            mainAxisAlignment: MainAxisAlignment.start,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: onChanged,
            onCompleted: onCompleted,
            defaultPinTheme: defaultPinTheme,
            focusedPinTheme: defaultPinTheme.copyWith(
              decoration: box(AppColors.primary, 2),
            ),
            submittedPinTheme: defaultPinTheme.copyWith(
              decoration: box(AppColors.textDark.withValues(alpha: 0.5), 1.5),
            ),
            errorPinTheme: defaultPinTheme.copyWith(
              decoration: box(AppColors.danger, 2),
            ),
            forceErrorState: hasError,
            showCursor: true,
            cursor: Container(
              width: 2,
              height: boxHeight * 0.42,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            separatorBuilder: (index) => const SizedBox(width: _gap),
            hapticFeedbackType: HapticFeedbackType.selectionClick,

            // Android SMS autofill (iOS uses the default oneTimeCode hint).
            smsRetriever: _smsRetriever,
          ),
        );
      },
    );
  }
}

class SmsRetrieverImpl implements SmsRetriever {
  const SmsRetrieverImpl(this.smartAuth);

  final SmartAuth smartAuth;

  @override
  Future<void> dispose() => smartAuth.removeUserConsentApiListener();

  @override
  Future<String?> getSmsCode() async {
    final res = await smartAuth.getSmsWithUserConsentApi();
    if (res.hasData) {
      return res.requireData.code;
    }
    return null;
  }

  @override
  bool get listenForMultipleSms => true;
}
