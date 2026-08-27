import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/utils/distance_format.dart';
import '../../../core/utils/onboarding_maps.dart';
import '../../../core/utils/screen_guard.dart';
import '../../../data/models/profile_model.dart';
import '../../../providers/chat_provider.dart';
import '../../../providers/match_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../providers/realtime_provider.dart';
import '../../common/widgets/widgets.dart';
import '../widgets/message_limit_paywall.dart';

/// What the grid card already knows about this person.
///
/// The sheet opens on top of a card that has a name and a photo on screen
/// already; making the person watch a spinner to see them again would be a
/// step backwards. The seed paints immediately and the full profile fills in
/// underneath it.
class ProfileSeed {
  const ProfileSeed({
    required this.name,
    required this.colorIndex,
    this.age,
    this.photoUrl,
    this.distanceBand,
    this.isOnline = false,
  });

  final String name;
  final int colorIndex;
  final int? age;
  final String? photoUrl;
  final String? distanceBand;
  final bool isOnline;
}

/// The tap-through profile: every photo, every selection made during
/// onboarding, and the two things you can do about it — like, or open with a
/// message.
class ProfileDetailSheet extends ConsumerStatefulWidget {
  const ProfileDetailSheet({
    super.key,
    required this.userId,
    required this.seed,
  });

  final String userId;
  final ProfileSeed seed;

  @override
  ConsumerState<ProfileDetailSheet> createState() => _ProfileDetailSheetState();
}

