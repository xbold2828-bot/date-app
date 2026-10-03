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
import '../../../data/models/tag_model.dart';
import '../../../data/models/user_model.dart';
import '../../../providers/core_providers.dart';
import '../../../providers/profile_provider.dart';
import '../../common/widgets/widgets.dart';
import '../widgets/onboarding_widgets.dart';

/// Step 5 — the private preferences, each group on its own allowance, and the
/// hard no's, which are never capped.
class BasicsScreen3 extends ConsumerStatefulWidget {
  const BasicsScreen3({super.key});

  @override
  ConsumerState<BasicsScreen3> createState() => _BasicsScreen3State();
}

class _BasicsScreen3State extends ConsumerState<BasicsScreen3> {
  Set<String> _selectedPreferences = {};
  Set<String> _selectedHardNos = {};
  bool _showHardNosOnProfile = true;
  bool _isLoading = false;
  bool _restoredHardNos = false;
  bool _restoredPreferences = false;

  void _restoreHardNos(MeUser me) {
    if (_restoredHardNos) return;
    _restoredHardNos = true;
    _selectedHardNos.addAll(me.profile.hardNos);
    _showHardNosOnProfile = me.profile.showHardNosOnProfile;
  }

  void _restorePreferences(MeUser me, Map<String, List<Tag>> grouped) {
    if (_restoredPreferences) return;
    _restoredPreferences = true;

    final saved = me.profile.preferenceTags;
    for (final category in TagCategories.preferences) {
      final slugs = {
        for (final tag in grouped[category] ?? const <Tag>[]) tag.slug,
      };
      _selectedPreferences.addAll(
        saved.where(slugs.contains).take(SelectionLimits.intoIn(category)),
      );
    }
  }

  Future<void> _onSave() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(onboardingRepositoryProvider);

      await repo.updatePreferences(_selectedPreferences.toList());
      final me = await repo.updateHardNos(
        _selectedHardNos.toList(),
        showOnProfile: _showHardNosOnProfile,
      );
      ref.read(meProvider.notifier).setMe(me);

      if (mounted) context.push(AppRoutes.photos);
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
    if (me != null) _restoreHardNos(me);

    final tags = ref.watch(tagsByCategoryProvider);
    final catalogue = tags.valueOrNull;
    if (me != null && catalogue != null) _restorePreferences(me, catalogue);

    return OnboardingScaffold(
      step: 5,
      section: AppString.sectionYourVibe,
      title: AppString.vibeTitle,
      subtitle: AppString.vibeSubtitle,
      actionLabel: AppString.continueText,
      onAction: _onSave,
      isLoading: _isLoading,
      children: [
        tags.when(
          loading: () => Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          ),
          error: (err, _) => _CatalogueError(
            onRetry: () => ref.invalidate(tagsByCategoryProvider),
          ),
          data: (grouped) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final category in TagCategories.preferences)
                if ((grouped[category] ?? const <Tag>[]).isNotEmpty)
                  _preferenceSection(category, grouped[category]!),
              _hardNos(grouped[TagCategories.hardNo] ?? const []),
            ],
          ),
        ),
      ],
    );
  }

  Widget _preferenceSection(String category, List<Tag> tags) {
    final title = TagCategories.label(category);
    final max = SelectionLimits.intoIn(category);
    final slugs = {for (final tag in tags) tag.slug};
    final chosen = _selectedPreferences.intersection(slugs);

    return Padding(
      padding: const EdgeInsets.only(bottom: 34),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The "0 / 3" counter states the allowance; a "Pick up to 3" line
          // under every heading said it twice.
          GroupHeading(title: title, count: chosen.length, max: max),
          LimitedChoicePills(
            tags: tags,
            selected: chosen,
            max: max,
            onChanged: (next) => setState(() {
              _selectedPreferences = {
                ..._selectedPreferences.difference(slugs),
                ...next,
              };
            }),
            onLimitReached: () => _toast(sectionLimitMessage(title, max)),
          ),
        ],
      ),
    );
  }

  /// Boundaries rather than preferences: never capped, and the only answers
  /// on this screen that can be made public.
  Widget _hardNos(List<Tag> hardNoTags) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(color: AppColors.inputBorder, height: 1, thickness: 1),
        const SizedBox(height: 28),
        const GroupHeading(
          title: AppString.hardNos,
          hint: AppString.hardNosHint,
        ),
        LimitedChoicePills(
          tags: hardNoTags,
          selected: _selectedHardNos,
          max: SelectionLimits.hardNos,
          onChanged: (next) => setState(() => _selectedHardNos = next),
          onLimitReached: () {},
        ),
        const SizedBox(height: 14),
        MergeSemantics(
          child: Row(
            children: [
              Expanded(
                child: Text(
                  AppString.showHardNosOnProfile,
                  style: AppTextStyles.bodyStrong.copyWith(fontSize: 15),
                ),
              ),
              Switch(
                value: _showHardNosOnProfile,
                onChanged: (v) => setState(() => _showHardNosOnProfile = v),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CatalogueError extends StatelessWidget {
  const _CatalogueError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppString.catalogueError,
          style: AppTextStyles.caption.copyWith(fontSize: 13),
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
