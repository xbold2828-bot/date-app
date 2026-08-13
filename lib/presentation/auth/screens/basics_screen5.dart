import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/utils/onboarding_maps.dart';
import '../../../providers/core_providers.dart';
import '../../../providers/profile_provider.dart';
import 'basics_screen7.dart';

class BasicsScreen5 extends ConsumerStatefulWidget {
  const BasicsScreen5({super.key});

  @override
  ConsumerState<BasicsScreen5> createState() => _BasicsScreen5State();
}

class _BasicsScreen5State extends ConsumerState<BasicsScreen5> {
  String? _selectedRadius;
  bool _isLoading = false;

  final List<Map<String, String>> _radiusOptions = [
    {'label': 'Immediate', 'value': '<2 km'},
    {'label': 'Local', 'value': '2–5 km'},
    {'label': 'Extended', 'value': '5–10 km'},
    {'label': 'Regional', 'value': '10 km+'},
  ];

  Future<void> _onAllow() async {
    setState(() => _isLoading = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _showSnack('Please turn on location services and try again.');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showSnack('Location permission is needed to find people near you.');
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      final me = await ref.read(onboardingRepositoryProvider).updateLocation(
            latitude: position.latitude,
            longitude: position.longitude,
            preferredBand: normalizeDistanceBand(_selectedRadius),
          );
      ref.read(meProvider.notifier).setMe(me);

      if (mounted) {
        // Straight to the agreement, skipping the live identity check.
        //
        // There is no verification provider behind that screen — the backend
        // runs a mock — so it was a camera ceremony that could not actually
        // verify anyone, sitting between people and a finished profile. It is
        // not an onboarding step the API tracks either, so nothing downstream
        // notices its absence. BasicsScreen6 is left in the tree, unrouted, to
        // be wired back in when real verification ships alongside
        // `REQUIRE_IDENTITY_VERIFICATION` on the backend.
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BasicsScreen7()),
        );
      }
    } on AppException catch (e) {
      _showSnack(e.message);
    } catch (e) {
      _showSnack('Could not get your location. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
              const SizedBox(height: 16),

              // Top bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.textDark, width: 2),
                        ),
                        child: const Center(
                          child: Icon(Icons.circle, size: 10, color: AppColors.primary),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Radius',
                        style: AppTextStyles.title,
                      ),
                    ],
                  ),
                  // Progress indicator
                  Row(
                    children: [
                      SizedBox(
                        width: 80,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: 5 / 6,
                            minHeight: 3,
                            backgroundColor: AppColors.inputBorder,
                            valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        '5/6',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textGrey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 40),

              Text(
                'Your Radius',
                style: AppTextStyles.display,
              ),
              const SizedBox(height: 8),
              const Text(
                'Radius uses your location to connect you with people physically near you right now.',
                style: TextStyle(fontSize: 13, color: AppColors.textGrey),
              ),

              const SizedBox(height: 40),

              // 2x2 radius grid
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 2,
                children: _radiusOptions.map((option) {
                  final selected = _selectedRadius == option['value'];
                  return GestureDetector(
                    onTap: () => setState(() => _selectedRadius = option['value']),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primary.withOpacity(0.08)
                            : AppColors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected ? AppColors.primary : AppColors.inputBorder,
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            option['label']!,
                            style: TextStyle(
                              fontSize: 11,
                              color: selected ? AppColors.primary : AppColors.textGrey,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            option['value']!,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: selected ? AppColors.primary : AppColors.textDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),

              const Spacer(),

              // Privacy note
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.shield_outlined, size: 16, color: AppColors.primary),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Others only see a band, never your exact spot.",
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Allow location button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _onAllow,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: AppColors.white)
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.near_me, color: AppColors.white, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Allow location',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.white,
                              ),
                            ),
                          ],
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