/// Generic page wrapper for list endpoints that return
/// `{ items, total, page, limit }`. The backend doesn't send `hasMore`, so we
/// derive it.
class PageResult<T> {
  final List<T> items;
  final int page;
  final int limit;
  final int? total;

  const PageResult({
    required this.items,
    required this.page,
    required this.limit,
    this.total,
  });

  bool get hasMore =>
      total == null ? items.length >= limit : page * limit < total!;

  factory PageResult.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic> item) itemFromJson,
  ) {
    final rawItems = (json['items'] as List?) ?? const [];
    return PageResult<T>(
      items: rawItems
          .whereType<Map>()
          .map((e) => itemFromJson(Map<String, dynamic>.from(e)))
          .toList(),
      page: (json['page'] as num?)?.toInt() ?? 1,
      limit: (json['limit'] as num?)?.toInt() ?? rawItems.length,
      total: (json['total'] as num?)?.toInt(),
    );
  }

  PageResult<T> merge(PageResult<T> next) => PageResult<T>(
        items: [...items, ...next.items],
        page: next.page,
        limit: next.limit,
        total: next.total,
      );
}
