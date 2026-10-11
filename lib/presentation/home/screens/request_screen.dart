import 'package:dating_app/core/router/app_router.dart';
import 'package:dating_app/core/utils/app_loader.dart';
import 'package:dating_app/core/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/extensions/global_back_extension.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/message_model.dart';
import '../../../providers/chat_provider.dart';
import '../../../providers/realtime_provider.dart';
import '../../../shared/widgets/empty_widget.dart';
import '../../../shared/widgets/premium_tab_bar.dart';
import '../../common/widgets/widgets.dart';
import '../widgets/chat_actions_menu.dart';
import './chat_detail_screen.dart';

// ============================================================================
// Screen
// ============================================================================

class ChatsScreen extends ConsumerStatefulWidget {
  const ChatsScreen({super.key});

  @override
  ConsumerState<ChatsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends ConsumerState<ChatsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController =
  TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _Header(),
        spacerH(10),
        _TabBarSection(tabController: _tabController),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              _ConversationList(
                state: 'vibing',
                emptyTitle: 'No conversations yet',
                emptyBody: 'When someone replies to your opener, the '
                    'conversation moves here.',
              ),
              _ConversationList(
                state: 'new_energy',
                emptyTitle: 'Nothing new',
                emptyBody: 'Openers waiting for a reply — yours or theirs — '
                    'show up here.',
              ),
            ],
          ),
        ),
      ],
    ).withGlobalBackHandler(context);
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 14),
      child: Row(
        children: [
          const Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Wordmark(size: 24),
            ),
          ),
          Semantics(
            button: true,
            label: 'Archived chats',
            excludeSemantics: true,
            child: InkWell(
              onTap: () => context.push(AppRoutes.archivedChats),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  Icons.archive_outlined,
                  size: 20,
                  color: AppColors.textDark,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Tab bar (premium pill / segmented style)
// ============================================================================

class _TabBarSection extends ConsumerWidget {
  const _TabBarSection({required this.tabController});

  final TabController tabController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vibing = ref.watch(conversationCountProvider('vibing'));
    final fresh = ref.watch(conversationCountProvider('new_energy'));

    String sem(String label, int? n) =>
        (n != null && n > 0) ? '$label, $n people' : label;

    return PremiumTabBar(
      controller: tabController,
      tabs: [
        PremiumTabItem(
          label: 'Vibing',
          icon: Icons.favorite_rounded,
          count: vibing,
          semanticLabel: sem('Vibing', vibing),
        ),
        PremiumTabItem(
          label: 'New Energy',
          icon: Icons.bolt_rounded,
          count: fresh,
          semanticLabel: sem('New Energy', fresh),
        ),
      ],
    );
  }
}

// ============================================================================
// Conversation list
// ============================================================================

class _ConversationList extends ConsumerWidget {
  const _ConversationList({
    required this.state,
    required this.emptyTitle,
    required this.emptyBody,
  });

  final String state;
  final String emptyTitle;
  final String emptyBody;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(conversationsProvider(state));
    final presence = ref.watch(presenceProvider);

    return async.when(
      loading: () => const Center(
        child: LoaderWidget(),
      ),
      error: (err, _) => const EmptyWidget(
        title: "Couldn't load conversations",
        body: 'Pull down to try again.',
      ),
      data: (items) {
        if (items.isEmpty) {
          return _RefreshableEmpty(
            state: state,
            title: emptyTitle,
            body: emptyBody,
          );
        }
        return _RefreshableList(state: state, items: items, presence: presence);
      },
    );
  }
}

class _RefreshableEmpty extends ConsumerWidget {
  const _RefreshableEmpty({
    required this.state,
    required this.title,
    required this.body,
  });

  final String state;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.card,
      onRefresh: () => ref.read(conversationsProvider(state).notifier).refresh(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [EmptyWidget(title: title, body: body)],
      ),
    );
  }
}

class _RefreshableList extends ConsumerWidget {
  const _RefreshableList({
    required this.state,
    required this.items,
    required this.presence,
  });

  final String state;
  final List<ConversationSummary> items;
  final Map<String, bool> presence;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.card,
      onRefresh: () => ref.read(conversationsProvider(state).notifier).refresh(),
      // WhatsApp-style list: full-width rows, no cards, and a hairline
      // divider that starts after the avatar.
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
        itemCount: items.length,
        separatorBuilder: (_, _) => Divider(
          height: 1,
          thickness: 0.6,
          indent: 86,
          endIndent: 16,
          color: AppColors.inputBorder,
        ),
        itemBuilder: (_, index) => ConversationTile(
          conversation: items[index],
          colorIndex: index,
          online: presence[items[index].otherUser.id] ??
              items[index].otherUser.isOnline,
        ),
      ),
    );
  }
}