/// Screenshots are blocked while this sheet is open — somebody else's photos
/// are theirs, and this is the only lever the platform gives us. Android only,
/// and a deterrent rather than a guarantee; see [ScreenGuard].
class _ProfileDetailSheetState extends ConsumerState<ProfileDetailSheet>
    with ScreenGuardMixin {
  final TextEditingController _openerController = TextEditingController();
  bool _isSending = false;
  bool _likeInFlight = false;

  /// Set only once this session's own tap has landed.
  ///
  /// The like state belongs to the server — `profile.hasLiked` — and this is
  /// nothing more than an optimistic overlay for the moment between the tap
  /// and the response. Keeping `_liked` as independent state is what caused
  /// the original bug: a fresh `false` on every open, contradicting a like the
  /// server already knew about.
  bool? _likedOverride;

  /// What the heart should show right now.
  bool get _liked =>
      _likedOverride ??
      ref.read(publicProfileProvider(widget.userId)).valueOrNull?.hasLiked ??
      false;

  @override
  void dispose() {
    _openerController.dispose();
    super.dispose();
  }

  String get _name =>
      ref.read(publicProfileProvider(widget.userId)).valueOrNull?.displayName ??
      widget.seed.name;

  Future<void> _sendOpener() async {
    final text = _openerController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    try {
      await ref.read(chatActionsProvider).open(widget.userId, text);
      _openerController.clear();
      if (mounted) Navigator.pop(context);
      // Raised after the pop, through the global messenger: the sheet's own
      // context is gone by now, and the confirmation belongs to the screen
      // underneath anyway.
      showRadiusToastGlobal('Message sent to $_name', tone: ToastTone.success);
    } on EntitlementRequiredException catch (gate) {
      // Out of free openers for today. The sheet stays open with the text
      // intact behind the paywall, so accepting the offer means one tap back
      // to what they already wrote.
      if (mounted) showMessageLimitPaywall(context, gate: gate);
    } on AppException catch (e) {
      _toast(e.message, tone: ToastTone.error);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  /// Like this person. Once only.
  ///
  /// A like is terminal here: liking twice used to re-run the match engine and
  /// replay the celebration, so the control goes inert the moment it is on.
  /// The server refuses a duplicate anyway — this just stops the request being
  /// made at all.
  Future<void> _onLike() async {
    if (_likeInFlight || _liked) return;
    setState(() {
      _likeInFlight = true;
      // Flip first: the animation is the feedback, and making it wait on the
      // network would put the pop somewhere after the tap that caused it.
      _likedOverride = true;
    });

    try {
      final result =
          await ref.read(likeActionsProvider).react(widget.userId, 'like');

      // `match` is only ever set on the reaction that CREATED the match, so a
      // repeat cannot get here — which is what stops the celebration replaying.
      if (result.match != null) {
        // Close the sheet first — the celebration is fullscreen and belongs to
        // the app, not to this profile.
        if (mounted) Navigator.pop(context);
        ref.read(matchCelebrationProvider.notifier).show(result.match!);
        ref.invalidate(mutualLikesProvider);
      } else if (!result.alreadyReacted) {
        _toast('You liked $_name', tone: ToastTone.success);
      }

      // Re-read the profile so `hasLiked` becomes the source of truth again
      // and the override can stop mattering.
      ref.invalidate(publicProfileProvider(widget.userId));
      ref.invalidate(likedYouProvider);
    } on AppException catch (e) {
      // Put the heart back where the server says it is.
      if (mounted) setState(() => _likedOverride = null);
      _toast(e.message, tone: ToastTone.error);
    } finally {
      if (mounted) setState(() => _likeInFlight = false);
    }
  }

  void _toast(String message, {ToastTone tone = ToastTone.neutral}) {
    if (!mounted) return;
    showRadiusToast(context, message, tone: tone);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(publicProfileProvider(widget.userId));
    final profile = async.valueOrNull;

    // Live presence wins over whatever the feed said when it was fetched, so an
    // open profile lights up the moment the socket reports them online. This is
    // the seam a fuller real-time profile feed plugs into later: broaden the
    // payload, and the rest of this screen already reads from providers.
    final isOnline = ref.watch(presenceProvider)[widget.userId] ??
        profile?.isOnline ??
        widget.seed.isOnline;

    const radius = BorderRadius.vertical(top: Radius.circular(26));

    return Container(
      height: MediaQuery.sizeOf(context).height * kSheetHeightFraction,
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: radius,
      ),
      // Clipped so the photo can run all the way to the sheet's top edge and
      // still take its rounded corners. There was a grab handle up here on a
      // strip of panel; it cost 17px of empty page above every photo, and the
      // sheet is draggable and has a close button with or without it.
      child: ClipRRect(
        borderRadius: radius,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PhotoCarousel(
                      photos: _photos(profile),
                      fallbackInitial: _name,
                      colorIndex: widget.seed.colorIndex,
                      onClose: () => Navigator.pop(context),
                    ),
                    _Details(
                      profile: profile,
                      seed: widget.seed,
                      isOnline: isOnline,
                      failedToLoad: async.hasError,
                      onRetry: () =>
                          ref.invalidate(publicProfileProvider(widget.userId)),
                      tagLabels:
                          ref.watch(tagLabelsProvider).valueOrNull ?? const {},
                    ),
                  ],
                ),
              ),
            ),
            _ActionBar(
              controller: _openerController,
              isSending: _isSending,
              liked: _liked,
              isMatch: profile?.isMatch ?? false,
              // Terminal: once it is on, it stays on and stops accepting taps.
              likeEnabled: !_likeInFlight && !_liked,
              name: _name,
              onLike: _onLike,
              onSend: _sendOpener,
            ),
          ],
        ),
      ),
    );
  }

  /// Every approved photo, newest arrangement first. Falls back to the single
  /// photo the card already had while the profile loads, so the carousel never
  /// starts empty on someone who plainly has a picture.
  List<String> _photos(PublicProfile? profile) {
    if (profile != null && profile.photos.isNotEmpty) return profile.photos;
    final single = profile?.primaryPhotoUrl ?? widget.seed.photoUrl;
    return single == null ? const [] : [single];
  }
}

// ── Photos ───────────────────────────────────────────────────────────────────

/// The photo strip. Swipe, or tap either edge.
///
/// Dots only appear for an actual set: a single photo with a lone dot under it
/// looks like a carousel that failed to load the rest.
///
/// Presence is deliberately not here. There used to be an "Online now" pill in
/// the top-left corner, which said the same thing as the green dot six lines
/// below it and said it over the person's face.
class _PhotoCarousel extends StatefulWidget {
  const _PhotoCarousel({
    required this.photos,
    required this.fallbackInitial,
    required this.colorIndex,
    required this.onClose,
  });

  final List<String> photos;
  final String fallbackInitial;
  final int colorIndex;
  final VoidCallback onClose;

  @override
  State<_PhotoCarousel> createState() => _PhotoCarouselState();
}

