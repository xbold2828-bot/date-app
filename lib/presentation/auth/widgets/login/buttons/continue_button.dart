
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dating_app/shared/widgets/buttons/common_button.dart';

import '../../../../../providers/auth/login_provider/login_provider.dart';

class ContinueButton extends ConsumerWidget {
  const ContinueButton({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(loginProvider.select((s) => s.isPhoneLoading));
    final canContinue = ref.watch(loginProvider.select((s) => s.canContinue));

    return CommonButton(
      text: 'Continue',
      isLoading: isLoading,
      isDisableButton: !canContinue,
      // null => disabled until the number is complete for the selected country
      onClick: canContinue ? onContinue : null,
    );
  }
}