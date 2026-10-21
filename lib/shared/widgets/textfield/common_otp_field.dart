// NOTE: `dart:async` and `debugPrint` are only used by Option A (sms_autofill).
// While Option B (smart_auth) is active they are unused — that is a harmless
// analyzer warning. They are kept so switching back is just comment/uncomment.
import 'dart:async';

import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pinput/pinput.dart';
import '../../../core/theme/app_styles.dart';

// ═════════════════════════════════════════════════════════════════════════════
// HOW TO SWITCH BETWEEN THE TWO SMS AUTOFILL OPTIONS
//
// There are three marked places in this file. In each one, comment out the
// ACTIVE option and uncomment the other:
//
//   STEP 1  – the import            (just below)
//   STEP 2  – the _smsRetriever line (inside CommonOtpField)
//   STEP 3  – the SmsRetrieverImpl class (bottom of the file)
//
// Option A — sms_autofill  (INACTIVE)
//   SMS Retriever API. Fully silent: no prompt, no tap. But the SMS must END
//   with the app's 11-character hash or nothing is delivered.
//
// Option B — smart_auth    (ACTIVE)
//   SMS User Consent API. Works with ANY SMS text, but Android shows an
//   "Allow?" prompt the user must tap once.
//
// Both classes are named SmsRetrieverImpl, so only ONE of the two may be
// uncommented at a time.
// ═════════════════════════════════════════════════════════════════════════════

// ── STEP 1: import ───────────────────────────────────────────────────────────
// Option A — sms_autofill (INACTIVE)
// import 'package:sms_autofill/sms_autofill.dart';
// Option B — smart_auth (ACTIVE)
import 'package:smart_auth/smart_auth.dart';

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

  // ── STEP 2: which retriever to create ──────────────────────────────────────
  // Only Android supports SMS autofill. Never create/use it on web (or iOS,
  // which uses the oneTimeCode keyboard hint). `kIsWeb` is checked first:
  // Chrome on an Android phone reports "android".

  // Option A — sms_autofill (INACTIVE)
  // static final SmsRetriever? _smsRetriever =
  //     (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
  //     ? SmsRetrieverImpl(SmsAutoFill())
  //     : null;

  // Option B — smart_auth (ACTIVE)
  static final SmsRetriever? _smsRetriever =
  (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
      ? SmsRetrieverImpl(SmartAuth.instance)
      : null;

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

              // null on web/iOS -> Pinput skips SMS retrieval entirely.
              smsRetriever: _smsRetriever,
            ),
          ),
        );
      },
    );
  }
}

// ── STEP 3: the retriever class ──────────────────────────────────────────────
// Keep exactly ONE of the two classes below uncommented.

// ─────────────────────────────────────────────────────────────────────────────
// Option A — sms_autofill (INACTIVE)
//
// Reads the OTP with Google's SMS Retriever API. Needs NO permission, NO
// "Allow?" dialog and no tap: the code is filled in the moment the SMS arrives.
//
// The catch: Google only hands over SMS messages that end with this app's
// 11-character signature hash, e.g.
//     <#> Your cozune code is 123456
//     FA+9qCX9VSu
// A message without it is never delivered to the app.
// (Debug and release builds have DIFFERENT hashes. Read the current build's
//  hash with:  print(await SmsAutoFill().getAppSignature);)
// ─────────────────────────────────────────────────────────────────────────────
// class SmsRetrieverImpl implements SmsRetriever {
//   const SmsRetrieverImpl(this.smsAutoFill);
//
//   final SmsAutoFill smsAutoFill;
//
//   /// How long one listen lasts. The platform stops listening after 5 minutes.
//   static const Duration _listenWindow = Duration(minutes: 5);
//
//   @override
//   Future<void> dispose() async {
//     try {
//       await smsAutoFill.unregisterListener();
//     } catch (e) {
//       debugPrint('SMS listener cleanup failed: $e');
//     }
//   }
//
//   @override
//   Future<String?> getSmsCode() async {
//     try {
//       await smsAutoFill.listenForCode();
//       final code = await smsAutoFill.code.first.timeout(_listenWindow);
//       return code.isEmpty ? null : code;
//     } on TimeoutException {
//       return null; // nothing arrived in the window
//     } catch (e) {
//       debugPrint('SMS retrieval failed: $e');
//       return null;
//     }
//   }
//
//   // Keep listening after a code arrives, so "Resend code" is picked up too.
//   @override
//   bool get listenForMultipleSms => true;
// }

// ─────────────────────────────────────────────────────────────────────────────
// Option B — smart_auth (ACTIVE)
//
// Reads the OTP with Google's SMS User Consent API. Works with ANY SMS text
// (no hash needed), but Android asks the user to tap "Allow" first.
// ─────────────────────────────────────────────────────────────────────────────
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