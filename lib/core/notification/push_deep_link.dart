import 'package:flutter/foundation.dart';

import '../constants/api_constants.dart';

/// Where a tapped notification should take the user.
enum PushDestination {
  /// One chat thread. Carries [PushDeepLink.userId], and usually a
  /// conversationId.
  conversation,

  /// The Matches tab.
  matches,

  /// The "Liked you" tab.
  likes,

  /// Somebody's profile.
  profile,

  /// An external URL (announcements).
  url,
}

/// A tap on a notification, parsed into something the UI can act on.
class PushDeepLink {
  const PushDeepLink({
    required this.destination,
    this.conversationId,
    this.userId,
    this.url,
  });

  final PushDestination destination;
  final String? conversationId;
  final String? userId;
  final String? url;

  /// Reads an FCM `data` map, or null when there is nothing to navigate to.
  ///
  /// Tolerant by design. This map is written by a server that ships
  /// independently of the app in somebody's pocket, so an unknown action, a
  /// missing field or a renamed key must degrade to "open the app normally"
  /// rather than throw inside a tap handler — where the exception would be
  /// invisible and the tap would simply appear to do nothing.
  static PushDeepLink? fromData(Map<String, dynamic> data) {
    final action = data[PushDataKeys.action] as String?;

    switch (action) {
      case PushAction.openConversation:
        final userId = data[PushDataKeys.userId] as String?;
        // The thread is keyed on the other person, not the conversation: a
        // match can be opened before any conversation exists, and the chat
        // screen is built to start empty and adopt the one the first message
        // creates.
        if (userId == null || userId.isEmpty) return null;
        return PushDeepLink(
          destination: PushDestination.conversation,
          conversationId: data[PushDataKeys.conversationId] as String?,
          userId: userId,
        );

      case PushAction.openMatches:
        return const PushDeepLink(destination: PushDestination.matches);

      case PushAction.openLikes:
        return const PushDeepLink(destination: PushDestination.likes);

      case PushAction.openProfile:
        final userId = data[PushDataKeys.userId] as String?;
        if (userId == null || userId.isEmpty) return null;
        return PushDeepLink(
          destination: PushDestination.profile,
          userId: userId,
        );

      case PushAction.openUrl:
        final url = data[PushDataKeys.url] as String?;
        if (url == null || url.isEmpty) return null;
        return PushDeepLink(destination: PushDestination.url, url: url);

      default:
        // `none`, or an action from a newer server. Opening the app is the
        // right outcome, and that has already happened by the time we get here.
        return null;
    }
  }

  @override
  String toString() =>
      'PushDeepLink(${destination.name}, conversation=$conversationId, '
      'user=$userId, url=$url)';
}

/// The inbox for notification taps.
///
/// A plain [ValueNotifier] rather than a provider, because of *when* a tap
/// arrives: on a cold start it is delivered from `main()`, before any widget
/// tree exists and with no `WidgetRef` to reach for. Parking it here means the
/// tap survives until a screen is mounted and ready to act on it, instead of
/// being dropped because it was early — which is precisely the case that
/// matters, since a cold-start tap is somebody who opened the app *because* of
/// the notification.
///
/// [consume] is what makes it safe to hand to a `build`: the link is read once
/// and cleared, so a rebuild for any other reason cannot re-navigate.
abstract final class PushDeepLinks {
  static final ValueNotifier<PushDeepLink?> pending =
      ValueNotifier<PushDeepLink?>(null);

  /// Record a tap. Ignores anything that does not parse into a destination.
  static void receive(Map<String, dynamic> data) {
    final link = PushDeepLink.fromData(data);
    if (link == null) return;
    pending.value = link;
  }

  /// Take the pending link, if any, and clear it.
  static PushDeepLink? consume() {
    final link = pending.value;
    if (link != null) pending.value = null;
    return link;
  }
}
