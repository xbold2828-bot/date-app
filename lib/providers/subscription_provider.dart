import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/subscription_model.dart';
import 'core_providers.dart';
import 'profile_provider.dart';

/// The paywall catalogue. Prices live on the server so a plan change doesn't
/// need an app release.
final planCatalogueProvider = FutureProvider<PlanCatalogue>(
      (ref) => ref.watch(subscriptionRepositoryProvider).plans(),
);

/// My premium status.
final mySubscriptionProvider = FutureProvider<MySubscription>(
      (ref) => ref.watch(subscriptionRepositoryProvider).mine(),
);

/// Purchase actions. Each one refreshes [meProvider] as well, because the
/// user's `premium` flag is denormalised onto the self-view and gates the
/// premium UI everywhere else.
class SubscriptionActions {
  SubscriptionActions(this._ref);
  final Ref _ref;

  Future<CheckoutResult> checkout(String plan) async {
    final result =
    await _ref.read(subscriptionRepositoryProvider).checkout(plan);
    await _refreshEntitlements();
    return result;
  }

  Future<MySubscription> restore() async {
    final result = await _ref.read(subscriptionRepositoryProvider).restore();
    await _refreshEntitlements();
    return result;
  }

  Future<MySubscription> cancel() async {
    final result = await _ref.read(subscriptionRepositoryProvider).cancel();
    await _refreshEntitlements();
    return result;
  }

  Future<void> _refreshEntitlements() async {
    _ref.invalidate(mySubscriptionProvider);
    await _ref.read(meProvider.notifier).refresh();
  }
}

final subscriptionActionsProvider =
Provider<SubscriptionActions>((ref) => SubscriptionActions(ref));




