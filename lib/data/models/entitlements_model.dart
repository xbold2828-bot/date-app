/// One feature's free daily allowance. `remaining == null` means unlimited
/// (premium).
class Allowance {
  final int limit;
  final int used;
  final int? remaining;

  const Allowance({required this.limit, required this.used, this.remaining});

  factory Allowance.fromJson(Map<String, dynamic> json) => Allowance(
        limit: (json['limit'] as num?)?.toInt() ?? 0,
        used: (json['used'] as num?)?.toInt() ?? 0,
        remaining: (json['remaining'] as num?)?.toInt(),
      );
}

/// `GET /entitlements/me` — premium status + credit balance + per-feature
/// free daily allowances. Drives the "Discovery Limit / credits left" UI.
class Entitlements {
  final bool isPremium;
  final int creditBalance;
  final Map<String, Allowance> allowances;

  const Entitlements({
    required this.isPremium,
    required this.creditBalance,
    required this.allowances,
  });

  Allowance? get nearby => allowances['nearby'];
  Allowance? get likes => allowances['likes'];
  Allowance? get conversations => allowances['conversations'];

  factory Entitlements.fromJson(Map<String, dynamic> json) {
    final raw = (json['allowances'] as Map?) ?? const {};
    return Entitlements(
      isPremium: json['isPremium'] as bool? ?? false,
      creditBalance: (json['creditBalance'] as num?)?.toInt() ?? 0,
      allowances: raw.map(
        (key, value) => MapEntry(
          key.toString(),
          Allowance.fromJson(Map<String, dynamic>.from(value as Map)),
        ),
      ),
    );
  }
}
