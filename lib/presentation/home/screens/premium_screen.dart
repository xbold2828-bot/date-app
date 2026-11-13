import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../providers/subscription_provider.dart';
import '../../common/widgets/widgets.dart';
import 'package:dating_app/core/constants/app_string.dart';


/// One purchasable plan, as this screen needs to draw it.
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

  static List<_Plan> get _fallbackPlans => [
    _Plan(
      id: 'monthly',
      label: AppString.planMonthlyLabel,
      sublabel: AppString.planMonthlySublabel,
      price: r'$14.99',
      isBestValue: true,
    ),
    _Plan(
      id: 'weekly',
      label: AppString.planWeeklyLabel,
      sublabel: AppString.planWeeklySublabel,
      price: r'$4.99',
    ),
    _Plan(
      id: 'yearly',
      label: AppString.planYearlyLabel,
      sublabel: AppString.planYearlySublabel,
      price: r'$99.99',
    ),
  ];

  static List<_Benefit> get _benefits => [
    _Benefit(AppString.benefitSeeEveryoneClaim, AppString.benefitSeeEveryoneDetail),
    _Benefit(AppString.benefitSeeWhoLikedClaim, AppString.benefitSeeWhoLikedDetail),
    _Benefit(AppString.benefitNoAdsClaim, AppString.benefitNoAdsDetail),
    _Benefit(AppString.benefitEveryFilterClaim, AppString.benefitEveryFilterDetail),
    _Benefit(AppString.benefitStartConvoClaim, AppString.benefitStartConvoDetail),
  ];

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


  Future<void> _onStartPremium() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final result =
      await ref.read(subscriptionActionsProvider).checkout(_selectedPlan);

      if (!mounted) return;
      if (result.isConfirmed) {
        showRadiusToast(context, AppString.premiumStarted);
        Navigator.pop(context);
      } else {
        showRadiusToast(context, AppString.premiumFinishPayment);
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
            ? AppString.premiumRestored
            : AppString.premiumNoPurchaseFound,
      );
    } on AppException catch (e) {
      if (mounted) showRadiusToast(context, e.message);
    } finally {
      if (mounted) setState(() => _isRestoring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  Text(AppString.cozunePremium, style: AppTextStyles.eyebrow),
                  const SizedBox(height: 10),
                  Text(
                    AppString.premiumTitle,
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
                    label: AppString.startPremiumPrice(current.price),
                    kind: RadiusButtonKind.premium,
                    isLoading: _isLoading,
                    onPressed: _onStartPremium,
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton(
                      onPressed: _isRestoring ? null : _onRestore,
                      child: Text(
                        _isRestoring ? AppString.restoring : AppString.restorePurchase,
                        style: AppTextStyles.bodyStrong.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    AppString.premiumBillingNote,
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
              AppString.bestValue,
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
