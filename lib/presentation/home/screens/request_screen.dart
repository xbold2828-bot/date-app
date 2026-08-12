import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/message_model.dart';
import '../../../providers/chat_provider.dart';
import '../../../providers/realtime_provider.dart';
import '../../common/widgets/widgets.dart';
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
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 18, 20, 14),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Wordmark(size: 24),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppColors.inputBorder, width: 1),
            ),
          ),
          child: TabBar(
            controller: _tabController,
            indicatorSize: TabBarIndicatorSize.tab,
            tabs: const [
              Tab(text: 'Vibing'),
              Tab(text: 'New Energy'),
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
            backgroundColor: AppColors.white,
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
          backgroundColor: AppColors.white,
          onRefresh: () =>
              ref.read(conversationsProvider(state).notifier).refresh(),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, index) => _ConversationTile(
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

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conversation,
    required this.colorIndex,
    required this.online,
  });

  final ConversationSummary conversation;
  final int colorIndex;
  final bool online;

  @override
  Widget build(BuildContext context) {
    final other = conversation.otherUser;
    final name = other.displayName ?? 'Someone';
    final snippet = conversation.lastMessage?.snippet ?? 'Say hello';
    final unread = conversation.unread;

    return Semantics(
      button: true,
      label: [
        name,
        snippet,
        if (unread > 0) '$unread unread',
        if (online) 'online now',
      ].join(', '),
      excludeSemantics: true,
      child: RadiusCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatDetailScreen(
              conversationId: conversation.id,
              user: {
                'id': other.id,
                'name': name,
                'age': other.age,
                'distance': '',
                'online': online,
                'color': kAvatarGradients[
                    colorIndex % kAvatarGradients.length][0],
                'photoUrl': other.primaryPhotoUrl,
              },
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
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyStrong.copyWith(fontSize: 15),
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
            const SizedBox(width: 10),
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
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      unread > 9 ? '9+' : '$unread',
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 10.5,
                        color: AppColors.white,
                        fontWeight: FontWeight.w700,
                        fontVariations: const [FontVariation('wght', 700)],
                      ),
                    ),
                  ),
                ],
              ],
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
                  color: const Color(0xFF3BD07E),
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
          const RadarMark(size: 88, color: AppColors.iconMuted),
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
