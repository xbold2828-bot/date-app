import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/selection_limits.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../data/models/tag_model.dart';
import '../../../data/models/user_model.dart';
import '../../../providers/core_providers.dart';
import '../../../providers/profile_provider.dart';
import '../../common/widgets/widgets.dart';
import '../widgets/onboarding_widgets.dart';
import 'basics_screen4.dart';

/// Steps 6 + 7 — "What I'm into" (`PATCH /onboarding/preferences`) and
/// "My hard no's" (`PATCH /onboarding/hard-nos`).
///
/// Every chip comes from `GET /tags`; the API validates slugs against the
/// catalogue, so labels are never sent. The verified-members-only rule on the
/// adult tags is switched off for now (see
/// `BusinessConfig.requireVerificationForDesires`) — everyone can select
/// anything, and saving none is still allowed.
///
/// Desires are capped at [SelectionLimits.into] across *all six* sections, not
/// per section; hard no's are never capped. Both limits are the same constants
/// the "Me" tab's editor enforces, so an answer given in the funnel and an
/// answer edited later obey one rule.
class BasicsScreen3 extends ConsumerStatefulWidget {
  const BasicsScreen3({super.key});

  @override
  ConsumerState<BasicsScreen3> createState() => _BasicsScreen3State();
}

class _BasicsScreen3State extends ConsumerState<BasicsScreen3> {
  static const Map<String, String> _sectionTitles = {
    TagCategories.roleEnergy: 'Role & energy',
    TagCategories.into: 'Into',
    TagCategories.scenario: 'Scenario',
    TagCategories.intensity: 'Intensity',
    TagCategories.experience: 'Experience',
    TagCategories.fantasySetting: 'Fantasy & setting',
  };

  Set<String> _selectedPreferences = {};
  Set<String> _selectedHardNos = {};
  bool _showHardNosOnProfile = true;
  bool _isLoading = false;
  bool _restoredFromServer = false;

  void _restore(MeUser me) {
    if (_restoredFromServer) return;
    _restoredFromServer = true;
    // Trimmed to the cap — an account that answered before the limit existed
    // would otherwise land here already over budget.
    _selectedPreferences.addAll(
      me.profile.preferenceTags.take(SelectionLimits.into),
    );
    _selectedHardNos.addAll(me.profile.hardNos);
    _showHardNosOnProfile = me.profile.showHardNosOnProfile;
  }

  Future<void> _onSave() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(onboardingRepositoryProvider);

      // Everything the user picked is sent as-is. The verified-members-only
      // rule on these tags is switched off server-side until identity
      // verification ships (BusinessConfig.requireVerificationForDesires).
      await repo.updatePreferences(_selectedPreferences.toList());
      final me = await repo.updateHardNos(
        _selectedHardNos.toList(),
        showOnProfile: _showHardNosOnProfile,
      );
      ref.read(meProvider.notifier).setMe(me);

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BasicsScreen4()),
        );
      }
    } on AppException catch (e) {
      _showSnack(e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(meProvider).valueOrNull;
    if (me != null) _restore(me);

    final tags = ref.watch(tagsByCategoryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const OnboardingHeader(step: 6, label: 'DESIRES'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    Text(
                      'Define your desires.',
                      style: AppTextStyles.display,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Pick your ${SelectionLimits.into} — across all of '
                            'these — and they stay private until you match '
                            'with someone.',
                            style: AppTextStyles.caption,
                          ),
                        ),
                        const SizedBox(width: 10),
                        // The budget is shared across every section below, so
                        // the counter lives up here with the instruction
                        // rather than beside any one group.
                        SelectionCounter(
                          count: _selectedPreferences.length,
                          max: SelectionLimits.into,
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    tags.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      error: (err, _) => _CatalogueError(
                        onRetry: () => ref.invalidate(tagsByCategoryProvider),
                      ),
                      data: (grouped) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Step 6 · preference sections ──────────────
                          for (final category in TagCategories.preferences)
                            if ((grouped[category] ?? const <Tag>[]).isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 28),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    OnboardingSectionLabel(
                                      _sectionTitles[category] ?? category,
                                    ),
                                    const SizedBox(height: 12),
                                    LimitedTagChipGroup(
                                      tags: grouped[category]!,
                                      selected: _selectedPreferences,
                                      // One budget, six sections. The cap is on
                                      // the answer, not on any section of it —
                                      // the profile prints them as one list.
                                      max: SelectionLimits.into,
                                      onChanged: (next) => setState(
                                        () => _selectedPreferences = next,
                                      ),
                                      onLimitReached: () => _showSnack(
                                        selectionLimitMessage(
                                          'desires in total',
                                          SelectionLimits.into,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                          // ── Step 7 · hard no's ────────────────────────
                          _hardNosCard(grouped[TagCategories.hardNo] ?? const []),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    OnboardingButton(
                      label: 'Continue',
                      isLoading: _isLoading,
                      onPressed: _onSave,
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hardNosCard(List<Tag> hardNoTags) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: OnboardingSectionLabel("Hard no's")),
              Switch(
                value: _showHardNosOnProfile,
                onChanged: (v) => setState(() => _showHardNosOnProfile = v),
                activeColor: AppColors.primary,
              ),
              const Flexible(
                child: Text(
                  'Show on profile',
                  style: TextStyle(fontSize: 12, color: AppColors.textDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Hard no's are never sensitive, and never rationed: a boundary you
          // were not allowed to state is not a limit worth having.
          LimitedTagChipGroup(
            tags: hardNoTags,
            selected: _selectedHardNos,
            max: SelectionLimits.hardNos,
            onChanged: (next) => setState(() => _selectedHardNos = next),
            onLimitReached: () {},
          ),
        ],
      ),
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
        const Text(
          "Couldn't load the tag options. You can continue and set these later.",
          style: TextStyle(fontSize: 13, color: AppColors.textGrey),
        ),
        TextButton(
          onPressed: onRetry,
          child: const Text('Retry', style: TextStyle(color: AppColors.primary)),
        ),
      ],
    );
  }
}
