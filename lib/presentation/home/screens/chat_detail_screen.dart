import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:dating_app/core/extensions/padding_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/ads/banner/banner_ad_widget.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/utils/app_loader.dart';
import '../../../core/utils/screen_guard.dart';
import '../../../core/utils/utils.dart';
import '../../../data/models/message_model.dart';
import '../../../providers/profile_provider.dart';
import '../../../providers/chat_provider.dart';
import '../../../providers/realtime_provider.dart';
import '../../common/widgets/widgets.dart';
import '../models/profile_seed.dart';
import '../widgets/chat_actions_menu.dart';
import '../widgets/message_limit_paywall.dart';
import '../widgets/send_failure.dart';
import './profile_detail_sheet.dart';

// ═════════════════════════════════════════════════════════════════════
// UI-only theme helpers (all derived from AppColors, so light & dark
// mode follow the active RadiusPalette automatically).
// ═════════════════════════════════════════════════════════════════════

/// Height of the floating, transparent top bar (excluding the status bar).
const double _kTopBarHeight = 64;

/// Soft elevation that stays visible in light mode and doesn't turn into
/// a muddy blob in dark mode.
List<BoxShadow> _softShadow({
  double light = 0.06,
  double dark = 0.35,
  double blur = 10,
  Offset offset = const Offset(0, 2),
}) {
  return [
    BoxShadow(
      color: Colors.black.withValues(alpha:AppColors.isDark ? dark : light),
      blurRadius: blur,
      offset: offset,
    ),
  ];
}

/// Fill colour for text-field pills (sits on top of AppColors.card).
Color get _fieldFill =>
    AppColors.isDark ? AppColors.background : AppColors.primaryTint;

/// Chat wallpaper base: the page background washed with a hint of the
/// brand tint, so white bubbles / card bubbles pop in both modes.
Color get _chatWallpaperBase => Color.alphaBlend(
  AppColors.primaryTint.withValues(alpha:AppColors.isDark ? 0.45 : 0.55),
  AppColors.background,
);

class ChatDetailScreen extends ConsumerStatefulWidget {
  final String? conversationId;

  final String userId;
  final String userName;
  final int? userAge;
  final String? photoUrl;
  final int colorIndex;

  final ChatOtherUser? otherUser;

  /// Text to start the composer with — an opener picked on the match screen.
  /// Typed in, never sent: the person still decides whether it goes.
  final String? initialDraft;

  const ChatDetailScreen({
    super.key,
    required this.conversationId,
    required this.userId,
    required this.userName,
    this.userAge,
    this.photoUrl,
    this.colorIndex = 0,
    this.otherUser,
    this.initialDraft,
  });

  @override
  ConsumerState<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends ConsumerState<ChatDetailScreen>
    with ScreenGuardMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<StreamSubscription<dynamic>> _subs = [];
  Timer? _typingTimer;
  bool _isTyping = false;
  bool _sending = false;

  /// The server said the New Energy allowance is spent. Cleared the moment
  /// their reply arrives — that reply is what lifts the cap server-side too.
  bool _awaitingReply = false;

  StateController<String?>? _activeClaim;

  String? _convId;

  String get _otherId => widget.userId;

