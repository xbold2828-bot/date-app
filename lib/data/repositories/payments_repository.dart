import '../../core/constants/api_constants.dart';
import '../../presentation/home/models/payment_model.dart';
import '../services/api_service.dart';

class PaymentsRepository {
  PaymentsRepository(this._api);

  final ApiClient _api;

  Future<PaymentsConfig> config() async {
    final data = await _api.get(ApiConstants.paymentsConfig);
    return PaymentsConfig.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<PaymentSubscriptionStatus> subscription() async {
    final data = await _api.get(ApiConstants.paymentsSubscription);
    return PaymentSubscriptionStatus.fromJson(
      Map<String, dynamic>.from(data as Map),
    );
  }

  Future<PaymentSubscriptionStatus> sync() async {
    final data = await _api.post(ApiConstants.paymentsSync);
    return PaymentSubscriptionStatus.fromJson(
      Map<String, dynamic>.from(data as Map),
    );
  }

  Future<PaymentSubscriptionStatus> restore() async {
    final data = await _api.post(ApiConstants.paymentsRestore);
    return PaymentSubscriptionStatus.fromJson(
      Map<String, dynamic>.from(data as Map),
    );
  }

  Future<PaymentHistoryPage> history({int page = 1, int perPage = 20}) async {
    final data = await _api.get(
      ApiConstants.paymentsHistory,
      query: {'page': page, 'per_page': perPage},
    );
    return PaymentHistoryPage.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<PaymentManageInfo> manage() async {
    final data = await _api.get(ApiConstants.paymentsManage);
    return PaymentManageInfo.fromJson(Map<String, dynamic>.from(data as Map));
  }
}