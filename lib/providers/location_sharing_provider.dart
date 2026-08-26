import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/location_sharing_model.dart';
import '../data/models/message_model.dart';
import '../data/repositories/location_sharing_repository.dart';
import 'chat_provider.dart';
import 'core_providers.dart';
import 'profile_provider.dart';

/// Who can see me on the Explore map.
///
/// ## One source of truth, on purpose
///
/// The setting arrives on the self-view, so the first read is free — this
/// seeds from [meProvider] rather than spending a request to learn something
/// the app already has. From then on **this notifier is the truth** and
/// `meProvider`'s copy is left to go stale.
///
/// That is a deliberate trade. Keeping the two in step would mean invalidating
/// `meProvider` after every toggle, and half the app hangs off it: the
/// location anchor re-reads GPS, which may re-anchor the account, which
/// reloads Explore. Flipping a privacy switch should not set that in motion.
/// So the setting has exactly one owner, every screen that shows it watches
/// this, and nothing else in the app reads `me.locationSharing` after boot.
///
/// ## What it does not do
///
/// It does not refresh Explore. This setting decides who sees *me*; it has no
/// bearing on who I see. Refreshing the map after changing it would be a
/// request that could only ever return the same people.
class LocationSharingNotifier extends AsyncNotifier<LocationSharing> {
  @override
  Future<LocationSharing> build() async {
    final me = await ref.watch(meProvider.future);
    return me.locationSharing;
  }

  /// Re-read the setting from the server, quietly.
  ///
  /// The seed above comes from a self-view the server caches for minutes, so a
  /// change made on another device — or before that cache last turned over —
  /// can be stale by the time the settings screen opens, which is the one
  /// moment somebody is looking straight at the answer.
  ///
  /// Failures are swallowed on purpose, and nothing is put into a loading
  /// state. What is on screen is still the last setting this device saw and is
  /// almost certainly right; replacing it with a spinner or an error would
  /// make a working screen look broken over a request nobody asked for.
  Future<void> reload() async {
    try {
      state = AsyncData(
        await ref.read(locationSharingRepositoryProvider).get(),
      );
    } catch (_) {
      // Keep what we have.
    }
  }

  /// The master switch. Off is "don't share with anyone"; the audience
  /// underneath is left alone so switching back on restores it.
  Future<void> setEnabled(bool enabled) => _write(
        _current.copyWith(enabled: enabled),
        (repo) => repo.update(enabled: enabled),
      );

  /// Choose an audience. Turning sharing back on in the same step, because
  /// picking who can see you is not something you do while hidden — the
  /// alternative is a screen where tapping "All friends" appears to do
  /// nothing.
  Future<void> setAudience(LocationAudience audience) => _write(
        _current.copyWith(enabled: true, audience: audience),
        (repo) => repo.update(enabled: true, audience: audience),
      );

  /// Replace the named-friends list. Implies the `selected` audience: this is
  /// only reachable from the picker, and arriving back at a list nobody is
  /// reading would be its own bug.
  Future<void> setAllowedFriends(List<String> userIds) => _write(
        _current.copyWith(
          enabled: true,
          audience: LocationAudience.selected,
          allowedUserIds: userIds,
        ),
        (repo) => repo.update(
          enabled: true,
          audience: LocationAudience.selected,
          allowedUserIds: userIds,
        ),
      );

  LocationSharing get _current => state.valueOrNull ?? LocationSharing.initial;

  /// Show the new setting at once, then let the server's answer stand as the
  /// final word — and put the old one back if it refuses.
  ///
  /// Optimism is right for this control: it is a switch, the person is looking
  /// straight at it, and a toggle that lags a round-trip feels broken. The
  /// rollback is what makes it honest — a failed write must never leave
  /// somebody believing they are hidden when they are not.
  Future<void> _write(
    LocationSharing optimistic,
    Future<LocationSharing> Function(LocationSharingRepository repo) request,
  ) async {
    final previous = state;
    state = AsyncData(optimistic);
    try {
      state = AsyncData(
        await request(ref.read(locationSharingRepositoryProvider)),
      );
    } catch (_) {
      state = previous;
      rethrow;
    }
  }
}

final locationSharingProvider =
    AsyncNotifierProvider<LocationSharingNotifier, LocationSharing>(
  LocationSharingNotifier.new,
);

/// The people the picker can offer: everybody I am vibing with.
///
/// Drawn from the inbox rather than a "friends" endpoint because there isn't
/// one — a friendship in this product *is* a conversation that got past the
/// opener, so the Vibing tab is the list. Deactivated accounts are dropped:
/// naming somebody who can no longer appear on a map is a row that can only
/// confuse.
///
/// Sorted by name, not by recency. This is a list to *find* somebody in, and a
/// picker that reorders itself between visits is one where the person you
/// ticked last time has moved.
final sharingFriendsProvider = Provider<AsyncValue<List<ChatOtherUser>>>((ref) {
  return ref.watch(conversationsProvider('vibing')).whenData((conversations) {
    final friends = [
      for (final conversation in conversations)
        if (!conversation.otherUser.isDeactivated) conversation.otherUser,
    ]..sort(
        (a, b) => (a.displayName ?? '').toLowerCase().compareTo(
              (b.displayName ?? '').toLowerCase(),
            ),
      );
    return friends;
  });
});
