import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../providers/subscription_provider.dart';
import '../../common/widgets/widgets.dart';

/// One purchasable plan, as this screen needs to draw it.
///
/// The words are here; the prices come from `GET /subscription/plans` so a
/// price change does not need an app release. The values below are the
/// fallback for a catalogue that has not loaded (or cannot), because a paywall
/// that renders without prices is worse than one showing last-known ones.
class _Plan {
  const _Plan({
    required this.id,
    required this.label,
    required this.sublabel,
    required this.price,
    this.priceInr,
    this.isBestValue = false,
  });

  final String id;
  final String label;

  /// What choosing this actually means, in plain terms.
  final String sublabel;
  final String price;

  /// The rupee price, when the server sent one.
  final String? priceInr;

  final bool isBestValue;

  _Plan withPrices(String usd, String? inr) => _Plan(
    id: id,
    label: label,
    sublabel: sublabel,
    price: usd,
    priceInr: inr,
    isBestValue: isBestValue,
  );
}

/// One thing Premium gets you. Written as a claim plus its consequence, so
/// each row says what changes rather than selling.
class _Benefit {
  const _Benefit(this.claim, this.detail);

  final String claim;
  final String detail;
}

class PremiumScreen extends ConsumerStatefulWidget {
  const PremiumScreen({super.key});

