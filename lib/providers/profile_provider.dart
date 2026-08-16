import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/media_model.dart';
import '../data/models/profile_model.dart';
import '../data/models/tag_model.dart';
import '../data/models/user_model.dart';
import 'core_providers.dart';

/// The authenticated user's self-view. Also the sink for onboarding steps,
/// which each return an updated [MeUser] via [setMe].
class MeNotifier extends AsyncNotifier<MeUser> {
  @override
  Future<MeUser> build() => ref.watch(profileRepositoryProvider).me();

  Future<void> refresh() async {
    state = const AsyncLoading<MeUser>().copyWithPrevious(state);
    state = await AsyncValue.guard(
      () => ref.read(profileRepositoryProvider).me(),
    );
  }

  /// Replace with a fresh self-view returned by an onboarding step.
  void setMe(MeUser me) => state = AsyncData(me);

  Future<void> updateProfile({String? bio, List<String>? personalityTags}) async {
    final updated = await ref
        .read(profileRepositoryProvider)
        .updateProfile(bio: bio, personalityTags: personalityTags);
    state = AsyncData(updated);
  }
}

final meProvider = AsyncNotifierProvider<MeNotifier, MeUser>(MeNotifier.new);

/// Another user's tap-through profile.
final publicProfileProvider =
    FutureProvider.autoDispose.family<PublicProfile, String>(
  (ref, userId) => ref.watch(profileRepositoryProvider).profile(userId),
);

/// My visit and like counters.
///
/// Its own fetch rather than a field on [meProvider]: the self-view is cached
/// server-side for minutes at a time, and these are numbers people expect to
/// see move. Refreshing the "Me" tab re-reads them; nothing else needs to.
final myProfileStatsProvider = FutureProvider<ProfileStats>(
  (ref) => ref.watch(profileRepositoryProvider).myStats(),
);

/// Counts one visit to somebody's profile.
///
/// Fire-and-forget by design — see `ProfileRepository.recordView`. Callers must
/// not await this before opening the profile.
final recordProfileViewProvider = Provider<Future<void> Function(String)>(
  (ref) => (userId) => ref.read(profileRepositoryProvider).recordView(userId),
);

/// The tag catalogue, optionally filtered by category (null = all).
final tagCatalogProvider = FutureProvider.family<List<Tag>, String?>(
  (ref, category) =>
      ref.watch(onboardingRepositoryProvider).tags(category: category),
);

/// Curated tag slug → its display label, for rendering somebody else's
/// selections. Profiles arrive as slugs (`night_owl`); this is what turns them
/// back into the words the catalogue actually uses ("Night owl").
///
/// Deliberately NOT autoDispose: the catalogue is small, unchanging, and read
/// by every profile the user opens. One fetch serves the session. Callers should
/// fall back to `humanizeSlug` while it loads rather than block the profile on
/// a vocabulary lookup.
final tagLabelsProvider = FutureProvider<Map<String, String>>((ref) async {
  final all = await ref.watch(onboardingRepositoryProvider).tags();
  return {for (final tag in all) tag.slug: tag.label};
});

/// The whole catalogue in one fetch, grouped by category. One request serves
/// every chip section instead of one per category.
final tagsByCategoryProvider = FutureProvider<Map<String, List<Tag>>>((ref) async {
  final all = await ref.watch(onboardingRepositoryProvider).tags();
  final grouped = <String, List<Tag>>{};
  for (final tag in all) {
    grouped.putIfAbsent(tag.category, () => []).add(tag);
  }
  for (final list in grouped.values) {
    list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }
  return grouped;
});

/// My uploaded media (profile gallery).
final myMediaProvider = FutureProvider<List<MediaAsset>>(
  (ref) => ref.watch(mediaRepositoryProvider).listMine(),
);
