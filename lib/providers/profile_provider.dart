import 'package:flutter_riverpod/flutter_riverpod.dart';

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

/// The tag catalogue, optionally filtered by category (null = all).
final tagCatalogProvider = FutureProvider.family<List<Tag>, String?>(
  (ref, category) =>
      ref.watch(onboardingRepositoryProvider).tags(category: category),
);
