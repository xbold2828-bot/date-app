import 'package:dating_app/core/constants/app_string.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_text_styles.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/core_providers.dart';
import '../../../providers/location_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../common/widgets/widgets.dart';
import '../widgets/onboarding_widgets.dart';

/// Step 7 — location, the one permission the product cannot work without.
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
      final me = await ref
          .read(onboardingRepositoryProvider)
          .updateLocation(
            latitude: position.latitude,
            longitude: position.longitude,
          );
      ref.read(meProvider.notifier).setMe(me);

      if (mounted) context.push(AppRoutes.agreement);
    } on AppException catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast(AppString.locationError);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toast(String msg) {
    if (mounted) showRadiusToast(context, msg, tone: ToastTone.error);
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      step: 7,
      section: AppString.sectionLocation,
      title: AppString.locationTitle,
      subtitle: AppString.locationBody,
      actionLabel: AppString.allowLocation,
      onAction: _onAllow,
      isLoading: _isLoading,
      children: const [
        _RadarLegend(),
        SizedBox(height: 30),
        FactLine(icon: Icons.shield_outlined, text: AppString.locationNoteBand),
        FactLine(
          icon: Icons.tune_rounded,
          text: AppString.locationNoteSettings,
        ),
      ],
    );
  }
}

/// The radar with its four rings named underneath — the privacy promise drawn
/// rather than described: people are placed in a ring, not on a point.
class _RadarLegend extends StatelessWidget {
  const _RadarLegend();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Center(child: RadarMark(size: 168, animate: true)),
        const SizedBox(height: 18),
        ExcludeSemantics(
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final ring in DistanceRing.values)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppColors.inputBorder),
                  ),
                  child: Text(
                    ring.wireValue,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 12,
                      color: AppColors.textDark,
                      fontWeight: FontWeight.w600,
                      fontVariations: const [FontVariation('wght', 600)],
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
