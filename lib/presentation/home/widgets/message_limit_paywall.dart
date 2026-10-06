import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/errors/app_exceptions.dart';
import '../providers/match_provider/match_provider.dart';
import '../../common/widgets/widgets.dart';
import '../screens/premium_screen.dart';

/// Shown when the daily opener allowance runs out.
///
/// The limit only covers *new* conversations — replying to someone who already
/// wrote to you is free and always will be — so the copy says that plainly.
/// Somebody who thinks they have been cut off mid-conversation will not come
/// back, and they would be wrong.
Future<void> showMessageLimitPaywall(
    BuildContext context, {
      required EntitlementRequiredException gate,
    }) {
  return showRadiusSheet<void>(
    context: context,
    builder: (_) => _MessageLimitSheet(gate: gate),
  );
}

class _MessageLimitSheet extends ConsumerStatefulWidget {
  const _MessageLimitSheet({required this.gate});

  final EntitlementRequiredException gate;

  @override
  ConsumerState<_MessageLimitSheet> createState() => _MessageLimitSheetState();
}

class _MessageLimitSheetState extends ConsumerState<_MessageLimitSheet> {
  bool _watching = false;

  Future<void> _watchAd() async {
    if (_watching) return;
    setState(() => _watching = true);
    try {
      final credits = await ref
          .read(adActionsProvider)
          .watchToUnlock(placement: 'message_limit');

      if (!mounted) return;
      Navigator.pop(context);
      showRadiusToastGlobal(
        credits > 0
            ? 'Unlocked — send your message again'
            : 'That one was already counted',
        tone: credits > 0 ? ToastTone.success : ToastTone.neutral,
      );
    } on AppException catch (e) {
      if (mounted) showRadiusToast(context, e.message, tone: ToastTone.error);
    } finally {
      if (mounted) setState(() => _watching = false);
    }
  }

  /// The free allocation is counted per UTC day on the server, so "tomorrow"
  /// is wrong for anyone east or west of Greenwich. This is that boundary on
  /// the person's own clock.
  static String _resetTime(BuildContext context) {
    final now = DateTime.now().toUtc();
    final reset = DateTime.utc(now.year, now.month, now.day + 1).toLocal();
    final use24h = MediaQuery.alwaysUse24HourFormatOf(context);
    return DateFormat(use24h ? 'HH:mm' : 'h:mm a').format(reset);
  }

  @override
  Widget build(BuildContext context) {
    // The 402 says *that* the allowance is spent, not how big it was; the
    // entitlements snapshot knows the number. Until it arrives the copy simply
    // leaves the number out rather than guessing one.
    final limit = ref
        .watch(entitlementsProvider)
        .valueOrNull
        ?.conversations
        ?.limit;
    final known = limit != null && limit > 0;
    final creditsOnly = widget.gate.reason == 'INSUFFICIENT_CREDITS';

    final title = creditsOnly
        ? 'New chats need credits'
        : known
        ? "That's your $limit new chats for today"
        : "That's today's new chats";

    final body = creditsOnly
        ? 'Starting a conversation costs ${widget.gate.cost} '
        '${widget.gate.cost == 1 ? 'credit' : 'credits'}. Replying to '
        'people who already wrote to you is always free.'
        : known
        ? 'Free accounts can start $limit new conversations a day. '
        'Replying to people who already wrote to you is always free.'
        : 'Free accounts get a few new conversations a day. Replying to '
        'people who already wrote to you is always free.';

    return RadiusSheet(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 6),
          if (known && !creditsOnly) ...[
            _SpentOpeners(count: limit),
            const SizedBox(height: 18),
          ],
          Text(
            title,
            style: AppTextStyles.title.copyWith(fontSize: 23, height: 1.2),
          ),
          const SizedBox(height: 8),
          Text(body, style: AppTextStyles.bodyMuted),
          const SizedBox(height: 22),
          RadiusButton(
            label: 'Unlimited new chats with Premium',
            kind: RadiusButtonKind.premium,
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PremiumScreen()),
              );
            },
          ),
          // const SizedBox(height: 10),
          // RadiusButton(
          //   // No number here on purpose: an ad mints credits, and how many
          //   // openers those buy is server configuration the client cannot see.
          //   label: _watching ? 'Loading' : 'Watch a short ad to keep going',
          //   kind: RadiusButtonKind.ghost,
          //   isLoading: _watching,
          //   onPressed: _watchAd,
          // ),
          const SizedBox(height: 15),
          Text(
            'New chats reset at ${_resetTime(context)}.',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

/// The day's openers as spent tickets — a row of struck-through slots, one per
/// conversation the free tier allows. It says "used up" before a word is read.
class _SpentOpeners extends StatelessWidget {
  const _SpentOpeners({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    // Never more slots than fit comfortably on a phone; a retuned limit of
    // twenty would otherwise draw twenty.
    final shown = count.clamp(1, 6);
    return Semantics(
      label: 'All $count new chats used today',
      excludeSemantics: true,
      child: Row(
        children: [
          for (var i = 0; i < shown; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Container(
              width: 34,
              height: 26,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.check_rounded,
                size: 16,
                color: AppColors.onAccent,
              ),
            ),
          ],
          const SizedBox(width: 10),
          Text(
            '$count / $count',
            style: AppTextStyles.bodyStrong.copyWith(
              color: AppColors.primaryInk,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