  @override
  void initState() {
    super.initState();
    _convId = widget.conversationId;
    final draft = widget.initialDraft;
    if (draft != null && draft.isNotEmpty) {
      _messageController.value = TextEditingValue(
        text: draft,
        selection: TextSelection.collapsed(offset: draft.length),
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _onOpen());
  }

  Future<void> _onOpen() async {
    if (_convId == null) {
      final existing = await _findExistingConversation();
      if (!mounted) return;
      if (existing == null) return;
      setState(() => _convId = existing);
    }
    if (!mounted) return;

    final convId = _convId!;

    _activeClaim = ref.read(activeConversationProvider.notifier);
    _activeClaim!.state = convId;

    final chat = ref.read(chatServiceProvider);
    _subs.add(chat.messages.listen((incoming) {
      if (!_isLive(incoming.conversationId)) return;
      ref.read(messagesProvider(convId).notifier).addIncoming(incoming.message);
      ref.read(chatActionsProvider).markRead(convId);
      // Their reply lifts the cap.
      if (!incoming.message.fromMe) _awaitingReply = false;
      _scrollToBottom();
    }));
    _subs.add(chat.updates.listen((update) {
      if (!_isLive(update.conversationId)) return;
      ref.read(messagesProvider(convId).notifier).replace(update.message);
    }));
    _subs.add(chat.reads.listen((receipt) {
      if (!_isLive(receipt.conversationId)) return;
      ref.read(messagesProvider(convId).notifier).markMineRead();
    }));
    _subs.add(chat.typing.listen((event) {
      if (!_isLive(event.conversationId)) return;
      setState(() => _isTyping = true);
      _typingTimer?.cancel();
      _typingTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _isTyping = false);
      });
    }));

    if (!mounted) return;
    try {
      await ref.read(chatActionsProvider).markRead(convId);
    } catch (_) {}
  }

  Future<String?> _findExistingConversation() async {
    try {
      return await ref.read(chatActionsProvider).conversationIdWith(_otherId);
    } catch (_) {
      return null;
    }
  }

  void _releaseActiveClaim() {
    final claim = _activeClaim;
    _activeClaim = null;
    if (claim == null) return;
    Future<void>(() {
      if (claim.mounted && claim.state == _convId) claim.state = null;
    });
  }

  bool _isLive(String conversationId) =>
      mounted && _convId != null && conversationId == _convId;

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _releaseActiveClaim();
    _typingTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sending) return;
    _messageController.clear();
    setState(() => _sending = true);
    try {
      final convId = _convId;
      if (convId == null) {
        final result =
        await ref.read(chatActionsProvider).open(_otherId, text);
        if (!mounted) return;
        setState(() => _convId = result.conversation.id);
        await _onOpen();
      } else {
        await ref.read(chatActionsProvider).send(convId, text);
      }
      _scrollToBottom();
    } on EntitlementRequiredException catch (gate) {
      // Out of new conversations for today. The draft goes back in the box so
      // accepting the offer is one tap back to what they wrote.
      removeFocus();
      _restoreDraft(text);
      if (mounted) showMessageLimitPaywall(context, gate: gate);
    } on AppException catch (e) {
      _restoreDraft(text);
      if (mounted) {
        final failure = SendFailure.from(e, name: widget.userName);
        if (failure.kind == SendFailureKind.awaitingReply) {
          _awaitingReply = true;
        }
        sendFailureHaptic();
        showRadiusToast(context, e.message, tone: ToastTone.error);
      }
    } catch (e, st) {
      // Safety net: a non-AppException (e.g. a parsing TypeError) must never
      // swallow the message with no feedback.
      debugPrint('send failed: $e\n$st');
      _restoreDraft(text);
      if (mounted) {
        showRadiusToast(
          context,
          'Something went wrong. Please try again.',
          tone: ToastTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// Puts a refused message back where it was typed, caret at the end, so the
  /// person can reword it rather than retype it.
  void _restoreDraft(String text) {
    _messageController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _onInputChanged(String _) {
    final convId = _convId;
    if (convId == null) return;
    ref
        .read(chatServiceProvider)
        .sendTyping(toUserId: _otherId, conversationId: convId);
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final local = dt.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final convId = _convId;
    // Space the content needs at the top so it starts below the floating bar.
    final topInset = MediaQuery.paddingOf(context).top + _kTopBarHeight;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // 1. Wallpaper – full screen, also behind the status bar + top bar
          Positioned.fill(
            child: ColoredBox(
              color: _chatWallpaperBase,
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _WallpaperPainter(
                    color: AppColors.primaryInk
                        .withValues(alpha:AppColors.isDark ? 0.07 : 0.08),
                  ),
                ),
              ),
            ),
          ),

          // 2. Messages + input bar
          Positioned.fill(
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  Expanded(
                    child: convId == null
                        ? Padding(
                      padding: EdgeInsets.only(top: topInset),
                      child: _EmptyThread(name: widget.userName),
                    )
                        : ref.watch(messagesProvider(convId)).when(
                      loading: () => Padding(
                        padding: EdgeInsets.only(top: topInset),
                        child: const Center(child: LoaderWidget()),
                      ),
                      error: (err, _) => Padding(
                        padding: EdgeInsets.only(top: topInset),
                        child: Center(
                          child: Text(
                            "Couldn't load messages.\n$err",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textGrey),
                          ),
                        ),
                      ),
                      data: (messages) =>
                          _buildMessageList(messages, topInset),
                    ),
                  ),
                  _buildInputBar(),
                ],
              ),
            ),
          ),

          // 3. Transparent top bar floating above everything
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(bottom: false, child: _buildTopBar()),
          ),
        ],
      ),
    );
  }

  void _openProfile() {
    showRadiusSheet<void>(
      context: context,
      builder: (_) => ProfileDetailSheet(
        userId: _otherId,
        seed: ProfileSeed(
          name: widget.userName,
          age: widget.userAge,
          photoUrl: widget.photoUrl,
          colorIndex: widget.colorIndex,
        ),
      ),
    );
  }

  Future<void> _openActions() async {
    final convId = _convId;
    if (convId == null) {
      showRadiusToast(context, 'Say something first');
      return;
    }
    final result = await showChatActionsMenu(
      context,
      conversationId: convId,
      userId: _otherId,
      userName: widget.userName,
      isMuted: _isMuted,
    );
    if (!mounted || result == null) return;
    const stayOpen = {
      ChatActionResult.reported,
      ChatActionResult.muted,
      ChatActionResult.unmuted,
    };
    if (!stayOpen.contains(result)) Navigator.pop(context);
  }

  bool get _isMuted {
    final convId = _convId;
    if (convId == null) return false;
    for (final state in const [null, 'vibing', 'new_energy']) {
      final list = ref.read(conversationsProvider(state)).valueOrNull;
      if (list == null) continue;
      for (final c in list) {
        if (c.id == convId) return c.muted;
      }
    }
    return false;
  }

  // ── Top bar (transparent, floats over the wallpaper) ─────────────────

  Widget _buildTopBar() {
    final name = widget.userName;
    final online = ref.watch(presenceProvider)[_otherId] ??
        widget.otherUser?.isOnline ??
        false;

    return SizedBox(
      height: _kTopBarHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            _GlassButton(
              icon: Icons.arrow_back_ios_new_rounded,
              label: 'Back',
              iconSize: 19,
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Semantics(
                button: true,
                label: "Open $name's profile",
                excludeSemantics: true,
                child: InkWell(
                  onTap: _openProfile,
                  borderRadius: BorderRadius.circular(14),
                  child: Row(
                    children: [
                      _buildAvatar(name, online),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.userAge != null
                                  ? '$name, ${widget.userAge}'
                                  : name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.bodyStrong.copyWith(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.1,
                                fontVariations: const [
                                  FontVariation('wght', 700),
                                ],
                              ),
                            ),
                            const SizedBox(height: 2),
                            _StatusFlags(
                              online: online,
                              typing: _isTyping,
                              other: widget.otherUser,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _GlassButton(
              icon: Icons.more_vert_rounded,
              label: 'More options',
              onTap: _openActions,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(String name, bool online) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 46,
          height: 46,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primarySoft, width: 1.5),
          ),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: widget.photoUrl == null
                  ? avatarGradient(widget.colorIndex)
                  : null,
              image: widget.photoUrl != null
                  ? DecorationImage(
                image: NetworkImage(widget.photoUrl!),
                fit: BoxFit.cover,
              )
                  : null,
            ),
            child: widget.photoUrl == null
                ? Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: AppTextStyles.avatarInitial(17),
              ),
            )
                : null,
          ),
        ),
        if (online)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 13,
              height: 13,
              decoration: BoxDecoration(
                color: AppColors.ok,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.card, width: 2),
              ),
            ),
          ),
      ],
    );
  }

  // ── Message list ─────────────────────────────────────────────────────

  Widget _buildMessageList(List<Message> messages, double topInset) {
    if (messages.isEmpty) {
      return Padding(
        padding: EdgeInsets.only(top: topInset),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.inputBorder),
              boxShadow: _softShadow(light: 0.05, blur: 10),
            ),
            child: Text(
              'Say hello 👋',
              style: TextStyle(
                color: AppColors.textGrey,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      );
    }
    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(12, topInset, 12, 10),
      itemCount: messages.length + 1,
      itemBuilder: (_, index) {
        if (index == 0) return _buildDateHeader('TODAY');
        final msg = messages[index - 1];
        final prev = index - 2 >= 0 ? messages[index - 2] : null;
        final firstInGroup = prev == null || prev.fromMe != msg.fromMe;
        return _buildMessageBubble(msg, firstInGroup: firstInGroup);
      },
    );
  }

  Widget _buildDateHeader(String label) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 14),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.inputBorder),
          boxShadow: _softShadow(light: 0.04, blur: 8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textGrey,
            letterSpacing: 1.1,
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Message msg, {required bool firstInGroup}) {
    final isMine = msg.fromMe;
    final deleted = msg.deleted;
    final sentStyle = isMine && !deleted;

    // Text/meta colours that stay legible on every bubble in both modes.
    // (AppColors.onAccent flips to near-black in dark mode, where the
    //  primary is a light blue — so it is always the right "on primary" ink.)
    final Color bodyColor = deleted
        ? AppColors.textGrey
        : (isMine ? AppColors.onAccent : AppColors.textDark);
    final Color metaColor = sentStyle
        ? AppColors.onAccent.withValues(alpha:0.70)
        : AppColors.textGrey;

    // Reserve room for the inline time / ticks so text never runs under them.
    double metaWidth = 54;
    if (msg.edited) metaWidth += 36;
    if (sentStyle) metaWidth += 18;

    final bodyStyle = deleted
        ? TextStyle(
      fontSize: 13.5,
      color: bodyColor,
      fontStyle: FontStyle.italic,
      height: 1.35,
    )
        : TextStyle(fontSize: 15, color: bodyColor, height: 1.35);

    final content = Stack(
      children: [
        Text.rich(
          TextSpan(
            children: [
              if (deleted)
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(
                      Icons.block,
                      size: 14,
                      color: AppColors.textGrey,
                    ),
                  ),
                ),
              TextSpan(text: msg.body, style: bodyStyle),
              WidgetSpan(
                alignment: PlaceholderAlignment.bottom,
                child: SizedBox(width: metaWidth, height: 14),
              ),
            ],
          ),
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (msg.edited) ...[
                Text(
                  'edited',
                  style: TextStyle(
                    fontSize: 10,
                    color: metaColor,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(width: 4),
              ],
              Text(
                _formatTime(msg.sentAt),
                style: TextStyle(fontSize: 10.5, color: metaColor),
              ),
              if (sentStyle) ...[
                const SizedBox(width: 3),
                // Single tick = sent, double tick = read (full-strength ink).
                Icon(
                  msg.read ? Icons.done_all_rounded : Icons.done_rounded,
                  size: 15,
                  color: msg.read
                      ? AppColors.onAccent
                      : AppColors.onAccent.withValues(alpha:0.60),
                ),
              ],
            ],
          ),
        ),
      ],
    );

    final radius = BorderRadius.only(
      topLeft: Radius.circular(!isMine && firstInGroup ? 4 : 16),
      topRight: Radius.circular(isMine && firstInGroup ? 4 : 16),
      bottomLeft: const Radius.circular(16),
      bottomRight: const Radius.circular(16),
    );

    return Padding(
      padding: EdgeInsets.only(top: firstInGroup ? 8 : 2),
      child: Row(
        mainAxisAlignment:
        isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: Semantics(
              button: !deleted,
              label: deleted ? null : 'Message options',
              child: GestureDetector(
                onLongPress: deleted ? null : () => _openMessageActions(msg),
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.78,
                  ),
                  padding: const EdgeInsets.fromLTRB(12, 8, 10, 6),
                  decoration: BoxDecoration(
                    gradient: sentStyle
                        ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.primary, AppColors.primaryDeep],
                    )
                        : null,
                    color: deleted
                        ? AppColors.background
                        : (isMine ? null : AppColors.card),
                    borderRadius: radius,
                    border: sentStyle
                        ? null
                        : Border.all(color: AppColors.inputBorder),
                    boxShadow: deleted
                        ? null
                        : (isMine
                        ? [
                      BoxShadow(
                        color: AppColors.primaryDeep.withValues(alpha:
                        AppColors.isDark ? 0.30 : 0.25,
                        ),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                        : _softShadow(light: 0.05, blur: 5)),
                  ),
                  child: content,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openMessageActions(Message msg) async {
    final isPremium =
        ref.read(meProvider).valueOrNull?.premium.isActive ?? false;

    final action = await showRadiusSheet<_MessageAction>(
      context: context,
      builder: (_) => _MessageActionsSheet(
        canModify: msg.fromMe,
        isPremium: isPremium,
      ),
    );
    if (action == null || !mounted) return;

    switch (action) {
      case _MessageAction.copy:
        await Clipboard.setData(ClipboardData(text: msg.body));
        if (mounted) showRadiusToast(context, 'Copied', tone: ToastTone.success);
      case _MessageAction.edit:
        await _editMessage(msg);
      case _MessageAction.delete:
        await _deleteMessage(msg);
      case _MessageAction.upgrade:
        if (mounted) {
          showRadiusToast(
            context,
            'Editing and deleting messages are premium features',
          );
        }
    }
  }

  Future<void> _editMessage(Message msg) async {
    final convId = _convId;
    if (convId == null) return;

    final next = await showRadiusSheet<String>(
      context: context,
      builder: (_) => _EditMessageSheet(original: msg.body),
    );
    final trimmed = next?.trim();
    if (trimmed == null || trimmed.isEmpty || trimmed == msg.body) return;

    try {
      await ref
          .read(chatActionsProvider)
          .editMessage(convId, msg.id, trimmed);
    } on AppException catch (e) {
      if (mounted) showRadiusToast(context, e.message, tone: ToastTone.error);
    }
  }

  Future<void> _deleteMessage(Message msg) async {
    final convId = _convId;
    if (convId == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.panel,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: AppColors.inputBorder),
        ),
        title: Text(
          'Delete this message?',
          style: AppTextStyles.title.copyWith(fontSize: 18),
        ),
        content: Text(
          'It disappears for both of you. ${widget.userName} will see that a '
              'message was deleted, in the place it was.',
          style: AppTextStyles.bodyMuted,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              'Cancel',
              style: AppTextStyles.bodyStrong
                  .copyWith(color: AppColors.textGrey),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              'Delete',
              style: AppTextStyles.bodyStrong.copyWith(
                color: AppColors.danger,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    try {
      await ref.read(chatActionsProvider).deleteMessage(convId, msg.id);
    } on AppException catch (e) {
      if (mounted) showRadiusToast(context, e.message, tone: ToastTone.error);
    }
  }

  // ── Input bar ────────────────────────────────────────────────────────

  Widget _buildInputBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.inputBorder, width: 1)),
        boxShadow: _softShadow(
          light: 0.05,
          dark: 0.30,
          blur: 14,
          offset: const Offset(0, -3),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const BannerAdWidget().paddingOnly(bottom: 8.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(
                    minHeight: 46,
                    maxHeight: 120,
                  ),
                  decoration: BoxDecoration(
                    color: _fieldFill,
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: AppColors.inputBorder),
                  ),
                  child: TextField(
                    controller: _messageController,
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                    cursorColor: AppColors.primary,
                    onChanged: _onInputChanged,
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.textDark,
                      height: 1.3,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Say something nice...',
                      hintStyle: TextStyle(
                        color: AppColors.textGrey,
                        fontSize: 15,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _sendMessage,
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.primary, AppColors.primaryDeep],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary
                            .withValues(alpha:AppColors.isDark ? 0.30 : 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: _sending
                      ? Padding(
                    padding: const EdgeInsets.all(13),
                    child: CircularProgressIndicator(
                      color: AppColors.onAccent,
                      strokeWidth: 2,
                    ),
                  )
                      : Icon(
                    Icons.send_rounded,
                    color: AppColors.onAccent,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════
// Frosted round button for the transparent top bar
// ═════════════════════════════════════════════════════════════════════

/// Round frosted-glass button that stays readable over the wallpaper.
class _GlassButton extends StatelessWidget {
  const _GlassButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.size = 44,
    this.iconSize = 21,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Material(
            color: AppColors.card.withValues(alpha:AppColors.isDark ? 0.55 : 0.72),
            child: InkWell(
              onTap: onTap,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.inputBorder.withValues(alpha:0.7),
                  ),
                ),
                child: Icon(icon, size: iconSize, color: AppColors.textDark),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════
// Wallpaper (subtle doodle pattern, WhatsApp-style)
// ═════════════════════════════════════════════════════════════════════

class _WallpaperPainter extends CustomPainter {
  _WallpaperPainter({required this.color});

  final Color color;

  static const List<IconData> _icons = [
    Icons.favorite_border_rounded,
    Icons.chat_bubble_outline_rounded,
    Icons.star_border_rounded,
    Icons.emoji_emotions_outlined,
    Icons.local_cafe_outlined,
    Icons.music_note_outlined,
    Icons.explore_outlined,
    Icons.camera_alt_outlined,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    const double step = 72;
    const double iconSize = 20;

    final painters = _icons.map((icon) {
      final tp = TextPainter(
        textDirection: TextDirection.ltr,
        text: TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(
            fontSize: iconSize,
            fontFamily: icon.fontFamily,
            package: icon.fontPackage,
            color: color,
          ),
        ),
      )..layout();
      return tp;
    }).toList();

    int row = 0;
    for (double y = 8; y < size.height; y += step) {
      final double shift = row.isEven ? 0 : step / 2;
      int col = 0;
      for (double x = 8 + shift; x < size.width; x += step) {
        final tp = painters[(row * 3 + col) % painters.length];
        canvas.save();
        canvas.translate(x + iconSize / 2, y + iconSize / 2);
        canvas.rotate(((row + col) % 5 - 2) * 0.18);
        tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
        canvas.restore();
        col++;
      }
      row++;
    }
  }

  @override
  bool shouldRepaint(covariant _WallpaperPainter oldDelegate) =>
      oldDelegate.color != color;
}

// ═════════════════════════════════════════════════════════════════════
// Sheets & small widgets
// ═════════════════════════════════════════════════════════════════════

enum _MessageAction { copy, edit, delete, upgrade }

class _MessageActionsSheet extends StatelessWidget {
  const _MessageActionsSheet({
    required this.canModify,
    required this.isPremium,
  });

  final bool canModify;

  final bool isPremium;

  @override
  Widget build(BuildContext context) {
    return RadiusSheet(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MessageActionRow(
            icon: Icons.copy_rounded,
            label: 'Copy',
            onTap: () => Navigator.pop(context, _MessageAction.copy),
          ),
          if (canModify) ...[
            _MessageActionRow(
              icon: Icons.edit_rounded,
              label: 'Edit',
              locked: !isPremium,
              onTap: () => Navigator.pop(
                context,
                isPremium ? _MessageAction.edit : _MessageAction.upgrade,
              ),
            ),
            _MessageActionRow(
              icon: Icons.delete_rounded,
              label: 'Delete',
              danger: true,
              locked: !isPremium,
              onTap: () => Navigator.pop(
                context,
                isPremium ? _MessageAction.delete : _MessageAction.upgrade,
              ),
            ),
          ],
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _MessageActionRow extends StatelessWidget {
  const _MessageActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
    this.locked = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final Color color = danger ? AppColors.danger : AppColors.textDark;
    final Color effective = locked ? AppColors.iconMuted : color;
    final Color badgeBg = locked
        ? AppColors.iconMuted.withValues(alpha:0.14)
        : (danger ? AppColors.danger.withValues(alpha:0.12) : AppColors.primaryTint);
    final Color badgeIcon =
    locked ? AppColors.iconMuted : (danger ? AppColors.danger : AppColors.primaryInk);

    return Semantics(
      button: true,
      label: locked ? '$label, premium' : label,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: badgeBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 19, color: badgeIcon),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: AppTextStyles.bodyStrong.copyWith(
                      fontSize: 15,
                      color: effective,
                    ),
                  ),
                ),
                if (locked)
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.premiumTint,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.lock_rounded,
                      size: 13,
                      color: AppColors.premiumInk,
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

class _EditMessageSheet extends StatefulWidget {
  const _EditMessageSheet({required this.original});

  final String original;

  @override
  State<_EditMessageSheet> createState() => _EditMessageSheetState();
}

class _EditMessageSheetState extends State<_EditMessageSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.original,
  )..selection = TextSelection.collapsed(offset: widget.original.length);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RadiusSheet(
      title: 'Edit message',
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'They will see that this message was edited.',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: _fieldFill,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.inputBorder),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: TextField(
                controller: _controller,
                autofocus: true,
                maxLines: null,
                maxLength: 4000,
                cursorColor: AppColors.primary,
                style: AppTextStyles.body,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  counterText: '',
                ),
              ),
            ),
            const SizedBox(height: 14),
            RadiusButton(
              label: 'Save',
              onPressed: () =>
                  Navigator.pop(context, _controller.text.trim()),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

class _EmptyThread extends StatelessWidget {
  const _EmptyThread({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.inputBorder),
            boxShadow: _softShadow(
              light: 0.07,
              dark: 0.40,
              blur: 24,
              offset: const Offset(0, 8),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadarMark(size: 76, color: AppColors.iconMuted),
              const SizedBox(height: 18),
              Text(
                'You matched with $name',
                textAlign: TextAlign.center,
                style: AppTextStyles.title.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                'Neither of you has said anything yet. Someone has to go first.',
                textAlign: TextAlign.center,
                style: AppTextStyles.caption,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusFlags extends StatelessWidget {
  const _StatusFlags({
    required this.online,
    this.typing = false,
    this.other,
  });

  final bool online;
  final bool typing;
  final ChatOtherUser? other;

  @override
  Widget build(BuildContext context) {
    if (other?.isDeactivated ?? false) {
      return const _Flag(
        icon: Icons.person_off_outlined,
        label: 'Account deactivated',
        tone: _FlagTone.muted,
      );
    }

    if (typing) {
      return Text(
        'typing…',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.caption.copyWith(
          fontSize: 12,
          color: AppColors.primaryInk,
          fontWeight: FontWeight.w600,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    final city = other?.city;
    final activity = online ? 'Active now' : other?.activityLabel;

    return Row(
      children: [
        if (city != null && city.isNotEmpty) ...[
          Flexible(
            child: _Flag(
              icon: Icons.location_on_outlined,
              label: city,
              tone: _FlagTone.muted,
            ),
          ),
          if (activity != null) const SizedBox(width: 10),
        ],
        if (activity != null)
          Flexible(
            child: _Flag(
              icon: Icons.circle,
              label: activity,
              tone: online ? _FlagTone.live : _FlagTone.muted,
            ),
          ),
      ],
    );
  }
}

enum _FlagTone { muted, live }

class _Flag extends StatelessWidget {
  const _Flag({required this.icon, required this.label, required this.tone});

  final IconData icon;
  final String label;
  final _FlagTone tone;

  @override
  Widget build(BuildContext context) {
    final color =
    tone == _FlagTone.live ? AppColors.ok : AppColors.textGrey;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: tone == _FlagTone.live ? 7 : 11, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(
              fontSize: 11.5,
              color: color,
              fontWeight:
              tone == _FlagTone.live ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }
}