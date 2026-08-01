/// A curated tag from `GET /tags` (personality / preference / hard-no vocab).
class Tag {
  final String slug;
  final String label;
  final String category;
  final String? group;
  final int sortOrder;
  final bool isSensitive;

  const Tag({
    required this.slug,
    required this.label,
    required this.category,
    this.group,
    this.sortOrder = 0,
    this.isSensitive = false,
  });

  factory Tag.fromJson(Map<String, dynamic> json) => Tag(
        slug: json['slug'] as String? ?? '',
        label: json['label'] as String? ?? '',
        category: json['category'] as String? ?? '',
        group: json['group'] as String?,
        sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
        isSensitive: json['isSensitive'] as bool? ?? false,
      );

  static List<Tag> listFrom(dynamic data) => (data as List? ?? const [])
      .whereType<Map>()
      .map((e) => Tag.fromJson(Map<String, dynamic>.from(e)))
      .toList();
}
