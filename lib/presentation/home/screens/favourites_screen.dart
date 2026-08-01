import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import 'profile_detail_sheet.dart';
import './premium_screen.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  // Mock data — replace with MatchService.getLikes()
  static final List<Map<String, dynamic>> _likedYou = [
    {
      'id': 'mock-1',
      'name': 'Julian',
      'age': 29,
      'distance': '<1 km',
      'online': true,
      'color': const Color(0xFF4A5568),
      'photoUrl': null,
      'vibes': ['Art', 'Music', 'Coffee'],
    },
    {
      'id': 'mock-2',
      'name': 'Maya',
      'age': 26,
      'distance': '2 km',
      'online': true,
      'color': const Color(0xFFB5A89A),
      'photoUrl': null,
      'vibes': ['Foodie', 'Night owl', 'Music'],
    },
    {
      'id': 'mock-3',
      'name': 'Leo',
      'age': 31,
      'distance': '3 km',
      'online': true,
      'color': const Color(0xFF8BA3B5),
      'photoUrl': null,
      'vibes': ['Travel', 'Fitness', 'Books'],
    },
    {
      'id': 'mock-4',
      'name': 'Soren',
      'age': 28,
      'distance': '4 km',
      'online': true,
      'color': const Color(0xFF7A6B5A),
      'photoUrl': null,
      'vibes': ['Photography', 'Coffee', 'Jazz'],
    },
    {
      'id': 'mock-5',
      'name': 'Elena',
      'age': 30,
      'distance': '5 km',
      'online': true,
      'color': const Color(0xFF6B7A8B),
      'photoUrl': null,
      'vibes': ['Reading', 'Wine', 'Yoga'],
    },
  ];

  // Locked placeholder count
  static const int _lockedCount = 3;

  @override
  Widget build(BuildContext context) {
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
                    // Avatar placeholder
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.inputBorder,
                      ),
                      child: const Icon(Icons.person,
                          size: 20, color: AppColors.textGrey),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Radius',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                  ],
                ),
                
              ],
            ),
          ),

          // Heading
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Liked You',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'People who are vibing with your profile',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textGrey,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Liked you grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.72,
              ),
              itemCount: _likedYou.length,
              itemBuilder: (context, index) =>
                  _likeCard(context, _likedYou[index]),
            ),
          ),

          const SizedBox(height: 10),

          // Discovery limit section with blurred locked cards behind
          Stack(
            children: [
              // Locked blurred cards grid
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: _lockedCount,
                  itemBuilder: (_, index) => _lockedCard(index),
                ),
              ),

              // Discovery limit overlay
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.background.withOpacity(0.0),
                        AppColors.background.withOpacity(0.85),
                        AppColors.background,
                      ],
                      stops: const [0.0, 0.3, 0.5],
                    ),
                  ),
                ),
              ),

              // Text + buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 80, 20, 24),
                child: Column(
                  children: [
                    const Text(
                      'Discovery Limit',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'You have more likes. Unlock the full list to see everyone who liked you.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textGrey,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Get Premium button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const PremiumScreen()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Get Premium',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.white,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Watch ad button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton(
                        onPressed: () {
                          // TODO: AdService.showRewardedAd()
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.inputBorder),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.play_circle_outline,
                                size: 18, color: AppColors.textDark),
                            SizedBox(width: 8),
                            Text(
                              'Watch an Ad to Unlock',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _likeCard(BuildContext context, Map<String, dynamic> user) {
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => ProfileDetailSheet(user: user),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: user['color'] as Color,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Stack(
          children: [
            // Photo
            if (user['photoUrl'] != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(
                  user['photoUrl'] as String,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),

            // Gradient overlay at bottom
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.6),
                    ],
                    stops: const [0.5, 1.0],
                  ),
                ),
              ),
            ),

            // Name, age, verified
            Positioned(
              bottom: 8,
              left: 8,
              right: 8,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${user['name']}, ${user['age']}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    width: 14,
                    height: 14,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check,
                        size: 8, color: AppColors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _lockedCard(int index) {
    final colors = [
      const Color(0xFFB8C8D0),
      const Color(0xFFC8C0D0),
      const Color(0xFFD4C0B0),
    ];
    return Container(
      decoration: BoxDecoration(
        color: colors[index % colors.length],
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.3),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.lock_outline,
              size: 14, color: AppColors.white),
        ),
      ),
    );
  }
}