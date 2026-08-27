import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/utils/utils.dart';
import 'buttons/common_button.dart';
import 'buttons/common_outlined_button.dart';

class CommonBottomTwoButtons extends StatelessWidget {
  final bool onTapCancelGoBack;
  final VoidCallback? onTapCancel;
  final VoidCallback onTapSend;
  final String? cancelText;
  final String? sendText;
  final bool isLoading;

  const CommonBottomTwoButtons({
    super.key,
    this.onTapCancel,
    this.onTapCancelGoBack = true,
    required this.onTapSend,
    this.cancelText,
    this.isLoading = false,
    this.sendText,
  });

  VoidCallback? _resolveCancelAction(BuildContext context) {
    if (onTapCancelGoBack) return () => context.pop();
    return onTapCancel; // may be null — button will appear disabled
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: CommonOutlinedButton(
            text: cancelText ?? "Cancel",
            onClick: _resolveCancelAction(context),
          ),
        ),
        spacerW(15),
        Expanded(
          child: CommonButton(
            isLoading: isLoading,
            text: sendText ?? "Send",
            onClick: onTapSend,
          ),
        ),
      ],
    );
  }
}
