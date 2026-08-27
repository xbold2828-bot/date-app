/// The nightly window in which pushes arrive silently.
///
/// Minutes from local midnight, matching the backend's storage, so no parsing
/// happens on either side of the wire. The window wraps midnight whenever
/// [startMinute] > [endMinute] — which is the ordinary case, not the edge one.
class QuietHours {
  const QuietHours({
    this.enabled = false,
    this.startMinute = 22 * 60,
    this.endMinute = 8 * 60,
    this.timezone,
  });

  final bool enabled;
  final int startMinute;
  final int endMinute;

  /// IANA zone. Left null, the backend adopts whatever the newest registered
  /// device reported — which follows the user when they travel.
  final String? timezone;

  factory QuietHours.fromJson(Map<String, dynamic> json) => QuietHours(
        enabled: json['enabled'] as bool? ?? false,
        startMinute: (json['startMinute'] as num?)?.toInt() ?? 22 * 60,
        endMinute: (json['endMinute'] as num?)?.toInt() ?? 8 * 60,
        timezone: json['timezone'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'startMinute': startMinute,
        'endMinute': endMinute,
        if (timezone != null) 'timezone': timezone,
      };

  QuietHours copyWith({
    bool? enabled,
    int? startMinute,
    int? endMinute,
    String? timezone,
  }) =>
      QuietHours(
        enabled: enabled ?? this.enabled,
        startMinute: startMinute ?? this.startMinute,
        endMinute: endMinute ?? this.endMinute,
        timezone: timezone ?? this.timezone,
      );

  /// "22:00" — for the settings row.
  String get startLabel => _label(startMinute);
  String get endLabel => _label(endMinute);

  static String _label(int minutes) {
    final h = (minutes ~/ 60).toString().padLeft(2, '0');
    final m = (minutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }
}

/// What the user has chosen to be told about.
///
/// Every switch defaults to on. An account that has never opened settings has
/// not opted out of anything, and the backend returns these same defaults
/// rather than a 404 — so this model never has to represent "unknown".
class NotificationPreferences {
  const NotificationPreferences({
    this.messages = true,
    this.matches = true,
    this.likes = true,
    this.announcements = true,
    this.quietHours = const QuietHours(),
  });

  final bool messages;
  final bool matches;
  final bool likes;
  final bool announcements;
  final QuietHours quietHours;

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) =>
      NotificationPreferences(
        messages: json['messages'] as bool? ?? true,
        matches: json['matches'] as bool? ?? true,
        likes: json['likes'] as bool? ?? true,
        announcements: json['announcements'] as bool? ?? true,
        quietHours: json['quietHours'] is Map
            ? QuietHours.fromJson(
                Map<String, dynamic>.from(json['quietHours'] as Map),
              )
            : const QuietHours(),
      );

  NotificationPreferences copyWith({
    bool? messages,
    bool? matches,
    bool? likes,
    bool? announcements,
    QuietHours? quietHours,
  }) =>
      NotificationPreferences(
        messages: messages ?? this.messages,
        matches: matches ?? this.matches,
        likes: likes ?? this.likes,
        announcements: announcements ?? this.announcements,
        quietHours: quietHours ?? this.quietHours,
      );
}