// import 'package:flutter/foundation.dart';
// import 'package:flutter/services.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:purchases_flutter/purchases_flutter.dart';
//
// import '../core/logger/app_logger.dart';
// import '../data/repositories/payments_repository.dart';
// import '../presentation/home/models/payment_model.dart';
// import 'core_providers.dart';
// import 'profile_provider.dart';
//
// final paymentsRepositoryProvider = Provider<PaymentsRepository>(
//       (ref) => PaymentsRepository(ref.watch(apiClientProvider)),
// );
//
// final paymentsConfigProvider = FutureProvider<PaymentsConfig>(
//       (ref) => ref.watch(paymentsRepositoryProvider).config(),
// );
//
// final paymentHistoryProvider = FutureProvider.autoDispose<PaymentHistoryPage>(
//       (ref) => ref.watch(paymentsRepositoryProvider).history(),
// );
//
// final paymentManageInfoProvider = FutureProvider.autoDispose<PaymentManageInfo>(
//       (ref) => ref.watch(paymentsRepositoryProvider).manage(),
// );
//
// final mySubscriptionProvider = FutureProvider<PaymentSubscriptionStatus>(
//       (ref) => ref.watch(paymentsRepositoryProvider).subscription(),
// );
//
// final revenueCatConfiguredProvider = FutureProvider<bool>((ref) async {
//   final config = await ref.watch(paymentsConfigProvider.future);
//   final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
//   final apiKey = isIOS ? config.publicKeyIos : config.publicKeyAndroid;
//
//   if (apiKey.isEmpty) {
//     AppLogger.e('RevenueCat: no public key for this platform in /payments/config');
//     return false;
//   }
//
//   await Purchases.setLogLevel(LogLevel.warn);
//   await Purchases.configure(
//     PurchasesConfiguration(apiKey)..appUserID = config.appUserId,
//   );
//   return true;
// });
//
// final paywallOfferingProvider = FutureProvider<Offering?>((ref) async {
//   final configured = await ref.watch(revenueCatConfiguredProvider.future);
//   if (!configured) {
//     AppLogger.e('RevenueCat: SDK not configured, no offering to fetch');
//     return null;
//   }
//
//   final config = await ref.watch(paymentsConfigProvider.future);
//   final offerings = await Purchases.getOfferings();
//   AppLogger.d(
//     'RevenueCat: offerings available = ${offerings.all.keys.toList()}, '
//         'looking for "${config.offeringId}"',
//   );
//   final offering = offerings.getOffering(config.offeringId) ?? offerings.current;
//   if (offering == null) {
//     AppLogger.e(
//       'RevenueCat: no offering matched "${config.offeringId}" and no '
//           'current offering is set in the dashboard',
//     );
//   } else {
//     AppLogger.d(
//       'RevenueCat: using offering "${offering.identifier}" with packages '
//           '${offering.availablePackages.map((p) => p.storeProduct.identifier).toList()}',
//     );
//   }
//   return offering;
// });
//
// final planPackagesProvider = FutureProvider<Map<String, Package>>((ref) async {
//   final offering = await ref.watch(paywallOfferingProvider.future);
//   if (offering == null) return {};
//
//   final config = await ref.watch(paymentsConfigProvider.future);
//   final result = <String, Package>{};
//   for (final plan in config.plans) {
//     final package = offering.availablePackages.firstWhereOrNull(
//           (p) =>
//       p.storeProduct.identifier == plan.productId ||
//           p.storeProduct.identifier.startsWith('${plan.productId}:'),
//     );
//     if (package == null) {
//       AppLogger.e(
//         'RevenueCat: no package found for plan "${plan.plan}" '
//             '(productId "${plan.productId}")',
//       );
//     }
//     if (package != null) result[plan.plan] = package;
//   }
//   return result;
// });
//
// enum PurchaseUiStatus { success, restored, cancelled, error }
//
// class PurchaseUiEvent {
//   const PurchaseUiEvent(this.status, {this.message});
//   final PurchaseUiStatus status;
//   final String? message;
// }
//
// class SubscriptionActions {
//   SubscriptionActions(this._ref);
//   final Ref _ref;
//
//   Future<PurchaseUiEvent> purchase(String planId) async {
//     try {
//       final packages = await _ref.read(planPackagesProvider.future);
//       final package = packages[planId];
//       if (package == null) {
//         return const PurchaseUiEvent(
//           PurchaseUiStatus.error,
//           message: 'This plan is not available on the store right now.',
//         );
//       }
//
//       await Purchases.purchase(PurchaseParams.package(package));
//       await _sync();
//       return const PurchaseUiEvent(PurchaseUiStatus.success);
//     } on PlatformException catch (e) {
//       final errorCode = PurchasesErrorHelper.getErrorCode(e);
//       if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
//         return const PurchaseUiEvent(PurchaseUiStatus.cancelled);
//       }
//       return PurchaseUiEvent(
//         PurchaseUiStatus.error,
//         message: e.message ?? 'Purchase could not be completed.',
//       );
//     } catch (e) {
//       return PurchaseUiEvent(PurchaseUiStatus.error, message: e.toString());
//     }
//   }
//
//   Future<PurchaseUiEvent> restore() async {
//     try {
//       await Purchases.restorePurchases();
//       final result = await _ref.read(paymentsRepositoryProvider).restore();
//       await _refreshEntitlements();
//       return PurchaseUiEvent(
//         result.isPremium ? PurchaseUiStatus.restored : PurchaseUiStatus.error,
//         message: result.isPremium
//             ? null
//             : 'No previous purchase found on this account.',
//       );
//     } catch (e) {
//       return PurchaseUiEvent(PurchaseUiStatus.error, message: e.toString());
//     }
//   }
//
//   Future<void> _sync() async {
//     await _ref.read(paymentsRepositoryProvider).sync();
//     await _refreshEntitlements();
//   }
//
//   Future<void> _refreshEntitlements() async {
//     _ref.invalidate(mySubscriptionProvider);
//     await _ref.read(meProvider.notifier).refresh();
//   }
// }
//
// final subscriptionActionsProvider =
// Provider<SubscriptionActions>((ref) => SubscriptionActions(ref));