class _PhotoCarouselState extends State<_PhotoCarousel> {
  final PageController _pages = PageController();
  int _index = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _step(int delta) {
    final next = _index + delta;
    if (next < 0 || next >= widget.photos.length) return;
    _pages.animateToPage(
      next,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  Widget get _placeholder => _Placeholder(
        initial: widget.fallbackInitial,
        colorIndex: widget.colorIndex,
      );

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.5;
    final count = widget.photos.length;

    return SizedBox(
      height: height,
      child: Stack(
        children: [
          Positioned.fill(
            child: count == 0
                ? _placeholder
                : PageView.builder(
                    controller: _pages,
                    itemCount: count,
                    onPageChanged: (i) => setState(() => _index = i),
                    // The gradient stands in while a photo loads as well as
                    // when it fails, so the strip never flashes empty mid-swipe.
                    itemBuilder: (_, i) => Image.network(
                      widget.photos[i],
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _placeholder,
                      loadingBuilder: (_, child, progress) =>
                          progress == null ? child : _placeholder,
                    ),
                  ),
          ),

          // Edge taps, for one-handed use. Behind the close button in the
          // stack, so they never swallow it.
          if (count > 1) ...[
            _TapZone(
              alignment: Alignment.centerLeft,
              label: 'Previous photo',
              onTap: () => _step(-1),
            ),
            _TapZone(
              alignment: Alignment.centerRight,
              label: 'Next photo',
              onTap: () => _step(1),
            ),
          ],

          if (count > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: 14,
              child: _Dots(count: count, active: _index),
            ),

          Positioned(
            top: 14,
            right: 14,
            child: Semantics(
              button: true,
              label: 'Close profile',
              excludeSemantics: true,
              child: GestureDetector(
                onTap: widget.onClose,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.38),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    size: 19,
                    color: AppColors.onImage,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TapZone extends StatelessWidget {
  const _TapZone({
    required this.alignment,
    required this.label,
    required this.onTap,
  });

  final Alignment alignment;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: onTap,
          child: FractionallySizedBox(
            widthFactor: 0.28,
            heightFactor: 1,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.active});

  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Photo ${active + 1} of $count',
      excludeSemantics: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == active ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: AppColors.onImage.withValues(alpha: i == active ? 1 : 0.5),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
        ],
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.initial, required this.colorIndex});

  final String initial;
  final int colorIndex;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(gradient: avatarGradient(colorIndex)),
      child: Center(
        child: Text(
          initial.isNotEmpty ? initial[0].toUpperCase() : '?',
          style: AppTextStyles.avatarInitial(76).copyWith(
            color: AppColors.onImage.withValues(alpha: 0.92),
          ),
        ),
      ),
    );
  }
}

// ── Details ──────────────────────────────────────────────────────────────────

/// Everything the person chose during onboarding, in the order it was asked.
class _Details extends StatelessWidget {
  const _Details({
    required this.profile,
    required this.seed,
    required this.isOnline,
    required this.failedToLoad,
    required this.onRetry,
    required this.tagLabels,
  });

  final PublicProfile? profile;
  final ProfileSeed seed;
  final bool isOnline;
  final bool failedToLoad;
  final VoidCallback onRetry;

  /// Curated slug → label. Empty while the catalogue loads, which is why every
  /// lookup falls through to [humanizeSlug] rather than waiting.
  final Map<String, String> tagLabels;

  String _tag(String slug) => tagLabels[slug] ?? humanizeSlug(slug);

  /// Slugs a loaded catalogue still recognises.
  ///
  /// A retired tag stays on a profile until that person next saves — and until
  /// the server's own sweep reaches them — and [humanizeSlug] would happily
  /// print the withdrawn word back onto the screen. Dropping them here means a
  /// vocabulary that was retired is retired everywhere at once.
  ///
  /// Only once the catalogue has arrived: while it is empty every slug is
  /// "unknown", and filtering then would blank out the whole profile.
  List<String> _tags(List<String> slugs) => tagLabels.isEmpty
      ? slugs.map(_tag).toList()
      : [for (final s in slugs) if (tagLabels.containsKey(s)) tagLabels[s]!];

  @override
  Widget build(BuildContext context) {
    final name = profile?.displayName ?? seed.name;
    final age = profile?.age ?? seed.age;

    // The opened profile is the one surface that says how far away somebody
    // actually is — "190 ft", not "<2 km". Falls back to the band while the
    // profile is still in flight (the seed only ever carried a band) and on a
    // profile with no location to measure from.
    final band = profile?.distanceBand ?? seed.distanceBand;
    final distance = formatDistanceAway(profile?.distanceMeters) ??
        (band != null && band.isNotEmpty ? '$band away' : null);

    final place = [
      if (distance != null) distance.toUpperCase(),
      if (profile?.city != null && profile!.city!.isNotEmpty) profile!.city!,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The same badge the owner sees on their own "Me" tab — verification
          // is a claim made to other people, so it is not gated on whose
          // profile this is. Only for people the backend actually marked
          // verified: a badge everyone gets is a badge that says nothing.
          NameWithTick(
            name: age != null
                ? '${name.toUpperCase()}, $age'
                : name.toUpperCase(),
            isVerified: profile?.isVerified ?? false,
            style: AppTextStyles.title,
            tickSize: 21,
            maxLines: 2,
          ),

          if (place.isNotEmpty) ...[
            const SizedBox(height: 7),
            Row(
              children: [
                // Presence, and the only place this profile states it: green
                // when they are here, muted when they are not. The pill that
                // used to sit on the photo said the same thing twice.
                Semantics(
                  label: isOnline ? 'Online now' : 'Offline',
                  child: Container(
                    width: isOnline ? 12 : 9,
                    height: isOnline ? 12 : 9,
                    decoration: BoxDecoration(
                      color: isOnline
                          ? AppColors.ok
                          : AppColors.iconMuted,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    place,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 11.5,
                      letterSpacing: 0.5,
                      fontWeight: FontWeight.w700,
                      fontVariations: const [FontVariation('wght', 700)],
                    ),
                  ),
                ),
              ],
            ),
          ],

          if (failedToLoad) ...[
            const SizedBox(height: 18),
            _CouldNotLoad(onRetry: onRetry),
          ],

          // Visits and likes used to sit here. They are somebody's popularity
          // scoreboard, and printing them on the profile you are deciding
          // about turns a person into a ranking — "4 visits" reads as a verdict
          // on them either way. They stay on the "Me" tab, where they are
          // yours to look at.

          if (profile?.bio != null && profile!.bio!.trim().isNotEmpty) ...[
            const SizedBox(height: 18),
            const SectionLabel('About'),
            Text(
              profile!.bio!,
              style: AppTextStyles.body.copyWith(height: 1.55),
            ),
          ],

          if (profile != null) ..._sections(profile!),

          // The profile is still in flight and the seed has nothing more to
          // show. Better than an abrupt stop under the photo.
          if (profile == null && !failedToLoad) ...[
            const SizedBox(height: 28),
            Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 2,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _sections(PublicProfile p) {
    final identity = [
      if (p.gender != null && p.gender!.isNotEmpty) genderLabel(p.gender!),
      ...p.pronouns.map(pronounLabel),
    ];

    return [
      if (p.intent.isNotEmpty)
        _Section(
          label: 'Here for',
          values: p.intent.map(intentLabel).toList(),
        ),

      if (identity.isNotEmpty)
        _Section(label: 'Identity', values: identity, tone: TagTone.neutral),

      if (p.relationshipStatus != null && p.relationshipStatus!.isNotEmpty)
        _Section(
          label: 'Situation',
          values: [relationshipStatusLabel(p.relationshipStatus!)],
          tone: TagTone.neutral,
        ),

      if (p.personalityTags.isNotEmpty)
        _Section(
          label: 'Interests & vibes',
          values: _tags(p.personalityTags),
        ),

      // Step 6's answers. `desiresLocked` is the server telling us the viewer
      // may not see them; it is off by default now that identity verification
      // is disabled, but the branch stays for when it returns.
      if (p.desiresLocked)
        const _LockedSection(
          label: 'Their vibe',
          message: 'Verify your identity to see more about them.',
        )
      else if (_tags(p.preferenceTags ?? const []).isNotEmpty)
        _Section(
          label: 'Their vibe',
          values: _tags(p.preferenceTags ?? const []),
        ),

      // Deliberately last, and deliberately quiet. These are boundaries, not
      // selling points, and the owner chose to publish them.
      if ((p.hardNos ?? const []).isNotEmpty)
        _Section(
          label: 'Hard no’s',
          values: _tags(p.hardNos!),
          tone: TagTone.neutral,
        ),
    ];
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.label,
    required this.values,
    this.tone = TagTone.accent,
  });

  final String label;
  final List<String> values;
  final TagTone tone;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(label),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final value in values) TagPill(label: value, tone: tone),
          ],
        ),
      ],
    );
  }
}

