import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../data/models/media_model.dart';
import '../../../providers/core_providers.dart';
import '../../../providers/profile_provider.dart';
import '../../common/widgets/widgets.dart';

/// My public photos, as the profile's grid — edge to edge, three across, the
/// way a profile grid is read everywhere else on a phone.
///
/// Tap a photo to make it the cover or delete it; the last tile adds one.
class YouGallery extends ConsumerStatefulWidget {
  const YouGallery({super.key, required this.primaryPhotoId});
  final String? primaryPhotoId;

  @override
  ConsumerState<YouGallery> createState() => YouGalleryState();
}

class YouGalleryState extends ConsumerState<YouGallery> {
  bool _isUploading = false;

  void _toast(String msg, {ToastTone tone = ToastTone.neutral}) {
    if (mounted) showRadiusToast(context, msg, tone: tone);
  }

  /// My public photos, profile photo first so it reads as the main one.
  List<MediaAsset> _publicPhotos(List<MediaAsset>? media) {
    final photos = (media ?? const <MediaAsset>[])
        .where((m) => m.isPublicPhoto)
        .toList();
    photos.sort((a, b) {
      if (a.id == widget.primaryPhotoId) return -1;
      if (b.id == widget.primaryPhotoId) return 1;
      return 0;
    });
    return photos;
  }

  /// Pick and upload one gallery photo. Upload failures surface as a message
  /// rather than an exception — object storage may be unreachable.
  Future<void> addPhoto() async {
    if (_isUploading) return;

    // The server rejects the 6th photo, so say so here rather than letting the
    // upload run and fail — and point at the way out.
    final current = _publicPhotos(ref.read(myMediaProvider).valueOrNull).length;
    if (current >= kMaxPublicPhotos) {
      _toast(
        'You can have $kMaxPublicPhotos photos. '
        'Tap one to delete it, then add a new one.',
      );
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

      setState(() => _isUploading = true);
      final result = await ref
          .read(mediaRepositoryProvider)
          .uploadPhoto(
            bytes: bytes,
            contentType: contentType,
            type: MediaKind.publicPhoto,
          );

      if (!mounted) return;
      if (result.succeeded) {
        ref.invalidate(myMediaProvider);
        _toast('Photo added', tone: ToastTone.success);
      } else if (result.wasRejected) {
        // Moderation refused it. Say what the server said and do NOT invite a
        // retry — the same file will be refused again, and the photo is
        // already gone from storage.
        _toast(
          result.failureReason ??
              "This photo doesn't meet our content guidelines.",
          tone: ToastTone.error,
        );
      } else {
        _toast(
          "Photo couldn't be uploaded. Please try again.",
          tone: ToastTone.error,
        );
      }
    } on AppException catch (e) {
      _toast(e.message, tone: ToastTone.error);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final photos = _publicPhotos(ref.watch(myMediaProvider).valueOrNull);
    final atCap = photos.length >= kMaxPublicPhotos;

    if (photos.isEmpty) return _empty();

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      crossAxisSpacing: 2,
      mainAxisSpacing: 2,
      childAspectRatio: 0.8,
      children: [
        for (final photo in photos)
          _photoTile(photo, isPrimary: photo.id == widget.primaryPhotoId),
        if (!atCap) _addTile(),
      ],
    );
  }

