import 'discovery_user_model.dart';

/// A person as the Explore map needs them: the discovery card that already
/// exists, plus somewhere to draw it.
///
/// Deliberately a wrapper rather than a parallel model. Everything a marker or
/// its preview shows — name, age, photo, band, verified, online, tags — is
/// already on [DiscoveryCard], and duplicating those fields here would give the
/// app two definitions of "a person in discovery" that drift the first time one
/// of them gains a field.
///
/// ## The coordinates are not where this person is
///
/// [latitude] / [longitude] come from the backend's `mapPosition`, which is the
/// stored point pushed 350–900 m along a per-user-stable bearing and then
/// snapped to a ~500 m grid (see `DiscoveryService.generalizeMapPosition`).
/// Stable, so a marker does not jitter between refreshes; coarse, so a marker
/// is not an address. The client never sees a real coordinate for anyone else
/// and must never try to reconstruct one.
class MapUser {
  const MapUser({
    required this.card,
    required this.latitude,
    required this.longitude,
  });

  final DiscoveryCard card;

  /// Generalized map position — see the class comment. Not a GPS fix.
  final double latitude;
  final double longitude;

  String get id => card.id;
  String get displayName => card.displayName ?? 'Someone';
  int? get age => card.age;
  String get distanceBand => card.distanceBand;
  String? get primaryPhotoUrl => card.primaryPhotoUrl;
  bool get isOnline => card.isOnline;
  bool get isVerified => card.isVerified;
  List<String> get personalityTags => card.personalityTags;
  List<String> get intent => card.intent;

  /// Null when the payload carried no usable position — a person the map has
  /// to skip rather than draw at (0, 0) in the Gulf of Guinea.
  static MapUser? fromJson(Map<String, dynamic> json) {
    final position = json['mapPosition'];
    if (position is! Map) return null;

    final latitude = (position['latitude'] as num?)?.toDouble();
    final longitude = (position['longitude'] as num?)?.toDouble();
    if (latitude == null || longitude == null) return null;
    if (latitude.abs() > 90 || longitude.abs() > 180) return null;

    final card = DiscoveryCard.fromJson(json);
    if (card.id.isEmpty) return null;

    return MapUser(card: card, latitude: latitude, longitude: longitude);
  }
}

/// The `GET /discovery/explore` response.
///
/// One page, no pagination: the endpoint caps itself at 100 people, which is
/// more than a map can usefully draw and well past the point where clustering
/// takes over anyway.
class ExplorePage {
  const ExplorePage({this.city, this.items = const []});

  final String? city;
  final List<MapUser> items;

  factory ExplorePage.fromJson(Map<String, dynamic> json) => ExplorePage(
        city: json['city'] as String?,
        items: ((json['items'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => MapUser.fromJson(Map<String, dynamic>.from(e)))
            .whereType<MapUser>()
            .toList(growable: false),
      );
}
