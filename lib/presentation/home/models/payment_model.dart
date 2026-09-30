import '../../../core/utils/json_parse_utils.dart';

class PaymentPlanOption {
  const PaymentPlanOption({
    required this.plan,
    required this.label,
    required this.productId,
    required this.priceUsd,
    required this.priceInr,
    required this.durationDays,
  });

  final String plan;
  final String label;
  final String productId;
  final num priceUsd;
  final num priceInr;
  final int durationDays;

  factory PaymentPlanOption.fromJson(Map<String, dynamic> json) {
    return PaymentPlanOption(
      plan: json.safeString('plan'),
      label: json.safeString('label'),
      productId: json.safeString('productId'),
      priceUsd: json.safeNum('priceUsd'),
      priceInr: json.safeNum('priceInr'),
      durationDays: json.safeInt('durationDays'),
    );
  }

  String get priceUsdLabel => '\$${priceUsd.toStringAsFixed(2)}';
  String get priceInrLabel => '₹${priceInr.toStringAsFixed(0)}';
}

class PaymentsConfig {
  const PaymentsConfig({
    required this.appUserId,
    required this.entitlementId,
    required this.offeringId,
    required this.publicKeyIos,
    required this.publicKeyAndroid,
    required this.plans,
    required this.perks,
    required this.enabled,
  });

  final String appUserId;
  final String entitlementId;
  final String offeringId;
  final String publicKeyIos;
  final String publicKeyAndroid;
  final List<PaymentPlanOption> plans;
  final List<String> perks;
  final bool enabled;

  factory PaymentsConfig.fromJson(Map<String, dynamic> json) {
    final keys = json.safeObject('publicKeys');
    return PaymentsConfig(
      appUserId: json.safeString('appUserId'),
      entitlementId: json.safeString('entitlementId', fallback: 'premium'),
      offeringId: json.safeString('offeringId'),
      publicKeyIos: keys.safeString('ios'),
      publicKeyAndroid: keys.safeString('android'),
      plans: json.safeList<PaymentPlanOption>(
        'plans',
        itemParser: (item) =>
            PaymentPlanOption.fromJson(Map<String, dynamic>.from(item as Map)),
      ),
      perks: json.safeList<String>('perks'),
      enabled: json.safeBool('enabled', fallback: true),
    );
  }

  static const empty = PaymentsConfig(
    appUserId: '',
    entitlementId: 'premium',
    offeringId: '',
    publicKeyIos: '',
    publicKeyAndroid: '',
    plans: [],
    perks: [],
    enabled: false,
  );
}

class PaymentSubscriptionStatus {
  const PaymentSubscriptionStatus({
    required this.isPremium,
    required this.entitlement,
    required this.plan,
    required this.status,
    required this.productId,
    required this.startedAt,
    required this.expiresAt,
    required this.willRenew,
    required this.isTrial,
    required this.inGracePeriod,
    required this.source,
    required this.provider,
  });

  final bool isPremium;
  final String entitlement;
  final String? plan;
  final String status;
  final String? productId;
  final DateTime? startedAt;
  final DateTime? expiresAt;
  final bool willRenew;
  final bool isTrial;
  final bool inGracePeriod;
  final String? source;
  final String? provider;

  factory PaymentSubscriptionStatus.fromJson(Map<String, dynamic> json) {
    return PaymentSubscriptionStatus(
      isPremium: json.safeBool('isPremium'),
      entitlement: json.safeString('entitlement', fallback: 'premium'),
      plan: json.safeStringNullable('plan'),
      status: json.safeString('status', fallback: 'inactive'),
      productId: json.safeStringNullable('productId'),
      startedAt: _parseDate(json.safeStringNullable('startedAt')),
      expiresAt: _parseDate(json.safeStringNullable('expiresAt')),
      willRenew: json.safeBool('willRenew'),
      isTrial: json.safeBool('isTrial'),
      inGracePeriod: json.safeBool('inGracePeriod'),
      source: json.safeStringNullable('source'),
      provider: json.safeStringNullable('provider'),
    );
  }

