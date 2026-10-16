import 'package:dating_app/core/router/app_router.dart';
import 'package:dating_app/core/utils/app_loader.dart';
import 'package:dating_app/core/utils/utils.dart';
import 'package:dating_app/shared/widgets/user_row_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/extensions/global_back_extension.dart';
import '../../../core/theme/app_colors.dart';
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
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
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
// Conversation tile — now a thin wrapper over the shared UserRowCard.
// Used by Vibing, New Energy and Archived.
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
    final muted = conversation.muted;

    void openMenu() => showChatActionsMenu(
      context,
      conversationId: conversation.id,
      userId: other.id,
      userName: name,
      isArchived: isArchived,
      isMuted: muted,
    );

    return UserRowCard(
      name: name,
      photoUrl: other.primaryPhotoUrl,
      colorIndex: colorIndex,
      online: online,
      subtitle: conversation.lastMessage?.snippet ?? 'Say hello',
      timeLabel: _ago(conversation.lastMessageAt),
      unread: conversation.unread,
      muted: muted,
      onTap: () => _openChat(context, other, name),
      onLongPress: openMenu,
      trailing: _RowMenu(onTap: openMenu, userName: name),
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
  const _RowMenu({required this.onTap, required this.userName});

  final VoidCallback onTap;
  final String userName;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Options for $userName',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(Icons.more_vert, size: 18, color: AppColors.iconMuted),
        ),
      ),
    );
  }
}