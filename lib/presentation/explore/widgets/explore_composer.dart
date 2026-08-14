import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../data/models/map_user_model.dart';
import '../../../providers/chat_provider.dart';
import '../../common/widgets/widgets.dart';
import '../../home/widgets/message_limit_paywall.dart';
import 'explore_avatar.dart';

/// The message bar pinned under the map.
///
/// The point of putting it here rather than behind a tap-through is that seeing
/// somebody a few streets away and saying something should be one gesture, not
/// four. It is always on screen so the map never has to be dismissed to use it.
///
/// It sends through [ChatActions.open] — the same call the full profile sheet
/// makes — so openers from the map are ordinary first messages: same
/// conversation, same New-Energy gating, same 402 paywall when the daily
/// allowance runs out. There is no second messaging path.
///
/// With nobody selected there is no addressee, so the field goes quiet and says
/// what to do instead of failing on send.
class ExploreComposer extends ConsumerStatefulWidget {
  const ExploreComposer({super.key, required this.recipient});

  /// The person the map is focused on, or null when it is showing everyone.
  final MapUser? recipient;

  @override
  ConsumerState<ExploreComposer> createState() => _ExploreComposerState();
}

class _ExploreComposerState extends ConsumerState<ExploreComposer> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    // Repaint the send button as the field goes from empty to not.
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onTextChanged() => setState(() {});

  @override
  void didUpdateWidget(covariant ExploreComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Switching to somebody else must not carry the half-typed opener across —
    // sending a message meant for one person to another is unrecoverable.
    if (oldWidget.recipient?.id != widget.recipient?.id) {
      _controller.clear();
      _focus.unfocus();
    }
  }

  Future<void> _send() async {
    final recipient = widget.recipient;
    final text = _controller.text.trim();
    if (recipient == null || text.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      await ref.read(chatActionsProvider).open(recipient.id, text);
      if (!mounted) return;
      _controller.clear();
      _focus.unfocus();
      showRadiusToast(
        context,
        'Message sent to ${recipient.displayName}',
        tone: ToastTone.success,
      );
    } on EntitlementRequiredException catch (gate) {
      // Out of openers for today. The text stays in the field behind the
      // paywall, so accepting the offer is one tap back to what they wrote.
      if (mounted) showMessageLimitPaywall(context, gate: gate);
    } on AppException catch (e) {
      if (mounted) showRadiusToast(context, e.message, tone: ToastTone.error);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final recipient = widget.recipient;
    final enabled = recipient != null && !_sending;
    final canSend = enabled && _controller.text.trim().isNotEmpty;

    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        10,
        12,
        10 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.panel,
        border: Border(top: BorderSide(color: AppColors.inputBorder)),
      ),
      child: Row(
        children: [
          if (recipient != null)
            ExploreAvatar(
              name: recipient.displayName,
              photoUrl: recipient.primaryPhotoUrl,
              size: 38,
              isOnline: recipient.isOnline,
              showOnlineDot: false,
            )
          else
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.white,
                border: Border.all(color: AppColors.inputBorder),
              ),
              child: const Icon(
                Icons.chat_bubble_outline,
                size: 17,
                color: AppColors.iconMuted,
              ),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              decoration: BoxDecoration(
                color: enabled ? AppColors.white : AppColors.background,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.inputBorder),
              ),
              child: TextField(
                controller: _controller,
                focusNode: _focus,
                enabled: enabled,
                minLines: 1,
                maxLines: 3,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                style: AppTextStyles.body,
                decoration: InputDecoration(
                  hintText: recipient == null
                      ? 'Pick someone to message'
                      : 'Message ${recipient.displayName}…',
                  hintStyle: AppTextStyles.body.copyWith(
                    color: AppColors.textGrey,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            button: true,
            enabled: canSend,
            label: recipient == null
                ? 'Pick someone on the map to message them'
                : 'Send to ${recipient.displayName}',
            excludeSemantics: true,
            child: GestureDetector(
              onTap: canSend ? _send : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: canSend
                      ? const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppMapColors.markerStart,
                            AppMapColors.markerEnd,
                          ],
                        )
                      : null,
                  color: canSend ? null : AppColors.inputBorder,
                ),
                child: _sending
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.white,
                        ),
                      )
                    : Icon(
                        Icons.send_rounded,
                        size: 19,
                        color: canSend ? AppColors.white : AppColors.iconMuted,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
