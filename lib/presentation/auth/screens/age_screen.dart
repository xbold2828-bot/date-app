import 'package:dating_app/core/constants/app_string.dart';
import 'package:dating_app/core/extensions/global_back_extension.dart';
import 'package:dating_app/core/extensions/unfocus_on_tap_extension.dart';
import 'package:dating_app/core/utils/utils.dart';
import 'package:dating_app/shared/widgets/buttons/common_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/core_providers.dart';
import '../../../providers/profile_provider.dart';
import '../widgets/onboarding_widgets.dart';

class AgeScreen extends ConsumerStatefulWidget {
  const AgeScreen({super.key});

  @override
  ConsumerState<AgeScreen> createState() => _AgeScreenState();
}

class _AgeScreenState extends ConsumerState<AgeScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _dayController = TextEditingController();
  final TextEditingController _monthController = TextEditingController();
  final TextEditingController _yearController = TextEditingController();

  DateTime? _selectedDate;
  bool _isAdult = false;
  bool _isLoading = false;

  Future<void> _onContinue() async {
    if (_nameController.text.trim().isEmpty) {
      _showSnack(AppString.ageEnterName);
      return;
    }
    if (_selectedDate == null) {
      _showSnack(AppString.ageSelectDob);
      return;
    }
    if (!_isAdult) {
      _showSnack(AppString.ageMustBeAdult);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final dob = _selectedDate!.toIso8601String().split('T').first;
      final me = await ref.read(onboardingRepositoryProvider).updateAge(dob);
      ref.read(meProvider.notifier).setMe(me);

      if (mounted) {
        context.push(AppRoutes.basics, extra: _nameController.text.trim());
      }
    } on AppException catch (e) {
      _showSnack(e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dayController.dispose();
    _monthController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final maxDate = DateTime(now.year - 1, now.month, now.day);
    final minDate = DateTime(now.year - 80);

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: minDate,
      lastDate: maxDate,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: AppColors.onAccent,
              surface: AppColors.card,
              onSurface: AppColors.textDark,
            ),
            dialogTheme: DialogThemeData(backgroundColor: AppColors.card),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final age = DateTime.now().difference(picked).inDays ~/ 365;

      setState(() {
        _selectedDate = picked;
        _dayController.text = picked.day.toString().padLeft(2, '0');
        _monthController.text = picked.month.toString().padLeft(2, '0');
        _yearController.text = picked.year.toString();
        _isAdult = age >= 18;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const OnboardingHeader(step: 1, label: AppString.sectionIdentity,isShowBackButton: false),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    spacerH(24),
                    Text(AppString.ageTitle, style: AppTextStyles.display),
                    spacerH(8),
                    Text(
                      AppString.ageSubtitle,
                      style: TextStyle(fontSize: 14, color: AppColors.textGrey),
                    ),
                    spacerH(32),
                    Text(
                      AppString.displayNameCaps,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textGrey,
                        letterSpacing: 1.1,
                      ),
                    ),
                    spacerH(8),
                    TextField(
                      controller: _nameController,
                      style: TextStyle(fontSize: 15, color: AppColors.textDark),
                      decoration: InputDecoration(
                        hintText: AppString.displayNameHint,
                        hintStyle: TextStyle(color: AppColors.textGrey),
                        filled: true,
                        fillColor: AppColors.card,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: AppColors.inputBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: AppColors.inputBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                          BorderSide(color: AppColors.primary, width: 1.5),
                        ),
                      ),
                    ),
                    spacerH(24),
                    Row(
                      children: [
                        _dobField(
                          AppString.dayLabel,
                          AppString.dayHint,
                          _dayController,
                        ),
                        spacerW(12),
                        _dobField(
                          AppString.monthLabel,
                          AppString.monthHint,
                          _monthController,
                        ),
                        spacerW(12),
                        _dobField(
                          AppString.yearLabel,
                          AppString.yearHint,
                          _yearController,
                        ),
                      ],
                    ),
                    spacerH(28),
                    _adultConfirmation(),
                    spacerH(20),
                    _infoNote(Icons.info_outline, AppString.ageNotePrivacy),
                    spacerH(12),
                    _infoNote(
                      Icons.chat_bubble_outline,
                      AppString.ageNoteOtp,
                    ),
                    spacerH(32),
                    CommonButton(
                      isLoading: _isLoading,
                      text: AppString.continueText,
                      onClick: _onContinue,
                    ),
                    spacerH(32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ).unfocusOnTap().withGlobalBackHandler(context);
  }

  Widget _adultConfirmation() {
    final picked = _selectedDate != null;
    final underage = picked && !_isAdult;

    return GestureDetector(
      onTap: picked ? null : () => _showSnack(AppString.ageSelectDobFirst),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _isAdult
              ? AppColors.primary.withValues(alpha: 0.08)
              : (underage
              ? AppColors.danger.withValues(alpha: 0.08)
              : AppColors.card),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isAdult
                ? AppColors.primary
                : (underage ? Colors.red.shade200 : AppColors.inputBorder),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isAdult ? AppColors.primary : Colors.grey.shade200,
                border: Border.all(
                  color: _isAdult ? AppColors.primary : Colors.grey.shade400,
                  width: 2,
                ),
              ),
              child: _isAdult
                  ? Icon(Icons.check, size: 14, color: AppColors.onAccent)
                  : (underage
                  ? const Icon(Icons.close, size: 14, color: Colors.red)
                  : null),
            ),
            spacerW(12),
            Expanded(
              child: Text(
                underage ? AppString.ageUnderage : AppString.ageConfirm,
                style: TextStyle(
                  fontSize: 14,
                  color: _isAdult
                      ? AppColors.textDark
                      : (underage ? Colors.red.shade400 : AppColors.textGrey),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (underage)
              const Icon(Icons.lock_outline, size: 16, color: Colors.red),
          ],
        ),
      ),
    );
  }

  Widget _dobField(
      String label,
      String hint,
      TextEditingController controller,
      ) {
    final isFilled = controller.text.isNotEmpty;
    final borderColor = isFilled ? AppColors.primary : AppColors.inputBorder;
    final borderWidth = isFilled ? 1.5 : 1.0;

    OutlineInputBorder border() => OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: borderColor, width: borderWidth),
    );

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textGrey,
              letterSpacing: 1.1,
            ),
          ),
          spacerH(6),
          GestureDetector(
            onTap: _pickDate,
            child: AbsorbPointer(
              child: TextField(
                controller: controller,
                textAlign: TextAlign.center,
                readOnly: true,
                style: TextStyle(
                  fontSize: 15,
                  color: isFilled ? AppColors.textDark : AppColors.textGrey,
                  fontWeight: isFilled ? FontWeight.w600 : FontWeight.normal,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: hint,
                  hintStyle: TextStyle(color: AppColors.textGrey),
                  filled: true,
                  fillColor: AppColors.card,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: border(),
                  enabledBorder: border(),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoNote(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.textGrey),
        spacerW(10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 12, color: AppColors.textGrey),
          ),
        ),
      ],
    );
  }
}