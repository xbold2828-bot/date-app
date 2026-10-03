import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../common/widgets/radius_button.dart';
import '../../models/notification_model.dart';
import '../../viewmodel/providers/notification_provider/notification_provider.dart';
import '../../viewmodel/providers/notification_provider/notification_state.dart';

extension _LocalDateTime on DateTime? {
  DateTime? get orNullLocal => this?.toLocal();
}

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Fire after the first frame so we're not calling ref.read during build.
    // fetchInitial() itself now triggers the auto-mark-as-read once the
    // list successfully loads — nothing extra needed here.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationListNotifierProvider.notifier).fetchInitial();
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Trigger the next page a bit before hitting the very bottom.
    final threshold = _scrollController.position.maxScrollExtent - 200;
    if (_scrollController.position.pixels >= threshold) {
      ref.read(notificationListNotifierProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationListNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      // REMOVED: the manual "Mark all read" TextButton — the notifier now
      // marks everything read automatically right after a successful list
      // fetch (see notification_provider.dart), so a separate button here
      // would just be a redundant, confusing no-op most of the time.
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: Text('Notifications', style: AppTextStyles.title),
      ),
      body: _buildBody(state),
    );
  }

  Widget _buildBody(NotificationListState state) {
    if (state.isLoading) {
      return Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (state.error != null && !state.hasData) {
      return _ErrorView(
        message: state.error!,
        onRetry: () =>
            ref.read(notificationListNotifierProvider.notifier).fetchInitial(),
      );
    }

    if (!state.hasData) {
      return const _EmptyView();
    }

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.card,
      onRefresh: () =>
          ref.read(notificationListNotifierProvider.notifier).refresh(),
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 4, bottom: 24),
        // Each group renders as: 1 date header + N items, plus a trailing
        // loader row when a next page is being fetched.
        itemCount: state.groups.length + (state.isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= state.groups.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
            );
          }
          return _NotificationGroupSection(group: state.groups[index]);
        },
      ),
    );
  }
}

class _NotificationGroupSection extends StatelessWidget {
  const _NotificationGroupSection({required this.group});

  final NotificationGroup group;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
          child: Semantics(
            header: true,
            child: Text(
              // The server's "date" bucket is a UTC-derived value. Convert
              // to the device's local day before comparing against
              // "today"/"yesterday", or a notification created late at
              // night UTC can land under the wrong header on the user's
              // phone.
              _formatGroupDate(group.date.orNullLocal),
              style: AppTextStyles.label,
            ),
          ),
        ),
        ...group.items.map((item) => _NotificationTile(item: item)),
      ],
    );
  }

  String _formatGroupDate(DateTime? localDate) {
    if (localDate == null) return '';
    final now = DateTime.now(); // already local
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(localDate.year, localDate.month, localDate.day);
    final diff = today.difference(that).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat('MMMM d, yyyy').format(localDate);
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item});

  final NotificationItem item;

  @override
  Widget build(BuildContext context) {
    // Compute once and reuse, rather than calling .toLocal() inline only
    // in the trailing Text — keeps this tile's notion of "time" in one
    // place so nothing downstream accidentally reads the raw UTC value.
    final localTime = item.time.orNullLocal;

    final unread = !item.isRead;

    return Semantics(
      label: [
        if (unread) 'New',
        item.title,
        item.message,
        if (localTime != null) DateFormat('h:mm a').format(localTime),
      ].join('. '),
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TypeMark(type: item.type),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyStrong.copyWith(
                      fontSize: 15,
                      fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                      fontVariations: [
                        FontVariation('wght', unread ? 700 : 500),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMuted.copyWith(
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (localTime != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      DateFormat('h:mm a').format(localTime),
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 12,
                        color: unread ? AppColors.primaryInk : null,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                if (unread) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
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
}

/// What kind of notification this is, as one ink glyph on a quiet disc. One
/// colour for all of them: a list of nine hues read as a toy box, and the
/// title already says what happened.
class _TypeMark extends StatelessWidget {
  const _TypeMark({required this.type});

  final NotificationType type;

  @override
  Widget build(BuildContext context) {
    final icon = switch (type) {
      NotificationType.match => Icons.favorite_rounded,
      NotificationType.message => Icons.chat_bubble_outline_rounded,
      NotificationType.like => Icons.favorite_border_rounded,
      NotificationType.superLike => Icons.star_border_rounded,
      NotificationType.profileView => Icons.visibility_outlined,
      NotificationType.verification => Icons.verified_outlined,
      NotificationType.promo => Icons.local_offer_outlined,
      NotificationType.matchExpiring => Icons.hourglass_bottom_rounded,
      NotificationType.safety => Icons.shield_outlined,
      NotificationType.unknown => Icons.notifications_none_rounded,
    };
    // A mutual like is the one worth the accent.
    final accent = type == NotificationType.match;

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: accent ? AppColors.primaryTint : AppColors.card,
        shape: BoxShape.circle,
        border: Border.all(
          color: accent ? AppColors.primarySoft : AppColors.inputBorder,
        ),
      ),
      child: Icon(
        icon,
        size: 20,
        color: accent ? AppColors.primary : AppColors.textDark,
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Couldn't load your notifications",
              textAlign: TextAlign.center,
              style: AppTextStyles.title.copyWith(fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(fontSize: 13.5),
            ),
            const SizedBox(height: 20),
            RadiusButton(
              label: 'Try again',
              kind: RadiusButtonKind.ghost,
              expand: false,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_none_rounded,
              size: 34,
              color: AppColors.iconMuted,
            ),
            const SizedBox(height: 14),
            Text(
              'Nothing yet',
              textAlign: TextAlign.center,
              style: AppTextStyles.title.copyWith(fontSize: 18),
            ),
            const SizedBox(height: 6),
            Text(
              'Likes, mutual likes and messages show up here.',
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(fontSize: 13.5),
            ),
          ],
        ),
      ),
    );
  }
}
