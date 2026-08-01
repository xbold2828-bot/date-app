import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/utils/onboarding_maps.dart';
import '../../../providers/core_providers.dart';
import '../../../providers/profile_provider.dart';
import 'basics_screen3.dart';

class BasicsScreen2 extends ConsumerStatefulWidget {
  const BasicsScreen2({super.key});

  @override
  ConsumerState<BasicsScreen2> createState() => _BasicsScreen2State();
}

class _BasicsScreen2State extends ConsumerState<BasicsScreen2> {
  final List<String> _intents =
      kIntentOptions.map((e) => e.key).toList();
  final List<String> _atmospheres = [
    'Quietly Confident', 'Adventurous',
    'Artistic', 'Deep Conversationalist',
    'Night Owl', 'Minimalist',
  ];

  String? _selectedIntent;
  final Set<String> _selectedAtmospheres = {};
  bool _isLoading = false;

  Future<void> _onContinue() async {
    if (_selectedIntent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your current intent')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final intentValue = kIntentOptions
          .firstWhere((e) => e.key == _selectedIntent)
          .value;
      final me = await ref
          .read(onboardingRepositoryProvider)
          .updateIntent([intentValue]);
      ref.read(meProvider.notifier).setMe(me);
      // NOTE: "Your Atmosphere" tags aren't persisted yet — they map to the
      // personality catalogue (GET /tags?category=personality), a Pass-2 rework.

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BasicsScreen3()),
        );
      }
    } on AppException catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),

            // Step indicator circle
            // Center(
            //   child: Stack(
            //     alignment: Alignment.center,
            //     children: [
            //       SizedBox(
            //         width: 56,
            //         height: 56,
            //         child: CircularProgressIndicator(
            //           value: 2 / 4,
            //           strokeWidth: 3,
            //           backgroundColor: AppColors.inputBorder,
            //           valueColor: const AlwaysStoppedAnimation(AppColors.primary),
            //         ),
            //       ),
            //       Container(
            //         width: 36,
            //         height: 36,
            //         decoration: BoxDecoration(
            //           shape: BoxShape.circle,
            //           border: Border.all(color: AppColors.textDark, width: 2),
            //         ),
            //         child: const Center(
            //           child: Icon(Icons.circle, size: 12, color: AppColors.primary),
            //         ),
            //       ),
            //     ],
            //   ),
            // ),

            Padding(
  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
  child: Row(
    children: [
      GestureDetector(
        onTap: () => Navigator.pop(context),
        child: const Icon(Icons.arrow_back, color: AppColors.textDark),
      ),
      const Expanded(
        child: Center(
          child: Text(
            'Radius',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
        ),
      ),
      const SizedBox(width: 24),
    ],
  ),
),


             // Progress bar — step 2 of 6
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text(
                        'STEP 2 OF 6',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                          letterSpacing: 1.1,
                        ),
                      ),
                      Text(
                        'IDENTITY',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textGrey,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: 2 / 6,
                      minHeight: 3,
                      backgroundColor: AppColors.inputBorder,
                      valueColor:
                          const AlwaysStoppedAnimation(AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            const Text(
              'STEP 02 OF 06',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 1.2,
                color: AppColors.textGrey,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Define your Radius.',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),

            const SizedBox(height: 24),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Current Intent
                    const Text(
                      'Current Intent',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'What are you looking for today?',
                      style: TextStyle(fontSize: 13, color: AppColors.textGrey),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _intents.map((intent) => _chip(
                        label: intent,
                        selected: _selectedIntent == intent,
                        onTap: () => setState(() => _selectedIntent = intent),
                      )).toList(),
                    ),

                    const SizedBox(height: 32),

                    // Your Atmosphere
                    const Text(
                      'Your Atmosphere',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Select the qualities that describe you.',
                      style: TextStyle(fontSize: 13, color: AppColors.textGrey),
                    ),
                    const SizedBox(height: 14),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 3,
                      children: _atmospheres.map((a) => _chip(
                        label: a,
                        selected: _selectedAtmospheres.contains(a),
                        onTap: () {
                          setState(() {
                            if (_selectedAtmospheres.contains(a)) {
                              _selectedAtmospheres.remove(a);
                            } else {
                              _selectedAtmospheres.add(a);
                            }
                          });
                        },
                      )).toList(),
                    ),

                    const SizedBox(height: 32),

                    // Continue to Verification button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _onContinue,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: AppColors.white)
                            : const Text(
                                'Continue to Verification',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.white,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Skip
                    Center(
                      child: GestureDetector(
                        onTap: () {
                          // TODO: GoRouter.of(context).go('/home')
                        },
                        child: const Text(
                          'Skip for now',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textGrey,
                          ),
                        ),
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

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withOpacity(0.1) : AppColors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.inputBorder,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: selected ? AppColors.primary : AppColors.textDark,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}