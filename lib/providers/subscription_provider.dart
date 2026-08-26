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
