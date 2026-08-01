import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  String _selectedPlan = 'monthly';
  bool _isLoading = false;

  final List<Map<String, dynamic>> _plans = [
    {
      'id': 'weekly',
      'label': 'Weekly',
      'sublabel': 'Short-term access',
      'price': '\$4.99',
      'isBestValue': false,
    },
    {
      'id': 'monthly',
      'label': 'Monthly',
      'sublabel': 'Our most popular plan',
      'price': '\$14.99',
      'isBestValue': true,
    },
    {
      'id': 'yearly',
      'label': 'Yearly',
      'sublabel': 'Annual commitment',
      'price': '\$99.99',
      'isBestValue': false,
    },
  ];

  final List<Map<String, dynamic>> _features = [
    {
      'icon': Icons.remove_circle_outline,
      'title': 'No ads',
      'subtitle': 'Pure browsing without interruptions or visual noise.',
    },
    {
      'icon': Icons.all_inclusive,
      'title': 'Unlimited discovery',
      'subtitle': 'No daily limits on viewing potential connections.',
    },
    {
      'icon': Icons.remove_red_eye_outlined,
      'title': 'See who liked you',
      'subtitle': 'Remove the veil and see your admirers instantly.',
    },
    {
      'icon': Icons.tune,
      'title': 'Advanced filters',
      'subtitle': 'Refine your search with precision verification metrics.',
    },
  ];

  Future<void> _onStartPremium() async {
    setState(() => _isLoading = true);

    // TODO: SubscriptionService.purchase(_selectedPlan)
    // TODO: Handle payment flow (in_app_purchase package)
    await Future.delayed(const Duration(milliseconds: 800));

    setState(() => _isLoading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Premium activated! 🎉'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back,
                        color: AppColors.textDark),
                  ),
                  const Text(
                    'RADIUS',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                      letterSpacing: 1.2,
                    ),
                  ),
                  // User avatar
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF6B7A8B),
                    ),
                    child: const Icon(Icons.person,
                        size: 20, color: AppColors.white),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 16),

                    // Icon
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.radio_outlined,
                        size: 36,
                        color: AppColors.primary,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Heading
                    const Text(
                      'Unlock Radius Premium',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Elevate your discovery experience with our most exclusive features and tools.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textGrey,
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Feature cards
                    ...(_features.map((f) => _featureCard(f))),

                    const SizedBox(height: 28),

                    // Plan selector
                    ...(_plans.map((plan) => _planTile(plan))),

                    const SizedBox(height: 24),

                    // Start Premium button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _onStartPremium,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: AppColors.white)
                            : const Text(
                                'Start Premium',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.white,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Recurring billing note
                    const Text(
                      'Recurring billing. Cancel anytime.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textGrey,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Restore + Terms
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: () {
                            // TODO: SubscriptionService.restorePurchases()
                          },
                          child: const Text(
                            'Restore Purchases',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text('•',
                              style: TextStyle(color: AppColors.textGrey)),
                        ),
                        GestureDetector(
                          onTap: () {
                            // TODO: Launch terms of service URL
                          },
                          child: const Text(
                            'Terms of Service',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Legal text
                    const Text(
                      'Payment will be charged to your Account at confirmation of purchase. Subscription automatically renews unless auto-renew is turned off at least 24-hours before the end of the current period.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textGrey,
                        height: 1.5,
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _featureCard(Map<String, dynamic> feature) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            feature['icon'] as IconData,
            size: 22,
            color: AppColors.primary,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feature['title'] as String,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  feature['subtitle'] as String,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textGrey,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _planTile(Map<String, dynamic> plan) {
    final isSelected = _selectedPlan == plan['id'];
    final isBestValue = plan['isBestValue'] as bool;

    return GestureDetector(
      onTap: () => setState(() => _selectedPlan = plan['id'] as String),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.05)
              : AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.inputBorder,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        plan['label'] as String,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textDark,
                        ),
                      ),
                      if (isBestValue) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'BEST VALUE',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: AppColors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    plan['sublabel'] as String,
                    style: TextStyle(
                      fontSize: 12,
                      color: isSelected
                          ? AppColors.primary.withOpacity(0.7)
                          : AppColors.textGrey,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              plan['price'] as String,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isSelected ? AppColors.primary : AppColors.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}