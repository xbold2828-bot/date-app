import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/visitor_model.dart';
import '../data/repositories/ads_repository.dart';
import '../presentation/home/providers/match_provider/match_provider.dart';
import 'core_providers.dart';

/// Who opened my profile — the list behind the Visits count.
final visitorsProvider = FutureProvider.autoDispose<VisitorsPage>(
  (ref) => ref.watch(profileRepositoryProvider).visitors(),
);

/// Revealing one visitor.
class VisitorActions {
  VisitorActions(this.ref);
  final Ref ref;

  /// Reveal the person behind [visitId] and refresh the list.
  ///
  /// [afterAd] is true when a rewarded ad was just watched for this: the view
  /// is claimed first, so its credits are in the wallet before the unlock
  /// spends one. If the unlock then fails, the credits stay — the next tap
  /// can use them without another ad.
  Future<VisitorCard> reveal(String visitId, {bool afterAd = false}) async {
    if (afterAd) {
      await ref
          .read(adsRepositoryProvider)
          .claimReward(
            idempotencyKey: AdsRepository.newIdempotencyKey(),
            placement: 'visitors_unlock',
          );
      ref.invalidate(entitlementsProvider);
    }
    try {
      return await ref.read(profileRepositoryProvider).unlockVisitor(visitId);
    } finally {
      ref.invalidate(visitorsProvider);
    }
  }
}

final visitorActionsProvider = Provider<VisitorActions>(
  (ref) => VisitorActions(ref),
);
