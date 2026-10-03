import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_text_styles.dart';
import '../../../core/theme/app_colors.dart';
import 'radius_button.dart';
import 'step_header.dart';

/// The frame for the screens that stop the app — offline, a retired version,
/// maintenance, an unsafe device.
///
/// They are rare and they are bad news, so they get the plainest treatment in
/// the app: the wordmark so you know where you are, a small mark, a headline
/// that says what happened in the words you would use, one paragraph on what
/// to do, and the one action that might fix it, pinned where the thumb is.
/// No glow, no pulsing badge, no status pill — urgency does not need
/// decoration, and these screens used to have all three.
class SystemStateLayout extends StatelessWidget {
  const SystemStateLayout({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    this.isLoading = false,
    this.secondaryLabel,
    this.onSecondary,
    this.danger = false,
    this.children = const [],
  });

  final IconData icon;
  final String title;
  final String message;

  final String actionLabel;
  final VoidCallback? onAction;
  final bool isLoading;

  /// A quiet second way out under the action — "Go back".
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  /// Marks the icon red, for a state that is about safety rather than timing.
  final bool danger;

  /// Detail under the message — the list of what is wrong, a live status.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    // Short phones keep the layout and lose some air, so the detail under
    // the message is not pushed straight under the button.
    final compact = MediaQuery.sizeOf(context).height < 700;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: AppColors.isDark
            ? Brightness.light
            : Brightness.dark,
        statusBarBrightness: AppColors.isDark
            ? Brightness.dark
            : Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 18, 24, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Wordmark(size: 20),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(24, compact ? 24 : 44, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        icon,
                        size: 30,
                        color: danger ? AppColors.danger : AppColors.textDark,
                      ),
                      SizedBox(height: compact ? 12 : 18),
                      Semantics(
                        header: true,
                        child: Text(
                          title,
                          style: compact
                              ? AppTextStyles.question.copyWith(fontSize: 28)
                              : AppTextStyles.question,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        message,
                        style: AppTextStyles.bodyMuted.copyWith(fontSize: 15),
                      ),
                      if (children.isNotEmpty) ...[
                        const SizedBox(height: 28),
                        ...children,
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    RadiusButton(
                      label: actionLabel,
                      isLoading: isLoading,
                      onPressed: onAction,
                    ),
                    if (secondaryLabel != null && onSecondary != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: TextButton(
                          onPressed: onSecondary,
                          style: TextButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            foregroundColor: AppColors.textGrey,
                          ),
                          child: Text(
                            secondaryLabel!,
                            style: AppTextStyles.bodyStrong.copyWith(
                              color: AppColors.textGrey,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One line of detail on a [SystemStateLayout]: a small mark, a short title
/// and what to do about it. Rows, not cards — hairlines between them.
class SystemStateRow extends StatelessWidget {
  const SystemStateRow({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.showDivider = true,
  });

  final IconData icon;
  final String title;
  final String? description;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: showDivider
            ? Border(top: BorderSide(color: AppColors.inputBorder))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 20, color: AppColors.textGrey),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyStrong.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    fontVariations: const [FontVariation('wght', 600)],
                  ),
                ),
                if (description != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    description!,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 13.5,
                      height: 1.45,
                      fontWeight: FontWeight.w400,
                      fontVariations: const [FontVariation('wght', 400)],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
