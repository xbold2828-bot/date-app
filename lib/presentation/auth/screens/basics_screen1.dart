import 'package:dating_app/core/constants/app_string.dart';
import 'package:dating_app/core/extensions/unfocus_on_tap_extension.dart';
import 'package:dating_app/core/utils/utils.dart';
import 'package:dating_app/shared/widgets/buttons/common_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/extensions/global_back_extension.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/onboarding_maps.dart';
import '../../../data/models/user_model.dart';
import '../../../providers/core_providers.dart';
import '../../../providers/profile_provider.dart';
import '../widgets/onboarding_widgets.dart';

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

  final List<String> _genderOptions = const [
    AppString.genderWoman,
    AppString.genderMan,
    AppString.genderNonBinary,
    AppString.genderTransWoman,
    AppString.genderTransMan,
    AppString.genderIntersex,
    AppString.genderSelfDescribe,
  ];
  final List<String> _pronounOptions = const [
    AppString.pronounSheHer,
    AppString.pronounHeHim,
    AppString.pronounTheyThem,
    AppString.pronounOther,
  ];

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

  Future<void> _onContinue() async {
    final displayName = _nameController.text.trim();
    if (displayName.length < 2) {
      _showSnack(AppString.basicsNameTooShort);
      return;
    }
    if (_selectedGender == null) {
      _showSnack(AppString.basicsSelectGender);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final pronounValue = kPronounValues[_selectedPronoun];
      final bio = _bioController.text.trim();
      final me = await ref.read(onboardingRepositoryProvider).updateBasics(
        displayName: displayName,
        gender: kGenderValues[_selectedGender]!,
        pronouns: pronounValue == null ? const [] : [pronounValue],
        showMe: const ['everyone'],
        bio: bio.isEmpty ? null : bio,
      );
      ref.read(meProvider.notifier).setMe(me);

      if (mounted) context.push(AppRoutes.intent);
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
  void dispose() {
    _bioController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration({
    required String hint,
    required EdgeInsets padding,
  }) {
    OutlineInputBorder border([Color? color, double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: color ?? AppColors.inputBorder,
            width: width,
          ),
        );

    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: AppColors.textGrey),
      filled: true,
      fillColor: AppColors.card,
      contentPadding: padding,
      border: border(),
      enabledBorder: border(),
      focusedBorder: border(AppColors.primary, 1.5),
    );
  }

  Widget _label(String text) => Text(
    text,
    style: TextStyle(fontSize: 13, color: AppColors.textGrey),
  );

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(meProvider).valueOrNull;
    if (me != null) _seed(me);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const OnboardingHeader(step: 2, label: AppString.sectionIdentity),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    spacerH(24),
                    Text(AppString.basicsTitle, style: AppTextStyles.display),
                    spacerH(24),
                    _label(AppString.displayNameLabel),
                    spacerH(10),
                    TextField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      style: TextStyle(fontSize: 15, color: AppColors.textDark),
                      decoration: _fieldDecoration(
                        hint: AppString.displayNameHint,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                    spacerH(28),
                    _label(AppString.iAmA),
                    spacerH(12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _genderOptions
                          .map((g) => _chip(
                        label: g,
                        selected: _selectedGender == g,
                        onTap: () =>
                            setState(() => _selectedGender = g),
                      ))
                          .toList(),
                    ),
                    spacerH(28),
                    _label(AppString.pronounsLabel),
                    spacerH(12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _pronounOptions
                          .map((p) => _chip(
                        label: p,
                        selected: _selectedPronoun == p,
                        onTap: () =>
                            setState(() => _selectedPronoun = p),
                      ))
                          .toList(),
                    ),
                    spacerH(28),
                    _label(AppString.bioLabel),
                    spacerH(10),
                    TextField(
                      controller: _bioController,
                      maxLength: 150,
                      maxLines: 4,
                      style: TextStyle(fontSize: 14, color: AppColors.textDark),
                      decoration: _fieldDecoration(
                        hint: AppString.bioHint,
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                    spacerH(16),
                    Center(
                      child: Text(
                        AppString.pricingNote,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textGrey,
                        ),
                      ),
                    ),
                    spacerH(24),
                    CommonButton(
                      isLoading: _isLoading,
                      text: AppString.continueText,
                      onClick: _onContinue,
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

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppColors.card,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.inputBorder,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: selected ? AppColors.primary : AppColors.textDark,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}