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

/// Step 1 — a first name and a birthday.
class AgeScreen extends ConsumerStatefulWidget {
  const AgeScreen({super.key});

  @override
  ConsumerState<AgeScreen> createState() => _AgeScreenState();
}

class _AgeScreenState extends ConsumerState<AgeScreen> {
  final TextEditingController _nameController = TextEditingController();

  DateTime? _dob;
  DobStatus _dobStatus = DobStatus.incomplete;
  bool _isLoading = false;

  bool get _hasName => _nameController.text.trim().isNotEmpty;
  bool get _ready => _hasName && _dob != null;

  /// What is still missing, said where the button is.
  String? get _hint {
    if (!_hasName) return AppString.ageHintName;
    return switch (_dobStatus) {
      DobStatus.incomplete => AppString.ageHintDob,
      DobStatus.invalid => AppString.ageHintInvalid,
      DobStatus.underage => AppString.ageMustBeAdult,
      DobStatus.ok => null,
    };
  }

  Future<void> _onContinue() async {
    final dob = _dob;
    if (!_hasName || dob == null) return;

    setState(() => _isLoading = true);
    try {
      final iso =
          '${dob.year.toString().padLeft(4, '0')}-'
          '${dob.month.toString().padLeft(2, '0')}-'
          '${dob.day.toString().padLeft(2, '0')}';
      final me = await ref.read(onboardingRepositoryProvider).updateAge(iso);
      ref.read(meProvider.notifier).setMe(me);

      if (mounted) {
        context.push(AppRoutes.basics, extra: _nameController.text.trim());
      }
    } on AppException catch (e) {
      if (mounted) showRadiusToast(context, e.message, tone: ToastTone.error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      step: 1,
      section: AppString.sectionIdentity,
      showBack: false,
      title: AppString.ageTitle,
      subtitle: AppString.ageSubtitle,
      actionLabel: AppString.continueText,
      onAction: _ready ? _onContinue : null,
      isLoading: _isLoading,
      hint: _ready ? null : _hint,
      hintIsWarning:
          _hasName &&
          (_dobStatus == DobStatus.invalid || _dobStatus == DobStatus.underage),
      children: [
        BigNameField(
          controller: _nameController,
          label: AppString.ageNameLabel,
          hint: AppString.ageNameHint,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 34),
        const GroupHeading(title: AppString.ageBirthdayHeading),
        DobInput(
          onChanged: (date, status) => setState(() {
            _dob = date;
            _dobStatus = status;
          }),
        ),
        const SizedBox(height: 30),
        const FactLine(
          icon: Icons.lock_outline_rounded,
          text: AppString.ageNotePrivacy,
        ),
        const FactLine(icon: Icons.sms_outlined, text: AppString.ageNoteOtp),
      ],
    );
  }
}
