import 'dart:async';
import 'package:dating_app/core/extensions/unfocus_on_tap_extension.dart';
import 'package:dating_app/core/utils/utils.dart';
import 'package:dating_app/shared/widgets/buttons/common_button.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide BackButton;
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/auth_service.dart';
import '../../../shared/widgets/textfield/common_otp_field.dart';
import '../../common/widgets/widgets.dart';

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

  Timer? _timer;
  int _secondsLeft = _resendSeconds;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    _otpFocus.dispose();
    super.dispose();
  }

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
    context.pop();
  }

  /// Called automatically when all 6 digits are entered
  /// (typed manually OR filled from the SMS).
  Future<void> _onVerify([String? code]) async {
    final otp = code ?? _otpController.text;

    if (_isLoading) return; // prevent double submit
    if (otp.length < _length) {
      _showSnack('Please enter the complete OTP');
      return;
    }

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
      _showSnack('Invalid OTP. Please try again.');
      _otpController.clear();
      _otpFocus.requestFocus();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onResendCode() async {
    if (_secondsLeft > 0) return;
    try {
      await _authService.sendOtp(widget.phoneNumber);
      if (!mounted) return;
      _otpController.clear();
      setState(() => _hasError = false);
      _startTimer();
      _showSnack('OTP resent!');
    } catch (e) {
      if (mounted) _showSnack('Failed to resend: $e');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final canResend = _secondsLeft <= 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              spacerH(16),
              BackButton(onTap: () => context.pop()),
              spacerH(20),
              Semantics(
                header: true,
                child:  Text("Verify it's you", style: AppTextStyles.display),
              ),
              spacerH( 12),
              Text.rich(
                TextSpan(
                  style: AppTextStyles.bodyMuted.copyWith(fontSize: 15),
                  children: [
                    const TextSpan(
                      text: 'Enter the 6-digit code we sent to ',
                    ),
                    TextSpan(
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
              spacerH(40),

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
                onCompleted: _onVerify, // auto-verify, no button tap needed
              ),

              spacerH(24),
              Row(
                children: [
                  Text(
                    "Didn't receive a code?  ",
                    style: TextStyle(fontSize: 13, color: AppColors.textGrey),
                  ),
                  GestureDetector(
                    onTap: canResend ? _onResendCode : null,
                    child: Text(
                      canResend ? 'Resend code' : 'Resend in ${_secondsLeft}s',
                      style: TextStyle(
                        fontSize: 13,
                        color: canResend
                            ? AppColors.primary
                            : AppColors.textGrey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              spacerH(32),

              // Kept as a fallback; OTP verifies automatically when complete.
              CommonButton(
                isLoading: _isLoading,
                text: 'Verify & Continue',
                onClick: () => _onVerify(),
              ),

              spacerH(50),
            ],
          ),
        ),
      ),
    ).unfocusOnTap();
  }
}