  /// Nothing uploaded yet: say what goes here and offer the one action.
  Widget _empty() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 36, 32, 12),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.textDark, width: 2),
            ),
            child: Icon(
              Icons.photo_camera_outlined,
              size: 28,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Add your photos',
            style: AppTextStyles.title.copyWith(fontSize: 20),
          ),
          const SizedBox(height: 6),
          Text(
            'Your cover photo is the first thing people nearby see.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMuted,
          ),
          const SizedBox(height: 18),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 240),
            child: RadiusButton(
              label: _isUploading ? 'Uploading' : 'Add a photo',
              isLoading: _isUploading,
              onPressed: addPhoto,
            ),
          ),
        ],
      ),
    );
  }

  Widget _photoTile(MediaAsset photo, {required bool isPrimary}) {
    return Semantics(
      button: true,
      label: isPrimary
          ? 'Cover photo. Tap for options'
          : photo.isPending
          ? 'Photo in review. Tap for options'
          : 'Photo. Tap for options',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => _showPhotoActions(photo, isPrimary: isPrimary),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              photo.url,
              fit: BoxFit.cover,
              // Presigned URLs expire, and photos uploaded before storage was
              // configured point at keys that no longer exist. Show a quiet
              // placeholder instead of the broken-image glyph.
              errorBuilder: (_, _, _) => ColoredBox(
                color: AppColors.inputBorder,
                child: Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    size: 22,
                    color: AppColors.textGrey,
                  ),
                ),
              ),
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : ColoredBox(color: AppColors.inputBorder),
            ),
            if (isPrimary)
              Positioned(left: 6, bottom: 6, child: _badge('Cover'))
            else if (photo.isPending)
              Positioned(left: 6, bottom: 6, child: _badge('In review')),
          ],
        ),
      ),
    );
  }

  Widget _badge(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: AppTextStyles.caption.copyWith(
        fontSize: 10.5,
        color: AppColors.onImage,
        fontWeight: FontWeight.w700,
        fontVariations: const [FontVariation('wght', 700)],
      ),
    ),
  );

  Widget _addTile() {
    return Semantics(
      button: true,
      label: 'Add photo',
      excludeSemantics: true,
      child: Material(
        color: AppColors.inputBorder.withValues(alpha: 0.45),
        child: InkWell(
          onTap: addPhoto,
          child: Center(
            child: _isUploading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.add_rounded,
                        size: 28,
                        color: AppColors.textDark,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Add',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
          ),
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
    await showRadiusSheet<void>(
      context: context,
      builder: (sheetContext) => RadiusSheet(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!isPrimary)
              _SheetAction(
                icon: Icons.account_circle_outlined,
                label: 'Make this my cover photo',
                detail: photo.isApproved
                    ? null
                    : 'Available once it has been reviewed',
                enabled: photo.isApproved,
                onTap: () {
                  Navigator.pop(sheetContext);
                  _setPrimary(photo);
                },
              )
            else
              _SheetAction(
                icon: Icons.check_circle_rounded,
                label: 'This is your cover photo',
                enabled: false,
                onTap: () {},
              ),
            _SheetAction(
              icon: Icons.delete_outline_rounded,
              label: 'Delete photo',
              danger: true,
              onTap: () {
                Navigator.pop(sheetContext);
                _deletePhoto(photo);
              },
            ),
            const SizedBox(height: 4),
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
      _toast('Cover photo updated', tone: ToastTone.success);
    } on AppException catch (e) {
      _toast(e.message, tone: ToastTone.error);
    }
  }

  Future<void> _deletePhoto(MediaAsset photo) async {
    final confirmed = await showRadiusConfirm(
      context,
      title: 'Delete photo?',
      message: 'This removes it from your profile and from storage. '
          'It cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed) return;

    try {
      await ref.read(mediaRepositoryProvider).delete(photo.id);
      ref.invalidate(myMediaProvider);
      // Deleting the profile photo clears the pointer on the user.
      await ref.read(meProvider.notifier).refresh();
      _toast('Photo deleted');
    } on AppException catch (e) {
      _toast(e.message, tone: ToastTone.error);
    }
  }
}

class _SheetAction extends StatelessWidget {
  const _SheetAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.detail,
    this.enabled = true,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final String? detail;
  final VoidCallback onTap;
  final bool enabled;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger
        ? AppColors.danger
        : (enabled ? AppColors.textDark : AppColors.textGrey);
    return Semantics(
      button: enabled,
      enabled: enabled,
      label: detail == null ? label : '$label. $detail',
      excludeSemantics: true,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
          child: Row(
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: AppTextStyles.bodyStrong.copyWith(
                        fontSize: 15.5,
                        color: color,
                      ),
                    ),
                    if (detail != null)
                      Text(detail!, style: AppTextStyles.caption),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
