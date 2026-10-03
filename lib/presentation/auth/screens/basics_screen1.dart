import 'package:dating_app/core/constants/app_string.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_text_styles.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/onboarding_maps.dart';
import '../../../data/models/user_model.dart';
import '../../../providers/core_providers.dart';
import '../../../providers/profile_provider.dart';
import '../../common/widgets/widgets.dart';
import '../widgets/onboarding_widgets.dart';

/// Step 2 — the name people see, gender, pronouns and a line of bio.
class BasicsScreen extends ConsumerStatefulWidget {
  const BasicsScreen({super.key, this.displayName = ''});

  final String displayName;

  @override
  ConsumerState<BasicsScreen> createState() => _BasicsScreenState();
}

class _BasicsScreenState extends ConsumerState<BasicsScreen> {
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  bool _seededFromServer = false;

  static const List<String> _genderOptions = [
    AppString.genderWoman,
    AppString.genderMan,
    AppString.genderNonBinary,
    AppString.genderTransWoman,
    AppString.genderTransMan,
    AppString.genderIntersex,
    AppString.genderSelfDescribe,
  ];
  static const List<String> _pronounOptions = [
    AppString.pronounSheHer,
    AppString.pronounHeHim,
    AppString.pronounTheyThem,
    AppString.pronounOther,
  ];

  static const int _bioMax = 150;

  String? _selectedGender;
  String? _selectedPronoun;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.displayName;
  }

  void _seed(MeUser me) {
    if (_seededFromServer) return;
    _seededFromServer = true;

    if (_nameController.text.trim().isEmpty) {
      _nameController.text = me.profile.displayName ?? '';
    }
    if (_bioController.text.isEmpty) {
      _bioController.text = me.profile.bio ?? '';
    }
    for (final entry in kGenderValues.entries) {
      if (entry.value == me.profile.gender) {
        _selectedGender = entry.key;
        break;
      }
    }
    if (me.profile.pronouns.isNotEmpty) {
      for (final entry in kPronounValues.entries) {
        if (entry.value == me.profile.pronouns.first) {
          _selectedPronoun = entry.key;
          break;
        }
      }
    }
  }

  bool get _nameOk => _nameController.text.trim().length >= 2;
  bool get _ready => _nameOk && _selectedGender != null;

  String? get _hint {
    if (!_nameOk) return AppString.basicsNameTooShort;
    if (_selectedGender == null) return AppString.basicsHintGender;
    return null;
  }

  Future<void> _onContinue() async {
    if (!_ready) return;
    final displayName = _nameController.text.trim();

    setState(() => _isLoading = true);
    try {
      final pronounValue = kPronounValues[_selectedPronoun];
      final bio = _bioController.text.trim();
      final me = await ref
          .read(onboardingRepositoryProvider)
          .updateBasics(
            displayName: displayName,
            gender: kGenderValues[_selectedGender]!,
            pronouns: pronounValue == null ? const [] : [pronounValue],
            showMe: const ['everyone'],
            bio: bio.isEmpty ? null : bio,
          );
      ref.read(meProvider.notifier).setMe(me);

      if (mounted) context.push(AppRoutes.intent);
    } on AppException catch (e) {
      if (mounted) showRadiusToast(context, e.message, tone: ToastTone.error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _bioController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(meProvider).valueOrNull;
    if (me != null) _seed(me);

    return OnboardingScaffold(
      step: 2,
      section: AppString.sectionIdentity,
      title: AppString.basicsTitle,
      subtitle: AppString.basicsSubtitle,
      actionLabel: AppString.continueText,
      onAction: _ready ? _onContinue : null,
      isLoading: _isLoading,
      hint: _hint,
      children: [
        BigNameField(
          controller: _nameController,
          label: AppString.basicsNameLabel,
          hint: AppString.ageNameHint,
          textInputAction: TextInputAction.done,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 34),
        const GroupHeading(title: AppString.basicsGenderHeading),
        ChoicePillWrap(
          children: [
            for (final g in _genderOptions)
              ChoicePill(
                label: g,
                selected: _selectedGender == g,
                onTap: () => setState(() => _selectedGender = g),
              ),
          ],
        ),
        const SizedBox(height: 16),
        const FactLine(
          icon: Icons.chat_bubble_outline_rounded,
          text: AppString.pricingNote,
        ),
        const GroupHeading(
          title: AppString.basicsPronounsHeading,
          hint: AppString.optionalHint,
          topSpacing: 20,
        ),
        ChoicePillWrap(
          children: [
            for (final p in _pronounOptions)
              ChoicePill(
                label: p,
                selected: _selectedPronoun == p,
                // Optional, so a second tap takes the answer back.
                onTap: () => setState(
                  () => _selectedPronoun = _selectedPronoun == p ? null : p,
                ),
              ),
          ],
        ),
        const GroupHeading(
          title: AppString.basicsBioHeading,
          hint: AppString.optionalHint,
          topSpacing: 34,
        ),
        _BioField(controller: _bioController, max: _bioMax),
      ],
    );
  }
}

class _BioField extends StatefulWidget {
  const _BioField({required this.controller, required this.max});

  final TextEditingController controller;
  final int max;

  @override
  State<_BioField> createState() => _BioFieldState();
}

class _BioFieldState extends State<_BioField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final used = widget.controller.text.characters.length;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: AppColors.inputBorder, width: 1.5),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        TextField(
          controller: widget.controller,
          maxLength: widget.max,
          minLines: 3,
          maxLines: 5,
          cursorColor: AppColors.primary,
          textCapitalization: TextCapitalization.sentences,
          style: AppTextStyles.body.copyWith(fontSize: 15.5, height: 1.5),
          decoration: InputDecoration(
            hintText: AppString.bioHint,
            hintStyle: AppTextStyles.body.copyWith(
              fontSize: 15.5,
              color: AppColors.textGrey,
            ),
            counterText: '',
            filled: true,
            fillColor: AppColors.card,
            contentPadding: const EdgeInsets.all(16),
            border: border,
            enabledBorder: border,
            focusedBorder: border.copyWith(
              borderSide: BorderSide(color: AppColors.primary, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '$used / ${widget.max}',
          style: AppTextStyles.caption.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
