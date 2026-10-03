import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_text_styles.dart';
import '../../../core/extensions/global_back_extension.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/onboarding_maps.dart';
import '../../../data/models/user_model.dart';
import '../../../providers/chat_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../common/widgets/widgets.dart';
import '../widgets/live_location_line.dart';
import '../widgets/profile_edit_sheets.dart';
import '../widgets/you_gallery.dart';
import '../widgets/you_header.dart';
import 'edit_profile_screen.dart';
import 'settings_screen.dart';

enum _YouTab { photos, about }

/// The profile tab, laid out the way a profile is read on a phone: who you
/// are and your numbers at the top, two buttons, then your photos and your
/// details as tabs.
///
/// It used to be one long column of cards — location, metrics, gallery, vibe,
/// bio, details, verification, premium, dark mode, blocked accounts, sign out —
/// so the account's settings sat between you and your own photos. Settings now
/// live behind the menu ([SettingsScreen]); editing lives behind "Edit
/// profile" ([EditProfileScreen]).
class YouScreen extends ConsumerStatefulWidget {
  const YouScreen({super.key});

  @override
  ConsumerState<YouScreen> createState() => _YouScreenState();
}

class _YouScreenState extends ConsumerState<YouScreen> {
  _YouTab _tab = _YouTab.photos;
  final _gallery = GlobalKey<YouGalleryState>();

  Future<void> _onEditBio(String bio) async {
    final saved = await showEditBioSheet(context, bio);
    if (saved && mounted) {
      showRadiusToast(context, 'Bio updated', tone: ToastTone.success);
    }
  }

  Future<void> _onEditVibes(List<String> vibes) async {
    final saved = await showEditVibesSheet(context, vibes);
    if (saved && mounted) {
      showRadiusToast(context, 'Vibes updated', tone: ToastTone.success);
    }
  }

  void _openEdit() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const EditProfileScreen()),
  );

  void _openSettings() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const SettingsScreen()),
  );

  /// Adding a photo lives in the grid; from anywhere else, show the grid
  /// first and then ask it.
  void _addPhoto() {
    if (_tab != _YouTab.photos) setState(() => _tab = _YouTab.photos);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _gallery.currentState?.addPhoto(),
    );
  }

  void _selectTab(_YouTab tab) {
    if (tab != _tab) setState(() => _tab = tab);
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(meProvider).valueOrNull;

    if (me == null) {
      return Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    final stats = ref.watch(myProfileStatsProvider).valueOrNull;
    final friends = ref.watch(activeConversationCountProvider);
    final tagLabels = ref.watch(tagLabelsProvider).valueOrNull ?? const {};
    final media = ref.watch(myMediaProvider).valueOrNull;
    final photoCount = media?.where((m) => m.isPublicPhoto).length;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        SliverToBoxAdapter(
          child: YouTopBar(me: me, onMenu: _openSettings),
        ),
        SliverToBoxAdapter(
          child: YouProfileHeader(
            me: me,
            avatarUrl: _primaryPhotoUrl(me.primaryPhotoId),
            visits: stats?.profileViews,
            likes: stats?.likesReceived,
            friends: friends,
          ),
        ),
        SliverToBoxAdapter(
          child: YouIdentity(
            me: me,
            tagLabels: tagLabels,
            onWriteBio: () => _onEditBio(me.profile.bio ?? ''),
          ),
        ),
        SliverToBoxAdapter(
          child: YouActions(me: me, onEdit: _openEdit),
        ),
        SliverToBoxAdapter(
          child: _FinishProfile(
            me: me,
            photoCount: photoCount,
            onAddPhoto: _addPhoto,
            onWriteBio: () => _onEditBio(me.profile.bio ?? ''),
            onPickVibes: () => _onEditVibes(me.profile.personalityTags),
            onSetPreferences: _openEdit,
          ),
        ),
        SliverPersistentHeader(
          pinned: true,
          delegate: _TabBarDelegate(selected: _tab, onSelect: _selectTab),
        ),
        SliverToBoxAdapter(
          child: GestureDetector(
            // Swipe between the two tabs, as a profile's tabs always allow.
            onHorizontalDragEnd: (details) {
              final v = details.primaryVelocity ?? 0;
              if (v < -250) _selectTab(_YouTab.about);
              if (v > 250) _selectTab(_YouTab.photos);
            },
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              switchInCurve: const Cubic(0.23, 1, 0.32, 1),
              child: switch (_tab) {
                _YouTab.photos => Padding(
                  key: const ValueKey('you-photos'),
                  padding: const EdgeInsets.only(top: 2),
                  child: YouGallery(
                    key: _gallery,
                    primaryPhotoId: me.primaryPhotoId,
                  ),
                ),
                _YouTab.about => _AboutTab(
                  key: const ValueKey('you-about'),
                  me: me,
                  tagLabels: tagLabels,
                  onEdit: _openEdit,
                  onWriteBio: () => _onEditBio(me.profile.bio ?? ''),
                ),
              },
            ),
          ),
        ),
        // Clear of the floating tab bar and the banner ad under it.
        const SliverToBoxAdapter(child: SizedBox(height: 140)),
      ],
    ).withGlobalBackHandler(context);
  }

  String? _primaryPhotoUrl(String? primaryId) {
    if (primaryId == null) return null;
    final media = ref.watch(myMediaProvider).valueOrNull ?? const [];

    for (final asset in media) {
      if (asset.id == primaryId) return asset.url;
    }
    return null;
  }
}

