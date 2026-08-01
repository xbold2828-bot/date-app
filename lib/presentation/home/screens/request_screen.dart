import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import './chat_detail_screen.dart';

class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Mock data — replace with API call
  final List<Map<String, dynamic>> _vibingList = [
    {
      'id': 'mock-1',
      'name': 'Julian',
      'lastMessage': 'That gallery opening next ...',
      'time': '12m',
      'online': true,
      'color': const Color(0xFFB5A89A),
      'unread': false,
    },
    {
      'id': 'mock-2',
      'name': 'Elena',
      'lastMessage': "I've actually never been th...",
      'time': '2h',
      'online': true,
      'color': const Color(0xFF4A4A5A),
      'unread': false,
    },
  ];

  final List<Map<String, dynamic>> _newEnergyList = [
    // TODO: ChatService.getNewRequests()
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Top bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
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
                      child: Icon(Icons.circle,
                          size: 10, color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Requests',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
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
        ),

        // Tabs
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppColors.inputBorder, width: 1),
            ),
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textGrey,
            indicatorColor: AppColors.primary,
            indicatorWeight: 2,
            labelStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.normal,
            ),
            tabs: const [
              Tab(text: 'Vibing'),
              Tab(text: 'New Energy'),
            ],
          ),
        ),

        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildChatList(_vibingList),
              _buildChatList(_newEnergyList),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChatList(List<Map<String, dynamic>> list) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined,
                size: 48, color: AppColors.textGrey.withOpacity(0.4)),
            const SizedBox(height: 12),
            const Text(
              'Nothing here yet',
              style: TextStyle(fontSize: 15, color: AppColors.textGrey),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, index) => _chatTile(list[index]),
    );
  }

  Widget _chatTile(Map<String, dynamic> user) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ChatDetailScreen(user: user),
    ),
  );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.inputBorder),
        ),
        child: Row(
          children: [
            // Avatar with online dot
            Stack(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: user['color'] as Color,
                  ),
                  child: user['photoUrl'] != null
                      ? ClipOval(
                          child: Image.network(
                            user['photoUrl'] as String,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Center(
                          child: Text(
                            (user['name'] as String)[0].toUpperCase(),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.white,
                            ),
                          ),
                        ),
                ),
                // Online + verified badge
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.white, width: 1.5),
                    ),
                    child: const Icon(Icons.check,
                        size: 9, color: AppColors.white),
                  ),
                ),
              ],
            ),

            const SizedBox(width: 12),

            // Name + last message
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user['name'] as String,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    user['lastMessage'] as String,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textGrey,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Time + options
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  user['time'] as String,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textGrey,
                  ),
                ),
                const SizedBox(height: 6),
                const Icon(Icons.more_vert,
                    size: 18, color: AppColors.textGrey),
              ],
            ),
          ],
        ),
      ),
    );
  }
}