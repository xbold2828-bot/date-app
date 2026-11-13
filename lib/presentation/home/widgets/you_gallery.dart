import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../data/models/media_model.dart';
import '../../../providers/core_providers.dart';
import '../../../providers/profile_provider.dart';
import '../../../shared/widgets/dialogs/all_dialogs/radius_dialog.dart';
import '../../common/widgets/widgets.dart';
import 'package:dating_app/core/constants/app_string.dart';


/// My public photos as Instagram's grid: edge to edge, three across, 1px
/// gaps, 4:5 tiles.
///
/// Tap a photo to make it the cover or delete it; the last tile adds more.
/// Several photos can be picked at once, but never more than the free slots
/// (kMaxPublicPhotos minus the photos already uploaded).
class YouGallery extends ConsumerStatefulWidget {
  const YouGallery({super.key, required this.primaryPhotoId});
  final String? primaryPhotoId;

  @override
  ConsumerState<YouGallery> createState() => YouGalleryState();
}

enum _UploadKind { success, rejected, failed }

class _UploadOutcome {
  const _UploadOutcome(this.kind, [this.message]);
  final _UploadKind kind;
  final String? message;
}

class YouGalleryState extends ConsumerState<YouGallery> {
  /// Uploads running at the same time: fast enough, light on memory.
  static const int _maxConcurrentUploads = 3;

  bool _isPicking = false;
  int _uploadTotal = 0; // 0 = idle
  int _uploadDone = 0;

  bool get _isUploading => _uploadTotal > 0;
  bool get _isBusy => _isPicking || _isUploading;

  String get _progressLabel =>
      _uploadTotal > 1 ? 'Uploading $_uploadDone/$_uploadTotal' : 'Uploading';

  void _toast(String msg, {ToastTone tone = ToastTone.neutral}) {
    if (mounted) showRadiusToast(context, msg, tone: tone);
  }

  /// My public photos, profile photo first so it reads as the main one.
  List<MediaAsset> _publicPhotos(List<MediaAsset>? media) {
    final photos = (media ?? const <MediaAsset>[])
        .where((m) => m.isPublicPhoto)
        .toList();
    final primaryId = widget.primaryPhotoId;
    if (primaryId != null) {
      photos.sort((a, b) {
        if (a.id == primaryId) return -1;
        if (b.id == primaryId) return 1;
        return 0;
      });
    }
    return photos;
  }

