import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_text_styles.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/profile_provider.dart';
import '../../common/widgets/widgets.dart';
import '../widgets/profile_edit_panel.dart';
import '../widgets/profile_edit_sheets.dart';

/// Every answer on the profile, editable in one place — what "Edit profile"
/// opens. The bio leads because it is the one thing people read first; the
/// rest is the onboarding answers, laid out open rather than folded away.
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
        leading: BackChevron(onTap: () => Navigator.of(context).maybePop()),
        titleSpacing: 0,
        title: Text('Edit profile', style: AppTextStyles.title),
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
                  20,
                  8,
                  20,
                  32 + MediaQuery.paddingOf(context).bottom,
                ),
                children: [
                  _BioBlock(
                    bio: bio,
                    onEdit: () async {
                      final saved = await showEditBioSheet(context, bio);
                      if (saved && context.mounted) {
                        showRadiusToast(
                          context,
                          'Bio updated',
                          tone: ToastTone.success,
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 22),
                  Divider(color: AppColors.inputBorder, height: 1),
                  const SizedBox(height: 22),
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
            Expanded(child: Text('Bio', style: AppTextStyles.label)),
            TextButton(
              onPressed: onEdit,
              child: Text(
                bio.isEmpty ? 'Write' : 'Edit',
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
          bio.isEmpty ? 'Say something worth replying to.' : bio,
          style: AppTextStyles.body.copyWith(
            height: 1.5,
            color: bio.isEmpty ? AppColors.textGrey : AppColors.textDark,
          ),
        ),
      ],
    );
  }
}
