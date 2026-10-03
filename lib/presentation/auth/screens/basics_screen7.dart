import 'package:dating_app/core/constants/app_string.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_text_styles.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/core_providers.dart';
import '../../../providers/profile_provider.dart';
import '../../common/widgets/widgets.dart';
import '../widgets/onboarding_widgets.dart';

/// Step 8 — the four house rules, each agreed to with its own tap.
///
/// There is deliberately no "agree to all": the server stores each consent as
/// its own field, and a single tap would make all four one decision.
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
    if (!_allChecked) return;

    setState(() => _isLoading = true);
    try {
      final me = await ref
          .read(onboardingRepositoryProvider)
          .acceptAgreement(
            isAdult: _checked('isAdult'),
            willBeRespectful: _checked('willBeRespectful'),
            noHarassment: _checked('noHarassment'),
            consentMatters: _checked('consentMatters'),
          );
      ref.read(meProvider.notifier).setMe(me);

      if (mounted) context.go(AppRoutes.dashboard);
    } on AppException catch (e) {
      if (mounted) showRadiusToast(context, e.message, tone: ToastTone.error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final done = _agreements.where((a) => a.checked).length;

    return OnboardingScaffold(
      step: 8,
      section: AppString.sectionAgreement,
      title: AppString.agreementTitle,
      subtitle: AppString.agreementSubtitle,
      actionLabel: AppString.enterCozune,
      onAction: _allChecked ? _onEnter : null,
      isLoading: _isLoading,
      hint: _allChecked ? null : '${AppString.agreementHint} · $done of 4',
      children: [
        Divider(color: AppColors.inputBorder, height: 1, thickness: 1),
        for (final item in _agreements) ...[
          _RuleRow(
            text: item.text,
            checked: item.checked,
            onTap: () => setState(() => item.checked = !item.checked),
          ),
          Divider(color: AppColors.inputBorder, height: 1, thickness: 1),
        ],
        const SizedBox(height: 22),
        const FactLine(
          icon: Icons.receipt_long_outlined,
          text: AppString.agreementNote,
        ),
      ],
    );
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({
    required this.text,
    required this.checked,
    required this.onTap,
  });

  final String text;
  final bool checked;
  final VoidCallback onTap;

  static const _easeOut = Cubic(0.23, 1, 0.32, 1);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: checked,
      button: true,
      label: text,
      excludeSemantics: true,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 68),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 180),
                    style: AppTextStyles.bodyStrong.copyWith(
                      fontSize: 17.5,
                      height: 1.35,
                      color: checked ? AppColors.textDark : AppColors.textGrey,
                      fontWeight: FontWeight.w700,
                      fontVariations: const [FontVariation('wght', 700)],
                    ),
                    child: Text(text),
                  ),
                ),
                const SizedBox(width: 16),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: _easeOut,
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: checked ? AppColors.primary : Colors.transparent,
                    border: Border.all(
                      color: checked ? AppColors.primary : AppColors.iconMuted,
                      width: 2,
                    ),
                  ),
                  child: AnimatedScale(
                    scale: checked ? 1 : 0.4,
                    duration: const Duration(milliseconds: 220),
                    curve: _easeOut,
                    child: AnimatedOpacity(
                      opacity: checked ? 1 : 0,
                      duration: const Duration(milliseconds: 140),
                      child: Icon(
                        Icons.check_rounded,
                        size: 19,
                        color: AppColors.onAccent,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
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