  /// Free slots right now. Always read fresh from the provider.
  int _slotsLeft() {
    final current = _publicPhotos(ref.read(myMediaProvider).valueOrNull).length;
    return math.max(0, kMaxPublicPhotos - current);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Adding photos
  // ─────────────────────────────────────────────────────────────────────────

  /// Pick several photos and upload them. Called by the grid's add tile, the
  /// empty state, and (being public) by the parent screen.
  Future<void> addPhoto() async {
    if (_isBusy) return;

    final remaining = _slotsLeft();
    if (remaining <= 0) {
      _toast(
        'You can have $kMaxPublicPhotos photos. '
            'Tap one to delete it, then add a new one.',
      );
      return;
    }

    final picked = await _pickImages(remaining);
    if (picked.isEmpty || !mounted) return;

    // HARD LIMIT. The system picker enforces `limit` only on some devices; on
    // the rest the user can tick as many as they like. Whatever the picker
    // allowed, nothing above the free slots is ever uploaded. An over-sized
    // selection is rejected as a whole so the user picks again deliberately,
    // instead of the app silently choosing which photos to drop.
    if (picked.length > remaining) {
      _toast(
        'You selected ${picked.length} photos, but you can add only '
            '$remaining more (max $kMaxPublicPhotos). Please select '
            '$remaining or fewer.',
        tone: ToastTone.error,
      );
      return;
    }

    // The gallery may have changed while the picker was open (another upload,
    // a refresh). Check again right before uploading.
    if (picked.length > _slotsLeft()) {
      _toast(
        'Your gallery changed. Please try adding again.',
        tone: ToastTone.error,
      );
      return;
    }

    setState(() {
      _uploadTotal = picked.length;
      _uploadDone = 0;
    });

    try {
      final outcomes = await _uploadAll(picked);
      if (!mounted) return;

      if (outcomes.any((o) => o.kind == _UploadKind.success)) {
        ref.invalidate(myMediaProvider);
      }
      _reportResult(outcomes);
    } finally {
      if (mounted) {
        setState(() {
          _uploadTotal = 0;
          _uploadDone = 0;
        });
      }
    }
  }

  /// Opens the system picker. Returns an empty list if cancelled or failed.
  Future<List<XFile>> _pickImages(int remaining) async {
    _isPicking = true;
    try {
      final picker = ImagePicker();

      // pickMultiImage asserts limit >= 2, so one free slot uses the
      // single-image picker, which can only return one photo.
      if (remaining == 1) {
        final file = await picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 85,
          maxWidth: 1080,
        );
        return file == null ? const [] : [file];
      }

      return await picker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 1080,
        limit: remaining, // honoured by the OS only where supported
      );
    } on PlatformException catch (e) {
      debugPrint('Photo picker failed: $e');
      _toast(
        "Couldn't open your photos. Check the photo permission.",
        tone: ToastTone.error,
      );
      return const [];
    } on ArgumentError catch (e) {
      debugPrint('Photo picker rejected its arguments: $e');
      _toast("Couldn't open your photos. Please try again.",
          tone: ToastTone.error);
      return const [];
    } finally {
      _isPicking = false;
    }
  }

  /// Uploads all files with bounded concurrency. One failure never stops the
  /// others, and results keep the order of [files].
  Future<List<_UploadOutcome>> _uploadAll(List<XFile> files) async {
    final outcomes = List<_UploadOutcome>.filled(
      files.length,
      const _UploadOutcome(_UploadKind.failed),
    );
    var next = 0;

    // Dart is single-threaded, so `next++` is race-free between workers.
    Future<void> worker() async {
      while (true) {
        final i = next++;
        if (i >= files.length) return;
        outcomes[i] = await _uploadOne(files[i]);
        if (mounted) setState(() => _uploadDone++);
      }
    }

    await Future.wait(
      List.generate(
        math.min(_maxConcurrentUploads, files.length),
            (_) => worker(),
      ),
    );
    return outcomes;
  }

  Future<_UploadOutcome> _uploadOne(XFile file) async {
    try {
      // Bytes are read here, per file, so only the files currently uploading
      // sit in memory.
      final bytes = await file.readAsBytes();
      final result = await ref
          .read(mediaRepositoryProvider)
          .uploadPhoto(
        bytes: bytes,
        contentType: _contentType(file),
        type: MediaKind.publicPhoto,
      );

      if (result.succeeded) return const _UploadOutcome(_UploadKind.success);
      if (result.wasRejected) {
        // Moderation refused it. The same file would be refused again, so
        // this is reported without inviting a retry.
        return _UploadOutcome(_UploadKind.rejected, result.failureReason);
      }
      return const _UploadOutcome(_UploadKind.failed);
    } on AppException catch (e) {
      return _UploadOutcome(_UploadKind.failed, e.message);
    } catch (e, stack) {
      debugPrint('Photo upload failed: $e');
      debugPrintStack(stackTrace: stack);
      return const _UploadOutcome(_UploadKind.failed);
    }
  }

  String _contentType(XFile file) {
    final mime = file.mimeType;
    if (mime != null && mime.startsWith('image/')) return mime;

    final name = file.name.toLowerCase();
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  /// One toast summarising the whole batch.
  void _reportResult(List<_UploadOutcome> outcomes) {
    final ok = outcomes.where((o) => o.kind == _UploadKind.success).length;
    final rejected = outcomes.where((o) => o.kind == _UploadKind.rejected);
    final failed = outcomes.where((o) => o.kind == _UploadKind.failed);

    if (rejected.isEmpty && failed.isEmpty) {
      _toast(
        ok == 1 ? 'Photo added' : '$ok photos added',
        tone: ToastTone.success,
      );
      return;
    }

    // A single photo that went wrong: show the specific reason.
    if (outcomes.length == 1) {
      final o = outcomes.first;
      _toast(
        o.kind == _UploadKind.rejected
            ? (o.message ?? "This photo doesn't meet our content guidelines.")
            : (o.message ?? "Photo couldn't be uploaded. Please try again."),
        tone: ToastTone.error,
      );
      return;
    }

    // A mixed or all-failed batch: counts, no per-file noise.
    final parts = <String>[
      if (ok > 0) '$ok added',
      if (rejected.isNotEmpty)
        '${rejected.length} not allowed by our content guidelines',
      if (failed.isNotEmpty) '${failed.length} failed, please try again',
    ];
    _toast(
      parts.join(' · '),
      tone: ok > 0 ? ToastTone.neutral : ToastTone.error,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final photos = _publicPhotos(ref.watch(myMediaProvider).valueOrNull);
    if (photos.isEmpty) return _empty();

    final slotsLeft = math.max(0, kMaxPublicPhotos - photos.length);

    // Decode images at tile size instead of full resolution.
    final cacheWidth =
    (MediaQuery.sizeOf(context).width /
        3 *
        MediaQuery.devicePixelRatioOf(context))
        .round();

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      crossAxisSpacing: 1,
      mainAxisSpacing: 1,
      childAspectRatio: 0.8,
      children: [
        for (final photo in photos)
          _photoTile(
            photo,
            isPrimary: photo.id == widget.primaryPhotoId,
            cacheWidth: cacheWidth,
          ),
        if (slotsLeft > 0) _addTile(slotsLeft),
      ],
    );
  }

  /// Nothing uploaded yet: say what goes here and offer the one action.
  Widget _empty() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 8),
      child: Column(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.textDark, width: 1.5),
            ),
            child: Icon(
              Icons.photo_camera_outlined,
              size: 28,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Add your photos',
            style: AppTextStyles.title.copyWith(fontSize: 20),
          ),
          const SizedBox(height: 4),
          Text(
            'Your cover photo is the first thing people nearby see. '
                'You can add up to $kMaxPublicPhotos.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMuted,
          ),
          const SizedBox(height: 14),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 240),
            child: RadiusButton(
              label: _isUploading ? _progressLabel : 'Add photos',
              isLoading: _isUploading,
              onPressed: addPhoto,
            ),
          ),
        ],
      ),
    );
  }

  Widget _photoTile(
      MediaAsset photo, {
        required bool isPrimary,
        required int cacheWidth,
      }) {
    return Semantics(
      key: ValueKey(photo.id),
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
              cacheWidth: cacheWidth,
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
              Positioned(left: 6, top: 6, child: _badge('Cover'))
            else if (photo.isPending)
              Positioned(left: 6, top: 6, child: _badge('In review')),
          ],
        ),
      ),
    );
  }

  Widget _badge(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.6),
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

  Widget _addTile(int slotsLeft) {
    return Semantics(
      button: true,
      label: 'Add photos. $slotsLeft more allowed',
      excludeSemantics: true,
      child: Material(
        color: AppColors.inputBorder.withValues(alpha: 0.45),
        child: InkWell(
          // Ignored while picking/uploading, so a double tap cannot open two
          // pickers.
          onTap: _isBusy ? null : addPhoto,
          child: Center(
            child: _isUploading
                ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                ),
                if (_uploadTotal > 1) ...[
                  const SizedBox(height: 6),
                  Text(
                    '$_uploadDone/$_uploadTotal',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ],
            )
                : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.add_rounded,
                  size: 28,
                  color: AppColors.textDark,
                ),
                Text(
                  'Add',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textDark,
                  ),
                ),
                // Tells the user how many they may pick before the
                // system picker opens.
                Text(
                  '$slotsLeft left',
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 10.5,
                    color: AppColors.textGrey,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Photo actions
  // ─────────────────────────────────────────────────────────────────────────

  /// Set-as-cover / delete. Deleting is the way to make room once the gallery
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
                label: AppString.photoMakeCover,
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
                label: AppString.photoIsCover,
                enabled: false,
                onTap: () {},
              ),
            _SheetAction(
              icon: Icons.delete_outline_rounded,
              label: AppString.photoDelete,
              danger: true,
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
      if (!mounted) return;
      // The primary id lives on the user, the badge on the media list.
      await ref.read(meProvider.notifier).refresh();
      if (!mounted) return;
      ref.invalidate(myMediaProvider);
      _toast('Cover photo updated', tone: ToastTone.success);
    } on AppException catch (e) {
      _toast(e.message, tone: ToastTone.error);
    }
  }

  Future<void> _deletePhoto(MediaAsset photo) async {
    final confirmed = await showRadiusConfirm(
      context,
      title: AppString.photoDeleteConfirmTitle,
      message:
      'This removes it from your profile and from storage. '
          'It cannot be undone.',
      confirmLabel: AppString.delete,
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    try {
      await ref.read(mediaRepositoryProvider).delete(photo.id);
      if (!mounted) return;
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
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Row(
            children: [
              Icon(icon, size: 24, color: color),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: AppTextStyles.bodyStrong.copyWith(
                        fontSize: 15,
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