import 'dart:typed_data';

import 'package:dating_app/core/constants/app_string.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_text_styles.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/media_model.dart';
import '../../../providers/core_providers.dart';
import '../../../providers/profile_provider.dart';
import '../../common/widgets/widgets.dart';
import '../widgets/onboarding_widgets.dart';

class _PickedPhoto {
  _PickedPhoto({required this.bytes, required this.contentType});

  final Uint8List bytes;
  final String contentType;
}

/// Step 6 — up to five photos, the first one the cover.
class BasicsScreen4 extends ConsumerStatefulWidget {
  const BasicsScreen4({super.key});

  static Key photoSlotKey(int index) => ValueKey('photo-slot-$index');

  @override
  ConsumerState<BasicsScreen4> createState() => _BasicsScreen4State();
}

class _BasicsScreen4State extends ConsumerState<BasicsScreen4> {
  static const int _slots = 5;

  final List<_PickedPhoto?> _photos = List.filled(_slots, null);
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  bool get _hasAnyPhoto => _photos.any((p) => p != null);

  String _contentTypeFor(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  /// Picks into [index] — empty or not. Tapping a photo that is already there
  /// swaps it; removing is its own, smaller control, so a stray tap can never
  /// throw a photo away (it used to).
  Future<void> _pickPhoto(int index) async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1080,
      );
      if (file == null) return;

      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _photos[index] = _PickedPhoto(
          bytes: bytes,
          contentType: _contentTypeFor(file.name),
        );
      });
    } catch (_) {
      _toast(AppString.galleryError, tone: ToastTone.error);
    }
  }

  void _pickIntoFirstEmpty() {
    final index = _photos.indexWhere((p) => p == null);
    if (index >= 0) _pickPhoto(index);
  }

  void _removePhoto(int index) => setState(() => _photos[index] = null);

  Future<void> _onContinue() async {
    setState(() => _isLoading = true);
    try {
      final media = ref.read(mediaRepositoryProvider);
      final picked = _photos.whereType<_PickedPhoto>().toList();

      var uploaded = 0;
      var rejected = 0;
      String? firstFailure;
      String? rejectionMessage;
      String? stepError;
      for (final photo in picked) {
        final result = await media.uploadPhoto(
          bytes: photo.bytes,
          contentType: photo.contentType,
          type: MediaKind.publicPhoto,
        );
        if (result.succeeded) {
          uploaded++;
        } else if (result.wasRejected) {
          rejected++;
          rejectionMessage ??= result.failureReason;
        } else {
          firstFailure ??= result.failureReason;
        }
      }

      try {
        final me = await ref
            .read(onboardingRepositoryProvider)
            .completePhotoStep(skipped: uploaded == 0);
        ref.read(meProvider.notifier).setMe(me);
      } on AppException catch (e) {
        stepError = e.message;
      }
      ref.invalidate(myMediaProvider);

      if (!mounted) return;
      if (stepError != null && uploaded == 0) {
        _toast(AppString.photoStepError(stepError), tone: ToastTone.error);
      } else if (rejected > 0 && uploaded == 0) {
        _toast(
          rejectionMessage ?? AppString.photosRejectedDefault,
          tone: ToastTone.error,
        );
      } else if (rejected > 0) {
        _toast(
          AppString.photosPartialRejected(uploaded, picked.length, rejected),
        );
      } else if (picked.isNotEmpty && uploaded == 0) {
        _toast(AppString.photosUploadFailed, tone: ToastTone.error);
      } else if (firstFailure != null) {
        _toast(AppString.photosPartialFailed(uploaded, picked.length));
      }

      context.push(AppRoutes.location);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toast(String msg, {ToastTone tone = ToastTone.neutral}) {
    if (mounted) showRadiusToast(context, msg, tone: tone);
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      step: 6,
      section: AppString.sectionIdentity,
      title: AppString.photosTitle,
      subtitle: AppString.photosSubtitle,
      actionLabel: _hasAnyPhoto
          ? AppString.continueText
          : AppString.photosAddFirst,
      onAction: _hasAnyPhoto ? _onContinue : _pickIntoFirstEmpty,
      isLoading: _isLoading,
      secondaryLabel: _hasAnyPhoto ? null : AppString.photosSkipForNow,
      onSecondary: _hasAnyPhoto ? null : _onContinue,
      children: [
        _photoGrid(),
        const SizedBox(height: 24),
        const FactLine(
          icon: Icons.wb_sunny_outlined,
          text: AppString.photosTipLine,
        ),
        const FactLine(
          icon: Icons.shield_outlined,
          text: AppString.photoGuidelines,
        ),
      ],
    );
  }

  Widget _photoGrid() {
    const gap = 10.0;
    const cellAspect = 1.25;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cellWidth = (constraints.maxWidth - gap * 2) / 3;
        final cellHeight = cellWidth * cellAspect;
        final primarySide = cellWidth * 2 + gap;
        final primaryHeight = cellHeight * 2 + gap;

        return Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: primarySide,
                  height: primaryHeight,
                  child: _photoTile(index: 0, isPrimary: true),
                ),
                const SizedBox(width: gap),
                SizedBox(
                  width: cellWidth,
                  height: primaryHeight,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(height: cellHeight, child: _photoTile(index: 1)),
                      const SizedBox(height: gap),
                      SizedBox(height: cellHeight, child: _photoTile(index: 2)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: gap),
            Row(
              children: [
                SizedBox(
                  width: cellWidth,
                  height: cellHeight,
                  child: _photoTile(index: 3),
                ),
                const SizedBox(width: gap),
                SizedBox(
                  width: cellWidth,
                  height: cellHeight,
                  child: _photoTile(index: 4),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _photoTile({required int index, bool isPrimary = false}) {
    final photo = _photos[index];
    final radius = BorderRadius.circular(isPrimary ? 22 : 16);

    if (photo == null) {
      return Semantics(
        button: true,
        label: isPrimary ? 'Add your cover photo' : 'Add photo ${index + 1}',
        excludeSemantics: true,
        child: Material(
          key: BasicsScreen4.photoSlotKey(index),
          color: AppColors.card,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(color: AppColors.inputBorder, width: 1.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _pickPhoto(index),
            child: Center(
              child: isPrimary
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.add_rounded,
                            size: 26,
                            color: AppColors.onAccent,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          AppString.photoPrimaryTile,
                          style: AppTextStyles.bodyStrong.copyWith(
                            fontSize: 14,
                          ),
                        ),
                      ],
                    )
                  : Icon(
                      Icons.add_rounded,
                      size: 24,
                      color: AppColors.iconMuted,
                    ),
            ),
          ),
        ),
      );
    }

    return Semantics(
      button: true,
      label: isPrimary
          ? 'Cover photo. Tap to replace'
          : 'Photo ${index + 1}. Tap to replace',
      child: Material(
        key: BasicsScreen4.photoSlotKey(index),
        color: AppColors.inputBorder,
        shape: RoundedRectangleBorder(borderRadius: radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _pickPhoto(index),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.memory(
                photo.bytes,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: AppColors.textGrey,
                  ),
                ),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: Semantics(
                  button: true,
                  label: 'Remove photo',
                  excludeSemantics: true,
                  child: GestureDetector(
                    onTap: () => _removePhoto(index),
                    behavior: HitTestBehavior.opaque,
                    // A 36px target around a 26px mark.
                    child: SizedBox(
                      width: 36,
                      height: 36,
                      child: Center(
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 15,
                            color: AppColors.onImage,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (isPrimary)
                Positioned(
                  left: 10,
                  bottom: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      AppString.photoPrimaryBadge,
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 11.5,
                        color: AppColors.onImage,
                        fontWeight: FontWeight.w700,
                        fontVariations: const [FontVariation('wght', 700)],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
