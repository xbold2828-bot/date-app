import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../data/models/media_model.dart';
import '../../../data/services/auth_service.dart';
import '../../../providers/core_providers.dart';
import '../../../providers/profile_provider.dart';
import '../../auth/screens/login_screen.dart';
import '../widgets/profile_edit_sheets.dart';
import './blocked_accounts_screen.dart';
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

  bool _isUploadingPhoto = false;

  Future<void> _onEditBio() async {
    final saved = await showEditBioSheet(context, _profile['bio'] as String);
    if (saved && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Bio updated')));
    }
  }

  Future<void> _onEditVibes() async {
    final saved = await showEditVibesSheet(
      context,
      List<String>.from(_profile['vibes'] as List),
    );
    if (saved && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Vibe updated')));
    }
  }

  /// Pick and upload one gallery photo. Upload failures surface as a message
  /// rather than an exception — object storage may be unreachable.
  Future<void> _onAddPhoto() async {
    if (_isUploadingPhoto) return;

    // The server rejects the 6th photo, so say so here rather than letting the
    // upload run and fail — and point at the way out.
    final current = _publicPhotos(
      ref.read(myMediaProvider).valueOrNull,
      null,
    ).length;
    if (current >= kMaxPublicPhotos) {
      _snack('You can have $kMaxPublicPhotos photos. '
          'Tap one to delete it, then add a new one.');
      return;
    }

    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1080,
      );
      if (file == null) return;

      final bytes = await file.readAsBytes();
      final name = file.name.toLowerCase();
      final contentType = name.endsWith('.png')
          ? 'image/png'
          : name.endsWith('.webp')
              ? 'image/webp'
              : 'image/jpeg';

      setState(() => _isUploadingPhoto = true);
      final result = await ref.read(mediaRepositoryProvider).uploadPhoto(
            bytes: bytes,
            contentType: contentType,
            type: MediaKind.publicPhoto,
          );

      if (!mounted) return;
      if (result.succeeded) {
        ref.invalidate(myMediaProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo uploaded — moderation pending')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Photo couldn't be uploaded. Please try again."),
          ),
        );
      }
    } on AppException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

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
      // The avatar shows the profile photo; the gallery below renders the rest.
      'avatarUrl': _primaryPhotoUrl(me.primaryPhotoId),
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
                        child: _profile['avatarUrl'] != null
                            ? Image.network(
                                _profile['avatarUrl'] as String,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                    Icons.person,
                                    size: 40,
                                    color: AppColors.white),
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
                  style: AppTextStyles.title,
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
                      style: AppTextStyles.caption,
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
                  onTap: _onAddPhoto,
                  child: const Text(
                    'Add photo',
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

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _gallery(me.primaryPhotoId),
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
                        onTap: _onEditVibes,
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
                        onTap: _onEditBio,
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
                      // Unconstrained text in a Row overflows the card on a
                      // narrow screen (and at larger system font scales); let
                      // it take the remaining width instead.
                      Expanded(
                        child: Text(
                          'Radius Premium',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.white,
                          ),
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

          // Blocked accounts.
          //
          // Takes over the "Safety Center" slot, which was a tile that did
          // nothing. This is the only route back from a block: once one lands,
          // that person is gone from the radar, from likes, from their profile
          // and from the inbox, so no other screen has a row left to unblock
          // them from.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _menuTile(
              icon: Icons.block_outlined,
              label: 'Blocked accounts',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const BlockedAccountsScreen(),
                ),
              ),
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


  /// URL of the photo marked as the profile picture, if it's loaded and still
  /// present (it may have just been deleted).
  String? _primaryPhotoUrl(String? primaryId) {
    if (primaryId == null) return null;
    for (final asset in ref.watch(myMediaProvider).valueOrNull ?? const []) {
      if (asset.id == primaryId) return asset.url;
    }
    return null;
  }

  /// My public photos, profile photo first so it reads as the main one.
  List<MediaAsset> _publicPhotos(List<MediaAsset>? media, String? primaryId) {
    final photos =
        (media ?? const <MediaAsset>[]).where((m) => m.isPublicPhoto).toList();
    photos.sort((a, b) {
      if (a.id == primaryId) return -1;
      if (b.id == primaryId) return 1;
      return 0;
    });
    return photos;
  }

  /// A 3-up grid of my photos plus one "+" tile, capped at [kMaxPublicPhotos]
  /// to match the server. Tapping a photo opens its actions.
  Widget _gallery(String? primaryId) {
    final photos =
        _publicPhotos(ref.watch(myMediaProvider).valueOrNull, primaryId);
    final atCap = photos.length >= kMaxPublicPhotos;

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 0.8,
      children: [
        for (final photo in photos)
          _photoTile(photo, isPrimary: photo.id == primaryId),
        if (!atCap) _addTile(),
      ],
    );
  }

  Widget _photoTile(MediaAsset photo, {required bool isPrimary}) {
    return GestureDetector(
      onTap: () => _showPhotoActions(photo, isPrimary: isPrimary),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              photo.url,
              fit: BoxFit.cover,
              // Presigned URLs expire, and photos uploaded before storage was
              // configured point at keys that no longer exist. Show a quiet
              // placeholder instead of the browser's broken-image glyph.
              errorBuilder: (_, __, ___) => Container(
                color: AppColors.inputBorder,
                child: const Center(
                  child: Icon(Icons.broken_image_outlined,
                      size: 22, color: AppColors.textGrey),
                ),
              ),
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : Container(
                      color: AppColors.inputBorder,
                      child: const Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
            ),
            if (isPrimary)
              Positioned(
                left: 6,
                bottom: 6,
                child: _tag('PROFILE', AppColors.primary),
              )
            else if (photo.isPending)
              Positioned(
                left: 6,
                bottom: 6,
                child: _tag('PENDING', Colors.black54),
              ),
            const Positioned(
              top: 6,
              right: 6,
              child: Icon(Icons.more_horiz, size: 18, color: AppColors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tag(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: AppColors.white,
            letterSpacing: 0.5,
          ),
        ),
      );

  Widget _addTile() {
    return GestureDetector(
      onTap: _onAddPhoto,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.inputBorder),
        ),
        child: Center(
          child: _isUploadingPhoto
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                )
              : const Icon(Icons.add, size: 24, color: AppColors.textGrey),
        ),
      ),
    );
  }

  /// Set-as-profile / delete. Deleting is the way to make room once the gallery
  /// is full, so the sheet is also where the cap gets resolved.
  Future<void> _showPhotoActions(
    MediaAsset photo, {
    required bool isPrimary,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.inputBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            if (!isPrimary)
              ListTile(
                leading: const Icon(Icons.account_circle_outlined,
                    color: AppColors.textDark),
                title: const Text('Make this my profile photo'),
                subtitle: photo.isApproved
                    ? null
                    : const Text('Available once moderation approves it'),
                enabled: photo.isApproved,
                onTap: () {
                  Navigator.pop(sheetContext);
                  _setPrimary(photo);
                },
              )
            else
              const ListTile(
                leading: Icon(Icons.check_circle, color: AppColors.primary),
                title: Text('This is your profile photo'),
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete photo',
                  style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(sheetContext);
                _deletePhoto(photo);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _setPrimary(MediaAsset photo) async {
    try {
      await ref.read(mediaRepositoryProvider).setPrimary(photo.id);
      // The primary id lives on the user, the badge on the media list.
      await ref.read(meProvider.notifier).refresh();
      ref.invalidate(myMediaProvider);
      if (mounted) _snack('Profile photo updated');
    } on AppException catch (e) {
      if (mounted) _snack(e.message);
    }
  }

  Future<void> _deletePhoto(MediaAsset photo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.white,
        title: const Text('Delete photo?'),
        content: const Text(
          'This removes it from your profile and from storage. '
          'It cannot be undone.',
          style: TextStyle(color: AppColors.textGrey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textGrey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(mediaRepositoryProvider).delete(photo.id);
      ref.invalidate(myMediaProvider);
      // Deleting the profile photo clears the pointer on the user.
      await ref.read(meProvider.notifier).refresh();
      if (mounted) _snack('Photo deleted');
    } on AppException catch (e) {
      if (mounted) _snack(e.message);
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));


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