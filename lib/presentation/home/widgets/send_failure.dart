import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../../../core/constants/app_text_styles.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/theme/app_colors.dart';

/// Why a message did not go, in words somebody can act on.
///
/// Every composer in the app — the chat thread, the Explore bar, the opener on
/// a profile — sends through the same two calls and can be refused for the
/// same reasons, so the wording lives here once. The 402 paywall is the one
/// refusal that is not a sentence: it has its own sheet, and [from] is never
/// asked about it.
enum SendFailureKind {
  /// Moderation refused the text. Only ever happens while a thread is still
  /// New Energy — the unsolicited phase — so this is the line someone sees
  /// when an opener crosses it.
  moderated,

  /// The New Energy cap: the opener's allowance is spent until they reply.
  awaitingReply,

  /// A plain rate limit — too many sends in too short a window.
  slowDown,

  /// The request never reached us. The draft is still in the box.
  offline,

  /// Anything else the server said no to; its own message is shown.
  other,
}

@immutable
class SendFailure {
  const SendFailure({
    required this.kind,
    required this.title,
    required this.body,
  });

  final SendFailureKind kind;
  final String title;
  final String body;

  /// One line, for surfaces that only have room for a toast.
  String get toastText => '$title. $body';

  /// [name] is the person the message was for — "Wait for Ava to reply" reads
  /// as a pause; "Wait for a reply" reads as an error.
  static SendFailure from(AppException e, {required String name}) {
    final who = name.trim().isEmpty ? 'them' : name.trim();

    return switch (e) {
      ContentRejectedException() => const SendFailure(
        kind: SendFailureKind.moderated,
        title: 'Message not sent',
        body:
            "Offensive or abusive words aren't allowed on cozune. "
            'Reword it and try again.',
      ),
      RateLimitedException(reason: 'NEW_ENERGY_CAP') => SendFailure(
        kind: SendFailureKind.awaitingReply,
        title: 'Wait for $who to reply',
        body:
            "You've sent ${_cap(e)} messages without an answer. "
            'You can send more once $who replies.',
      ),
      RateLimitedException(:final retryAfterSeconds) => SendFailure(
        kind: SendFailureKind.slowDown,
        title: 'Slow down a little',
        body: retryAfterSeconds != null && retryAfterSeconds > 0
            ? 'Too many messages at once. Try again in '
                  '${retryAfterSeconds}s.'
            : 'Too many messages at once. Try again in a moment.',
      ),
      NetworkException() || RequestTimeoutException() => const SendFailure(
        kind: SendFailureKind.offline,
        title: "Couldn't send",
        body: 'Check your connection — your message is still here.',
      ),
      VerificationRequiredException() => SendFailure(
        kind: SendFailureKind.other,
        title: 'Verify to send messages',
        body: e.message,
      ),
      NotFoundException() => SendFailure(
        kind: SendFailureKind.other,
        title: "Couldn't send",
        body: '$who is not available right now.',
      ),
      _ => SendFailure(
        kind: SendFailureKind.other,
        title: "Couldn't send",
        body: e.message,
      ),
    };
  }

  /// The cap the server reported, falling back to the documented default. The
  /// number comes from the server's refusal rather than a constant here, so a
  /// retuned limit never contradicts what the person was just told.
  static int _cap(RateLimitedException e) =>
      (e.details?['limit'] as num?)?.toInt() ?? 3;
}

/// The refusal, pinned just above the composer that caused it.
///
/// Not a [SnackBar]: the thread's composer carries a banner ad and the
/// keyboard, and a floating snackbar positioned off the bottom of the scaffold
/// landed on top of the very field the person was typing in. Anchoring it to
/// the composer keeps it next to the text it is about, whatever the keyboard is
/// doing.
class SendFailureNotice extends StatelessWidget {
  const SendFailureNotice({
    super.key,
    required this.failure,
    required this.onDismiss,
  });

  final SendFailure failure;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    // The pill inverts with the theme (ink on paper, paper on ink), so the
    // accent marks use the toast's own pair, which clears 3:1 on both.
    final dark = AppColors.isDark;
    final accent = switch (failure.kind) {
      SendFailureKind.moderated => const Color(0xFFE5484D),
      SendFailureKind.awaitingReply =>
        dark ? const Color(0xFF2E5CBF) : const Color(0xFF8FB0FF),
      _ => dark ? const Color(0xFF9A6700) : const Color(0xFFF5B83D),
    };
    final icon = switch (failure.kind) {
      SendFailureKind.moderated => Icons.do_not_disturb_on_outlined,
      SendFailureKind.awaitingReply => Icons.hourglass_bottom_rounded,
      SendFailureKind.offline => Icons.wifi_off_rounded,
      _ => Icons.error_outline_rounded,
    };

    return Semantics(
      liveRegion: true,
      label: '${failure.title}. ${failure.body}',
      excludeSemantics: true,
      // No drop shadow: the composer paints over the bottom of anything cast
      // below the pill, which cut it into a hard grey shelf. The inverted fill
      // separates it from the thread on its own, in either theme.
      child: Material(
        color: AppColors.textDark,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onDismiss,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 13),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(icon, size: 19, color: accent),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        failure.title,
                        style: AppTextStyles.bodyStrong.copyWith(
                          fontSize: 14,
                          height: 1.3,
                          color: AppColors.background,
                          fontWeight: FontWeight.w700,
                          fontVariations: const [FontVariation('wght', 700)],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        failure.body,
                        style: AppTextStyles.body.copyWith(
                          fontSize: 13,
                          height: 1.4,
                          color: AppColors.background.withValues(alpha: 0.78),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: AppColors.background.withValues(alpha: 0.55),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Slides a [SendFailureNotice] up from the composer and back down again.
///
/// Entrance is a short rise on a strong ease-out; the exit is faster than the
/// entrance, the way a dismissal should be. With reduced motion the rise is
/// dropped and only the fade remains, so the message still arrives.
class SendFailureSlot extends StatelessWidget {
  const SendFailureSlot({
    super.key,
    required this.failure,
    required this.serial,
    required this.onDismiss,
  });

  /// Null hides the slot.
  final SendFailure? failure;

  /// Bumped on every refusal, so a second identical refusal still re-animates
  /// instead of silently matching the notice already on screen.
  final int serial;

  final VoidCallback onDismiss;

  static const _easeOut = Cubic(0.23, 1, 0.32, 1);

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final current = failure;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      reverseDuration: const Duration(milliseconds: 160),
      switchInCurve: _easeOut,
      switchOutCurve: Curves.easeOut,
      transitionBuilder: (child, animation) {
        final fade = FadeTransition(opacity: animation, child: child);
        if (reduceMotion) return fade;
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.35),
            end: Offset.zero,
          ).animate(animation),
          child: fade,
        );
      },
      child: current == null
          ? const SizedBox(
              key: ValueKey('send-failure-none'),
              width: double.infinity,
            )
          : SendFailureNotice(
              key: ValueKey('send-failure-$serial'),
              failure: current,
              onDismiss: onDismiss,
            ),
    );
  }
}

/// A refused send should be felt as well as read — the composer just did not
/// do what the thumb asked.
void sendFailureHaptic() => HapticFeedback.mediumImpact();
