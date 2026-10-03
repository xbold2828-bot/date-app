import 'package:dating_app/core/constants/app_string.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/selection_limits.dart';
import '../../../core/constants/tag_categories.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/onboarding_maps.dart';
import '../../../data/models/tag_model.dart';
import '../../../data/models/user_model.dart';
import '../../../providers/core_providers.dart';
import '../../../providers/profile_provider.dart';
import '../../common/widgets/widgets.dart';
import '../widgets/onboarding_widgets.dart';

/// Step 3 — what you are out for, and three words that describe you.
class BasicsScreen2 extends ConsumerStatefulWidget {
  const BasicsScreen2({super.key});

  @override
  ConsumerState<BasicsScreen2> createState() => _BasicsScreen2State();
}

class _BasicsScreen2State extends ConsumerState<BasicsScreen2> {
  String? _selectedIntent;
  Set<String> _selectedPersonality = {};
  bool _isLoading = false;
  bool _restoredFromServer = false;

  void _restore(MeUser me) {
    if (_restoredFromServer) return;
    _restoredFromServer = true;

    if (me.profile.intent.isNotEmpty) {
      final saved = me.profile.intent.first;
      for (final option in kIntentOptions) {
        if (option.value == saved) {
          _selectedIntent = option.key;
          break;
        }
      }
    }
    _selectedPersonality.addAll(
      me.profile.personalityTags.take(SelectionLimits.vibes),
    );
  }

  Future<void> _onContinue() async {
    if (_selectedIntent == null) return;

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(onboardingRepositoryProvider);
      final intentValue = kIntentOptions
          .firstWhere((e) => e.key == _selectedIntent)
          .value;

      await repo.updateIntent([intentValue]);
      final me = await repo.updatePersonality(_selectedPersonality.toList());
      ref.read(meProvider.notifier).setMe(me);

      if (mounted) context.push(AppRoutes.status);
    } on AppException catch (e) {
      _toast(e.message, tone: ToastTone.error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toast(String msg, {ToastTone tone = ToastTone.neutral}) {
    if (mounted) showRadiusToast(context, msg, tone: tone);
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(meProvider).valueOrNull;
    if (me != null) _restore(me);

    final personality = ref.watch(tagsByCategoryProvider);

    return OnboardingScaffold(
      step: 3,
      section: AppString.sectionIdentity,
      title: AppString.intentTitle,
      subtitle: AppString.intentSubtitle,
      actionLabel: AppString.continueText,
      onAction: _selectedIntent == null ? null : _onContinue,
      isLoading: _isLoading,
      hint: _selectedIntent == null ? AppString.intentHint : null,
      children: [
        ChoicePillWrap(
          children: [
            for (final option in kIntentOptions)
              ChoicePill(
                label: option.key,
                selected: _selectedIntent == option.key,
                onTap: () => setState(() => _selectedIntent = option.key),
              ),
          ],
        ),
        GroupHeading(
          title: AppString.yourAtmosphere,
          hint: AppString.atmosphereSubtitle,
          count: _selectedPersonality.length,
          max: SelectionLimits.vibes,
          topSpacing: 40,
        ),
        personality.when(
          loading: () => const _TagsLoading(),
          error: (err, _) => _TagsUnavailable(
            onRetry: () => ref.invalidate(tagsByCategoryProvider),
          ),
          data: (grouped) => LimitedChoicePills(
            tags: grouped[TagCategories.personality] ?? const <Tag>[],
            selected: _selectedPersonality,
            max: SelectionLimits.vibes,
            onChanged: (next) => setState(() => _selectedPersonality = next),
            onLimitReached: () => _toast(
              selectionLimitMessage(AppString.vibesNoun, SelectionLimits.vibes),
            ),
          ),
        ),
      ],
    );
  }
}

class _TagsLoading extends StatelessWidget {
  const _TagsLoading();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SizedBox(
        height: 22,
        width: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

class _TagsUnavailable extends StatelessWidget {
  const _TagsUnavailable({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            AppString.tagsUnavailable,
            style: AppTextStyles.caption.copyWith(fontSize: 13),
          ),
        ),
        TextButton(
          onPressed: onRetry,
          child: Text(
            AppString.retry,
            style: AppTextStyles.bodyStrong.copyWith(
              color: AppColors.primaryInk,
            ),
          ),
        ),
      ],
    );
  }
}