  static DateTime? _parseDate(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  static const empty = PaymentSubscriptionStatus(
    isPremium: false,
    entitlement: 'premium',
    plan: null,
    status: 'inactive',
    productId: null,
    startedAt: null,
    expiresAt: null,
    willRenew: false,
    isTrial: false,
    inGracePeriod: false,
    source: null,
    provider: null,
  );
}

class PaymentHistoryEntry {
  const PaymentHistoryEntry({
    required this.id,
    required this.type,
    required this.plan,
    required this.productId,
    required this.store,
    required this.source,
    required this.transactionId,
    required this.occurredAt,
    required this.purchasedAt,
    required this.expiresAt,
    required this.price,
    required this.currency,
    required this.priceUsd,
    required this.periodType,
    required this.isTrial,
    required this.environment,
  });

  final String id;
  final String type;
  final String plan;
  final String productId;
  final String store;
  final String source;
  final String transactionId;
  final DateTime? occurredAt;
  final DateTime? purchasedAt;
  final DateTime? expiresAt;
  final num price;
  final String currency;
  final num priceUsd;
  final String periodType;
  final bool isTrial;
  final String environment;

  factory PaymentHistoryEntry.fromJson(Map<String, dynamic> json) {
    return PaymentHistoryEntry(
      id: json.safeString('id'),
      type: json.safeString('type'),
      plan: json.safeString('plan'),
      productId: json.safeString('productId'),
      store: json.safeString('store'),
      source: json.safeString('source'),
      transactionId: json.safeString('transactionId'),
      occurredAt: _parseDate(json.safeStringNullable('occurredAt')),
      purchasedAt: _parseDate(json.safeStringNullable('purchasedAt')),
      expiresAt: _parseDate(json.safeStringNullable('expiresAt')),
      price: json.safeNum('price'),
      currency: json.safeString('currency', fallback: 'USD'),
      priceUsd: json.safeNum('priceUsd'),
      periodType: json.safeString('periodType'),
      isTrial: json.safeBool('isTrial'),
      environment: json.safeString('environment'),
    );
  }

  static DateTime? _parseDate(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  static const _symbols = {'INR': '₹', 'USD': '\$'};

  String get amountLabel {
    final symbol = _symbols[currency];
    final amount = price % 1 == 0 ? price.toStringAsFixed(0) : price.toStringAsFixed(2);
    return symbol != null ? '$symbol$amount' : '$currency $amount';
  }

  String get typeLabel =>
      type.isEmpty ? '' : '${type[0]}${type.substring(1).toLowerCase()}';

  String get storeLabel => switch (store) {
    'PLAY_STORE' => 'Play Store',
    'APP_STORE' => 'App Store',
    _ => store,
  };
}

class PaymentHistoryPage {
  const PaymentHistoryPage({
    required this.payments,
    required this.currentPage,
    required this.perPage,
    required this.totalRecords,
    required this.totalPages,
  });

  final List<PaymentHistoryEntry> payments;
  final int currentPage;
  final int perPage;
  final int totalRecords;
  final int totalPages;

  bool get hasMore => currentPage < totalPages;

  factory PaymentHistoryPage.fromJson(Map<String, dynamic> json) {
    final pagination = json.safeObject('pagination');
    return PaymentHistoryPage(
      payments: json.safeList<PaymentHistoryEntry>(
        'payments',
        itemParser: (item) =>
            PaymentHistoryEntry.fromJson(Map<String, dynamic>.from(item as Map)),
      ),
      currentPage: pagination.safeInt('current_page', fallback: 1),
      perPage: pagination.safeInt('per_page', fallback: 20),
      totalRecords: pagination.safeInt('total_records'),
      totalPages: pagination.safeInt('total_pages', fallback: 1),
    );
  }

  static const empty = PaymentHistoryPage(
    payments: [],
    currentPage: 1,
    perPage: 20,
    totalRecords: 0,
    totalPages: 1,
  );
}

class PaymentManageInfo {
  const PaymentManageInfo({required this.managementUrl, required this.fallbackUrl});

  final String managementUrl;
  final String fallbackUrl;

  String get openUrl => managementUrl.isNotEmpty ? managementUrl : fallbackUrl;

  factory PaymentManageInfo.fromJson(Map<String, dynamic> json) {
    return PaymentManageInfo(
      managementUrl: json.safeString('managementUrl'),
      fallbackUrl: json.safeString('fallbackUrl'),
    );
  }

  static const empty = PaymentManageInfo(managementUrl: '', fallbackUrl: '');
}