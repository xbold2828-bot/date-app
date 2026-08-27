import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/extensions/padding_extension.dart';
import '../../../../core/utils/utils.dart';
import '../../app_text.dart';
import '../../buttons/common_button.dart';
import '../../buttons/common_outlined_button.dart';
import '../../textfield/common_text_field.dart';

class ReasonDialog extends StatefulWidget {
  final String headingText;
  final String descriptionText;
  final String buttonText;
  final String hintText;
  final IconData? iconData;

  const ReasonDialog({
    super.key,
    required this.headingText,
    required this.descriptionText,
    required this.buttonText,
    this.hintText = 'Type your reason here...',
    this.iconData,
  });

  @override
  State<ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<ReasonDialog> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();
  bool _touched = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleConfirm() {
    setState(() => _touched = true);
    if (_formKey.currentState!.validate()) {
      Navigator.of(context).pop(_controller.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: 20.w),
      backgroundColor: colorScheme.onPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            spacerH(15),
            if (widget.iconData != null)
              CircleAvatar(
                backgroundColor: colorScheme.primary,
                radius: 40.r,
                child: Center(child: Icon(widget.iconData)),
              ),
            spacerH(20),
            AppText(
              text: widget.headingText,
              fontSize: 20,
              fontWeight: FontWeight.w600,
              textAlign: TextAlign.center,
              height: 1.25,
            ).paddingSymmetric(horizontal: 10.w),
            spacerH(5),
            AppText(
              text: widget.descriptionText,
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
              textAlign: TextAlign.center,
            ).paddingSymmetric(horizontal: 10.w),
            spacerH(16),
            CommonTextField(
              controller: _controller,
              minLines: 3,
              maxLines: 3,
              maxLength: 500,
              hintText: widget.hintText,
              filled: true,
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) return 'Please enter a reason to continue';
                if (text.length < 5) return 'Please add a bit more detail';
                return null;
              },
            ).paddingSymmetric(horizontal: 10.w),
            spacerH(20),
            Row(
              children: [
                Expanded(
                  child: CommonOutlinedButton(
                    height: 44,
                    text: "Cancel",
                    onClick: () => Navigator.of(context).pop(),
                  ),
                ),
                spacerW(10),
                Expanded(
                  child: CommonButton(
                    height: 44,
                    bgColor: colorScheme.primary,
                    text: widget.buttonText,
                    onClick: _handleConfirm,
                  ),
                ),
              ],
            ).paddingSymmetric(horizontal: 10.w),
            spacerH(10),
          ],
        ).paddingAll(20.r),
      ),
    );
  }
}
