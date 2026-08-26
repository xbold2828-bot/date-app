import 'dart:math';

import '../../core/constants/api_constants.dart';
import '../services/api_service.dart';

/// What one rewarded-ad view was worth.
class AdReward {
  /// The server had already seen this impression, so nothing was minted. Not an
  /// error — it is the idempotency guard doing its job on a retry.
  final bool alreadyClaimed;

  final int creditsAwarded;

  /// Credit balance after the claim.
  final int balance;

  const AdReward({
    required this.alreadyClaimed,
    required this.creditsAwarded,
    required this.balance,
  });

  factory AdReward.fromJson(Map<String, dynamic> json) => AdReward(
        alreadyClaimed: json['alreadyClaimed'] as bool? ?? false,
        creditsAwarded: (json['creditsAwarded'] as num?)?.toInt() ?? 0,
        balance: (json['balance'] as num?)?.toInt() ?? 0,
      );
}

/// Rewarded ads → credits, which is what actually unlocks the gated surfaces
/// (the rest of "Liked you", more of the radar).
///
/// There is no ad SDK yet: the backend runs `MockVerificationProvider`, which
/// approves any impression, so calling [claimReward] is the whole flow. When a
/// real network is wired in, its "reward granted" callback replaces the direct
/// call here and passes through the same idempotency key — nothing downstream
/// changes.
class AdsRepository {
  AdsRepository(this._api);

  final ApiClient _api;

  static final Random _random = Random.secure();

  /// A key unique to one impression. The server rejects a replay of it, so a
  /// double-tap or a retry after a dropped response cannot mint twice.
  static String newIdempotencyKey() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final salt = _random.nextInt(1 << 32).toRadixString(16);
    return 'ad-$now-$salt';
  }

  /// `POST /ads/reward` — claim the credits for a completed view.
  ///
  /// Throws on the daily cap (429), which is a real limit worth surfacing:
  /// "You've watched all today's ads."
  Future<AdReward> claimReward({
    required String idempotencyKey,
    String? placement,
  }) async {
    final data = await _api.post(
      ApiConstants.adsReward,
      body: {
        'idempotencyKey': idempotencyKey,
        if (placement != null) 'placement': placement,
      },
    );
    return AdReward.fromJson(Map<String, dynamic>.from(data as Map));
  }
}
