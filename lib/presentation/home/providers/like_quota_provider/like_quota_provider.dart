import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exceptions.dart';
import '../../../../core/utils/app_snack_bar.dart';
import '../../../../providers/core_providers.dart';
import '../../models/like_quota_model.dart';

class LikeQuotaNotifier extends AsyncNotifier<LikeQuota> {
  @override
  Future<LikeQuota> build() => ref.read(matchRepositoryProvider).quota();

  /// Re-fetches from the server (e.g. sheet opened, app resumed).
  ///
  /// On failure the last known quota stays on screen (we do NOT replace it
  /// with an error state), and the error is shown in an AppSnackBar.
  Future<void> refresh() async {
    final previous = state;
    state = const AsyncLoading<LikeQuota>().copyWithPrevious(previous);
    try {
      state = AsyncData(await ref.read(matchRepositoryProvider).quota());
    } on AppException catch (e) {
      state = previous;
      AppSnackBar.showErrorSnackBar(message: e.message);
    } catch (_) {
      state = previous;
      AppSnackBar.showErrorSnackBar(message: 'Could not load your likes.');
    }
  }

  /// Spends an ad credit. Returns true on success.
  ///
  /// - Generates ONE idempotency key per earned reward and sends it to the
  ///   server (required: non-empty string, <= 120 chars). A retry of the same
  ///   reward passes the same [idempotencyKey] so it can never be double-spent.
  /// - On error it shows an AppSnackBar and returns false. It does NOT call
  ///   any other API afterwards — the caller must stop when this is false.
  Future<bool> unlockMore({String? idempotencyKey}) async {
    final key = idempotencyKey ?? newIdempotencyKey();
    try {
      final result = await ref
          .read(matchRepositoryProvider)
          .unlockQuota(idempotencyKey: key);
      state = AsyncData(result); // response is the new source of truth
      return true;
    } on AppException catch (e) {
      AppSnackBar.showErrorSnackBar(message: e.message);
      return false;
    } catch (_) {
      AppSnackBar.showErrorSnackBar(
        message: 'Could not add the like. Please try again.',
      );
      return false;
    }
  }

  /// Writes a server-returned quota straight into state (e.g. from unlike).
  void setQuota(LikeQuota quota) {
    state = AsyncData(quota);
  }

  /// Unique per ad reward, ~56 chars (limit is 120). No extra package needed.
  static String newIdempotencyKey() {
    final rnd = math.Random.secure();
    final rand = List.generate(
      16,
          (_) => rnd.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    return 'unlock-${DateTime.now().microsecondsSinceEpoch}-$rand';
  }
}

final likeQuotaProvider =
AsyncNotifierProvider<LikeQuotaNotifier, LikeQuota>(LikeQuotaNotifier.new);