import 'package:flutter/material.dart';

import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../presentation/common/widgets/radius_dialog.dart';

/// Asks for a few words of explanation and pops them, trimmed. Pops null on
/// cancel.
class ReasonDialog extends StatefulWidget {
  final String headingText;
  final String descriptionText;
  final String buttonText;
  final String hintText;

  const ReasonDialog({
    super.key,
    required this.headingText,
    required this.descriptionText,
    required this.buttonText,
    this.hintText = 'What happened?',
  });

  @override
  State<ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<ReasonDialog> {
  static const int _maxLength = 500;
  static const int _minLength = 5;

  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    // The send row enables itself as the reason gets long enough.
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _ready => _controller.text.trim().length >= _minLength;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color, width: width),
    );

    return RadiusAlert(
      title: widget.headingText,
      message: widget.descriptionText,
      actions: [
        RadiusAlertAction(
          label: widget.buttonText,
          tone: RadiusAlertTone.primary,
          onPressed: _ready
              ? () => Navigator.of(context).pop(_controller.text.trim())
              : null,
        ),
        RadiusAlertAction(
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
      child: TextField(
        controller: _controller,
        autofocus: true,
        minLines: 3,
        maxLines: 5,
        maxLength: _maxLength,
        cursorColor: AppColors.primary,
        textCapitalization: TextCapitalization.sentences,
        style: AppTextStyles.body,
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: AppTextStyles.body.copyWith(color: AppColors.iconMuted),
          filled: true,
          fillColor: AppColors.card,
          isDense: true,
          contentPadding: const EdgeInsets.all(14),
          counterStyle: AppTextStyles.caption.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
          border: border(AppColors.inputBorder, 1.5),
          enabledBorder: border(AppColors.inputBorder, 1.5),
          focusedBorder: border(AppColors.primary, 2),
        ),
      ),
    );
  }
}
