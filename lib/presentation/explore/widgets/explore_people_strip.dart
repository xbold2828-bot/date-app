import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/map_user_model.dart';
import 'explore_avatar.dart';

/// The row of faces above the map.
///
/// Two jobs. It is the fast way to pick somebody without hunting for their
/// marker, and it is the answer to "who is even out there" for a user who has
/// not panned around yet — a map of unfamiliar streets does not tell you that.
///
/// "All" leads the row and opens the grid — everybody at once, and where the
/// map gets repopulated from. When somebody *is* selected they move to the
/// front and "All" takes second place, so the current subject is always the
/// first thing under the thumb and the way onwards is always the second.
class ExplorePeopleStrip extends StatelessWidget {
  const ExplorePeopleStrip({
    super.key,
    required this.people,
    required this.selectedId,
    required this.onSelect,
    required this.onShowAll,
  });

  final List<MapUser> people;
  final String? selectedId;
  final ValueChanged<MapUser> onSelect;

  /// Opens the grid of everybody. Both the leading "All" tile and the
  /// trailing "See all" tile go here — the grid is where the map is repopulated
  /// from, via its own "All" tile.
  final VoidCallback onShowAll;

  /// Past this many, scrolling to find a particular face stops being
  /// reasonable and the grid is the better tool. The strip still scrolls; this
  /// only decides whether the "See all" tile is offered at the end of it.
  static const int gridThreshold = 8;

  static const double height = 82;

  @override
  Widget build(BuildContext context) {
    // Nothing to pick from. An empty 82 px band above the map reads as a row
    // that failed to load; the empty-state card on the map says what is
    // actually going on.
    if (people.isEmpty) return const SizedBox.shrink();

    // Selected first, then everyone else in the order the API ranked them
    // (nearest first) — a strip that reshuffled on every selection would make
    // people hunt for a face they had just been looking at.
    final ordered = <MapUser>[
      ...people.where((person) => person.id == selectedId),
      ...people.where((person) => person.id != selectedId),
    ];
    final selectedLeads = selectedId != null && ordered.first.id == selectedId;

    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        // People, plus the "All" tile, plus "See all" when the row is long.
        itemCount: ordered.length +
            1 +
            (people.length > gridThreshold ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          // "All" leads, unless somebody is selected — then they do, and All
          // slides to second.
          final allIndex = selectedLeads ? 1 : 0;
          if (index == allIndex) {
            return _AllTile(active: selectedId == null, onTap: onShowAll);
          }

          final personIndex = index > allIndex ? index - 1 : index;
          if (personIndex >= ordered.length) {
            return _ShowAllTile(count: people.length, onTap: onShowAll);
          }

          final person = ordered[personIndex];
          return _PersonTile(
            person: person,
            selected: person.id == selectedId,
            onTap: () => onSelect(person),
          );
        },
      ),
    );
  }
}

class _PersonTile extends StatelessWidget {
  const _PersonTile({
    required this.person,
    required this.selected,
    required this.onTap,
  });

  final MapUser person;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: selected
          ? '${person.displayName}, selected. Open All to see everyone again.'
          : 'Show ${person.displayName} on the map',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 56,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExploreAvatar(
                name: person.displayName,
                photoUrl: person.primaryPhotoUrl,
                size: 50,
                selected: selected,
                isOnline: person.isOnline,
              ),
              const SizedBox(height: 4),
              Text(
                person.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTextStyles.caption.copyWith(
                  fontSize: 10.5,
                  height: 1.2,
                  color: selected ? AppColors.primary : AppColors.textGrey,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  fontVariations: [
                    FontVariation('wght', selected ? 700 : 500),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A round tile with an icon and a caption, matching a person's silhouette so
/// the row reads as one rhythm rather than controls bolted onto faces.
class _IconTile extends StatelessWidget {
  const _IconTile({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    required this.semanticLabel,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: active,
      label: semanticLabel,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 56,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: active
                      ? const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppMapColors.markerStart,
                            AppMapColors.markerEnd,
                          ],
                        )
                      : null,
                  color: active ? null : AppColors.card,
                  border: active
                      ? null
                      : Border.all(color: AppColors.inputBorder, width: 1.4),
                ),
                child: Icon(
                  icon,
                  size: 21,
                  color: active ? AppColors.onImage : AppColors.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(
                  fontSize: 10.5,
                  height: 1.2,
                  color: active ? AppColors.primary : AppColors.textGrey,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  fontVariations: [FontVariation('wght', active ? 700 : 500)],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AllTile extends StatelessWidget {
  const _AllTile({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _IconTile(
        icon: Icons.groups_outlined,
        label: 'All',
        active: active,
        onTap: onTap,
        semanticLabel: active
            ? 'Showing everyone on the map'
            : 'Show everyone on the map again',
      );
}

class _ShowAllTile extends StatelessWidget {
  const _ShowAllTile({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _IconTile(
        icon: Icons.grid_view_rounded,
        label: 'See all',
        active: false,
        onTap: onTap,
        semanticLabel: 'See all $count people in a grid',
      );
}
