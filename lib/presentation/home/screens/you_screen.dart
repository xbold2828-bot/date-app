import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/services/auth_service.dart';
import '../../../providers/core_providers.dart';
import '../../../providers/profile_provider.dart';
import '../../auth/screens/login_screen.dart';
import './premium_screen.dart';

class YouScreen extends ConsumerStatefulWidget {
  const YouScreen({super.key});

  @override
  ConsumerState<YouScreen> createState() => _YouScreenState();
}

class _YouScreenState extends ConsumerState<YouScreen> {
  // Populated from meProvider at the top of build().
  Map<String, dynamic> _profile = {
    'name': '',
    'age': null,
    'location': '',
    'isPremium': false,
    'isVerified': false,
    'bio': '',
    'vibes': <String>[],
    'photos': [null, null, null, null],
  };

  Future<void> _onSignOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.white,
        title: const Text('Sign Out',
            style: TextStyle(color: AppColors.textDark)),
        content: const Text('Are you sure you want to sign out?',
            style: TextStyle(color: AppColors.textGrey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textGrey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out',
                style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await AuthService().signOut();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _onDeleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.white,
        title: const Text('Delete Account',
            style: TextStyle(color: Colors.red)),
        content: const Text(
          'This will permanently delete your account and all data. This cannot be undone.',
          style: TextStyle(color: AppColors.textGrey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textGrey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await ref.read(profileRepositoryProvider).deleteAccount();
      } catch (_) {
        // Even if the server call fails, sign out locally.
      }
      await AuthService().signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(meProvider).valueOrNull;
    if (me == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    _profile = {
      'name': me.displayName ?? 'You',
      'age': me.age,
      'location': me.location?.city ?? '',
      'isPremium': me.premium.isActive,
      'isVerified': me.verified,
      'bio': me.profile.bio ?? '',
      'vibes': me.profile.personalityTags,
      'photos': const [null, null, null, null],
    };
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.radio_button_checked,
                        size: 20, color: AppColors.textDark),
                    const SizedBox(width: 8),
                    const Text(
                      'RADIUS',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                
              ],
            ),
          ),

          // Profile header
          Center(
            child: Column(
              children: [
                // Avatar with verified ring
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Verified ring
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _profile['isVerified'] == true
                              ? Colors.green
                              : AppColors.inputBorder,
                          width: 2.5,
                        ),
                      ),
                    ),

                    // Photo
                    Container(
                      width: 92,
                      height: 92,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF6B7A8B),
                        border: Border.all(
                            color: AppColors.white, width: 3),
                      ),
                      child: ClipOval(
                        child: _profile['photos'][0] != null
                            ? Image.network(
                                _profile['photos'][0] as String,
                                fit: BoxFit.cover,
                              )
                            : const Icon(Icons.person,
                                size: 40, color: AppColors.white),
                      ),
                    ),

                    // Verified badge
                    if (_profile['isVerified'] == true)
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: AppColors.white, width: 2),
                          ),
                          child: const Icon(Icons.check,
                              size: 12, color: AppColors.white),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 12),

                // Name + age
                Text(
                  '${_profile['name']}, ${_profile['age']}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),

                const SizedBox(height: 6),

                // Premium badge
                if (_profile['isPremium'] == true)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: AppColors.primary.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.circle,
                            size: 8, color: AppColors.primary),
                        SizedBox(width: 6),
                        Text(
                          'PREMIUM',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 6),

                // Location
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 14, color: AppColors.textGrey),
                    const SizedBox(width: 4),
                    Text(
                      _profile['location'] as String,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textGrey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // Gallery
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'GALLERY',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textGrey,
                    letterSpacing: 1.2,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    // TODO: Navigate to edit photos screen
                  },
                  child: const Text(
                    'Edit All',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Photo grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Primary large photo
                Expanded(
                  flex: 5,
                  child: _photoSlot(0, height: 200, isPrimary: true),
                ),
                const SizedBox(width: 8),
                // Two small + two add slots
                Expanded(
                  flex: 4,
                  child: Column(
                    children: [
                      _photoSlot(1, height: 96),
                      const SizedBox(height: 8),
                      _photoSlot(2, height: 96),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Two add slots row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(child: _addSlot()),
                const SizedBox(width: 8),
                Expanded(child: _addSlot()),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // My Vibe section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.inputBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'MY VIBE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textGrey,
                          letterSpacing: 1.2,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          // TODO: Navigate to edit vibes screen
                        },
                        child: const Icon(Icons.edit_outlined,
                            size: 16, color: AppColors.textGrey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: (_profile['vibes'] as List<String>)
                        .map((vibe) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(
                                    color: AppColors.inputBorder),
                              ),
                              child: Text(
                                vibe,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textDark,
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Bio section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.inputBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'BIO',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textGrey,
                          letterSpacing: 1.2,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          // TODO: Navigate to edit bio screen
                        },
                        child: const Icon(Icons.edit_outlined,
                            size: 16, color: AppColors.textGrey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _profile['bio'] as String,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textDark,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Account verification
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _profile['isVerified'] == true
                      ? Colors.green.withOpacity(0.3)
                      : AppColors.inputBorder,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.verified_outlined,
                        size: 18, color: Colors.green),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ACCOUNT VERIFICATION',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textGrey,
                            letterSpacing: 1,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Identity Verified',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                        Text(
                          'Your profile is trusted and visible to others.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.check_circle,
                      size: 20, color: Colors.green),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Radius Premium card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.radio_button_checked,
                          size: 20, color: AppColors.primary),
                      SizedBox(width: 8),
                      Text(
                        'Radius Premium',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Unlimited radius expansion and priority verification are active.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white60,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                     onPressed: () {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const PremiumScreen()),
  );
},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Manage Subscription',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Safety Center
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _menuTile(
              icon: Icons.security_outlined,
              label: 'Safety Center',
              onTap: () {
                // TODO: Navigate to safety center
              },
            ),
          ),

          const SizedBox(height: 8),

          // Sign Out
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _menuTile(
              icon: Icons.logout_outlined,
              label: 'Sign Out',
              onTap: _onSignOut,
            ),
          ),

          const SizedBox(height: 16),

          // Delete account
          Center(
            child: GestureDetector(
              onTap: _onDeleteAccount,
              child: const Text(
                'Delete Account',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _photoSlot(int index, {required double height, bool isPrimary = false}) {
    final photos = _profile['photos'] as List;
    final hasPhoto = index < photos.length && photos[index] != null;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: hasPhoto ? null : const Color(0xFF6B7A8B),
        borderRadius: BorderRadius.circular(12),
        border: hasPhoto ? null : Border.all(color: AppColors.inputBorder),
      ),
      child: hasPhoto
          ? ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                photos[index] as String,
                fit: BoxFit.cover,
                width: double.infinity,
              ),
            )
          : Center(
              child: Icon(
                isPrimary ? Icons.person : Icons.add_a_photo_outlined,
                size: isPrimary ? 36 : 24,
                color: AppColors.white.withOpacity(0.7),
              ),
            ),
    );
  }

  Widget _addSlot() {
    return GestureDetector(
      onTap: () {
        // TODO: Open image picker to add photo
      },
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.inputBorder),
        ),
        child: const Center(
          child: Icon(Icons.add, size: 22, color: AppColors.textGrey),
        ),
      ),
    );
  }

  Widget _menuTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.inputBorder),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.textDark),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textDark,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(Icons.chevron_right,
                size: 20, color: AppColors.textGrey),
          ],
        ),
      ),
    );
  }
}