class _LockedSection extends StatelessWidget {
  const _LockedSection({required this.label, required this.message});

  final String label;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(label),
        NoticeBox(text: message, icon: Icons.lock_outline),
      ],
    );
  }
}

class _CouldNotLoad extends StatelessWidget {
  const _CouldNotLoad({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            "Couldn't load the rest of this profile.",
            style: AppTextStyles.caption,
          ),
        ),
        TextButton(
          onPressed: onRetry,
          child: Text(
            'Retry',
            style: AppTextStyles.bodyStrong.copyWith(
              color: AppColors.primary,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Actions ──────────────────────────────────────────────────────────────────

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.controller,
    required this.isSending,
    required this.liked,
    required this.isMatch,
    required this.likeEnabled,
    required this.name,
    required this.onLike,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool isSending;
  final bool liked;
  final bool isMatch;
  final bool likeEnabled;
  final String name;
  final VoidCallback onLike;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        16 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border(
          top: BorderSide(color: AppColors.inputBorder, width: 1),
        ),
      ),
      child: Row(
        children: [
          _LikeButton(
            liked: liked,
            isMatch: isMatch,
            name: name,
            onTap: likeEnabled ? onLike : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: AppColors.inputBorder),
              ),
              child: TextField(
                controller: controller,
                textInputAction: TextInputAction.send,
                style: AppTextStyles.body,
                decoration: InputDecoration(
                  hintText: 'Send an opener...',
                  hintStyle: AppTextStyles.body.copyWith(
                    color: AppColors.textGrey,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Semantics(
            button: true,
            label: 'Send opener',
            excludeSemantics: true,
            child: GestureDetector(
              onTap: isSending ? null : onSend,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: isSending
                    ? Padding(
                        padding: EdgeInsets.all(13),
                        child: CircularProgressIndicator(
                          color: AppColors.onAccent,
                          strokeWidth: 2,
                        ),
                      )
                    : Icon(
                        Icons.send,
                        color: AppColors.onAccent,
                        size: 20,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The like control.
///
/// Liking is the one thing on this screen with no page transition, no sheet and
/// no obvious result — the old button just sat there while a request went out.
/// So the button itself is the receipt: it swells, blooms an accent glow, and
/// settles filled. The whole thing is over in under half a second, and it runs
/// on tap rather than on the response, so the feedback lands with the finger.
class _LikeButton extends StatefulWidget {
  const _LikeButton({
    required this.liked,
    required this.isMatch,
    required this.name,
    required this.onTap,
  });

  final bool liked;

  /// They liked back. The heart earns its colour rather than just its fill.
  final bool isMatch;

  final String name;

  /// Null while a like is in flight, and permanently once liked — a like is
  /// terminal here, because repeating it re-ran the match engine.
  final VoidCallback? onTap;

  @override
  State<_LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<_LikeButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 460),
  );

  /// Overshoot and settle. A plain ease would read as the button resizing;
  /// passing 1.0 and coming back reads as a reaction.
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(begin: 1.0, end: 1.32)
          .chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 34,
    ),
    TweenSequenceItem(
      tween: Tween(begin: 1.32, end: 0.94)
          .chain(CurveTween(curve: Curves.easeInOutCubic)),
      weight: 30,
    ),
    TweenSequenceItem(
      tween: Tween(begin: 0.94, end: 1.0)
          .chain(CurveTween(curve: Curves.easeOutBack)),
      weight: 36,
    ),
  ]).animate(_controller);

  /// The glow: out fast, gone slowly. Peaks with the scale so they read as one
  /// gesture rather than two effects.
  late final Animation<double> _glow = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 34),
    TweenSequenceItem(
      tween: Tween(begin: 1.0, end: 0.0)
          .chain(CurveTween(curve: Curves.easeOut)),
      weight: 66,
    ),
  ]).animate(_controller);

  @override
  void didUpdateWidget(_LikeButton old) {
    super.didUpdateWidget(old);
    // Only when the like happens here, now. A profile that arrives already
    // liked renders filled and still — replaying the animation on every open
    // would celebrate something the person did days ago.
    if (widget.liked && !old.liked) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: widget.liked,
      enabled: widget.onTap != null,
      label: switch ((widget.liked, widget.isMatch)) {
        (true, true) => 'You matched with ${widget.name}',
        (true, false) => 'You liked ${widget.name}',
        _ => 'Like ${widget.name}',
      },
      excludeSemantics: true,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final glow = _glow.value;
            return Transform.scale(
              scale: _scale.value,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.liked
                      ? AppColors.primaryTint
                      : Colors.transparent,
                  border: Border.all(
                    color: widget.liked
                        ? AppColors.primary
                        : AppColors.inputBorder,
                    width: 1.5,
                  ),
                  boxShadow: glow == 0
                      ? null
                      : [
                          BoxShadow(
                            color: AppColors.primary
                                .withValues(alpha: 0.42 * glow),
                            blurRadius: 22 * glow,
                            spreadRadius: 5 * glow,
                          ),
                        ],
                ),
                child: Icon(
                  widget.liked ? Icons.favorite : Icons.favorite_border,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
