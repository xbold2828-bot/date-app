import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_text_styles.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/profile_provider.dart';
import '../../common/widgets/widgets.dart';
import '../widgets/profile_edit_panel.dart';
import '../widgets/profile_edit_sheets.dart';
import 'package:dating_app/core/constants/app_string.dart';


/// Every answer on the profile, editable in one place — what "Edit profile"
/// opens. Like Instagram's edit screen: small grey label, value beneath, a
/// blue action on the right. The bio leads; the rest is the onboarding
/// answers, laid out open rather than folded away.
class EditProfileScreen extends ConsumerWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider).valueOrNull;
    final bio = (me?.profile.bio ?? '').trim();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: BackChevron(onTap: () => Navigator.of(context).maybePop()),
        titleSpacing: 0,
        title: Text(AppString.editProfileTitle, style: AppTextStyles.title),
      ),
      body: me == null
          ? Center(child: CircularProgressIndicator(color: AppColors.primary))
          : GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: ListView(
          keyboardDismissBehavior:
          ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
            16,
            4,
            16,
            16 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            _BioBlock(
              bio: bio,
              onEdit: () async {
                final saved = await showEditBioSheet(context, bio);
                if (saved && context.mounted) {
                  showRadiusToast(
                    context,
                    AppString.editProfileBioUpdated,
                    tone: ToastTone.success,
                  );
                }
              },
            ),
            const SizedBox(height: 8),
            Divider(color: AppColors.inputBorder, height: 1),
            const SizedBox(height: 12),
            ProfileEditPanel(me: me, embedded: true),
          ],
        ),
      ),
    );
  }
}

class _BioBlock extends StatelessWidget {
  const _BioBlock({required this.bio, required this.onEdit});

  final String bio;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                AppString.bioLabel,
                style: AppTextStyles.label.copyWith(color: AppColors.textGrey),
              ),
            ),
            TextButton(
              onPressed: onEdit,
              style: TextButton.styleFrom(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                bio.isEmpty ? AppString.write : AppString.edit,
                style: AppTextStyles.bodyStrong.copyWith(
                  color: AppColors.primaryInk,
                  fontWeight: FontWeight.w700,
                  fontVariations: const [FontVariation('wght', 700)],
                ),
              ),
            ),
          ],
        ),
        Text(
          bio.isEmpty ? AppString.editProfileBioPlaceholder : bio,
          style: AppTextStyles.body.copyWith(
            fontSize: 14,
            height: 1.35,
            color: bio.isEmpty ? AppColors.textGrey : AppColors.textDark,
          ),
        ),
      ],
    );
  }
}
