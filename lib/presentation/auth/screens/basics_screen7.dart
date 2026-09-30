import 'package:dating_app/core/constants/app_string.dart';
import 'package:dating_app/core/utils/app_snack_bar.dart';
import 'package:dating_app/core/utils/utils.dart';
import 'package:dating_app/shared/widgets/buttons/common_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/extensions/global_back_extension.dart';
import '../../../core/extensions/unfocus_on_tap_extension.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/core_providers.dart';
import '../../../providers/profile_provider.dart';
import '../widgets/onboarding_widgets.dart';

class BasicsScreen7 extends ConsumerStatefulWidget {
  const BasicsScreen7({super.key});

  @override
  ConsumerState<BasicsScreen7> createState() => _BasicsScreen7State();
}

class _BasicsScreen7State extends ConsumerState<BasicsScreen7> {
  final List<_Consent> _agreements = [
    _Consent(field: 'isAdult', text: AppString.agreementAdult),
    _Consent(field: 'willBeRespectful', text: AppString.agreementRespectful),
    _Consent(field: 'noHarassment', text: AppString.agreementNoHarassment),
    _Consent(field: 'consentMatters', text: AppString.agreementConsent),
  ];

  bool _isLoading = false;

  bool get _allChecked => _agreements.every((a) => a.checked);

  bool _checked(String field) =>
      _agreements.firstWhere((a) => a.field == field).checked;

  Future<void> _onEnter() async {
    if (!_allChecked) {
      AppSnackBar.showWarningSnackBar(
        message: "You must agree to all terms to continue",
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final me = await ref.read(onboardingRepositoryProvider).acceptAgreement(
        isAdult: _checked('isAdult'),
        willBeRespectful: _checked('willBeRespectful'),
        noHarassment: _checked('noHarassment'),
        consentMatters: _checked('consentMatters'),
      );
      ref.read(meProvider.notifier).setMe(me);

      if (mounted) context.go(AppRoutes.dashboard);
    } on AppException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const OnboardingHeader(step: 8, label: AppString.sectionAgreement),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    spacerH(24),
                    Text(AppString.agreementTitle, style: AppTextStyles.display),
                    spacerH(6),
                    Text(
                      AppString.agreementSubtitle,
                      style: TextStyle(fontSize: 13, color: AppColors.textGrey),
                    ),
                    spacerH(32),
                    Expanded(
                      child: ListView.separated(
                        itemCount: _agreements.length,
                        separatorBuilder: (_, _) => spacerH(12),
                        itemBuilder: (_, index) => _agreementTile(
                          _agreements[index],
                        ),
                      ),
                    ),
                    spacerH(16),
                    Text(
                      AppString.agreementNote,
                      style: TextStyle(fontSize: 11.5, color: AppColors.textGrey),
                    ),
                    spacerH(16),
                    CommonButton(
                      text: AppString.enterCozune,
                      isLoading: _isLoading,
                      onClick: _onEnter,
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

  Widget _agreementTile(_Consent item) {
    final checked = item.checked;

    return GestureDetector(
      onTap: () => setState(() => item.checked = !checked),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: checked
              ? AppColors.primary.withValues(alpha: 0.06)
              : AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: checked ? AppColors.primary : AppColors.inputBorder,
            width: checked ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: checked ? AppColors.primary : AppColors.card,
                border: Border.all(
                  color: checked ? AppColors.primary : AppColors.inputBorder,
                  width: 2,
                ),
              ),
              child: checked
                  ? Icon(Icons.check, size: 14, color: AppColors.onAccent)
                  : null,
            ),
            spacerW(16),
            Text(
              item.text,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: checked ? AppColors.primary : AppColors.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Consent {
  _Consent({required this.field, required this.text});

  /// Matches the property name on `AcceptAgreementDto`.
  final String field;
  final String text;
  bool checked = false;
}