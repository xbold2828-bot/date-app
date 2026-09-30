import 'package:dating_app/core/constants/app_string.dart';
import 'package:dating_app/core/utils/utils.dart';
import 'package:dating_app/shared/widgets/buttons/common_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/extensions/global_back_extension.dart';
import '../../../core/extensions/unfocus_on_tap_extension.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/core_providers.dart';
import '../../../providers/location_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../common/widgets/widgets.dart';

class BasicsScreen5 extends ConsumerStatefulWidget {
  const BasicsScreen5({super.key});

  @override
  ConsumerState<BasicsScreen5> createState() => _BasicsScreen5State();
}

class _BasicsScreen5State extends ConsumerState<BasicsScreen5> {
  bool _isLoading = false;

  Future<void> _onAllow() async {
    setState(() => _isLoading = true);
    try {
      final position = await ref.read(locationServiceProvider).current();
      final me = await ref.read(onboardingRepositoryProvider).updateLocation(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      ref.read(meProvider.notifier).setMe(me);

      if (mounted) context.push(AppRoutes.agreement);
    } on AppException catch (e) {
      _showSnack(e.message);
    } catch (_) {
      _showSnack(AppString.locationError);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const StepHeader(step: 7, label: AppString.sectionLocation),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    spacerH(40),
                    const Center(child: RadarMark(size: 132, animate: true)),
                    spacerH(40),
                    Text(AppString.locationTitle, style: AppTextStyles.display),
                    spacerH(8),
                    Text(
                      AppString.locationBody,
                      style: TextStyle(fontSize: 13, color: AppColors.textGrey),
                    ),
                    spacerH(28),
                    _note(
                      icon: Icons.shield_outlined,
                      text: AppString.locationNoteBand,
                    ),
                    spacerH(10),
                    _note(
                      icon: Icons.tune,
                      text: AppString.locationNoteSettings,
                    ),
                    spacerH(36),
                    CommonButton(
                      iconData: Icons.near_me,
                      text: AppString.allowLocation,
                      isLoading: _isLoading,
                      onClick: _onAllow,
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

  Widget _note({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          spacerW(10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}