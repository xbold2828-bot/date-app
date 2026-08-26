/// When somebody was last around, in the fewest words that still mean
/// something.
///
/// ## What it refuses to say
///
/// Two things, both deliberate.
///
/// **It never prints a clock time or a date.** "Active at 23:04" and "Active on
/// 3 March" are a pattern of life: read a few times they say when somebody
/// wakes, works and sleeps. A relative age answers the only question a card is
/// actually asked — *is this person still around* — and stops there.
///
/// **It gives up rather than getting precise about the distant past.**
/// Everything past a month is "a while ago". Nobody decides anything
/// differently on "5 weeks" versus "9 weeks", and the number would only be an
/// invitation to compute a date.
///
/// Presence, when it is known, wins over all of it: somebody online right now
/// is not "3h ago", whatever the mirrored timestamp still says.
library;

/// Past this, everything reads the same: gone a while.
const Duration _tooOldToDate = Duration(days: 30);

/// "Online now" · "Just now" · "12m ago" · "3h ago" · "Yesterday" · "6d ago" ·
/// "2w ago" · "A while ago", or null when there is nothing to say.
///
/// [isOnline] short-circuits everything: it comes from the presence socket,
/// which knows sooner than the timestamp on the card ever will.
String? formatLastSeen(DateTime? lastActiveAt, {bool isOnline = false}) {
  if (isOnline) return 'Online now';
  if (lastActiveAt == null) return null;

  final elapsed = DateTime.now().difference(lastActiveAt.toLocal());

  // A clock skewed forward, or a heartbeat that landed a moment ago. Either
  // way "in 3 minutes" is not a thing to print.
  if (elapsed.isNegative) return 'Just now';

  if (elapsed.inMinutes < 1) return 'Just now';
  if (elapsed.inMinutes < 60) return '${elapsed.inMinutes}m ago';
  if (elapsed.inHours < 24) return '${elapsed.inHours}h ago';
  if (elapsed.inDays == 1) return 'Yesterday';
  if (elapsed.inDays < 7) return '${elapsed.inDays}d ago';
  if (elapsed < _tooOldToDate) return '${elapsed.inDays ~/ 7}w ago';
  return 'A while ago';
}
