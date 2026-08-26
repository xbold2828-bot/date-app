import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/message_model.dart';
import '../../../providers/chat_provider.dart';
import '../../../providers/realtime_provider.dart';
import '../../common/widgets/widgets.dart';
import '../widgets/chat_actions_menu.dart';
import './archived_chats_screen.dart';
import './chat_detail_screen.dart';

/// The inbox.
///
/// Two tabs, matching the backend's conversation states. **Vibing** is a
/// conversation that has been answered; **New Energy** is one where the
/// opener is still waiting for a reply. Keeping them apart is the point — it
/// stops unanswered openers burying live conversations.
class RequestsScreen extends ConsumerStatefulWidget {
  const RequestsScreen({super.key});

  @override
  ConsumerState<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends ConsumerState<RequestsScreen>
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
        Padding(
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
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ArchivedChatsScreen(),
                    ),
                  ),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: EdgeInsets.all(8),
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
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppColors.inputBorder, width: 1),
            ),
          ),
          child: TabBar(
            controller: _tabController,
            indicatorSize: TabBarIndicatorSize.tab,
            tabs: const [
              _CountedTab(label: 'Vibing', state: 'vibing'),
              _CountedTab(label: 'New Energy', state: 'new_energy'),
            ],
          ),
        ),
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
    );
  }
}

/// A tab that says how many people are behind it.
///
/// The two tabs are the whole navigation of this screen, and without a number
/// on them the only way to find out whether New Energy has anything in it is to
/// go and look. The count comes from the same list the tab opens, so it can
/// never disagree with what is underneath.
///
/// Nothing is drawn while the list is loading, and nothing is drawn at zero:
/// an empty tab already says "nothing here" with its own empty state, and a
/// grey "0" beside the label is just a worse way of saying it.
class _CountedTab extends ConsumerWidget {
  const _CountedTab({required this.label, required this.state});

  final String label;
  final String state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(conversationCountProvider(state));

    return Tab(
      child: Semantics(
        label: count == null || count == 0 ? label : '$label, $count people',
        excludeSemantics: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (count != null && count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6.5,
                  vertical: 1.5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryTint,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 11,
                    height: 1.25,
                    color: AppColors.primaryInk,
                    fontWeight: FontWeight.w700,
                    fontVariations: const [FontVariation('wght', 700)],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

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
      loading: () => Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
      error: (err, _) => _Empty(
        title: "Couldn't load conversations",
        body: 'Pull down to try again.',
      ),
      data: (items) {
        if (items.isEmpty) {
          return RefreshIndicator(
            color: AppColors.primary,
            backgroundColor: AppColors.card,
            onRefresh: () =>
                ref.read(conversationsProvider(state).notifier).refresh(),
            // A ListView so the empty state can still be pulled to refresh.
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [_Empty(title: emptyTitle, body: emptyBody)],
            ),
          );
        }

        return RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.card,
          onRefresh: () =>
              ref.read(conversationsProvider(state).notifier).refresh(),
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
      },
    );
  }
}

/// One row of the inbox. Public because the archive screen renders the same
/// row — an archived chat is the same conversation, just filed elsewhere.
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
        onTap: () => Navigator.push(
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
        ),
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
              child: Column(
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
                      // The one visible trace of a mute. Without it the row
                      // reads as an inbox that has quietly stopped working.
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
                      // An unread line reads as live; a read one recedes.
                      color: unread > 0
                          ? AppColors.textDark
                          : AppColors.textGrey,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _ago(conversation.lastMessageAt),
                  style: AppTextStyles.caption.copyWith(fontSize: 11),
                ),
                if (unread > 0) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      // A muted thread still counts its own messages — it just
                      // stops shouting about them.
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
            ),
            // Every action the thread itself offers, without having to open it.
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

  String _ago(DateTime? dt) {
    if (dt == null) return '';
    final d = DateTime.now().difference(dt.toLocal());
    if (d.inMinutes < 1) return 'now';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    return '${d.inDays}d';
  }
}

/// The three-dot menu on an inbox row.
///
/// Same sheet the thread's own header opens, so an action is never somewhere
/// people have to go looking for it — and there is only one implementation to
/// keep correct.
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
          // Generous, because this sits inside a row that is itself tappable —
          // a small target here means opening the chat by accident.
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Icon(Icons.more_vert, size: 19, color: AppColors.iconMuted),
        ),
      ),
    );
  }
}

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

class _Empty extends StatelessWidget {
  const _Empty({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 64, 32, 24),
      child: Column(
        children: [
          RadarMark(size: 88, color: AppColors.iconMuted),
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
