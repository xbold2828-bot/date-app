import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../providers/core_providers.dart';
import '../../../providers/profile_provider.dart';
import '../../home/screens/home_screen.dart';

class BasicsScreen7 extends ConsumerStatefulWidget {
  const BasicsScreen7({super.key});

  @override
  ConsumerState<BasicsScreen7> createState() => _BasicsScreen7State();
}

class _BasicsScreen7State extends ConsumerState<BasicsScreen7> {
  final List<Map<String, dynamic>> _agreements = [
    {'text': "I'm 18 or older", 'checked': false},
    {'text': "I'll be respectful", 'checked': false},
    {'text': 'No harassment', 'checked': false},
    {'text': 'Consent always matters', 'checked': false},
  ];

  bool _isLoading = false;

  bool get _allChecked => _agreements.every((a) => a['checked'] == true);

  Future<void> _onEnter() async {
    if (!_allChecked) return;

    setState(() => _isLoading = true);
    try {
      final me = await ref.read(onboardingRepositoryProvider).acceptAgreement();
      ref.read(meProvider.notifier).setMe(me);

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),

              Text(
                'The vibe agreement',
                style: AppTextStyles.display,
              ),
              const SizedBox(height: 6),
              Text(
                'One tap each.',
                style: TextStyle(fontSize: 13, color: AppColors.textGrey),
              ),

              const SizedBox(height: 32),

              // Agreement items
              Expanded(
                child: ListView.separated(
                  itemCount: _agreements.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, index) {
                    final item = _agreements[index];
                    final checked = item['checked'] as bool;

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _agreements[index]['checked'] = !checked;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 18),
                        decoration: BoxDecoration(
                          color: checked
                              ? AppColors.primary.withOpacity(0.06)
                              : AppColors.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: checked
                                ? AppColors.primary
                                : AppColors.inputBorder,
                            width: checked ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: checked
                                    ? AppColors.primary
                                    : AppColors.card,
                                border: Border.all(
                                  color: checked
                                      ? AppColors.primary
                                      : AppColors.inputBorder,
                                  width: 2,
                                ),
                              ),
                              child: checked
                                  ? Icon(Icons.check,
                                      size: 14, color: AppColors.onAccent)
                                  : null,
                            ),
                            const SizedBox(width: 16),
                            Text(
                              item['text'] as String,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: checked
                                    ? AppColors.primary
                                    : AppColors.textDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 20),

              // Enter Radius button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: (_allChecked && !_isLoading) ? _onEnter : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _allChecked
                        ? AppColors.primary
                        : AppColors.textGrey.withOpacity(0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? CircularProgressIndicator(color: AppColors.onAccent)
                      : Text(
                          'Enter Radius',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _allChecked
                                ? AppColors.onAccent
                                : AppColors.textGrey,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}