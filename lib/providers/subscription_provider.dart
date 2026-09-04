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



// import 'dart:async';
//
// import 'package:flutter/foundation.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:in_app_purchase/in_app_purchase.dart';
//
// import '../core/logger/app_logger.dart';
// import '../data/models/subscription_model.dart';
// import 'core_providers.dart';
// import 'profile_provider.dart';
//
// /// Store product IDs, keyed by the same plan ids the backend/UI already use
// /// ('weekly' / 'monthly' / 'yearly'). These must match exactly what's
// /// configured in App Store Connect / Play Console.
// class PurchaseIds {
//   const PurchaseIds._();
//
//   static const weekly = 'cozune_premium_weekly';
//   static const monthly = 'cozune_premium_monthly';
//   static const yearly = 'cozune_premium_yearly';
//
//   static const all = <String>{weekly, monthly, yearly};
//
//   static String? planForProductId(String productId) {
//     switch (productId) {
//       case weekly:
//         return 'weekly';
//       case monthly:
//         return 'monthly';
//       case yearly:
//         return 'yearly';
//       default:
//         return null;
//     }
//   }
// }
//
// /// The plugin's single instance. `in_app_purchase` doesn't need an explicit
// /// init call — the first real call (`isAvailable`, `queryProductDetails`)
// /// wakes up StoreKit/Play Billing lazily.
// final inAppPurchaseProvider =
// Provider<InAppPurchase>((ref) => InAppPurchase.instance);
//
// /// Whether the store is reachable at all on this device — false on an iOS
// /// Simulator without a sandbox account, or a device with no Play Store.
// final iapAvailableProvider = FutureProvider<bool>(
//       (ref) => ref.watch(inAppPurchaseProvider).isAvailable(),
// );
//
// /// Store-priced products for the three plans, keyed by [PurchaseIds]. The buy
// /// call always uses a `ProductDetails` the store just handed back, never a
// /// stale/cached one.
// final productDetailsProvider =
// FutureProvider<Map<String, ProductDetails>>((ref) async {
//   final available = await ref.watch(iapAvailableProvider.future);
//   if (!available) return {};
//
//   final iap = ref.watch(inAppPurchaseProvider);
//   final response = await iap.queryProductDetails(PurchaseIds.all);
//
//   if (response.error != null) {
//     AppLogger.e('queryProductDetails failed: ${response.error}');
//   }
//   if (response.notFoundIDs.isNotEmpty) {
//     AppLogger.e('Store product IDs not found: ${response.notFoundIDs}');
//   }
//
//   return {for (final p in response.productDetails) p.id: p};
// });
//
// /// The paywall catalogue. Prices live on the server so a plan change doesn't
// /// need an app release; the store's own localized price (via
// /// [productDetailsProvider]) is what `PremiumScreen` should actually charge —
// /// see the override there. Store guidelines require the price shown to match
// /// what the store charges.
// final planCatalogueProvider = FutureProvider<PlanCatalogue>(
//       (ref) => ref.watch(subscriptionRepositoryProvider).plans(),
// );
//
// /// My premium status.
// final mySubscriptionProvider = FutureProvider<MySubscription>(
//       (ref) => ref.watch(subscriptionRepositoryProvider).mine(),
// );
//
// /// One purchase-stream outcome, surfaced for the UI to react to.
// enum PurchaseUiStatus { pending, success, restored, error, cancelled }
//
// class PurchaseUiEvent {
//   const PurchaseUiEvent(this.status, {this.message});
//   final PurchaseUiStatus status;
//   final String? message;
// }
//
// final purchaseEventProvider = StateProvider<PurchaseUiEvent?>((ref) => null);
//
// /// Owns the app-wide purchase stream subscription. Read this provider once,
// /// early (e.g. in `AuthGate`/`MyApp`'s build), so a purchase queued while the
// /// app was killed — a common iOS restore case, or Android's slow-network
// /// PENDING state — gets replayed into a live listener instead of silently
// /// dropped because nothing was subscribed yet.
// final purchaseStreamControllerProvider = Provider<PurchaseStreamController>(
//       (ref) {
//     final controller = PurchaseStreamController(ref);
//     controller._start();
//     ref.onDispose(controller.dispose);
//     return controller;
//   },
// );
//
// class PurchaseStreamController {
//   PurchaseStreamController(this._ref);
//   final Ref _ref;
//   StreamSubscription<List<PurchaseDetails>>? _sub;
//
//   void _start() {
//     final iap = _ref.read(inAppPurchaseProvider);
//     _sub = iap.purchaseStream.listen(
//       _onPurchaseUpdate,
//       onDone: () => _sub?.cancel(),
//       onError: (Object error) {
//         AppLogger.e('Purchase stream error', error: error);
//         _ref.read(purchaseEventProvider.notifier).state =
//             PurchaseUiEvent(PurchaseUiStatus.error, message: error.toString());
//       },
//     );
//   }
//
//   Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
//     for (final purchase in purchases) {
//       switch (purchase.status) {
//         case PurchaseStatus.pending:
//           _ref.read(purchaseEventProvider.notifier).state =
//           const PurchaseUiEvent(PurchaseUiStatus.pending);
//           break;
//
//         case PurchaseStatus.purchased:
//         case PurchaseStatus.restored:
//           await _verifyAndComplete(purchase);
//           break;
//
//         case PurchaseStatus.error:
//           _ref.read(purchaseEventProvider.notifier).state = PurchaseUiEvent(
//             PurchaseUiStatus.error,
//             message: purchase.error?.message ?? 'Purchase failed.',
//           );
//           if (purchase.pendingCompletePurchase) {
//             await _ref.read(inAppPurchaseProvider).completePurchase(purchase);
//           }
//           break;
//
//         case PurchaseStatus.canceled:
//           _ref.read(purchaseEventProvider.notifier).state =
//           const PurchaseUiEvent(PurchaseUiStatus.cancelled);
//           if (purchase.pendingCompletePurchase) {
//             await _ref.read(inAppPurchaseProvider).completePurchase(purchase);
//           }
//           break;
//       }
//     }
//   }
//
//   /// Sends the receipt/purchase token to the backend so it can verify
//   /// server-to-server with Apple/Google and flip `premium` on the account —
//   /// trusting the on-device status alone is spoofable.
//   ///
//   /// `verifyPurchase` isn't defined on `SubscriptionRepository` yet — add it
//   /// there to match your `/subscription/verify`-style endpoint.
//   Future<void> _verifyAndComplete(PurchaseDetails purchase) async {
//     try {
//       final plan = PurchaseIds.planForProductId(purchase.productID);
//       final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
//
//       await _ref.read(subscriptionRepositoryProvider).verifyPurchase(
//         plan: plan,
//         productId: purchase.productID,
//         transactionId: purchase.purchaseID,
//         source: kIsWeb? "web" : isIOS ? 'ios' : 'android',
//         receiptData: purchase.verificationData.serverVerificationData,
//       );
//
//       _ref.invalidate(mySubscriptionProvider);
//       await _ref.read(meProvider.notifier).refresh();
//
//       _ref.read(purchaseEventProvider.notifier).state = PurchaseUiEvent(
//         purchase.status == PurchaseStatus.restored
//             ? PurchaseUiStatus.restored
//             : PurchaseUiStatus.success,
//       );
//     } catch (e, s) {
//       AppLogger.e('Purchase verification failed', error: e, stackTrace: s);
//       _ref.read(purchaseEventProvider.notifier).state = const PurchaseUiEvent(
//         PurchaseUiStatus.error,
//         message: 'We received your payment but could not confirm it yet. '
//             'Try "Restore purchase" in a moment.',
//       );
//     } finally {
//       // Always ack the store, verified or not — an un-acked purchase gets
//       // replayed on every app start until it is.
//       if (purchase.pendingCompletePurchase) {
//         await _ref.read(inAppPurchaseProvider).completePurchase(purchase);
//       }
//     }
//   }
//
//   void dispose() => _sub?.cancel();
// }
//
// /// Purchase actions the UI calls directly.
// class SubscriptionActions {
//   SubscriptionActions(this._ref);
//   final Ref _ref;
//
//   /// Starts a real store purchase for [plan] ('weekly' / 'monthly' / 'yearly').
//   /// Fire-and-forget by design: StoreKit/Play Billing take over with their own
//   /// payment sheet, and the result arrives later on [purchaseEventProvider]
//   /// via the purchase stream — not as a return value here.
//   Future<void> checkout(String plan) async {
//     // Make sure the stream listener exists before we buy anything.
//     _ref.read(purchaseStreamControllerProvider);
//
//     final products = await _ref.read(productDetailsProvider.future);
//     final productId = switch (plan) {
//       'weekly' => PurchaseIds.weekly,
//       'monthly' => PurchaseIds.monthly,
//       'yearly' => PurchaseIds.yearly,
//       _ => throw ArgumentError('Unknown plan: $plan'),
//     };
//
//     final product = products[productId];
//     if (product == null) {
//       _ref.read(purchaseEventProvider.notifier).state = const PurchaseUiEvent(
//         PurchaseUiStatus.error,
//         message: 'This plan is not available on the store right now.',
//       );
//       return;
//     }
//
//     final purchaseParam = PurchaseParam(productDetails: product);
//     // Subscriptions go through buyNonConsumable on both platforms — the
//     // plugin has no separate buySubscription API.
//     await _ref
//         .read(inAppPurchaseProvider)
//         .buyNonConsumable(purchaseParam: purchaseParam);
//   }
//
//   /// Replays past purchases through the same stream `checkout` uses, so
//   /// restored transactions get verified and acked the same way.
//   Future<void> restore() async {
//     _ref.read(purchaseStreamControllerProvider);
//     await _ref.read(inAppPurchaseProvider).restorePurchases();
//   }
//
//   Future<MySubscription> cancel() async {
//     final result = await _ref.read(subscriptionRepositoryProvider).cancel();
//     _ref.invalidate(mySubscriptionProvider);
//     await _ref.read(meProvider.notifier).refresh();
//     return result;
//   }
// }
//
// final subscriptionActionsProvider =
// Provider<SubscriptionActions>((ref) => SubscriptionActions(ref));