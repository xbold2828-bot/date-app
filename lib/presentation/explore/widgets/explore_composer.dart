import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../data/models/map_user_model.dart';
import '../../../providers/chat_provider.dart';
import '../../common/widgets/widgets.dart';
import '../../home/models/profile_seed.dart';
import '../../home/screens/profile_detail_sheet.dart';
import '../../home/widgets/message_limit_paywall.dart';
import 'explore_avatar.dart';

/// Message bar pinned under the map.
///
/// Messages go through [ChatActions.open], the same call the profile sheet
/// uses, so they follow the same gating and paywall rules. With nobody
/// selected the bar is hidden.
class ExploreComposer extends ConsumerStatefulWidget {
  const ExploreComposer({super.key, required this.recipient});

  /// The person the map is focused on, or null when it shows everyone.
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
    // A half-typed message must never carry over to a different person.
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
      // The text stays in the field so it is still there after the paywall.
      if (mounted) showMessageLimitPaywall(context, gate: gate);
    } on AppException catch (e) {
      if (mounted) showRadiusToast(context, e.message, tone: ToastTone.error);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _openProfile(MapUser recipient) {
    showRadiusSheet<void>(
      context: context,
      builder: (_) => ProfileDetailSheet(
        userId: recipient.id,
        seed: ProfileSeed(
          name: recipient.displayName,
          age: recipient.age,
          photoUrl: recipient.primaryPhotoUrl,
          distanceBand: recipient.distanceBand,
          isOnline: recipient.isOnline,
          colorIndex: recipient.id.hashCode,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recipient = widget.recipient;
    if (recipient == null) return const SizedBox.shrink();

    final enabled = !_sending;
    final canSend = enabled && _controller.text.trim().isNotEmpty;

    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        10,
        12,
        10 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border(top: BorderSide(color: AppColors.inputBorder)),
      ),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: "Open ${recipient.displayName}'s profile",
            excludeSemantics: true,
            child: GestureDetector(
              onTap: () => _openProfile(recipient),
              child: ExploreAvatar(
                name: recipient.displayName,
                photoUrl: recipient.primaryPhotoUrl,
                size: 46,
                isOnline: recipient.isOnline,
                showOnlineDot: false,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              decoration: BoxDecoration(
                color: enabled ? AppColors.card : AppColors.background,
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
                  hintText: 'Message ${recipient.displayName}…',
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
            label: 'Send to ${recipient.displayName}',
            excludeSemantics: true,
            child: GestureDetector(
              onTap: canSend ? _send : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: canSend ? AppColors.blue : AppColors.inputBorder,
                ),
                child: _sending
                    ? Padding(
                  padding: const EdgeInsets.all(12),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.onAccent,
                  ),
                )
                    : Icon(
                  Icons.send_rounded,
                  size: 19,
                  color:
                  canSend ? AppColors.onAccent : AppColors.iconMuted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}