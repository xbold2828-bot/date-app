import '../../core/constants/api_constants.dart';
import '../models/discovery_user_model.dart';
import '../models/entitlements_model.dart';
import '../services/api_service.dart';

/// Discovery ("Near you") + entitlement snapshot.
class DiscoveryRepository {
  DiscoveryRepository(this._api);

  final ApiClient _api;

  /// `GET /discovery/nearby`. Throws [EntitlementRequiredException] (402) when
  /// out of free allowance + credits, or [BadRequestException] (400) when the
  /// user hasn't set a location. `verifiedOnly`/`onlineOnly` are premium-only
  /// (403 otherwise).
  Future<NearbyPage> nearby({
    int page = 1,
    int limit = 20,
    String? intent,
    String? band,
    bool? verifiedOnly,
    bool? onlineOnly,
  }) async {
    final query = <String, dynamic>{
      'page': page,
      'limit': limit,
      if (intent != null) 'intent': intent,
      if (band != null) 'band': band,
      if (verifiedOnly == true) 'verifiedOnly': true,
      if (onlineOnly == true) 'onlineOnly': true,
    };
    final data = await _api.get(ApiConstants.discoveryNearby, query: query);
    return NearbyPage.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// `GET /entitlements/me` — premium + credits + free daily allowances.
  Future<Entitlements> entitlements() async {
    final data = await _api.get(ApiConstants.entitlementsMe);
    return Entitlements.fromJson(Map<String, dynamic>.from(data as Map));
  }
}