// ============================================================================
// Conversation tile (WhatsApp-style row)
//
// Avatar on the left. Name on top with the time at the right edge; the
// last-message snippet below with the unread badge at the right edge.
// Long-press opens the chat actions menu (archive / mute / etc.).
// ============================================================================

class ConversationTile extends StatelessWidget {
  const ConversationTile({
    super.key,
    required this.conversation,
    required this.colorIndex,
    required this.online,
    this.isArchived = false,
  });

  final ConversationSummary conversation;
  final int colorIndex;
  final bool online;
  final bool isArchived;

  @override
  Widget build(BuildContext context) {
    final other = conversation.otherUser;
    final name = other.displayName ?? 'Someone';
    final snippet = conversation.lastMessage?.snippet ?? 'Say hello';
    final unread = conversation.unread;
    final muted = conversation.muted;
    final hasUnread = unread > 0;

    return Semantics(
      button: true,
      label: [
        name,
        snippet,
        if (unread > 0) '$unread unread',
        if (muted) 'muted',
        if (online) 'online now',
      ].join(', '),
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openChat(context, other, name),
          onLongPress: () => showChatActionsMenu(
            context,
            conversationId: conversation.id,
            userId: other.id,
            userName: name,
            isArchived: isArchived,
            isMuted: muted,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 6, 10),
            child: Row(
              children: [
                _Avatar(
                  name: name,
                  photoUrl: other.primaryPhotoUrl,
                  colorIndex: colorIndex,
                  online: online,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Top line: name ........ time
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.bodyStrong.copyWith(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _ago(conversation.lastMessageAt),
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 12,
                              color: hasUnread && !muted
                                  ? AppColors.primary
                                  : AppColors.textGrey,
                              fontWeight: hasUnread
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      // Bottom line: snippet ........ muted icon / badge
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              snippet,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.caption.copyWith(
                                fontSize: 13.5,
                                color: hasUnread
                                    ? AppColors.textDark
                                    : AppColors.textGrey,
                              ),
                            ),
                          ),
                          if (muted) ...[
                            const SizedBox(width: 8),
                            Icon(
                              Icons.notifications_off_outlined,
                              size: 16,
                              color: AppColors.iconMuted,
                            ),
                          ],
                          if (hasUnread) ...[
                            const SizedBox(width: 8),
                            Container(
                              constraints: const BoxConstraints(
                                minWidth: 20,
                                minHeight: 20,
                              ),
                              padding:
                              const EdgeInsets.symmetric(horizontal: 6),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: muted
                                    ? AppColors.iconMuted
                                    : AppColors.primary,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                unread > 99 ? '99+' : '$unread',
                                style: AppTextStyles.caption.copyWith(
                                  fontSize: 11,
                                  color: AppColors.onAccent,
                                  fontWeight: FontWeight.w700,
                                  fontVariations: const [
                                    FontVariation('wght', 700),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                _RowMenu(
                  conversationId: conversation.id,
                  userId: other.id,
                  userName: name,
                  isArchived: isArchived,
                  isMuted: muted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openChat(BuildContext context, dynamic other, String name) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatDetailScreen(
          conversationId: conversation.id,
          userId: other.id,
          userName: name,
          userAge: other.age,
          photoUrl: other.primaryPhotoUrl,
          colorIndex: colorIndex,
          otherUser: other,
        ),
      ),
    );
  }

  static String _ago(DateTime? dt) {
    if (dt == null) return '';
    final d = DateTime.now().difference(dt.toLocal());
    if (d.inMinutes < 1) return 'now';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    return '${d.inDays}d';
  }
}

class _RowMenu extends StatelessWidget {
  const _RowMenu({
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
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Options for $userName',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => showChatActionsMenu(
          context,
          conversationId: conversationId,
          userId: userId,
          userName: userName,
          isArchived: isArchived,
          isMuted: isMuted,
        ),
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Icon(Icons.more_vert, size: 19, color: AppColors.iconMuted),
        ),
      ),
    );
  }
}

// ============================================================================
// Shared bits
// ============================================================================

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.name,
    required this.colorIndex,
    required this.online,
    this.photoUrl,
  });

  final String name;
  final String? photoUrl;
  final int colorIndex;
  final bool online;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: photoUrl == null ? avatarGradient(colorIndex) : null,
              image: photoUrl != null
                  ? DecorationImage(
                image: NetworkImage(photoUrl!),
                fit: BoxFit.cover,
              )
                  : null,
            ),
            child: photoUrl == null
                ? Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: AppTextStyles.avatarInitial(22),
              ),
            )
                : null,
          ),
          if (online)
            Positioned(
              right: 1,
              bottom: 1,
              child: Container(
                width: 13,
                height: 13,
                decoration: BoxDecoration(
                  color: AppColors.ok,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.background, width: 2.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}