import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class ChatDetailScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const ChatDetailScreen({super.key, required this.user});

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;

  // Mock messages — replace with ChatService.getMessages(userId)
  final List<Map<String, dynamic>> _messages = [
    {
      'id': '1',
      'text': 'I saw you were nearby at the gallery earlier! What did you think of the new installation?',
      'isMine': false,
      'time': '2:41 PM',
      'status': null,
    },
    {
      'id': '2',
      'text': 'The scale of it was incredible. I loved how they used the negative space. Are you a regular there?',
      'isMine': true,
      'time': '2:43 PM',
      'status': 'read', // null, 'sent', 'delivered', 'read'
    },
    {
      'id': '3',
      'text': 'I try to go once a month. It\'s one of my favorite "radius" spots. We should grab a coffee nearby sometime soon and compare notes?',
      'isMine': false,
      'time': '2:45 PM',
      'status': null,
    },
  ];

  @override
  void initState() {
    super.initState();
    // Simulate typing indicator
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _isTyping = true);
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'text': text,
        'isMine': true,
        'time': _formatTime(DateTime.now()),
        'status': 'sent',
      });
      _isTyping = false;
    });

    _messageController.clear();

    // TODO: ChatService.sendMessage(
    //   toUserId: widget.user['id'],
    //   message: text,
    // )

    // Scroll to bottom
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(user),
            Expanded(
              child: _buildMessageList(),
            ),
            if (_isTyping) _buildTypingIndicator(),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(Map<String, dynamic> user) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border(
          bottom: BorderSide(color: AppColors.inputBorder, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back, color: AppColors.textDark),
          ),

          const SizedBox(width: 10),

          // Avatar
          Stack(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: user['color'] as Color? ?? AppColors.inputBorder,
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
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.white,
                          ),
                        ),
                      ),
              ),
            ],
          ),

          const SizedBox(width: 10),

          // Name, age, distance
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${user['name']}, ${user['age']}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Verified badge
                    Container(
                      width: 18,
                      height: 18,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check,
                          size: 11, color: AppColors.white),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 12, color: AppColors.textGrey),
                    const SizedBox(width: 2),
                    Text(
                      user['distance'] as String? ?? '',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textGrey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Action icons
          Row(
            children: [
              _topBarIcon(Icons.phone_outlined, () {
                // TODO: initiate voice call
              }),
              const SizedBox(width: 4),
              _topBarIcon(Icons.videocam_outlined, () {
                // TODO: initiate video call
              }),
              const SizedBox(width: 4),
              _topBarIcon(Icons.more_vert, () {
                _showOptionsMenu();
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _topBarIcon(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.background,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: AppColors.textDark),
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _messages.length + 1, // +1 for date header
      itemBuilder: (_, index) {
        if (index == 0) return _buildDateHeader('TODAY');
        final msg = _messages[index - 1];
        return _buildMessageBubble(msg);
      },
    );
  }

  Widget _buildDateHeader(String label) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 16),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.inputBorder),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textGrey,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg) {
    final isMine = msg['isMine'] as bool;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment:
            isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMine) const SizedBox(width: 4),
              Flexible(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.72,
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isMine ? AppColors.primary : AppColors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isMine ? 18 : 4),
                      bottomRight: Radius.circular(isMine ? 4 : 18),
                    ),
                    border: isMine
                        ? null
                        : Border.all(color: AppColors.inputBorder),
                  ),
                  child: Text(
                    msg['text'] as String,
                    style: TextStyle(
                      fontSize: 14,
                      color: isMine ? AppColors.white : AppColors.textDark,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Time + read status
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
            child: Row(
              mainAxisAlignment:
                  isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
              children: [
                Text(
                  msg['time'] as String,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textGrey,
                  ),
                ),
                if (isMine && msg['status'] != null) ...[
                  const SizedBox(width: 4),
                  _readStatus(msg['status'] as String),
                ],
              ],
            ),
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _readStatus(String status) {
    switch (status) {
      case 'sent':
        return const Icon(Icons.check, size: 12, color: AppColors.textGrey);
      case 'delivered':
        return const Icon(Icons.done_all, size: 12, color: AppColors.textGrey);
      case 'read':
        return const Icon(Icons.done_all, size: 12, color: Colors.blue);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(left: 20, bottom: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.inputBorder),
            ),
            child: Row(
              children: [
                _dot(0),
                const SizedBox(width: 4),
                _dot(1),
                const SizedBox(width: 4),
                _dot(2),
                const SizedBox(width: 8),
                Text(
                  '${widget.user['name']} is typing...',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textGrey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.4, end: 1.0),
      duration: Duration(milliseconds: 400 + (index * 150)),
      builder: (_, value, __) => Opacity(
        opacity: value,
        child: Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: AppColors.textGrey,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border(
          top: BorderSide(color: AppColors.inputBorder, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Emoji button
          GestureDetector(
            onTap: () {},
            child: const Icon(Icons.sentiment_satisfied_alt_outlined,
                size: 24, color: AppColors.textGrey),
          ),

          const SizedBox(width: 10),

          // Text input
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: AppColors.inputBorder),
              ),
              child: TextField(
                controller: _messageController,
                maxLines: null,
                style: const TextStyle(
                    fontSize: 14, color: AppColors.textDark),
                decoration: const InputDecoration(
                  hintText: 'Say something nice...',
                  hintStyle:
                      TextStyle(color: AppColors.textGrey, fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),

          const SizedBox(width: 10),

          // Send button
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send,
                  color: AppColors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  void _showOptionsMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _optionTile(Icons.block_outlined, 'Block user', Colors.red, () {
              Navigator.pop(context);
              // TODO: UserService.blockUser(widget.user['id'])
            }),
            _optionTile(Icons.flag_outlined, 'Report', Colors.orange, () {
              Navigator.pop(context);
              // TODO: UserService.reportUser(widget.user['id'])
            }),
            _optionTile(Icons.delete_outline, 'Delete chat', Colors.red, () {
              Navigator.pop(context);
              // TODO: ChatService.deleteChat(widget.user['id'])
            }),
          ],
        ),
      ),
    );
  }

  Widget _optionTile(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}