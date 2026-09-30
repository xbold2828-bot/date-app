import 'package:dating_app/core/constants/app_string.dart';
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

class StatusScreen extends ConsumerStatefulWidget {
  const StatusScreen({super.key});

  @override
  ConsumerState<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends ConsumerState<StatusScreen> {
  static const List<(String, String, String)> _options = [
    (AppString.statusSingle, 'single', AppString.statusSingleBlurb),
    (AppString.statusSeeing, 'seeing_someone', AppString.statusSeeingBlurb),
    (AppString.statusOpen, 'open_relationship', AppString.statusOpenBlurb),
    (AppString.statusCouple, 'couple', AppString.statusCoupleBlurb),
    (
    AppString.statusPrivate,
    'prefer_not_to_say',
    AppString.statusPrivateBlurb,
    ),
  ];

  String? _selected;
  bool _isLoading = false;

  Future<void> _onContinue() async {
    if (_selected == null) {
      _showSnack(AppString.statusPickError);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final me = await ref
          .read(onboardingRepositoryProvider)
          .updateRelationshipStatus(_selected!);
      ref.read(meProvider.notifier).setMe(me);

      if (mounted) context.push(AppRoutes.preferences);
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const OnboardingHeader(step: 4, label: AppString.sectionIdentity),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    spacerH(28),
                    Text(AppString.statusTitle, style: AppTextStyles.display),
                    spacerH(6),
                    Text(
                      AppString.statusSubtitle,
                      style: TextStyle(fontSize: 13, color: AppColors.textGrey),
                    ),
                    spacerH(28),
                    ..._options.map(_optionTile),
                    spacerH(32),
                    CommonButton(
                      text: AppString.continueText,
                      isLoading: _isLoading,
                      isDisableButton: _selected == null,
                      onClick: _onContinue,
                    ),
                    spacerH(40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ).unfocusOnTap().withGlobalBackHandler(context);
  }

  Widget _optionTile((String, String, String) option) {
    final (label, value, blurb) = option;
    final selected = _selected == value;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => setState(() => _selected = value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.06)
                : AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.inputBorder,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? AppColors.primary : AppColors.card,
                  border: Border.all(
                    color: selected ? AppColors.primary : AppColors.inputBorder,
                    width: 2,
                  ),
                ),
                child: selected
                    ? Icon(Icons.check, size: 13, color: AppColors.onAccent)
                    : null,
              ),
              spacerW(14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color:
                        selected ? AppColors.primary : AppColors.textDark,
                      ),
                    ),
                    spacerH(2),
                    Text(
                      blurb,
                      style: TextStyle(fontSize: 12, color: AppColors.textGrey),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}