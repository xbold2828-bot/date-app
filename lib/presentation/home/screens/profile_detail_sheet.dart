import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../providers/chat_provider.dart';
import '../../../providers/match_provider.dart';

class ProfileDetailSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> user;

  const ProfileDetailSheet({super.key, required this.user});

  @override
  ConsumerState<ProfileDetailSheet> createState() =>
      _ProfileDetailSheetState();
}

class _ProfileDetailSheetState extends ConsumerState<ProfileDetailSheet> {
  final TextEditingController _openerController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _openerController.dispose();
    super.dispose();
  }

  String? get _userId => widget.user['id'] as String?;

  Future<void> _sendOpener() async {
    final text = _openerController.text.trim();
    final userId = _userId;
    if (text.isEmpty || userId == null) return;

    setState(() => _isSending = true);
    try {
      await ref.read(chatActionsProvider).open(userId, text);
      _openerController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Opener sent!')),
        );
        Navigator.pop(context);
      }
    } on VerificationRequiredException {
      _showGate('Verify your identity to start messaging.');
    } on EntitlementRequiredException catch (e) {
      _showGate(e.message);
    } on AppException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _onLike() async {
    final userId = _userId;
    if (userId == null) return;
    try {
      final result = await ref.read(likeActionsProvider).react(userId, 'like');
      _snack(
        result.isMatch
            ? "It's a match with ${widget.user['name']}!"
            : 'You liked ${widget.user['name']}!',
      );
    } on AppException catch (e) {
      _snack(e.message);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.primary),
    );
  }

  void _showGate(String message) {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.white,
        title: const Text('One more step',
            style: TextStyle(color: AppColors.textDark)),
        content: Text(message,
            style: const TextStyle(color: AppColors.textGrey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK',
                style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.inputBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Photo
                  Stack(
                    children: [
                      // Photo placeholder — replace with real photo
                      ClipRRect(
  borderRadius: const BorderRadius.vertical(
    top: Radius.circular(24),
  ),
  child: Container(
    width: double.infinity,
    height: MediaQuery.of(context).size.height * 0.52,
    decoration: BoxDecoration(
      color: user['color'] as Color? ?? AppColors.inputBorder,
    ),
    child: user['photoUrl'] != null
        ? Image.network(
            user['photoUrl'] as String,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                _photoPlaceholder(user),
          )
        : _photoPlaceholder(user),
  ),
),
                      // Close button
                      Positioned(
                        top: 16,
                        right: 16,
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.3),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close,
                                size: 18, color: AppColors.white),
                          ),
                        ),
                      ),

                      // Online dot on photo
                      if (user['online'] == true)
                        Positioned(
                          bottom: 16,
                          right: 16,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: AppColors.white, width: 2),
                            ),
                          ),
                        ),
                    ],
                  ),

                  // Profile info
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name, age, verified
                        Row(
                          children: [
                            Text(
                              '${(user['name'] as String).toUpperCase()}, ${user['age']}',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Verified badge
                            Container(
                              width: 22,
                              height: 22,
                              decoration: const BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check,
                                  size: 13, color: AppColors.white),
                            ),
                          ],
                        ),

                        const SizedBox(height: 6),

                        // Distance
                        Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${user['distance']} AWAY',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textGrey,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Bio — if available
                        if (user['bio'] != null) ...[
                          Text(
                            user['bio'] as String,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textGrey,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // Interests & Vibes
                        const Text(
                          'INTERESTS & VIBES',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textGrey,
                            letterSpacing: 1.2,
                          ),
                        ),

                        const SizedBox(height: 10),

                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: ((user['vibes'] as List<String>?) ??
                                  ['Foodie', 'Night owl', 'Music'])
                              .map((vibe) => Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: AppColors.background,
                                      borderRadius:
                                          BorderRadius.circular(30),
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

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom action bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            decoration: BoxDecoration(
              color: AppColors.white,
              border: Border(
                top: BorderSide(color: AppColors.inputBorder, width: 1),
              ),
            ),
            child: Row(
              children: [
                // Like button
                GestureDetector(
                  onTap: _onLike,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: AppColors.inputBorder, width: 1.5),
                    ),
                    child: const Icon(Icons.favorite_border,
                        color: AppColors.primary, size: 22),
                  ),
                ),

                const SizedBox(width: 12),

                // Send opener input
                Expanded(
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: AppColors.inputBorder),
                    ),
                    child: TextField(
                      controller: _openerController,
                      style: const TextStyle(
                          fontSize: 14, color: AppColors.textDark),
                      decoration: const InputDecoration(
                        hintText: 'Send an opener...',
                        hintStyle: TextStyle(
                            color: AppColors.textGrey, fontSize: 14),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                      ),
                      onSubmitted: (_) => _sendOpener(),
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                // Send button
                GestureDetector(
                  onTap: _isSending ? null : _sendOpener,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: _isSending
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(
                                color: AppColors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.send,
                            color: AppColors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _photoPlaceholder(Map<String, dynamic> user) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(30), // change this to whatever radius you want
    child: Container(
      decoration: BoxDecoration(
        color: user['color'] as Color? ?? AppColors.inputBorder,
      ),
      child: Center(
        child: Text(
          (user['name'] as String)[0].toUpperCase(),
          style: const TextStyle(
            fontSize: 72,
            fontWeight: FontWeight.bold,
            color: AppColors.white,
          ),
        ),
      ),
    ),
  );
}
}