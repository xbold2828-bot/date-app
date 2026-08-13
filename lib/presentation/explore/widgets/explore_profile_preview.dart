import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/utils/onboarding_maps.dart';
import '../../../data/models/map_user_model.dart';
import '../../../providers/match_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../providers/realtime_provider.dart';
import '../../common/widgets/widgets.dart';
import '../../home/screens/profile_detail_sheet.dart';

/// The card that rises when a marker is tapped.
///
/// Deliberately a *preview*, not a destination. Tapping a face on a map is a
/// glance, and replacing the map with a full-screen profile would throw away
/// the thing the person was in the middle of doing — so this is short, the map
/// keeps moving behind it, and "View profile" is the way through to the real
/// screen.
///
/// Neither action here is new machinery. Like goes through
/// [likeActionsProvider] and raises the existing celebration; View profile
/// opens the existing [ProfileDetailSheet].
class ExploreProfilePreview extends ConsumerStatefulWidget {
  const ExploreProfilePreview({
    super.key,
    required this.user,
    required this.onDismiss,
  });

  final MapUser user;
  final VoidCallback onDismiss;

  @override
  ConsumerState<ExploreProfilePreview> createState() =>
      _ExploreProfilePreviewState();
}

class _ExploreProfilePreviewState
    extends ConsumerState<ExploreProfilePreview> {
  bool _likeInFlight = false;

  /// Set only once this session's own tap has landed — the server's
  /// `hasLiked` is the truth, and this is the optimistic overlay over the gap
  /// between the tap and the response. Same shape as [ProfileDetailSheet],
  /// for the same reason: independent like state is how a profile ends up
  /// offering to like somebody the user already liked.
  bool? _likedOverride;

  bool get _liked =>
      _likedOverride ??
      ref.read(publicProfileProvider(widget.user.id)).valueOrNull?.hasLiked ??
      false;

  Future<void> _onLike() async {
    if (_likeInFlight || _liked) return;
    setState(() {
      _likeInFlight = true;
      _likedOverride = true;
    });

    try {
      final result =
          await ref.read(likeActionsProvider).react(widget.user.id, 'like');

      if (result.match != null) {
        // The celebration is full-screen and belongs to the app, not to a card
        // floating over a map.
        widget.onDismiss();
        ref.read(matchCelebrationProvider.notifier).show(result.match!);
        ref.invalidate(mutualLikesProvider);
      } else if (!result.alreadyReacted && mounted) {
        showRadiusToast(
          context,
          'You liked ${widget.user.displayName}',
          tone: ToastTone.success,
        );
      }

      ref.invalidate(publicProfileProvider(widget.user.id));
      ref.invalidate(likedYouProvider);
    } on AppException catch (e) {
      if (mounted) {
        setState(() => _likedOverride = null);
        showRadiusToast(context, e.message, tone: ToastTone.error);
      }
    } finally {
      if (mounted) setState(() => _likeInFlight = false);
    }
  }

  void _openProfile() {
    final user = widget.user;
    showRadiusSheet<void>(
      context: context,
      builder: (_) => ProfileDetailSheet(
        userId: user.id,
        // The face is already on screen; the seed keeps it there instead of
        // replacing it with a spinner.
        seed: ProfileSeed(
          name: user.displayName,
          age: user.age,
          photoUrl: user.primaryPhotoUrl,
          distanceBand: user.distanceBand,
          isOnline: user.isOnline,
          colorIndex: user.id.hashCode.abs(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    // Live presence beats whatever the map fetched, so a card opened on
    // somebody who just came online says so.
    final isOnline = ref.watch(presenceProvider)[user.id] ?? user.isOnline;
    final tagLabels = ref.watch(tagLabelsProvider).valueOrNull ?? const {};

    return Semantics(
      container: true,
      label: '${user.displayName} preview',
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.panel,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.inputBorder),
          boxShadow: [
            BoxShadow(
              color: AppColors.textDark.withValues(alpha: 0.16),
              blurRadius: 26,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PreviewPhoto(
                  url: user.primaryPhotoUrl,
                  name: user.displayName,
                  isOnline: isOnline,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _Summary(
                    user: user,
                    isOnline: isOnline,
                    tagLabels: tagLabels,
                  ),
                ),
                Semantics(
                  button: true,
                  label: 'Close preview',
                  excludeSemantics: true,
                  child: IconButton(
                    onPressed: widget.onDismiss,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(
                      Icons.close,
                      size: 20,
                      color: AppColors.iconMuted,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Semantics(
                    button: true,
                    label: _liked
                        ? 'Already liked ${user.displayName}'
                        : 'Like ${user.displayName}',
                    excludeSemantics: true,
                    child: RadiusButton(
                      label: _liked ? 'Liked' : 'Like',
                      icon: _liked ? Icons.favorite : Icons.favorite_border,
                      isLoading: _likeInFlight,
                      // Terminal, exactly as on the full profile: liking twice
                      // used to re-run the match engine and replay the
                      // celebration.
                      onPressed: _liked || _likeInFlight ? null : _onLike,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: Semantics(
                    button: true,
                    label: 'View ${user.displayName}',
                    excludeSemantics: true,
                    child: RadiusButton(
                      label: 'View profile',
                      kind: RadiusButtonKind.ghost,
                      onPressed: _openProfile,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewPhoto extends StatelessWidget {
  const _PreviewPhoto({
    required this.url,
    required this.name,
    required this.isOnline,
  });

  final String? url;
  final String name;
  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    const size = 78.0;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppMapColors.markerStart, AppMapColors.markerEnd],
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: url == null || url!.isEmpty
                ? Center(
                    child: Text(
                      name.isEmpty ? '?' : name[0].toUpperCase(),
                      style: AppTextStyles.avatarInitial(30),
                    ),
                  )
                : CachedNetworkImage(
                    imageUrl: url!,
                    fit: BoxFit.cover,
                    // The preview is 78 pt; a full-resolution portrait here
                    // would be decoded at ten times the size it is drawn at.
                    memCacheWidth: 300,
                    errorWidget: (_, _, _) => Center(
                      child: Text(
                        name.isEmpty ? '?' : name[0].toUpperCase(),
                        style: AppTextStyles.avatarInitial(30),
                      ),
                    ),
                  ),
          ),
          if (isOnline)
            Positioned(
              right: -3,
              bottom: -3,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: AppColors.ok,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.panel, width: 3),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.user,
    required this.isOnline,
    required this.tagLabels,
  });

  final MapUser user;
  final bool isOnline;
  final Map<String, String> tagLabels;

  @override
  Widget build(BuildContext context) {
    final title = user.age == null
        ? user.displayName
        : '${user.displayName}, ${user.age}';

    // Presence first because it is the reason to act now; then how far, which
    // is a band and never a distance.
    final meta = [
      if (isOnline) 'Active now',
      if (user.distanceBand.isNotEmpty) user.distanceBand,
    ].join(' · ');

    // Two at most. This is a card on top of a map, and a wall of chips here
    // pushes the buttons off the bottom of a small phone.
    final tags = user.personalityTags.take(2).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 2),
        Row(
          children: [
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.title.copyWith(fontSize: 19),
              ),
            ),
            if (user.isVerified) ...[
              const SizedBox(width: 6),
              const Icon(Icons.verified, size: 16, color: AppColors.gold),
            ],
          ],
        ),
        if (meta.isNotEmpty) ...[
          const SizedBox(height: 3),
          Row(
            children: [
              if (isOnline) ...[
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppColors.ok,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption,
                ),
              ),
            ],
          ),
        ],
        if (tags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final tag in tags)
                TagPill(label: tagLabels[tag] ?? humanizeSlug(tag)),
            ],
          ),
        ],
      ],
    );
  }
}
