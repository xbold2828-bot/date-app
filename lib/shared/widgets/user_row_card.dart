import 'package:dating_app/core/constants/app_text_styles.dart';
import 'package:dating_app/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import '../../presentation/common/widgets/profile_grid_card.dart';
import '../../presentation/common/widgets/radius_surfaces.dart';

class UserRowCard extends StatelessWidget {
  const UserRowCard({
    super.key,
    required this.name,
    required this.colorIndex,
    required this.online,
    required this.onTap,
    this.photoUrl,
    this.age,
    this.subtitle,
    this.timeLabel,
    this.unread = 0,
    this.muted = false,
    this.trailing,
    this.onLongPress,
    this.semanticLabel,
    this.avatarSize = 44,
  });

  final String name;
  final int colorIndex;
  final bool online;
  final VoidCallback onTap;
  final String? photoUrl;
  final int? age;
  final String? subtitle;
  final String? timeLabel;
  final int unread;
  final bool muted;
  final Widget? trailing;
  final VoidCallback? onLongPress;
  final String? semanticLabel;
  final double avatarSize;

  @override
  Widget build(BuildContext context) {
    final hasUnread = unread > 0;
    final title = age != null ? '$name, $age' : name;

    return Semantics(
      button: true,
      label: semanticLabel ??
          [
            title,
            ?subtitle,
            if (hasUnread) '$unread unread',
            if (muted) 'muted',
            if (online) 'online now',
          ].join(', '),
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.deferToChild,
        onLongPress: onLongPress,
        child: RadiusCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          onTap: onTap,
          child: Row(
            children: [
              _UserAvatar(
                name: name,
                photoUrl: photoUrl,
                colorIndex: colorIndex,
                online: online,
                size: avatarSize,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodyStrong.copyWith(
                              fontSize: 14.5,
                            ),
                          ),
                        ),
                        if (timeLabel != null && timeLabel!.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Text(
                            timeLabel!,
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 11.5,
                              color: hasUnread && !muted
                                  ? AppColors.primary
                                  : AppColors.textGrey,
                              fontWeight:
                              hasUnread ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (subtitle != null || hasUnread || muted) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              subtitle ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.caption.copyWith(
                                fontSize: 12.5,
                                color: hasUnread
                                    ? AppColors.textDark
                                    : AppColors.textGrey,
                              ),
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
                          if (hasUnread) ...[
                            const SizedBox(width: 6),
                            _UnreadBadge(count: unread, muted: muted),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 4),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count, required this.muted});

  final int count;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: muted ? AppColors.iconMuted : AppColors.primary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: AppTextStyles.caption.copyWith(
          fontSize: 10.5,
          color: AppColors.onAccent,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  const _UserAvatar({
    required this.name,
    required this.colorIndex,
    required this.online,
    required this.size,
    this.photoUrl,
  });

  final String name;
  final String? photoUrl;
  final int colorIndex;
  final bool online;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Container(
            width: size,
            height: size,
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
                style: AppTextStyles.avatarInitial(size * 0.4),
              ),
            )
                : null,
          ),
          if (online)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: AppColors.ok,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.onImage, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}