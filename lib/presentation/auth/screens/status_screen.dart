import 'package:dating_app/core/constants/app_string.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exceptions.dart';
import '../../../core/router/app_router.dart';
import '../../../providers/core_providers.dart';
import '../../../providers/profile_provider.dart';
import '../../common/widgets/widgets.dart';
import '../widgets/onboarding_widgets.dart';

/// Step 4 — relationship status. One answer, each with a line saying what it
/// means, because "open relationship" and "couple" are exactly the two people
/// guess wrong about each other.
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
  bool _restored = false;

  Future<void> _onContinue() async {
    final selected = _selected;
    if (selected == null) return;

    setState(() => _isLoading = true);
    try {
      final me = await ref
          .read(onboardingRepositoryProvider)
          .updateRelationshipStatus(selected);
      ref.read(meProvider.notifier).setMe(me);

      if (mounted) context.push(AppRoutes.preferences);
    } on AppException catch (e) {
      if (mounted) showRadiusToast(context, e.message, tone: ToastTone.error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Coming back to this step shows the answer already given.
    final saved = ref.watch(meProvider).valueOrNull?.profile.relationshipStatus;
    if (!_restored && saved != null) {
      _restored = true;
      _selected ??= saved;
    }

    return OnboardingScaffold(
      step: 4,
      section: AppString.sectionIdentity,
      title: AppString.statusTitle,
      subtitle: AppString.statusSubtitle,
      actionLabel: AppString.continueText,
      onAction: _selected == null ? null : _onContinue,
      isLoading: _isLoading,
      hint: _selected == null ? AppString.statusHint : null,
      children: [
        for (final (label, value, blurb) in _options)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ChoiceRow(
              label: label,
              description: blurb,
              selected: _selected == value,
              onTap: () => setState(() => _selected = value),
            ),
          ),
      ],
    );
  }
}
