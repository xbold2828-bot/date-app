import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/services/auth_service.dart';
import '../../auth/screens/login_screen.dart';
import './profile_detail_sheet.dart';
import './request_screen.dart';
import './favourites_screen.dart';
import './you_screen.dart';
import './premium_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentTab = 0;
  String _selectedFilter = 'All';

  final List<String> _filters = ['All', 'Casual', 'Dating', 'Right now'];

  // Mock data — replace with API call later
  final List<Map<String, dynamic>> _circleUsers = [
  {
    'name': 'Maya',
    'age': 26,
    'distance': '<1 km',
    'online': true,
    'color': const Color(0xFFB5A89A),
    'bio': 'Living life one coffee at a time ☕',
    'vibes': ['Foodie', 'Night owl', 'Music'],
    'photoUrl': null, 
    'id': 'mock-1',  
  },
  {
    'name': 'Sarah',
    'age': 24,
    'distance': '2 km',
    'online': true,
    'color': const Color(0xFF8B6F6F),
    'bio': 'Adventure seeker and dog lover 🐶',
    'vibes': ['Travel', 'Fitness', 'Art'],
    'photoUrl': null,
    'id': 'mock-2',
  },
  {
    'name': 'Elena',
    'age': 27,
    'distance': '5 km',
    'online': true,
    'color': const Color(0xFF4A4A5A),
    'bio': 'Books, wine and good conversations 🍷',
    'vibes': ['Reading', 'Wine', 'Yoga'],
    'photoUrl': null,
    'id': 'mock-3',
  },
];

  final List<Color> _lockedCardColors = [
    const Color(0xFFB8C8D0),
    const Color(0xFFC8C0D0),
    const Color(0xFFD4C0B0),
    const Color(0xFFC0B8C8),
    const Color(0xFFD0C8B8),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _buildCurrentTab(),
            ),
            _buildBottomNav(),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentTab() {
    switch (_currentTab) {
      case 0:
        return _buildNearbyTab();
     case 1:
  return const RequestsScreen();
      case 2:
  return const FavoritesScreen();
      case 3:
  return const YouScreen();
      default:
        return _buildNearbyTab();
    }
  }

  Widget _buildNearbyTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),

          // Top bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Near you',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  Text(
                    'New York',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textGrey,
                    ),
                  ),
                ],
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.inputBorder),
                ),
                child: const Icon(Icons.tune,
                    size: 20, color: AppColors.textDark),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _filters.map((filter) {
                final isSelected = _selectedFilter == filter;
                return GestureDetector(
                  onTap: () => setState(() => _selectedFilter = filter),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.textDark
                          : AppColors.white,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.textDark
                            : AppColors.inputBorder,
                      ),
                    ),
                    child: Text(
                      filter,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isSelected
                            ? AppColors.white
                            : AppColors.textDark,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 28),

          // In your circle
          const Text(
            'In your circle',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),

          const SizedBox(height: 14),

          // Circle cards horizontal scroll
          SizedBox(
            height: 180,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _circleUsers.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, index) {
                final user = _circleUsers[index];
                return _circleCard(user);
              },
            ),
          ),

          const SizedBox(height: 32),

          // Discovery limit
          Center(
            child: Column(
              children: [
                const Text(
                  'Discovery Limit',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Unlock 100+ more nearby',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.textGrey),
                ),
                const SizedBox(height: 16),
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
                GestureDetector(
                  onTap: () {},
                  child: const Text(
                    'Watch an ad to unlock',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Locked cards grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.75,
            ),
            itemCount: 5,
            itemBuilder: (_, index) => _lockedCard(index),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

 Widget _circleCard(Map<String, dynamic> user) {
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
      width: 130,
      decoration: BoxDecoration(
        color: user['color'] as Color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          // Online indicator
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: user['online'] == true
                    ? Colors.green
                    : Colors.red,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.white, width: 1.5),
              ),
            ),
          ),

          // Name, age, distance at bottom
          Positioned(
            bottom: 10,
            left: 10,
            right: 10,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${user['name']}, ${user['age']}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on,
                        size: 11, color: AppColors.white),
                    const SizedBox(width: 2),
                    Text(
                      user['distance'] as String,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.white,
                      ),
                    ),
                  ],
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
    return Container(
      decoration: BoxDecoration(
        color: _lockedCardColors[index],
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.3),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.lock_outline,
              size: 16, color: AppColors.white),
        ),
      ),
    );
  }

  Widget _buildPlaceholderTab(String title) {
    return Center(
      child: Text(
        '$title coming soon',
        style: const TextStyle(
          fontSize: 16,
          color: AppColors.textGrey,
        ),
      ),
    );
  }

  Widget _buildProfileTab() {
    final user = AuthService().currentUser;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withOpacity(0.1),
              border: Border.all(color: AppColors.primary, width: 2),
            ),
            child: const Icon(Icons.person,
                size: 40, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text(
            user?.email ?? user?.phone ?? 'User',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: ElevatedButton(
              onPressed: () async {
                await AuthService().signOut();
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Sign Out',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    final items = [
      {'icon': Icons.explore, 'label': 'Nearby'},
      {'icon': Icons.mail_outline, 'label': 'Requests'},
      {'icon': Icons.favorite_border, 'label': 'Favorites'},
      {'icon': Icons.person_outline, 'label': 'You'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border(
          top: BorderSide(color: AppColors.inputBorder, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(items.length, (index) {
          final isActive = _currentTab == index;
          return GestureDetector(
            onTap: () => setState(() => _currentTab = index),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  items[index]['icon'] as IconData,
                  size: 24,
                  color: isActive
                      ? AppColors.primary
                      : AppColors.textGrey,
                ),
                const SizedBox(height: 4),
                Text(
                  items[index]['label'] as String,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isActive
                        ? FontWeight.w600
                        : FontWeight.normal,
                    color: isActive
                        ? AppColors.primary
                        : AppColors.textGrey,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}