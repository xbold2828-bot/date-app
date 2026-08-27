import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../data/repositories/safety_repository.dart';
import '../../../providers/chat_provider.dart';
import '../../common/widgets/widgets.dart';

/// Everyone I have blocked, and the way back.
///
/// This screen exists because a block is thorough: the moment it lands, that
/// person is gone from the radar, from likes, from their own profile page and
/// from the inbox. Every row that could have carried an "unblock" disappears
/// along with them — so without a list like this, blocking somebody by accident
/// would be permanent.
class BlockedAccountsScreen extends ConsumerWidget {
  const BlockedAccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(blockedUsersProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: Border(
          bottom: BorderSide(color: AppColors.inputBorder, width: 1),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Blocked accounts',
          style: AppTextStyles.title.copyWith(fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.card,
          onRefresh: () async => ref.invalidate(blockedUsersProvider),
          child: async.when(
            loading: () => Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
            error: (err, _) => ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                _Empty(
                  title: "Couldn't load your blocked list",
                  body: 'Pull down to try again.',
                ),
              ],
            ),
            data: (blocked) {
              if (blocked.isEmpty) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    _Empty(
                      title: 'Nobody blocked',
                      body: 'People you block are listed here, so you can '
                          'always let them back in.',
                    ),
                  ],
                );
              }

              return ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                itemCount: blocked.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, index) => _BlockedRow(
                  user: blocked[index],
                  colorIndex: index,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _BlockedRow extends ConsumerStatefulWidget {
  const _BlockedRow({required this.user, required this.colorIndex});

  final BlockedUser user;
  final int colorIndex;

  @override
  ConsumerState<_BlockedRow> createState() => _BlockedRowState();
}

class _BlockedRowState extends ConsumerState<_BlockedRow> {
  bool _busy = false;

  String get _name => widget.user.displayName ?? 'Someone';

  Future<void> _unblock() async {
    if (_busy) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.panel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Unblock $_name?',
          style: AppTextStyles.title.copyWith(fontSize: 18),
        ),
        content: Text(
          'You will be able to see and message each other again. Anything '
          'they sent while blocked stays undelivered.',
          style: AppTextStyles.bodyMuted,
        ),
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
              'Unblock',
              style: AppTextStyles.bodyStrong.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busy = true);
    try {
      await ref.read(chatActionsProvider).unblockUser(widget.user.id);
      showRadiusToastGlobal('$_name unblocked', tone: ToastTone.success);
    } on AppException catch (e) {
      if (mounted) showRadiusToast(context, e.message, tone: ToastTone.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RadiusCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: widget.user.primaryPhotoUrl == null
                  ? avatarGradient(widget.colorIndex)
                  : null,
              image: widget.user.primaryPhotoUrl != null
                  ? DecorationImage(
                      image: NetworkImage(widget.user.primaryPhotoUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: widget.user.primaryPhotoUrl == null
                ? Center(
                    child: Text(
                      _name.isNotEmpty ? _name[0].toUpperCase() : '?',
                      style: AppTextStyles.avatarInitial(18),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyStrong.copyWith(fontSize: 15),
                ),
                if (widget.user.blockedAt != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Blocked ${_ago(widget.user.blockedAt!)}',
                    style: AppTextStyles.caption.copyWith(fontSize: 11.5),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          _UnblockButton(busy: _busy, onTap: _unblock, name: _name),
        ],
      ),
    );
  }

  String _ago(DateTime at) {
    final d = DateTime.now().difference(at.toLocal());
    if (d.inMinutes < 60) return 'just now';
    if (d.inHours < 24) return '${d.inHours}h ago';
    if (d.inDays < 30) return '${d.inDays}d ago';
    return 'a while ago';
  }
}

/// The compact "Unblock" pill.
///
/// Not a [RadiusButton]: that one is built for footers — 54px tall with 16pt
/// type — and squeezing it into a list row is what split the label across two
/// lines as "Unblo / ck". This sizes to its own text instead, so it stays on
/// one line and leaves the name beside it room to breathe.
///
/// Accent tint rather than the neutral ghost fill: it is the only action on
/// the row and should look like one. It borrows the same tint/ink pairing as
/// `TagPill`, so it reads as part of the same family.
class _UnblockButton extends StatelessWidget {
  const _UnblockButton({
    required this.busy,
    required this.onTap,
    required this.name,
  });

  final bool busy;
  final VoidCallback onTap;
  final String name;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: !busy,
      label: busy ? 'Unblocking $name' : 'Unblock $name',
      excludeSemantics: true,
      child: Material(
        color: AppColors.primaryTint,
        borderRadius: BorderRadius.circular(999),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: busy ? null : onTap,
          // Deepens on hover and again on press, so the control answers a
          // pointer before it is clicked — this list is used on the web build,
          // where a static pill gives no sign it is interactive.
          hoverColor: AppColors.primary.withValues(alpha: 0.14),
          splashColor: AppColors.primary.withValues(alpha: 0.20),
          highlightColor: AppColors.primary.withValues(alpha: 0.10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            child: busy
                ? SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primaryInk,
                    ),
                  )
                : Text(
                    'Unblock',
                    // One line, always. The pill grows to fit rather than
                    // breaking the word.
                    maxLines: 1,
                    softWrap: false,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 13,
                      color: AppColors.primaryInk,
                      fontWeight: FontWeight.w700,
                      fontVariations: const [FontVariation('wght', 700)],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 72, 32, 24),
      child: Column(
        children: [
          RadarMark(size: 84, color: AppColors.iconMuted),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextStyles.title.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(body, textAlign: TextAlign.center, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}