  @override
  ConsumerState<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends ConsumerState<PremiumScreen> {
  String _selectedPlan = 'monthly';
  bool _isLoading = false;
  bool _isRestoring = false;

  static const List<_Plan> _fallbackPlans = [
    _Plan(
      id: 'monthly',
      label: '1 month',
      sublabel: 'Our most popular plan',
      price: r'$14.99',
      isBestValue: true,
    ),
    _Plan(
      id: 'weekly',
      label: '1 week',
      sublabel: 'Try it out, cancel anytime',
      price: r'$4.99',
    ),
    _Plan(
      id: 'yearly',
      label: '1 year',
      sublabel: 'Best price per month',
      price: r'$99.99',
    ),
  ];

  static const List<_Benefit> _benefits = [
    _Benefit('See everyone nearby', 'No daily limit on your radar.'),
    _Benefit('See who liked you', 'Every name, before you reply.'),
    // Free accounts earn their unlocks by watching rewarded ads. Premium is
    // the version of the app where that never comes up.
    _Benefit('No ads, ever', 'Nothing to watch, nothing to sit through.'),
    _Benefit(
      'Every filter',
      'Online now, verified, situation, atmosphere and vibe.',
    ),
    _Benefit('Start any conversation', 'No cap on openers.'),
  ];

  /// The plans, priced by the server where it answered.
  ///
  /// The order and the words are this screen's; only the numbers come from the
  /// catalogue. A plan the server does not offer keeps its fallback price
  /// rather than disappearing mid-scroll.
  List<_Plan> get _plans {
    final catalogue = ref.watch(planCatalogueProvider).valueOrNull;
    if (catalogue == null || catalogue.plans.isEmpty) return _fallbackPlans;

    return [
      for (final plan in _fallbackPlans)
            () {
          final priced = catalogue.plans.where((p) => p.plan == plan.id);
          if (priced.isEmpty) return plan;
          final option = priced.first;
          return plan.withPrices(
            option.priceLabel,
            option.hasInrPrice ? option.priceInrLabel : null,
          );
        }(),
    ];
  }


  /// Buy the selected plan.
  ///
  /// The backend's sandbox payment provider confirms inline and returns no
  /// checkout URL, so premium is live the moment this returns — no store
  /// credentials needed. If a real provider is configured later it returns a
  /// URL instead, which is the only case that needs a payment sheet.
  Future<void> _onStartPremium() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final result =
      await ref.read(subscriptionActionsProvider).checkout(_selectedPlan);

      if (!mounted) return;
      if (result.isConfirmed) {
        // The button said "Start Premium"; this says it started. Same words,
        // so the outcome is recognisably the thing that was pressed.
        showRadiusToast(context, 'Premium started. Your full radius is open.');
        Navigator.pop(context);
      } else {
        // A live provider wants the payment completed elsewhere.
        showRadiusToast(context, 'Finish the payment to start Premium.');
      }
    } on AppException catch (e) {
      if (mounted) showRadiusToast(context, e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onRestore() async {
    if (_isRestoring) return;
    setState(() => _isRestoring = true);
    try {
      final result = await ref.read(subscriptionActionsProvider).restore();
      if (!mounted) return;
      showRadiusToast(
        context,
        result.isPremium
            ? 'Premium restored.'
            : 'No previous purchase found on this account.',
      );
    } on AppException catch (e) {
      if (mounted) showRadiusToast(context, e.message);
    } finally {
      if (mounted) setState(() => _isRestoring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Read once per build: `_plans` watches the catalogue, and the button needs
    // to agree with the cards about what the selected plan costs.
    final plans = _plans;
    final current = plans.firstWhere(
          (p) => p.id == _selectedPlan,
      orElse: () => plans.first,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: RadiusBackButton(),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
                children: [
                  Text('cozune Premium', style: AppTextStyles.eyebrow),
                  const SizedBox(height: 10),
                  Text(
                    'See everyone.\nFilter everything.',
                    style: AppTextStyles.display,
                  ),
                  const SizedBox(height: 22),

                  ..._benefits.map(
                        (b) => TickRow(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: b.claim,
                              style: AppTextStyles.bodyStrong,
                            ),
                            TextSpan(
                              text: ' — ${b.detail}',
                              style: AppTextStyles.bodyMuted,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  ...plans.map(
                        (plan) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _PlanCard(
                        plan: plan,
                        selected: plan.id == _selectedPlan,
                        onTap: () => setState(() => _selectedPlan = plan.id),
                      ),
                    ),
                  ),

                  const SizedBox(height: 6),
                  RadiusButton(
                    // Carries the price, so nobody taps to find out what it
                    // costs. The rupee figure stays on the card rather than
                    // riding along here — two currencies on a button is a
                    // button nobody reads.
                    label: 'Start Premium · ${current.price}',
                    kind: RadiusButtonKind.premium,
                    isLoading: _isLoading,
                    onPressed: _onStartPremium,
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton(
                      onPressed: _isRestoring ? null : _onRestore,
                      child: Text(
                        _isRestoring ? 'Restoring…' : 'Restore purchase',
                        style: AppTextStyles.bodyStrong.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Billed through the App Store or Play Store. Cancel any '
                        'time from your store account.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption.copyWith(fontSize: 11.5),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A plan, priced. Selection changes fill, border and the radio mark together
/// — never the border alone.
class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.selected,
    required this.onTap,
  });

  final _Plan plan;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final card = RadiusOptionTile(
      title: plan.label,
      subtitle: plan.sublabel,
      selected: selected,
      onTap: onTap,
      // Both currencies, one under the other. The dollar figure keeps the
      // display face it has always had; the rupee price sits beneath it in
      // caption type, because it is the same price said again rather than a
      // second thing to decide between.
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            plan.price,
            style: AppTextStyles.title.copyWith(
              fontSize: 22,
              color: selected ? AppColors.primaryInk : AppColors.textDark,
            ),
          ),
          if (plan.priceInr != null)
            Text(
              plan.priceInr!,
              style: AppTextStyles.caption.copyWith(fontSize: 12),
            ),
        ],
      ),
    );

    if (!plan.isBestValue) return card;

    // The flag sits proud of the card's top edge, so it reads as applied to
    // the plan rather than as another line inside it.
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(padding: const EdgeInsets.only(top: 6), child: card),
        Positioned(
          top: -4,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.premium,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'BEST VALUE',
              style: AppTextStyles.caption.copyWith(
                fontSize: 10,
                color: AppColors.onAccent,
                letterSpacing: 0.6,
                fontWeight: FontWeight.w700,
                fontVariations: const [FontVariation('wght', 700)],
              ),
            ),
          ),
        ),
      ],
    );
  }
}




// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
//
// import '../../../core/theme/app_colors.dart';
// import '../../../core/constants/app_text_styles.dart';
// import '../../../providers/subscription_provider.dart';
// import '../../common/widgets/widgets.dart';
//
// class _Plan {
//   const _Plan({
//     required this.id,
//     required this.label,
//     required this.sublabel,
//     required this.price,
//     this.priceInr,
//     this.isBestValue = false,
//   });
//
//   final String id;
//   final String label;
//   final String sublabel;
//   final String price;
//   final String? priceInr;
//   final bool isBestValue;
//
//   _Plan withPrices(String usd, String? inr) => _Plan(
//     id: id,
//     label: label,
//     sublabel: sublabel,
//     price: usd,
//     priceInr: inr,
//     isBestValue: isBestValue,
//   );
// }
//
// class _Benefit {
//   const _Benefit(this.claim, this.detail);
//   final String claim;
//   final String detail;
// }
//
// class PremiumScreen extends ConsumerStatefulWidget {
//   const PremiumScreen({super.key});
//
//   @override
//   ConsumerState<PremiumScreen> createState() => _PremiumScreenState();
// }
//
// class _PremiumScreenState extends ConsumerState<PremiumScreen> {
//   String _selectedPlan = 'monthly';
//   bool _isLoading = false;
//   bool _isRestoring = false;
//
//   static const List<_Plan> _fallbackPlans = [
//     _Plan(
//       id: 'monthly',
//       label: '1 month',
//       sublabel: 'Our most popular plan',
//       price: r'$14.99',
//       isBestValue: true,
//     ),
//     _Plan(
//       id: 'weekly',
//       label: '1 week',
//       sublabel: 'Try it out, cancel anytime',
//       price: r'$4.99',
//     ),
//     _Plan(
//       id: 'yearly',
//       label: '1 year',
//       sublabel: 'Best price per month',
//       price: r'$99.99',
//     ),
//   ];
//
//   static const List<_Benefit> _benefits = [
//     _Benefit('See everyone nearby', 'No daily limit on your radar.'),
//     _Benefit('See who liked you', 'Every name, before you reply.'),
//     _Benefit('No ads, ever', 'Nothing to watch, nothing to sit through.'),
//     _Benefit(
//       'Every filter',
//       'Online now, verified, situation, atmosphere and vibe.',
//     ),
//     _Benefit('Start any conversation', 'No cap on openers.'),
//   ];
//
//   /// The plans, priced first by the server, then overridden by the store's
//   /// own localized price where the store answered — that's the number that
//   /// actually gets charged, and both platforms require it to match.
//   List<_Plan> get _plans {
//     final catalogue = ref.watch(planCatalogueProvider).valueOrNull;
//     final storePrices = ref.watch(productDetailsProvider).valueOrNull ?? {};
//
//     var plans = _fallbackPlans;
//     if (catalogue != null && catalogue.plans.isNotEmpty) {
//       plans = [
//         for (final plan in _fallbackPlans)
//               () {
//             final priced = catalogue.plans.where((p) => p.plan == plan.id);
//             if (priced.isEmpty) return plan;
//             final option = priced.first;
//             return plan.withPrices(
//               option.priceLabel,
//               option.hasInrPrice ? option.priceInrLabel : null,
//             );
//           }(),
//       ];
//     }
//
//     return [
//       for (final plan in plans)
//             () {
//           final productId = switch (plan.id) {
//             'weekly' => PurchaseIds.weekly,
//             'monthly' => PurchaseIds.monthly,
//             'yearly' => PurchaseIds.yearly,
//             _ => null,
//           };
//           final storePrice = storePrices[productId]?.price;
//           if (storePrice == null) return plan;
//           // Store price replaces the USD figure; the INR line stays as an
//           // informational estimate from the server since the store charges
//           // in the device's own store-account currency, not necessarily INR.
//           return plan.withPrices(storePrice, plan.priceInr);
//         }(),
//     ];
//   }
//
//   Future<void> _onStartPremium() async {
//     if (_isLoading) return;
//     setState(() => _isLoading = true);
//     try {
//       await ref.read(subscriptionActionsProvider).checkout(_selectedPlan);
//       // Loading stays true — the native payment sheet is up, and
//       // `ref.listen` below turns it off once the purchase stream resolves.
//     } on AppException catch (e) {
//       if (mounted) {
//         showRadiusToast(context, e.message);
//         setState(() => _isLoading = false);
//       }
//     } catch (_) {
//       if (mounted) {
//         showRadiusToast(context, 'Could not start the purchase. Try again.');
//         setState(() => _isLoading = false);
//       }
//     }
//   }
//
//   Future<void> _onRestore() async {
//     if (_isRestoring) return;
//     setState(() => _isRestoring = true);
//     try {
//       await ref.read(subscriptionActionsProvider).restore();
//       // Same deal — `ref.listen` resolves `_isRestoring`.
//     } catch (_) {
//       if (mounted) {
//         showRadiusToast(context, 'Could not restore purchases. Try again.');
//         setState(() => _isRestoring = false);
//       }
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     ref.listen<PurchaseUiEvent?>(purchaseEventProvider, (previous, event) {
//       if (event == null) return;
//       switch (event.status) {
//         case PurchaseUiStatus.pending:
//           break; // Keep spinning — store is waiting on parental approval etc.
//         case PurchaseUiStatus.success:
//           setState(() {
//             _isLoading = false;
//             _isRestoring = false;
//           });
//           showRadiusToast(context, 'Premium started. Your full radius is open.');
//           Navigator.pop(context);
//           break;
//         case PurchaseUiStatus.restored:
//           setState(() {
//             _isLoading = false;
//             _isRestoring = false;
//           });
//           showRadiusToast(context, 'Premium restored.');
//           Navigator.pop(context);
//           break;
//         case PurchaseUiStatus.cancelled:
//           setState(() {
//             _isLoading = false;
//             _isRestoring = false;
//           });
//           break;
//         case PurchaseUiStatus.error:
//           setState(() {
//             _isLoading = false;
//             _isRestoring = false;
//           });
//           showRadiusToast(
//             context,
//             event.message ?? 'Purchase could not be completed.',
//           );
//           break;
//       }
//     });
//
//     final plans = _plans;
//     final current = plans.firstWhere(
//           (p) => p.id == _selectedPlan,
//       orElse: () => plans.first,
//     );
//
//     return Scaffold(
//       backgroundColor: AppColors.background,
//       body: SafeArea(
//         child: Column(
//           children: [
//             const Padding(
//               padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
//               child: Align(
//                 alignment: Alignment.centerLeft,
//                 child: RadiusBackButton(),
//               ),
//             ),
//             Expanded(
//               child: ListView(
//                 padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
//                 children: [
//                   Text('cozune Premium', style: AppTextStyles.eyebrow),
//                   const SizedBox(height: 10),
//                   Text(
//                     'See everyone.\nFilter everything.',
//                     style: AppTextStyles.display,
//                   ),
//                   const SizedBox(height: 22),
//                   ..._benefits.map(
//                         (b) => TickRow(
//                       child: Text.rich(
//                         TextSpan(
//                           children: [
//                             TextSpan(
//                               text: b.claim,
//                               style: AppTextStyles.bodyStrong,
//                             ),
//                             TextSpan(
//                               text: ' — ${b.detail}',
//                               style: AppTextStyles.bodyMuted,
//                             ),
//                           ],
//                         ),
//                       ),
//                     ),
//                   ),
//                   const SizedBox(height: 20),
//                   ...plans.map(
//                         (plan) => Padding(
//                       padding: const EdgeInsets.only(bottom: 12),
//                       child: _PlanCard(
//                         plan: plan,
//                         selected: plan.id == _selectedPlan,
//                         onTap: () => setState(() => _selectedPlan = plan.id),
//                       ),
//                     ),
//                   ),
//                   const SizedBox(height: 6),
//                   RadiusButton(
//                     label: 'Start Premium · ${current.price}',
//                     kind: RadiusButtonKind.premium,
//                     isLoading: _isLoading,
//                     onPressed: _onStartPremium,
//                   ),
//                   const SizedBox(height: 12),
//                   Center(
//                     child: TextButton(
//                       onPressed: _isRestoring ? null : _onRestore,
//                       child: Text(
//                         _isRestoring ? 'Restoring…' : 'Restore purchase',
//                         style: AppTextStyles.bodyStrong.copyWith(
//                           color: AppColors.primary,
//                         ),
//                       ),
//                     ),
//                   ),
//                   const SizedBox(height: 6),
//                   Text(
//                     'Billed through the App Store or Play Store. Cancel any '
//                         'time from your store account.',
//                     textAlign: TextAlign.center,
//                     style: AppTextStyles.caption.copyWith(fontSize: 11.5),
//                   ),
//                   const SizedBox(height: 16),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
//
// class _PlanCard extends StatelessWidget {
//   const _PlanCard({
//     required this.plan,
//     required this.selected,
//     required this.onTap,
//   });
//
//   final _Plan plan;
//   final bool selected;
//   final VoidCallback onTap;
//
//   @override
//   Widget build(BuildContext context) {
//     final card = RadiusOptionTile(
//       title: plan.label,
//       subtitle: plan.sublabel,
//       selected: selected,
//       onTap: onTap,
//       trailing: Column(
//         crossAxisAlignment: CrossAxisAlignment.end,
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Text(
//             plan.price,
//             style: AppTextStyles.title.copyWith(
//               fontSize: 22,
//               color: selected ? AppColors.primaryInk : AppColors.textDark,
//             ),
//           ),
//           if (plan.priceInr != null)
//             Text(
//               plan.priceInr!,
//               style: AppTextStyles.caption.copyWith(fontSize: 12),
//             ),
//         ],
//       ),
//     );
//
//     if (!plan.isBestValue) return card;
//
//     return Stack(
//       clipBehavior: Clip.none,
//       children: [
//         Padding(padding: const EdgeInsets.only(top: 6), child: card),
//         Positioned(
//           top: -4,
//           right: 16,
//           child: Container(
//             padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
//             decoration: BoxDecoration(
//               color: AppColors.premium,
//               borderRadius: BorderRadius.circular(999),
//             ),
//             child: Text(
//               'BEST VALUE',
//               style: AppTextStyles.caption.copyWith(
//                 fontSize: 10,
//                 color: AppColors.onAccent,
//                 letterSpacing: 0.6,
//                 fontWeight: FontWeight.w700,
//                 fontVariations: const [FontVariation('wght', 700)],
//               ),
//             ),
//           ),
//         ),
//       ],
//     );
//   }
// }