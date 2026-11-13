import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/map_user_model.dart';
import '../../common/widgets/widgets.dart';
import 'explore_avatar.dart';
import 'package:dating_app/core/constants/app_string.dart';


/// Everyone on the map as a searchable grid, opened from the strip.
///
/// Shown as a sheet instead of a route so the map underneath is never rebuilt.
/// Picking someone selects them and closes the sheet.
class ExplorePeopleGrid extends StatefulWidget {
  const ExplorePeopleGrid({
    super.key,
    required this.people,
    required this.selectedId,
    required this.onSelect,
    required this.onShowAll,
    required this.onClose,
  });

  final List<MapUser> people;
  final String? selectedId;
  final ValueChanged<MapUser> onSelect;

  /// The "All" tile: put everybody back on the map and close.
  final VoidCallback onShowAll;

  final VoidCallback onClose;

  @override
  State<ExplorePeopleGrid> createState() => _ExplorePeopleGridState();
}

class _ExplorePeopleGridState extends State<ExplorePeopleGrid> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// The "All" tile is hidden while searching because it ignores the query.
  bool get _showsAllTile => _query.trim().isEmpty;

  List<MapUser> get _visible {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return widget.people;
    return widget.people
        .where((p) => p.displayName.toLowerCase().contains(query))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final people = _visible;

    return Container(
      height: MediaQuery.sizeOf(context).height * kSheetHeightFraction,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            _header(),
            _searchField(),
            Flexible(
              child: people.isEmpty
                  ? _noMatches()
                  : GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                gridDelegate:
                const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 88,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.78,
                ),
                itemCount: people.length + (_showsAllTile ? 1 : 0),
                itemBuilder: (context, index) {
                  if (_showsAllTile && index == 0) {
                    return _AllTile(
                      active: widget.selectedId == null,
                      onTap: widget.onShowAll,
                    );
                  }
                  final person =
                  people[_showsAllTile ? index - 1 : index];
                  return _GridTile(
                    person: person,
                    selected: person.id == widget.selectedId,
                    onTap: () => widget.onSelect(person),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    final total = widget.people.length;
    final shown = _visible.length;
    final title =
    _query.trim().isEmpty ? 'All people ($total)' : '$shown of $total';

    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 6, 12, 2),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: AppString.exploreBackToMap,
            excludeSemantics: true,
            child: IconButton(
              onPressed: widget.onClose,
              icon: Icon(Icons.chevron_left, color: AppColors.textDark),
            ),
          ),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: AppTextStyles.title.copyWith(fontSize: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: TextField(
        controller: _search,
        onChanged: (value) => setState(() => _query = value),
        textInputAction: TextInputAction.search,
        style: AppTextStyles.body,
        decoration: InputDecoration(
          isDense: true,
          hintText: AppString.searchByName,
          hintStyle: AppTextStyles.body.copyWith(color: AppColors.textGrey),
          prefixIcon: Icon(Icons.search, size: 20, color: AppColors.iconMuted),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
            onPressed: () {
              _search.clear();
              setState(() => _query = '');
            },
            icon: Icon(
              Icons.close,
              size: 18,
              color: AppColors.iconMuted,
            ),
          ),
          filled: true,
          fillColor: AppColors.card,
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: AppColors.inputBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: AppColors.inputBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.blue, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _noMatches() => Padding(
    padding: const EdgeInsets.fromLTRB(24, 30, 24, 44),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.search_off, size: 34, color: AppColors.iconMuted),
        const SizedBox(height: 12),
        Text(
          'Nobody here by that name',
          style: AppTextStyles.bodyStrong,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          'Only the people currently on your map can be searched.',
          style: AppTextStyles.caption,
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}

/// Puts everybody back on the map.
class _AllTile extends StatelessWidget {
  const _AllTile({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: active,
      label: AppString.showEveryoneOnMap,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active ? AppColors.blue : AppColors.card,
                border: active
                    ? null
                    : Border.all(color: AppColors.inputBorder, width: 1.4),
              ),
              child: Icon(
                Icons.groups_outlined,
                size: 24,
                color: active ? AppColors.onImage : AppColors.primary,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'All',
              style: AppTextStyles.caption.copyWith(
                fontSize: 11,
                height: 1.2,
                color: active ? AppColors.primary : AppColors.textDark,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                fontVariations: [FontVariation('wght', active ? 700 : 500)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GridTile extends StatelessWidget {
  const _GridTile({
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
      label: 'Show ${person.displayName} on the map',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExploreAvatar(
              name: person.displayName,
              photoUrl: person.primaryPhotoUrl,
              size: 58,
              selected: selected,
              isOnline: person.isOnline,
            ),
            const SizedBox(height: 5),
            Text(
              person.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(
                fontSize: 11,
                height: 1.2,
                color: selected ? AppColors.primary : AppColors.textDark,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                fontVariations: [FontVariation('wght', selected ? 700 : 500)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}