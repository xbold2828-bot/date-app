import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/onboarding_maps.dart';
import '../../../data/models/user_model.dart';
import '../../../providers/location_sharing_provider.dart';
import '../../common/widgets/widgets.dart';

/// Instagram's top row: bold username on the left, "+" (add photo) and the
/// menu on the right. Dark mode, blocked accounts, sign out and the rest
/// live behind [onMenu].
class YouTopBar extends StatelessWidget {
  const YouTopBar({
    super.key,
    required this.me,
    required this.onMenu,
    this.onAdd,
  });

  final MeUser me;
  final VoidCallback onMenu;

  /// Adds a photo. Hidden when null.
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 4, 0),
      child: Row(
        children: [
          Expanded(
            child: NameWithTick(
              name: me.displayName ?? 'You',
              isVerified: me.verified,
              style: AppTextStyles.title.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
              tickSize: 16,
            ),
          ),
          if (onAdd != null)
            IconButton(
              onPressed: onAdd,
              visualDensity: VisualDensity.compact,
              tooltip: 'Add photo',
              icon: Icon(
                Icons.add_box_outlined,
                size: 26,
                color: AppColors.textDark,
              ),
            ),
          Semantics(
            button: true,
            label: 'Settings',
            excludeSemantics: true,
            child: IconButton(
              onPressed: onMenu,
              visualDensity: VisualDensity.compact,
              icon: Icon(
                Icons.menu_rounded,
                size: 26,
                color: AppColors.textDark,
              ),
              tooltip: 'Settings',
            ),
          ),
        ],
      ),
    );
  }
}

/// Photo on the left, the three numbers on the right.
class YouProfileHeader extends StatelessWidget {
  const YouProfileHeader({
    super.key,
    required this.me,
    required this.avatarUrl,
    required this.visits,
    required this.likes,
    required this.friends,
  });

  final MeUser me;
  final String? avatarUrl;

  /// Each null renders as a dash — "we could not load this" is not "zero".
  final int? visits;
  final int? likes;
  final int? friends;

  @override
  Widget build(BuildContext context) {
    final isPremium = me.premium.isActive;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Row(
        children: [
          PremiumAvatar(
            size: 86,
            isPremium: isPremium,
            isCurrentUser: true,
            ringColor: me.verified ? AppColors.ok : AppColors.inputBorder,
            child: avatarUrl != null
                ? CachedNetworkImage(
              imageUrl: avatarUrl!,
              fit: BoxFit.cover,
              placeholder: (_, _) =>
                  ColoredBox(color: AppColors.inputBorder),
              errorWidget: (_, _, _) => _Monogram(name: me.displayName),
            )
                : _Monogram(name: me.displayName),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Row(
              children: [
                _Stat(value: visits, label: 'Visits'),
                _Stat(value: likes, label: 'Likes'),
                _Stat(value: friends, label: 'Friends'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Initial on a flat colour — no gradient.
class _Monogram extends StatelessWidget {
  const _Monogram({this.name});

  final String? name;

  @override
  Widget build(BuildContext context) {
    final n = (name ?? '').trim();
    return ColoredBox(
      color: AppColors.primary,
      child: Center(
        child: n.isEmpty
            ? const Icon(Icons.person, size: 38, color: AppColors.onImage)
            : Text(n[0].toUpperCase(), style: AppTextStyles.avatarInitial(34)),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final int? value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final count = value;
    return Expanded(
      child: Semantics(
        label: count == null
            ? '$label unavailable'
            : '$count ${label.toLowerCase()}',
        excludeSemantics: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                count == null ? '—' : compactCount(count),
                maxLines: 1,
                style: AppTextStyles.stat(17).copyWith(
                  fontWeight: FontWeight.w700,
                  color: count == null
                      ? AppColors.textGrey
                      : AppColors.textDark,
                ),
              ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                fontSize: 13,
                color: AppColors.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Who you are in one bold line, then your bio and your three words.
class YouIdentity extends StatelessWidget {
  const YouIdentity({
    super.key,
    required this.me,
    required this.tagLabels,
    required this.onWriteBio,
  });

  final MeUser me;
  final Map<String, String> tagLabels;
  final VoidCallback onWriteBio;

  @override
  Widget build(BuildContext context) {
    final p = me.profile;
    final facts = [
      if (me.age != null) '${me.age}',
      if (p.intent.isNotEmpty) intentLabel(p.intent.first),
      if (p.relationshipStatus != null &&
          p.relationshipStatus != 'prefer_not_to_say')
        relationshipStatusLabel(p.relationshipStatus!),
      if ((me.location?.city ?? '').isNotEmpty) me.location!.city!,
    ];
    final bio = (p.bio ?? '').trim();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (facts.isNotEmpty)
            Text(
              facts.join(' · '),
              style: AppTextStyles.bodyStrong.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                fontVariations: const [FontVariation('wght', 700)],
              ),
            ),
          if (bio.isNotEmpty)
            Text(
              bio,
              style: AppTextStyles.body.copyWith(fontSize: 14, height: 1.3),
            )
          else
            Semantics(
              button: true,
              label: 'Write a bio',
              excludeSemantics: true,
              child: InkWell(
                onTap: onWriteBio,
                child: Text(
                  'Add a bio — say something worth replying to.',
                  style: AppTextStyles.body.copyWith(
                    fontSize: 14,
                    color: AppColors.primaryInk,
                  ),
                ),
              ),
            ),
          if (p.personalityTags.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final vibe in p.personalityTags)
                  TagPill(
                    label: tagLabels[vibe] ?? humanizeSlug(vibe),
                    tone: TagTone.neutral,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// The two buttons under the header: edit, and where you stand on the map.
/// Two equal flat grey buttons side by side.
class YouActions extends ConsumerWidget {
  const YouActions({super.key, required this.me, required this.onEdit});

  final MeUser me;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sharing =
        ref.watch(locationSharingProvider).valueOrNull ?? me.locationSharing;
    final on = sharing.isSharingWithAnyone;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: TonalButton(label: 'Edit profile', onTap: onEdit),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: TonalButton(
              label: on ? 'Location · On' : 'Location · Off',
              semanticLabel: _locationLabel(sharing),
              leading: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: on ? AppColors.ok : AppColors.iconMuted,
                ),
              ),
              onTap: () => context.push(AppRoutes.locationSharing),
            ),
          ),
        ],
      ),
    );
  }

  static String _locationLabel(LocationSharing s) => s.isSharingWithAnyone
      ? 'Live location is on. Choose who can see you'
      : 'Live location is off. Choose who can see you';
}

/// A flat, neutral button for secondary actions on the profile, sized like
/// Instagram's: 32 high, 8 radius, semi-bold 13.5 label.
class TonalButton extends StatelessWidget {
  const TonalButton({
    super.key,
    required this.label,
    required this.onTap,
    this.leading,
    this.semanticLabel,
  });

  final String label;
  final VoidCallback onTap;
  final Widget? leading;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel ?? label,
      excludeSemantics: true,
      child: Material(
        color: AppColors.inputBorder,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            constraints: const BoxConstraints(minHeight: 32),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 6)],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyStrong.copyWith(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      fontVariations: const [FontVariation('wght', 600)],
                    ),
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