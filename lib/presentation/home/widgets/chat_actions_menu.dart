import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../data/repositories/safety_repository.dart';
import '../../../providers/chat_provider.dart';
import '../../common/widgets/widgets.dart';

/// What happened, so the caller can react — a screen sitting *inside* the
/// conversation has to leave when that conversation stops existing.
enum ChatActionResult {
  archived,
  unarchived,
  deleted,
  blocked,
  unblocked,
  reported,
  /// Muting leaves the thread exactly where it is, so unlike the rest of these
  /// it is never a reason for an open conversation to close.
  muted,
  unmuted,
}

/// The block/delete/archive/report menu.
///
/// One implementation behind both entry points: the three-dot button on an
/// inbox row and the header menu inside a thread. They offer the same things
/// because they act on the same thing, and two menus that drift apart is how
/// people end up unable to find the action they used yesterday.
Future<ChatActionResult?> showChatActionsMenu(
  BuildContext context, {
  required String conversationId,
  required String userId,
  required String userName,
  bool isArchived = false,
  bool isMuted = false,
}) {
  return showRadiusSheet<ChatActionResult>(
    context: context,
    builder: (_) => _ChatActionsSheet(
      conversationId: conversationId,
      userId: userId,
      userName: userName,
      isArchived: isArchived,
      isMuted: isMuted,
    ),
  );
}

class _ChatActionsSheet extends ConsumerStatefulWidget {
  const _ChatActionsSheet({
    required this.conversationId,
    required this.userId,
    required this.userName,
    required this.isArchived,
    required this.isMuted,
  });

  final String conversationId;
  final String userId;
  final String userName;
  final bool isArchived;
  final bool isMuted;

  @override
  ConsumerState<_ChatActionsSheet> createState() => _ChatActionsSheetState();
}

class _ChatActionsSheetState extends ConsumerState<_ChatActionsSheet> {
  bool _busy = false;