/// What is still missing from the profile, as one line of progress and a row
/// of the actions that fix it. Gone once there is nothing left to do.
class _FinishProfile extends StatelessWidget {
  const _FinishProfile({
    required this.me,
    required this.photoCount,
    required this.onAddPhoto,
    required this.onWriteBio,
    required this.onPickVibes,
    required this.onSetPreferences,
  });

  final MeUser me;

  /// Null while the gallery is loading — the strip waits rather than nagging
  /// about photos it has not counted yet.
  final int? photoCount;
  final VoidCallback onAddPhoto;
  final VoidCallback onWriteBio;
  final VoidCallback onPickVibes;
  final VoidCallback onSetPreferences;

  static const _photoGoal = 3;

  @override
  Widget build(BuildContext context) {
    final photos = photoCount;
    if (photos == null) return const SizedBox(height: 18);

    final p = me.profile;
    final steps = <(bool, IconData, String, VoidCallback)>[
      (
        photos >= _photoGoal,
        Icons.add_photo_alternate_outlined,
        photos == 0
            ? 'Add photos'
            : 'Add ${_photoGoal - photos} more '
                  '${_photoGoal - photos == 1 ? 'photo' : 'photos'}',
        onAddPhoto,
      ),
      (
        (p.bio ?? '').trim().isNotEmpty,
        Icons.short_text_rounded,
        'Write a bio',
        onWriteBio,
      ),
      (
        p.personalityTags.isNotEmpty,
        Icons.local_offer_outlined,
        'Pick your three words',
        onPickVibes,
      ),
      (
        p.preferenceTags.isNotEmpty,
        Icons.tune_rounded,
        'Set your kind of night',
        onSetPreferences,
      ),
    ];
    final done = steps.where((s) => s.$1).length;
    if (done == steps.length) return const SizedBox(height: 18);

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 22, 0, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Finish your profile',
                    style: AppTextStyles.bodyStrong.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      fontVariations: const [FontVariation('wght', 700)],
                    ),
                  ),
                ),
                Text(
                  '$done of ${steps.length}',
                  style: AppTextStyles.caption.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _Progress(done: done, total: steps.length),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                for (final (isDone, icon, label, onTap) in steps)
                  if (!isDone)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _TodoChip(icon: icon, label: label, onTap: onTap),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// [done] of [total] as filled segments. Static: it is a status, not news.
class _Progress extends StatelessWidget {
  const _Progress({required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Row(
        children: [
          for (var i = 0; i < total; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: Container(
                height: 3.5,
                decoration: BoxDecoration(
                  color: i < done ? AppColors.primary : AppColors.inputBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TodoChip extends StatelessWidget {
  const _TodoChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: AppColors.card,
        shape: StadiumBorder(
          side: BorderSide(color: AppColors.inputBorder, width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 9, 14, 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 17, color: AppColors.primaryInk),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: AppTextStyles.bodyStrong.copyWith(fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The Photos / About switch, pinned under the header while the content
/// scrolls beneath it.
class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  _TabBarDelegate({required this.selected, required this.onSelect});

  final _YouTab selected;
  final ValueChanged<_YouTab> onSelect;

  static const double _height = 48;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  bool shouldRebuild(_TabBarDelegate old) => old.selected != selected;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    // A pinned header has to paint its whole extent; left to the icons'
    // own height it painted 24 of its 48 and the sliver refused it.
    return Container(
      height: _height,
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(bottom: BorderSide(color: AppColors.inputBorder)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _tab(_YouTab.photos, Icons.grid_on_rounded, 'Photos'),
          _tab(_YouTab.about, Icons.person_outline_rounded, 'About'),
        ],
      ),
    );
  }

  Widget _tab(_YouTab tab, IconData icon, String label) {
    final on = tab == selected;
    return Expanded(
      child: Semantics(
        button: true,
        selected: on,
        label: label,
        excludeSemantics: true,
        child: InkWell(
          onTap: () => onSelect(tab),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                icon,
                size: 24,
                color: on ? AppColors.textDark : AppColors.iconMuted,
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: AnimatedOpacity(
                  opacity: on ? 1 : 0,
                  duration: const Duration(milliseconds: 160),
                  child: Container(height: 2, color: AppColors.textDark),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Everything you said about yourself, read-only, in the order someone
/// opening your profile meets it.
class _AboutTab extends StatelessWidget {
  const _AboutTab({
    super.key,
    required this.me,
    required this.tagLabels,
    required this.onEdit,
    required this.onWriteBio,
  });

  final MeUser me;
  final Map<String, String> tagLabels;
  final VoidCallback onEdit;
  final VoidCallback onWriteBio;

  @override
  Widget build(BuildContext context) {
    final p = me.profile;
    String label(String slug) => tagLabels[slug] ?? humanizeSlug(slug);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'About you',
                  style: AppTextStyles.title.copyWith(fontSize: 19),
                ),
              ),
              TextButton(
                onPressed: onEdit,
                child: Text(
                  'Edit',
                  style: AppTextStyles.bodyStrong.copyWith(
                    color: AppColors.primaryInk,
                    fontWeight: FontWeight.w700,
                    fontVariations: const [FontVariation('wght', 700)],
                  ),
                ),
              ),
            ],
          ),
          _Fact(
            title: 'Here for',
            child: _Plain(
              p.intent.isEmpty ? null : p.intent.map(intentLabel).join(', '),
            ),
          ),
          _Fact(
            title: 'Situation',
            child: _Plain(
              p.relationshipStatus == null
                  ? null
                  : relationshipStatusLabel(p.relationshipStatus!),
            ),
          ),
          _Fact(
            title: 'In three words',
            child: _Pills([for (final v in p.personalityTags) label(v)]),
          ),
          _Fact(
            title: 'Your kind of night',
            note: 'Private until you match',
            child: _Pills([for (final t in p.preferenceTags) label(t)]),
          ),
          _Fact(
            title: "Hard no's",
            note: p.showHardNosOnProfile
                ? 'Shown on your profile'
                : 'Hidden from your profile',
            child: _Pills([for (final t in p.hardNos) label(t)]),
          ),
          _Fact(
            title: 'Where you are',
            child: LiveLocationLine(
              city: me.location?.city,
              anchorLatitude: me.location?.latitude,
              anchorLongitude: me.location?.longitude,
              alignment: CrossAxisAlignment.start,
            ),
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.title, required this.child, this.note});

  final String title;
  final String? note;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  title,
                  style: AppTextStyles.bodyStrong.copyWith(
                    fontSize: 13.5,
                    color: AppColors.textGrey,
                  ),
                ),
              ),
              if (note != null) ...[
                Text('  ·  ', style: AppTextStyles.caption),
                Flexible(
                  child: Text(
                    note!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 7),
          child,
        ],
      ),
    );
  }
}

class _Plain extends StatelessWidget {
  const _Plain(this.value);

  final String? value;

  @override
  Widget build(BuildContext context) => Text(
    value ?? 'Not set',
    style: AppTextStyles.body.copyWith(
      fontSize: 15,
      color: value == null ? AppColors.textGrey : AppColors.textDark,
    ),
  );
}

class _Pills extends StatelessWidget {
  const _Pills(this.labels);

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty) return const _Plain(null);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final l in labels) TagPill(label: l, tone: TagTone.neutral),
      ],
    );
  }
}
