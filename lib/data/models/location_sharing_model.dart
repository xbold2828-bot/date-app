/// Who can see me on the Explore map.
///
/// The setting is the answer to one question — *who gets to know where I am* —
/// and it has four answers, held here as a flag plus a three-value audience
/// rather than a four-value enum. That shape is deliberate and comes from the
/// server: switching sharing off has to preserve the audience underneath it,
/// so that switching back on restores the choice the person made instead of
/// dropping them somewhere they never picked.
///
/// It governs the **map pin only**. Radar still bands everyone by distance to
/// people browsing nearby — that is what the product is, it is never a
/// coordinate, and the settings screen says so out loud rather than letting
/// "no one" imply an invisibility it does not deliver.
library;

/// The audiences, widest first. Each is a superset of the one below it.
enum LocationAudience {
  /// Anyone with an open conversation — including New Energy, where somebody
  /// reached out and has not been answered yet. The only value that shows a
  /// pin to an unanswered sender.
  everyone('everyone'),

  /// People I am vibing with. A friendship in this product *is* a conversation
  /// both sides have spoken in, so this is "all my friends".
  friends('friends'),

  /// Only the friends I named.
  selected('selected');

  const LocationAudience(this.wire);

  /// The value the API speaks.
  final String wire;

  static LocationAudience parse(String? value) {
    for (final audience in LocationAudience.values) {
      if (audience.wire == value) return audience;
    }
    // Unknown, or absent: the server's default, and the behaviour the map had
    // before this setting existed.
    return LocationAudience.friends;
  }
}

class LocationSharing {
  const LocationSharing({
    this.enabled = true,
    this.audience = LocationAudience.friends,
    this.allowedUserIds = const [],
    this.updatedAt,
  });

  /// The master switch. False is "don't share with anyone" — the fourth
  /// option — and it wins over [audience] without discarding it.
  final bool enabled;

  final LocationAudience audience;

  /// The friends named under [LocationAudience.selected]. Kept whatever the
  /// audience is, so switching away and back does not lose a curated list.
  final List<String> allowedUserIds;

  final DateTime? updatedAt;

  /// The defaults, which are also what an account that predates the feature
  /// gets: shared, with friends.
  static const LocationSharing initial = LocationSharing();

  /// Is anybody at all being shown my pin? Note that "selected friends, nobody
  /// selected" is off in every way that matters, and says so.
  bool get isSharingWithAnyone =>
      enabled &&
      (audience != LocationAudience.selected || allowedUserIds.isNotEmpty);

  int get selectedCount => allowedUserIds.length;

  LocationSharing copyWith({
    bool? enabled,
    LocationAudience? audience,
    List<String>? allowedUserIds,
    DateTime? updatedAt,
  }) =>
      LocationSharing(
        enabled: enabled ?? this.enabled,
        audience: audience ?? this.audience,
        allowedUserIds: allowedUserIds ?? this.allowedUserIds,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  /// Adds or removes one friend from the named list.
  LocationSharing toggleFriend(String userId) {
    final next = [...allowedUserIds];
    if (!next.remove(userId)) next.add(userId);
    return copyWith(allowedUserIds: next);
  }

  factory LocationSharing.fromJson(Map<String, dynamic> json) =>
      LocationSharing(
        // Absent means an older server or an untouched account, and the
        // honest reading of both is the default — not "off". Claiming a
        // sharing user is hidden is the more damaging of the two errors: it
        // would tell somebody they are private while their friends still see
        // the pin.
        enabled: json['enabled'] as bool? ?? true,
        audience: LocationAudience.parse(json['audience'] as String?),
        allowedUserIds: ((json['allowedUserIds'] as List?) ?? const [])
            .whereType<String>()
            .toList(growable: false),
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
      );

  /// The PATCH body. Only what changed is sent — see the server DTO.
  Map<String, dynamic> toPatch({bool includeAllowed = true}) => {
        'enabled': enabled,
        'audience': audience.wire,
        if (includeAllowed) 'allowedUserIds': allowedUserIds,
      };
}
