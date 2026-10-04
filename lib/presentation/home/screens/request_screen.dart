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
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
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
// Conversation tile
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
      child: RadiusCard(
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
        onTap: () => _openChat(context, other, name),
        child: Row(
          children: [
            _Avatar(
              name: name,
              photoUrl: other.primaryPhotoUrl,
              colorIndex: colorIndex,
              online: online,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _TileText(
                name: name,
                snippet: snippet,
                muted: muted,
                unread: unread,
              ),
            ),
            const SizedBox(width: 8),
            _TileMeta(lastMessageAt: conversation.lastMessageAt, unread: unread, muted: muted),
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
}

class _TileText extends StatelessWidget {
  const _TileText({
    required this.name,
    required this.snippet,
    required this.muted,
    required this.unread,
  });

  final String name;
  final String snippet;
  final bool muted;
  final int unread;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyStrong.copyWith(fontSize: 15),
              ),
            ),
            if (muted) ...[
              const SizedBox(width: 6),
              Icon(
                Icons.notifications_off_outlined,
                size: 14,
                color: AppColors.iconMuted,
              ),
            ],
          ],
        ),
        const SizedBox(height: 3),
        Text(
          snippet,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.caption.copyWith(
            color: unread > 0 ? AppColors.textDark : AppColors.textGrey,
          ),
        ),
      ],
    );
  }
}

class _TileMeta extends StatelessWidget {
  const _TileMeta({
    required this.lastMessageAt,
    required this.unread,
    required this.muted,
  });

  final DateTime? lastMessageAt;
  final int unread;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _ago(lastMessageAt),
          style: AppTextStyles.caption.copyWith(fontSize: 11),
        ),
        if (unread > 0) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: muted ? AppColors.iconMuted : AppColors.primary,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              unread > 9 ? '9+' : '$unread',
              style: AppTextStyles.caption.copyWith(
                fontSize: 10.5,
                color: AppColors.onAccent,
                fontWeight: FontWeight.w700,
                fontVariations: const [FontVariation('wght', 700)],
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _ago(DateTime? dt) {
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
      width: 52,
      height: 52,
      child: Stack(
        children: [
          Container(
            width: 52,
            height: 52,
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
                style: AppTextStyles.avatarInitial(20),
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