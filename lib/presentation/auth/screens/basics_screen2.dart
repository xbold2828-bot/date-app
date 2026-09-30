import 'package:dating_app/core/constants/app_string.dart';
import 'package:dating_app/core/utils/utils.dart';
import 'package:dating_app/shared/widgets/buttons/common_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/selection_limits.dart';
import '../../../core/constants/tag_categories.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/extensions/global_back_extension.dart';
import '../../../core/extensions/unfocus_on_tap_extension.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/onboarding_maps.dart';
import '../../../data/models/tag_model.dart';
import '../../../data/models/user_model.dart';
import '../../../providers/core_providers.dart';
import '../../../providers/profile_provider.dart';
import '../../common/widgets/widgets.dart';
import '../widgets/onboarding_widgets.dart';

class BasicsScreen2 extends ConsumerStatefulWidget {
  const BasicsScreen2({super.key});

  @override
  ConsumerState<BasicsScreen2> createState() => _BasicsScreen2State();
}

class _BasicsScreen2State extends ConsumerState<BasicsScreen2> {
  final List<String> _intents = kIntentOptions.map((e) => e.key).toList();

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
    if (_selectedIntent == null) {
      _showSnack(AppString.intentSelectError);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(onboardingRepositoryProvider);
      final intentValue =
          kIntentOptions.firstWhere((e) => e.key == _selectedIntent).value;

      await repo.updateIntent([intentValue]);
      final me = await repo.updatePersonality(_selectedPersonality.toList());
      ref.read(meProvider.notifier).setMe(me);

      if (mounted) context.push(AppRoutes.status);
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
    final me = ref.watch(meProvider).valueOrNull;
    if (me != null) _restore(me);

    final personality = ref.watch(tagsByCategoryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const OnboardingHeader(step: 3, label: AppString.sectionIdentity),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    spacerH(24),
                    Text(AppString.intentTitle, style: AppTextStyles.display),
                    spacerH(28),
                    Text(
                      AppString.currentIntent,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    spacerH(4),
                    Text(
                      '${AppString.intentSubtitle} '
                          '${selectionHint(SelectionLimits.intent)}.',
                      style: TextStyle(fontSize: 13, color: AppColors.textGrey),
                    ),
                    spacerH(14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _intents
                          .map((intent) => OnboardingChip(
                        label: intent,
                        selected: _selectedIntent == intent,
                        onTap: () =>
                            setState(() => _selectedIntent = intent),
                      ))
                          .toList(),
                    ),
                    spacerH(32),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            AppString.yourAtmosphere,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                        SelectionCounter(
                          count: _selectedPersonality.length,
                          max: SelectionLimits.vibes,
                        ),
                      ],
                    ),
                    spacerH(4),
                    Text(
                      '${AppString.atmosphereSubtitle} '
                          '${selectionHint(SelectionLimits.vibes)}.',
                      style: TextStyle(fontSize: 13, color: AppColors.textGrey),
                    ),
                    spacerH(14),
                    personality.when(
                      loading: () => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      error: (err, _) => _TagsUnavailable(
                        onRetry: () => ref.invalidate(tagsByCategoryProvider),
                      ),
                      data: (grouped) => LimitedTagChipGroup(
                        tags: grouped[TagCategories.personality] ??
                            const <Tag>[],
                        selected: _selectedPersonality,
                        max: SelectionLimits.vibes,
                        onChanged: (next) =>
                            setState(() => _selectedPersonality = next),
                        onLimitReached: () => _showSnack(
                          selectionLimitMessage(
                            AppString.vibesNoun,
                            SelectionLimits.vibes,
                          ),
                        ),
                      ),
                    ),
                    spacerH(32),
                    CommonButton(
                      text: AppString.continueText,
                      isLoading: _isLoading,
                      isDisableButton: _selectedIntent == null,
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
            style: TextStyle(fontSize: 13, color: AppColors.textGrey),
          ),
        ),
        TextButton(
          onPressed: onRetry,
          child: Text(
            AppString.retry,
            style: TextStyle(color: AppColors.primary),
          ),
        ),
      ],
    );
  }
}