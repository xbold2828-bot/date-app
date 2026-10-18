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

/// The profile tab, laid out like Instagram's: username bar, avatar + stats,
/// name / bio, two flat buttons, "complete your profile" strip, then a
/// pinned Photos / About tab bar over an edge-to-edge grid.
///
/// Settings live behind the menu ([SettingsScreen]); editing lives behind
/// "Edit profile" ([EditProfileScreen]).
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
          child: YouTopBar(me: me, onAdd: _addPhoto, onMenu: _openSettings),
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
                  padding: const EdgeInsets.only(top: 1),
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

/// Instagram's "Complete your profile" strip: heading with "n of m
/// complete", then a row of small cards — icon, title, hint, flat button.
/// Gone once there is nothing left to do.
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
    if (photos == null) return const SizedBox(height: 8);

    final p = me.profile;
    final steps = <_TodoStep>[
      _TodoStep(
        done: photos >= _photoGoal,
        icon: Icons.add_photo_alternate_outlined,
        title: photos == 0
            ? 'Add photos'
            : 'Add ${_photoGoal - photos} more '
            '${_photoGoal - photos == 1 ? 'photo' : 'photos'}',
        hint: 'Show people who you are.',
        action: 'Add',
        onTap: onAddPhoto,
      ),
      _TodoStep(
        done: (p.bio ?? '').trim().isNotEmpty,
        icon: Icons.short_text_rounded,
        title: 'Write a bio',
        hint: 'Tell people about yourself.',
        action: 'Add',
        onTap: onWriteBio,
      ),
      _TodoStep(
        done: p.personalityTags.isNotEmpty,
        icon: Icons.local_offer_outlined,
        title: 'Pick your three words',
        hint: 'Describe your vibe.',
        action: 'Add',
        onTap: onPickVibes,
      ),
      _TodoStep(
        done: p.preferenceTags.isNotEmpty,
        icon: Icons.tune_rounded,
        title: 'Set your kind of night',
        hint: 'Share what you are into.',
        action: 'Set',
        onTap: onSetPreferences,
      ),
    ];
    final done = steps.where((s) => s.done).length;
    if (done == steps.length) return const SizedBox(height: 8);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  'Complete your profile',
                  style: AppTextStyles.bodyStrong.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    fontVariations: const [FontVariation('wght', 700)],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '$done of ${steps.length} complete',
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 12.5,
                    color: AppColors.textGrey,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final step in steps)
                    if (!step.done)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _TodoCard(step: step),
                      ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TodoStep {
  const _TodoStep({
    required this.done,
    required this.icon,
    required this.title,
    required this.hint,
    required this.action,
    required this.onTap,
  });

  final bool done;
  final IconData icon;
  final String title;
  final String hint;
  final String action;
  final VoidCallback onTap;
}

/// One "complete your profile" card: outlined icon circle, title, hint and a
/// flat solid action button.
class _TodoCard extends StatelessWidget {
  const _TodoCard({required this.step});

  final _TodoStep step;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${step.title}. ${step.hint}',
      excludeSemantics: true,
      child: Material(
        color: AppColors.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppColors.inputBorder, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: step.onTap,
          child: SizedBox(
            width: 150,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
              child: Column(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.inputBorder,
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      step.icon,
                      size: 24,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    step.title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyStrong.copyWith(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      fontVariations: const [FontVariation('wght', 700)],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    step.hint,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 12,
                      color: AppColors.textGrey,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      step.action,
                      style: AppTextStyles.bodyStrong.copyWith(
                        fontSize: 13.5,
                        color: AppColors.onAccent,
                        fontWeight: FontWeight.w700,
                        fontVariations: const [FontVariation('wght', 700)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The Photos / About switch, pinned under the header while the content
/// scrolls beneath it. Icon-only with a thin underline, as on Instagram.
class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  _TabBarDelegate({required this.selected, required this.onSelect});

  final _YouTab selected;
  final ValueChanged<_YouTab> onSelect;

  static const double _height = 44;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  bool shouldRebuild(_TabBarDelegate old) => old.selected != selected;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    // A pinned header has to paint its whole extent.
    return Container(
      height: _height,
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(
          bottom: BorderSide(color: AppColors.inputBorder, width: 0.5),
        ),
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
                  child: Container(height: 1, color: AppColors.textDark),
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'About you',
                  style: AppTextStyles.title.copyWith(fontSize: 17),
                ),
              ),
              TextButton(
                onPressed: onEdit,
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
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
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  title,
                  style: AppTextStyles.bodyStrong.copyWith(
                    fontSize: 13,
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
          const SizedBox(height: 4),
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
      fontSize: 14,
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