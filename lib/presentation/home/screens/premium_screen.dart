import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../providers/subscription_provider.dart';
import '../../common/widgets/widgets.dart';

/// One purchasable plan.
class _Plan {
  const _Plan({
    required this.id,
    required this.label,
    required this.sublabel,
    required this.price,
    this.isBestValue = false,
  });

  final String id;
  final String label;

  /// What choosing this actually means, in plain terms.
  final String sublabel;
  final String price;
  final bool isBestValue;
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

  static const List<_Plan> _plans = [
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
    _Benefit(
      'Every filter',
      'Online now, verified, situation, vibe and desires.',
    ),
    _Benefit('Start any conversation', 'No cap on openers.'),
  ];

  _Plan get _current =>
      _plans.firstWhere((p) => p.id == _selectedPlan, orElse: () => _plans[0]);

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
                  Text('Radius Premium', style: AppTextStyles.eyebrow),
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

                  ..._plans.map(
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
                    // costs.
                    label: 'Start Premium · ${_current.price}',
                    kind: RadiusButtonKind.gold,
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
      trailing: Text(
        plan.price,
        style: AppTextStyles.title.copyWith(
          fontSize: 22,
          color: selected ? AppColors.primaryDeep : AppColors.textDark,
        ),
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
              color: AppColors.gold,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'BEST VALUE',
              style: AppTextStyles.caption.copyWith(
                fontSize: 10,
                color: AppColors.white,
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
