import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pinput/pinput.dart';
import 'package:smart_auth/smart_auth.dart';
import '../../../core/theme/app_styles.dart';

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

  static const double _gap = 10;
  static const double _maxBoxWidth = 54;
  static const double _minBoxWidth = 38;

  static final SmsRetriever _smsRetriever =
  SmsRetrieverImpl(SmartAuth.instance);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth - (_gap * (length - 1));
        final boxWidth =
        (available / length).clamp(_minBoxWidth, _maxBoxWidth).toDouble();
        final boxHeight = boxWidth * 1.15;

        final defaultPinTheme = PinTheme(
          width: boxWidth,
          height: boxHeight,
          textStyle: textStyle ??
              context.appTextStyle(fontSize: 22, fontWeight: FontWeight.w600),
          decoration: BoxDecoration(
            color: enabled ? Colors.white : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 3),
              ),
            ],
          ),
        );

        final focusedPinTheme = defaultPinTheme.copyWith(
          decoration: defaultPinTheme.decoration!.copyWith(
            border: Border.all(color: Colors.black87, width: 1.5),
          ),
        );

        final submittedPinTheme = defaultPinTheme.copyWith(
          decoration: defaultPinTheme.decoration!.copyWith(
            border: Border.all(color: Colors.black54, width: 1.2),
          ),
        );

        final errorPinTheme = defaultPinTheme.copyWith(
          decoration: defaultPinTheme.decoration!.copyWith(
            border: Border.all(color: Colors.redAccent, width: 1.5),
          ),
        );

        return IgnorePointer(
          ignoring: !enabled,
          child: Opacity(
            opacity: enabled ? 1 : 0.6,
            child: Pinput(
              controller: controller,
              focusNode: focusNode,
              length: length,
              autofocus: autoFocus,
              enabled: enabled,
              keyboardType: TextInputType.number,
              mainAxisAlignment: MainAxisAlignment.center,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: onChanged,
              onCompleted: onCompleted,
              defaultPinTheme: defaultPinTheme,
              focusedPinTheme: focusedPinTheme,
              submittedPinTheme: submittedPinTheme,
              errorPinTheme: errorPinTheme,
              forceErrorState: hasError,
              showCursor: true,
              separatorBuilder: (index) => const SizedBox(width: _gap),

              // Android SMS autofill (iOS uses the default oneTimeCode hint).
              smsRetriever: _smsRetriever,
            ),
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