  /// Runs one action, closing the sheet only once it has actually succeeded.
  /// Closing first would report success for something that then failed.
  Future<void> _run(
    Future<void> Function() action, {
    required ChatActionResult result,
    required String confirmation,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      Navigator.pop(context, result);
      showRadiusToastGlobal(confirmation, tone: ToastTone.success);
    } on AppException catch (e) {
      if (mounted) showRadiusToast(context, e.message, tone: ToastTone.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _archive() {
    final actions = ref.read(chatActionsProvider);
    return widget.isArchived
        ? _run(
            () => actions.unarchive(widget.conversationId),
            result: ChatActionResult.unarchived,
            confirmation: 'Moved back to your inbox',
          )
        : _run(
            () => actions.archive(widget.conversationId),
            result: ChatActionResult.archived,
            confirmation: 'Archived',
          );
  }

  /// Mute is the quiet option between doing nothing and blocking somebody.
  ///
  /// Worth being precise about in the copy, because people reasonably assume a
  /// mute stops delivery or is somehow visible: it does neither. It only takes
  /// the thread out of the badge.
  Future<void> _toggleMute() {
    final actions = ref.read(chatActionsProvider);
    return widget.isMuted
        ? _run(
            () => actions.setMuted(widget.conversationId, false),
            result: ChatActionResult.unmuted,
            confirmation: 'Notifications on',
          )
        : _run(
            () => actions.setMuted(widget.conversationId, true),
            result: ChatActionResult.muted,
            confirmation: 'Muted — messages still arrive, quietly',
          );
  }

  Future<void> _delete() async {
    final ok = await _confirm(
      title: 'Delete this conversation?',
      body: 'It disappears from your inbox. ${widget.userName} keeps their '
          'copy, and if they message you again the chat comes back.',
      confirmLabel: 'Delete',
    );
    if (!ok) return;
    await _run(
      () => ref.read(chatActionsProvider).deleteConversation(widget.conversationId),
      result: ChatActionResult.deleted,
      confirmation: 'Conversation deleted',
    );
  }

  Future<void> _block() async {
    final ok = await _confirm(
      title: 'Block ${widget.userName}?',
      body: 'They will not be able to message you, and you will not see each '
          'other anywhere in cozune. Anything they send from now on will not '
          'reach you.\n\nYou can undo this in You → Blocked accounts.',
      confirmLabel: 'Block',
    );
    if (!ok) return;
    await _run(
      () => ref.read(chatActionsProvider).blockUser(widget.userId),
      result: ChatActionResult.blocked,
      confirmation: '${widget.userName} blocked',
    );
  }

  Future<void> _unblock() async {
    final ok = await _confirm(
      title: 'Unblock ${widget.userName}?',
      body: 'You will be able to see and message each other again. Anything '
          'they sent while blocked stays undelivered.',
      confirmLabel: 'Unblock',
    );
    if (!ok) return;
    await _run(
      () => ref.read(chatActionsProvider).unblockUser(widget.userId),
      result: ChatActionResult.unblocked,
      confirmation: '${widget.userName} unblocked',
    );
  }

  Future<void> _report() async {
    final reason = await showRadiusSheet<String>(
      context: context,
      builder: (_) => _ReportReasonSheet(userName: widget.userName),
    );
    if (reason == null) return;
    await _run(
      () => ref
          .read(chatActionsProvider)
          .reportUser(widget.userId, reason: reason),
      result: ChatActionResult.reported,
      confirmation: 'Reported — thank you',
    );
  }

  Future<bool> _confirm({
    required String title,
    required String body,
    required String confirmLabel,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(title, style: AppTextStyles.title.copyWith(fontSize: 18)),
        content: Text(body, style: AppTextStyles.bodyMuted),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              'Cancel',
              style: AppTextStyles.bodyStrong.copyWith(
                color: AppColors.textGrey,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              confirmLabel,
              style: AppTextStyles.bodyStrong.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) {
    // Reading the blocked set rather than tracking it locally: the menu can be
    // opened from an inbox row or from inside a thread, and both have to agree
    // about whether this person is already blocked.
    final isBlocked = ref.watch(blockedUserIdsProvider).contains(widget.userId);

    return RadiusSheet(
      title: widget.userName,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ActionRow(
            icon: widget.isMuted
                ? Icons.notifications_active_outlined
                : Icons.notifications_off_outlined,
            label: widget.isMuted
                ? 'Unmute ${widget.userName}'
                : 'Mute ${widget.userName}',
            onTap: _busy ? null : _toggleMute,
          ),
          _ActionRow(
            icon: widget.isArchived
                ? Icons.unarchive_outlined
                : Icons.archive_outlined,
            label: widget.isArchived ? 'Move to inbox' : 'Archive chat',
            onTap: _busy ? null : _archive,
          ),
          _ActionRow(
            icon: Icons.delete_outline,
            label: 'Delete chat',
            onTap: _busy ? null : _delete,
          ),
          if (isBlocked)
            _ActionRow(
              icon: Icons.check_circle_outline,
              label: 'Unblock ${widget.userName}',
              onTap: _busy ? null : _unblock,
            )
          else
            _ActionRow(
              icon: Icons.block,
              label: 'Block ${widget.userName}',
              tone: _ActionTone.danger,
              onTap: _busy ? null : _block,
            ),
          _ActionRow(
            icon: Icons.flag_outlined,
            label: 'Report',
            tone: _ActionTone.danger,
            onTap: _busy ? null : _report,
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

enum _ActionTone { normal, danger }

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.tone = _ActionTone.normal,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final _ActionTone tone;

  @override
  Widget build(BuildContext context) {
    final color =
        tone == _ActionTone.danger ? AppColors.primary : AppColors.textDark;

    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
            child: Row(
              children: [
                Icon(icon, size: 21, color: color),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyStrong.copyWith(
                      color: onTap == null ? AppColors.iconMuted : color,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Reporting asks why, because a report with no reason is a report moderation
/// cannot act on.
class _ReportReasonSheet extends StatelessWidget {
  const _ReportReasonSheet({required this.userName});

  final String userName;

  @override
  Widget build(BuildContext context) {
    return RadiusSheet(
      title: 'Report $userName',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'What is happening? This goes to our moderation team and they '
            'will not know you reported it.',
            style: AppTextStyles.bodyMuted,
          ),
          const SizedBox(height: 8),
          for (final option in ReportReason.options)
            _ActionRow(
              icon: Icons.chevron_right,
              label: option.key,
              onTap: () => Navigator.pop(context, option.value),
            ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}
