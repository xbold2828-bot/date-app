import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      final result = await ref
          .read(subscriptionActionsProvider)
          .checkout(_selectedPlan);

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
                  Semantics(
                    header: true,
                    child: Text(
                      'See everyone.\nFilter everything.',
                      style: AppTextStyles.question,
                    ),
                  ),
                  const SizedBox(height: 24),

                  for (final b in _benefits) _BenefitRow(benefit: b),

                  const SizedBox(height: 22),

                  ...plans.map(
                    (plan) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _PlanCard(
                        plan: plan,
                        selected: plan.id == _selectedPlan,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedPlan = plan.id);
                        },
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
                          color: AppColors.textGrey,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Billed through the App Store or Play Store. Cancel any '
                    'time from your store account.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption.copyWith(fontSize: 12),
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

/// One thing Premium gets you: the claim, and under it the plain fact behind
/// it. A check in premium ink — the same purple as the button that buys it.
class _BenefitRow extends StatelessWidget {
  const _BenefitRow({required this.benefit});

  final _Benefit benefit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              Icons.check_rounded,
              size: 20,
              color: AppColors.premiumInk,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  benefit.claim,
                  style: AppTextStyles.bodyStrong.copyWith(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                    fontVariations: const [FontVariation('wght', 600)],
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  benefit.detail,
                  style: AppTextStyles.bodyMuted.copyWith(fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A plan, priced. Selection changes the border and the radio mark together
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
      accent: AppColors.premium,
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
            style: AppTextStyles.stat(22).copyWith(
              color: selected ? AppColors.premiumInk : AppColors.textDark,
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
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.premium,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.background, width: 2),
            ),
            child: Text(
              'Best value',
              style: AppTextStyles.caption.copyWith(
                fontSize: 11.5,
                color: AppColors.onAccent,
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
// import 'package:url_launcher/url_launcher.dart';
//
// import '../../../core/theme/app_colors.dart';
// import '../../../core/constants/app_text_styles.dart';
// import '../../../providers/subscription_provider.dart';
// import '../../common/widgets/widgets.dart';
// import '../models/payment_model.dart';
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
// const _fallbackPlans = [
//   _Plan(
//     id: 'monthly',
//     label: '1 month',
//     sublabel: 'Our most popular plan',
//     price: r'$14.99',
//     isBestValue: true,
//   ),
//   _Plan(id: 'weekly', label: '1 week', sublabel: 'Try it out, cancel anytime', price: r'$4.99'),
//   _Plan(id: 'yearly', label: '1 year', sublabel: 'Best price per month', price: r'$99.99'),
// ];
//
// const _benefits = [
//   _Benefit('See everyone nearby', 'No daily limit on your radar.'),
//   _Benefit('See who liked you', 'Every name, before you reply.'),
//   _Benefit('No ads, ever', 'Nothing to watch, nothing to sit through.'),
//   _Benefit('Every filter', 'Online now, verified, situation, atmosphere and vibe.'),
//   _Benefit('Start any conversation', 'No cap on openers.'),
// ];
//
// String _formatDate(DateTime date) {
//   const months = [
//     'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
//     'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
//   ];
//   return '${months[date.month - 1]} ${date.day}, ${date.year}';
// }
//
// /// Plans priced by the server where it answered. Order and copy are this
// /// screen's own; only the numbers come from `/payments/config`. A plan the
// /// server doesn't return keeps its fallback price instead of disappearing.
// List<_Plan> _pricedPlans(PaymentsConfig? config) {
//   if (config == null || config.plans.isEmpty) return _fallbackPlans;
//   return [
//     for (final plan in _fallbackPlans)
//           () {
//         final match = config.plans.where((p) => p.plan == plan.id);
//         if (match.isEmpty) return plan;
//         return plan.withPrices(match.first.priceUsdLabel, match.first.priceInrLabel);
//       }(),
//   ];
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
//   String? _selectedPlan;
//   bool _isLoading = false;
//   bool _isRestoring = false;
//   bool _isLoadingManage = false;
//
//   /// Local toast helper. Deliberately does NOT use `showRadiusToast`
//   /// (floating behavior) — a floating SnackBar throws a layout assertion on
//   /// this screen because it can't compute room above the bottom safe area
//   /// reliably during rapid state changes (e.g. right after restore/manage
//   /// taps). `fixed` behavior skips that geometry check entirely.
//   void _showToast(String message) {
//     if (!mounted) return;
//     ScaffoldMessenger.of(context)
//       ..clearSnackBars()
//       ..showSnackBar(
//         SnackBar(
//           content: Text(message),
//           behavior: SnackBarBehavior.fixed,
//           duration: const Duration(seconds: 3),
//         ),
//       );
//   }
//
//   Future<void> _onStartPremium(String planId) async {
//     if (_isLoading) return;
//     setState(() => _isLoading = true);
//     try {
//       final event = await ref.read(subscriptionActionsProvider).purchase(planId);
//       if (!mounted) return;
//
//       switch (event.status) {
//         case PurchaseUiStatus.success:
//           _showToast('Premium started. Your full radius is open.');
//           ref.invalidate(mySubscriptionProvider);
//           ref.invalidate(paymentHistoryProvider);
//           Navigator.pop(context);
//           break;
//         case PurchaseUiStatus.cancelled:
//           break;
//         case PurchaseUiStatus.restored:
//           _showToast('Premium restored.');
//           break;
//         case PurchaseUiStatus.error:
//           _showToast(event.message ?? 'Could not start the purchase. Try again.');
//           break;
//       }
//     } catch (e) {
//       if (mounted) _showToast('Something went wrong. Try again.');
//     } finally {
//       if (mounted) setState(() => _isLoading = false);
//     }
//   }
//
//   Future<void> _onRestore() async {
//     if (_isRestoring) return;
//     setState(() => _isRestoring = true);
//     try {
//       final event = await ref.read(subscriptionActionsProvider).restore();
//       if (!mounted) return;
//       _showToast(
//         event.status == PurchaseUiStatus.restored
//             ? 'Premium restored.'
//             : (event.message ?? 'No previous purchase found on this account.'),
//       );
//     } catch (e) {
//       if (mounted) _showToast('Could not restore purchases. Try again.');
//     } finally {
//       if (mounted) setState(() => _isRestoring = false);
//     }
//   }
//
//   Future<void> _onManageSubscription() async {
//     if (_isLoadingManage) return;
//     setState(() => _isLoadingManage = true);
//     try {
//       final info = await ref.read(paymentManageInfoProvider.future);
//       final url = Uri.tryParse(info.openUrl);
//
//       if (url == null || info.openUrl.isEmpty) {
//         _showToast('Could not open subscription settings.');
//         return;
//       }
//
//       final canOpen = await canLaunchUrl(url);
//       if (!canOpen) {
//         _showToast('Could not open subscription settings.');
//         return;
//       }
//
//       final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
//       if (!opened && mounted) {
//         _showToast('Could not open subscription settings.');
//       }
//     } catch (e) {
//       if (mounted) _showToast('Could not open subscription settings.');
//     } finally {
//       if (mounted) setState(() => _isLoadingManage = false);
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final config = ref.watch(paymentsConfigProvider).valueOrNull;
//     final subAsync = ref.watch(mySubscriptionProvider);
//     final sub = subAsync.valueOrNull;
//
//     final plans = _pricedPlans(config);
//     _selectedPlan ??= sub?.plan ?? 'monthly';
//     final selected = plans.firstWhere(
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
//               child: Align(alignment: Alignment.centerLeft, child: RadiusBackButton()),
//             ),
//             Expanded(
//               child: ListView(
//                 padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
//                 children: [
//                   Text('cozune Premium', style: AppTextStyles.eyebrow),
//                   const SizedBox(height: 10),
//                   Text('See everyone.\nFilter everything.', style: AppTextStyles.display),
//                   const SizedBox(height: 22),
//
//                   if (subAsync.isLoading)
//                     const Padding(
//                       padding: EdgeInsets.only(bottom: 20),
//                       child: LinearProgressIndicator(),
//                     )
//                   else if (sub != null && sub.isPremium)
//                     _StatusCard(
//                       sub: sub,
//                       isManaging: _isLoadingManage,
//                       onManage: _onManageSubscription,
//                     ),
//
//                   for (final b in _benefits)
//                     TickRow(
//                       child: Text.rich(
//                         TextSpan(
//                           children: [
//                             TextSpan(text: b.claim, style: AppTextStyles.bodyStrong),
//                             TextSpan(text: ' — ${b.detail}', style: AppTextStyles.bodyMuted),
//                           ],
//                         ),
//                       ),
//                     ),
//
//                   const SizedBox(height: 20),
//
//                   for (final plan in plans)
//                     Padding(
//                       padding: const EdgeInsets.only(bottom: 12),
//                       child: _PlanCard(
//                         plan: plan,
//                         selected: plan.id == _selectedPlan,
//                         onTap: () => setState(() => _selectedPlan = plan.id),
//                       ),
//                     ),
//
//                   const SizedBox(height: 6),
//                   RadiusButton(
//                     label: sub?.isPremium == true
//                         ? 'Continue Premium · ${selected.price}'
//                         : 'Start Premium · ${selected.price}',
//                     kind: RadiusButtonKind.premium,
//                     isLoading: _isLoading,
//                     onPressed: () => _onStartPremium(selected.id),
//                   ),
//                   const SizedBox(height: 12),
//                   Center(
//                     child: TextButton(
//                       onPressed: _isRestoring ? null : _onRestore,
//                       child: Text(
//                         _isRestoring ? 'Restoring…' : 'Restore purchase',
//                         style: AppTextStyles.bodyStrong.copyWith(color: AppColors.primary),
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
//
//                   const _PaymentHistorySection(),
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
// /// Banner shown when the account is already Premium: renewal/expiry date,
// /// plus a way to manage or cancel through the store.
// class _StatusCard extends StatelessWidget {
//   const _StatusCard({
//     required this.sub,
//     required this.isManaging,
//     required this.onManage,
//   });
//
//   final PaymentSubscriptionStatus sub;
//   final bool isManaging;
//   final VoidCallback onManage;
//
//   @override
//   Widget build(BuildContext context) {
//     final dateLabel = sub.expiresAt != null ? _formatDate(sub.expiresAt!) : null;
//     final statusLine = dateLabel == null
//         ? 'Your Premium is active.'
//         : sub.willRenew
//         ? 'Renews on $dateLabel.'
//         : 'Active until $dateLabel, then won\'t renew.';
//
//     return Container(
//       width: double.infinity,
//       margin: const EdgeInsets.only(bottom: 20),
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: AppColors.premium.withValues(alpha: 0.10),
//         borderRadius: BorderRadius.circular(16),
//         border: Border.all(color: AppColors.premium.withValues(alpha: 0.35)),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Icon(Icons.workspace_premium, color: AppColors.premium, size: 20),
//               const SizedBox(width: 8),
//               Text(
//                 sub.plan != null ? 'You\'re Premium · ${sub.plan}' : 'You\'re Premium',
//                 style: AppTextStyles.bodyStrong,
//               ),
//             ],
//           ),
//           const SizedBox(height: 6),
//           Text(statusLine, style: AppTextStyles.bodyMuted),
//           const SizedBox(height: 4),
//           Text(
//             'Buying a plan below won\'t start a second subscription — it '
//                 'just continues this one.',
//             style: AppTextStyles.caption,
//           ),
//           const SizedBox(height: 10),
//           TextButton(
//             onPressed: isManaging ? null : onManage,
//             style: TextButton.styleFrom(padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
//             child: isManaging
//                 ? SizedBox(
//               height: 16,
//               width: 16,
//               child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.premium),
//             )
//                 : Text(
//               'Manage subscription',
//               style: AppTextStyles.bodyStrong.copyWith(color: AppColors.premium),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// class _PlanCard extends StatelessWidget {
//   const _PlanCard({required this.plan, required this.selected, required this.onTap});
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
//             Text(plan.priceInr!, style: AppTextStyles.caption.copyWith(fontSize: 12)),
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
//
// /// Past renewals and purchases, from `/payments/history`. Stays hidden for
// /// an account with no payment history, so it never clutters a first-time
// /// paywall view.
// class _PaymentHistorySection extends ConsumerWidget {
//   const _PaymentHistorySection();
//
//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     final historyAsync = ref.watch(paymentHistoryProvider);
//
//     return historyAsync.when(
//       loading: () => const SizedBox.shrink(),
//       error: (_, _) => const SizedBox.shrink(),
//       data: (page) {
//         if (page.payments.isEmpty) return const SizedBox.shrink();
//
//         return Padding(
//           padding: const EdgeInsets.only(top: 24),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text('Payment history', style: AppTextStyles.bodyStrong),
//               const SizedBox(height: 10),
//               for (final entry in page.payments) _HistoryRow(entry: entry),
//             ],
//           ),
//         );
//       },
//     );
//   }
// }
//
// class _HistoryRow extends StatelessWidget {
//   const _HistoryRow({required this.entry});
//
//   final PaymentHistoryEntry entry;
//
//   @override
//   Widget build(BuildContext context) {
//     final date = entry.occurredAt ?? entry.purchasedAt;
//
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 8),
//       child: Row(
//         children: [
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text('${entry.typeLabel} · ${entry.plan}', style: AppTextStyles.bodyStrong),
//                 if (date != null)
//                   Text(
//                     '${_formatDate(date)} · ${entry.storeLabel}',
//                     style: AppTextStyles.caption,
//                   ),
//               ],
//             ),
//           ),
//           Text(entry.amountLabel, style: AppTextStyles.bodyStrong),
//         ],
//       ),
//     );
//   }
// }
