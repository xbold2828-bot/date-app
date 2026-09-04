import '../../core/constants/api_constants.dart';
import '../models/subscription_model.dart';
import '../services/api_service.dart';

/// Premium billing.
///
/// The backend's payment provider is pluggable; with the sandbox provider
/// `checkout` confirms instantly and returns a null `checkoutUrl` — no store
/// credentials, no charge. When a real provider is configured the same call
/// returns a URL to send the user to, which is why [CheckoutResult] carries it.
///
/// [verifyPurchase] is the store path: once `in_app_purchase` reports a
/// completed/restored transaction on-device, the receipt/token is sent here
/// so the backend can verify it server-to-server with Apple/Google before
/// flipping `premium` on the account. The on-device status alone is
/// spoofable, so nothing should trust it without this round trip.
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

  /// `POST /subscription/verify` — hand a StoreKit/Play Billing purchase to
  /// the backend for server-to-server verification.
  ///
  /// [plan] is the app's own plan id ('weekly'/'monthly'/'yearly'), resolved
  /// client-side from the store product id — sent along mainly for logging,
  /// since the backend should derive the plan itself from [productId] rather
  /// than trust the client's mapping.
  ///
  /// [receiptData] is the App Store receipt (base64) on iOS, or the Play
  /// purchase token on Android — `PurchaseDetails.verificationData
  /// .serverVerificationData` gives you the right one for the current
  /// platform either way, so this method doesn't need to branch on it.
  Future<MySubscription> verifyPurchase({
    required String? plan,
    required String productId,
    required String? transactionId,
    required String source, // 'app_store' | 'play_store'
    required String receiptData,
  }) async {
    final data = await _api.post(
      ApiConstants.subscriptionVerify,
      body: {
        'plan': plan,
        'productId': productId,
        'transactionId': transactionId,
        'source': source,
        'receiptData': receiptData,
      },
    );
    return MySubscription.fromJson(Map<String, dynamic>.from(data as Map));
  }
}