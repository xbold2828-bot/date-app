import '../../core/constants/api_constants.dart';
import '../models/subscription_model.dart';
import '../services/api_service.dart';

/// Premium billing.
///
/// The backend's payment provider is pluggable; with the sandbox provider
/// `checkout` confirms instantly and returns a null `checkoutUrl` — no store
/// credentials, no charge. When a real provider is configured the same call
/// returns a URL to send the user to, which is why [CheckoutResult] carries it.
class SubscriptionRepository {
  SubscriptionRepository(this._api);

  final ApiClient _api;

  /// `GET /subscription/plans` — catalogue + advertised perks.
  Future<PlanCatalogue> plans() async {
    final data = await _api.get(ApiConstants.subscriptionPlans);
    return PlanCatalogue.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// `GET /subscription/me` — my premium status.
  Future<MySubscription> mine() async {
    final data = await _api.get(ApiConstants.subscriptionMe);
    return MySubscription.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// `POST /subscription/checkout` — buy a plan.
  Future<CheckoutResult> checkout(String plan) async {
    final data = await _api.post(
      ApiConstants.subscriptionCheckout,
      body: {'plan': plan},
    );
    return CheckoutResult.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// `POST /subscription/restore` — re-resolve the latest entitlement.
  Future<MySubscription> restore() async {
    final data = await _api.post(ApiConstants.subscriptionRestore);
    return MySubscription.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// `POST /subscription/cancel` — stop auto-renew (premium until period end).
  Future<MySubscription> cancel() async {
    final data = await _api.post(ApiConstants.subscriptionCancel);
    return MySubscription.fromJson(Map<String, dynamic>.from(data as Map));
  }
}
