import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/constants/app_text_styles.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../common/widgets/step_header.dart';
import '../../../common/widgets/system_state.dart';
import '../../viewmodel/providers/internet_provider/internet_provider.dart';
import '../../viewmodel/providers/internet_provider/internet_state.dart';

/// Shown when the connection drops. It closes itself the moment the
/// connection comes back, so it says so — "Try again" is for the impatient,
/// not a step anyone has to take.
class InternetScreen extends ConsumerWidget {
  const InternetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<InternetState>(internetProvider, (prev, curr) {
      if (prev != null && !prev.isConnected && curr.isConnected) {
        ref.read(internetProvider.notifier).isInternetScreenShown = false;
        if (context.mounted && routeCanPop(context)) routePop(context);
      }
    });

    final canGoBack = routeCanPop(context);

    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          ref.read(internetProvider.notifier).isInternetScreenShown = false;
        }
      },
      child: SystemStateLayout(
        icon: Icons.wifi_off_rounded,
        title: "You're offline",
        message:
            "cozune needs a connection to show who's around. Check your "
            'Wi-Fi or mobile data, or step somewhere with better signal.',
        actionLabel: 'Try again',
        onAction: () => ref.read(internetProvider.notifier).retry(),
        secondaryLabel: canGoBack ? 'Go back' : null,
        onSecondary: canGoBack ? () => routePop(context) : null,
        children: const [_Waiting()],
      ),
    );
  }
}

/// A small live line: this screen is listening, and will get out of the way.
class _Waiting extends StatelessWidget {
  const _Waiting();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.iconMuted,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Waiting for a connection — this closes by itself.',
            style: AppTextStyles.caption.copyWith(fontSize: 13),
          ),
        ),
      ],
    );
  }
}
