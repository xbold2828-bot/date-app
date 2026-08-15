/// A purchasable plan from `GET /subscription/plans`.
class PlanOption {
  final String plan;
  final String label;
  final double priceUsd;

  /// The rupee price, set on the server beside the dollar one.
  ///
  /// A *price*, not a conversion: the app never multiplies by an exchange rate,
  /// because it has no way to know whether the rate it was shipped with is
  /// still current. Zero when an older backend does not send it, which is the
  /// signal to show the dollar price alone rather than a made-up rupee figure.
  final double priceInr;

  final int durationDays;

  const PlanOption({
    required this.plan,
    required this.label,
    required this.priceUsd,
    this.priceInr = 0,
    required this.durationDays,
  });

  /// "$14.99" — the paywall's price line.
  String get priceLabel => '\$${priceUsd.toStringAsFixed(2)}';

  bool get hasInrPrice => priceInr > 0;

  /// "₹1,199". Whole rupees, grouped — nobody prices a subscription in paise.
  String get priceInrLabel {
    final digits = priceInr.round().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      // Indian grouping: the last three digits, then pairs (1,23,456).
      final fromEnd = digits.length - i;
      if (i > 0 && (fromEnd == 3 || (fromEnd > 3 && fromEnd.isOdd))) {
        buffer.write(',');
      }
      buffer.write(digits[i]);
    }
    return '₹$buffer';
  }

  factory PlanOption.fromJson(Map<String, dynamic> json) => PlanOption(
        plan: json['plan'] as String? ?? '',
        label: json['label'] as String? ?? '',
        priceUsd: (json['priceUsd'] as num?)?.toDouble() ?? 0,
        priceInr: (json['priceInr'] as num?)?.toDouble() ?? 0,
        durationDays: (json['durationDays'] as num?)?.toInt() ?? 0,
      );
}

/// The paywall payload: what you get and what it costs.
class PlanCatalogue {
  final List<String> perks;
  final List<PlanOption> plans;

  const PlanCatalogue({this.perks = const [], this.plans = const []});

  factory PlanCatalogue.fromJson(Map<String, dynamic> json) => PlanCatalogue(
        perks: (json['perks'] as List? ?? const [])
            .map((e) => e.toString())
            .toList(),
        plans: (json['plans'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => PlanOption.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

/// A subscription record as the API views it.
class SubscriptionView {
  final String id;
  final String plan;
  final String status;
  final String provider;
  final DateTime? currentPeriodEnd;
  final bool autoRenew;

  const SubscriptionView({
    required this.id,
    required this.plan,
    required this.status,
    required this.provider,
    this.currentPeriodEnd,
    this.autoRenew = true,
  });

  factory SubscriptionView.fromJson(Map<String, dynamic> json) =>
      SubscriptionView(
        id: json['id'] as String? ?? '',
        plan: json['plan'] as String? ?? '',
        status: json['status'] as String? ?? '',
        provider: json['provider'] as String? ?? '',
        currentPeriodEnd:
            DateTime.tryParse(json['currentPeriodEnd'] as String? ?? ''),
        autoRenew: json['autoRenew'] as bool? ?? true,
      );
}

/// `GET /subscription/me`.
class MySubscription {
  final bool isPremium;
  final SubscriptionView? subscription;

  const MySubscription({required this.isPremium, this.subscription});

  factory MySubscription.fromJson(Map<String, dynamic> json) => MySubscription(
        isPremium: json['isPremium'] as bool? ?? false,
        subscription: json['subscription'] == null
            ? null
            : SubscriptionView.fromJson(
                Map<String, dynamic>.from(json['subscription'] as Map),
              ),
      );
}

/// `POST /subscription/checkout`.
///
/// [checkoutUrl] is null when the provider confirmed inline (the sandbox
/// provider always does) — meaning premium is already active on return.
class CheckoutResult {
  final String? checkoutUrl;
  final SubscriptionView subscription;

  const CheckoutResult({this.checkoutUrl, required this.subscription});

  bool get isConfirmed => checkoutUrl == null;

  factory CheckoutResult.fromJson(Map<String, dynamic> json) => CheckoutResult(
        checkoutUrl: json['checkoutUrl'] as String?,
        subscription: SubscriptionView.fromJson(
          Map<String, dynamic>.from(json['subscription'] as Map? ?? const {}),
        ),
      );
}
