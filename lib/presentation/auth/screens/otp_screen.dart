import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_text_styles.dart';
import '../../../core/extensions/unfocus_on_tap_extension.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/auth_service.dart';
import '../../../shared/widgets/textfield/common_otp_field.dart';
import '../../common/widgets/widgets.dart';

/// The second half of phone sign-in: six digits from a text message.
///
/// Laid out like an onboarding step — the way back top left, one question,
/// the boxes, and the action pinned to the bottom edge. The code verifies by
/// itself as the sixth digit lands (typed or read from the SMS); the button
/// is there for the person who pasted it and wants to press something.
class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key, required this.phoneNumber});

  final String phoneNumber;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  static const int _length = 6;
  static const int _resendSeconds = 30;

  final TextEditingController _otpController = TextEditingController();
  final FocusNode _otpFocus = FocusNode();
  final AuthService _authService = AuthService();

  late final TapGestureRecognizer _changeNumberTap = TapGestureRecognizer()
    ..onTap = _changeNumber;

  bool _isLoading = false;
  bool _hasError = false;
  bool _resending = false;

  Timer? _timer;
  int _secondsLeft = _resendSeconds;

  @override
  void initState() {
    super.initState();
    _otpController.addListener(_onCodeChanged);
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    _otpFocus.dispose();
    _changeNumberTap.dispose();
    super.dispose();
  }

  void _onCodeChanged() => setState(() {});

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = _resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      if (_secondsLeft <= 1) {
        t.cancel();
      }
      setState(() => _secondsLeft--);
    });
  }

  void _changeNumber() {
    if (routeCanPop(context)) routePop(context);
  }

  /// Called automatically when all 6 digits are entered
  /// (typed manually OR filled from the SMS).
  Future<void> _onVerify([String? code]) async {
    final otp = code ?? _otpController.text;

    if (_isLoading) return; // prevent double submit
    if (otp.length < _length) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final response = await _authService.verifyOtp(
        phone: widget.phoneNumber,
        token: otp,
      );

      // The splash screen decides between onboarding and home.
      if (response.user != null && mounted) {
        context.go(AppRoutes.splash, extra: true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _hasError = true);
      _otpController.clear();
      _otpFocus.requestFocus();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onResendCode() async {
    if (_secondsLeft > 0 || _resending) return;
    setState(() => _resending = true);
    try {
      await _authService.sendOtp(widget.phoneNumber);
      if (!mounted) return;
      _otpController.clear();
      setState(() => _hasError = false);
      _startTimer();
      showRadiusToast(context, 'New code sent', tone: ToastTone.success);
    } catch (e) {
      if (mounted) {
        showRadiusToast(
          context,
          "Couldn't send a new code. Try again in a moment.",
          tone: ToastTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final complete = _otpController.text.length == _length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
              child: SizedBox(
                height: 48,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: BackChevron(onTap: _changeNumber),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        'Check your\nmessages',
                        style: AppTextStyles.question,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text.rich(
                      TextSpan(
                        style: AppTextStyles.bodyMuted.copyWith(fontSize: 15),
                        children: [
                          const TextSpan(
                            text: 'Enter the 6-digit code we sent to ',
                          ),
                          TextSpan(
                            // Non-breaking spaces: a number split across two
                            // lines is a number nobody can check at a glance.
                            text: displayPhoneNumber(widget.phoneNumber)
                                .replaceAll(' ', ' '),
                            style: TextStyle(
                              color: AppColors.textDark,
                              fontWeight: FontWeight.w600,
                              fontVariations: const [
                                FontVariation('wght', 600),
                              ],
                            ),
                          ),
                          const TextSpan(text: '. '),
                          TextSpan(
                            text: 'Wrong number?',
                            style: TextStyle(
                              color: AppColors.primaryInk,
                              fontWeight: FontWeight.w600,
                              fontVariations: const [
                                FontVariation('wght', 600),
                              ],
                            ),
                            recognizer: _changeNumberTap,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 36),
                    CommonOtpField(
                      length: _length,
                      controller: _otpController,
                      focusNode: _otpFocus,
                      autoFocus: true,
                      enabled: !_isLoading,
                      hasError: _hasError,
                      onChanged: (_) {
                        if (_hasError) setState(() => _hasError = false);
                      },
                      onCompleted: _onVerify,
                    ),
                    const SizedBox(height: 16),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: _hasError
                          ? Semantics(
                              key: const ValueKey('otp-error'),
                              liveRegion: true,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 1),
                                    child: Icon(
                                      Icons.error_outline_rounded,
                                      size: 16,
                                      color: AppColors.danger,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      "That code didn't work. Check the "
                                      'message and try again.',
                                      style: AppTextStyles.caption.copyWith(
                                        fontSize: 13.5,
                                        color: AppColors.danger,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : const SizedBox(key: ValueKey('otp-ok'), height: 0),
                    ),
                    const SizedBox(height: 8),
                    _ResendLine(
                      secondsLeft: _secondsLeft,
                      resending: _resending,
                      onResend: _onResendCode,
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
              child: RadiusButton(
                label: 'Verify',
                isLoading: _isLoading,
                onPressed: complete ? () => _onVerify() : null,
              ),
            ),
          ],
        ),
      ),
    ).unfocusOnTap();
  }
}

/// "+918688712132" as people read it: "+91 86887 12132".
String displayPhoneNumber(String e164) {
  String grouped(String digits, List<int> groups) {
    final out = StringBuffer();
    var i = 0;
    for (final g in groups) {
      if (i >= digits.length) break;
      if (out.isNotEmpty) out.write(' ');
      final end = (i + g).clamp(0, digits.length);
      out.write(digits.substring(i, end));
      i = end;
    }
    if (i < digits.length) out.write(digits.substring(i));
    return out.toString();
  }

  if (e164.startsWith('+91') && e164.length == 13) {
    return '+91 ${grouped(e164.substring(3), const [5, 5])}';
  }
  if (e164.startsWith('+1') && e164.length == 12) {
    return '+1 ${grouped(e164.substring(2), const [3, 3, 4])}';
  }
  return e164;
}

/// "Resend code in 0:29", then a way to ask for another.
class _ResendLine extends StatelessWidget {
  const _ResendLine({
    required this.secondsLeft,
    required this.resending,
    required this.onResend,
  });

  final int secondsLeft;
  final bool resending;
  final VoidCallback onResend;

  @override
  Widget build(BuildContext context) {
    if (secondsLeft > 0) {
      final m = secondsLeft ~/ 60;
      final s = (secondsLeft % 60).toString().padLeft(2, '0');
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'Get a new code in $m:$s',
          style: AppTextStyles.caption.copyWith(
            fontSize: 13.5,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        onPressed: resending ? null : onResend,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
          minimumSize: const Size(0, 44),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          foregroundColor: AppColors.primaryInk,
        ),
        child: Text(
          resending ? 'Sending a new code…' : 'Send me a new code',
          style: AppTextStyles.bodyStrong.copyWith(
            fontSize: 14.5,
            color: resending ? AppColors.textGrey : AppColors.primaryInk,
            fontWeight: FontWeight.w700,
            fontVariations: const [FontVariation('wght', 700)],
          ),
        ),
      ),
    );
  }
}
