import 'dart:typed_data';

import 'package:dating_app/core/constants/app_string.dart';
import 'package:dating_app/core/utils/utils.dart';
import 'package:dating_app/shared/widgets/buttons/common_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_text_styles.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/extensions/global_back_extension.dart';
import '../../../core/extensions/unfocus_on_tap_extension.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/media_model.dart';
import '../../../providers/core_providers.dart';
import '../../../providers/profile_provider.dart';
import '../widgets/onboarding_widgets.dart';

class _PickedPhoto {
  _PickedPhoto({required this.bytes, required this.contentType});

  final Uint8List bytes;
  final String contentType;
}

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
      if (mounted) _showSnack(AppString.galleryError);
    }
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
        _showSnack(AppString.photoStepError(stepError));
      } else if (rejected > 0 && uploaded == 0) {
        _showSnack(rejectionMessage ?? AppString.photosRejectedDefault);
      } else if (rejected > 0) {
        _showSnack(
          AppString.photosPartialRejected(uploaded, picked.length, rejected),
        );
      } else if (picked.isNotEmpty && uploaded == 0) {
        _showSnack(AppString.photosUploadFailed);
      } else if (firstFailure != null) {
        _showSnack(AppString.photosPartialFailed(uploaded, picked.length));
      }

      context.push(AppRoutes.location);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            OnboardingHeader(
              step: 6,
              label: AppString.sectionIdentity,
              trailing: _isLoading
                  ? null
                  : GestureDetector(
                onTap: _onContinue,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    AppString.skip,
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.textGrey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            spacerH(20),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppString.photosTitle, style: AppTextStyles.display),
                    spacerH(6),
                    Text(
                      AppString.photosSubtitle,
                      style: TextStyle(fontSize: 13, color: AppColors.textGrey),
                    ),
                    spacerH(24),
                    _photoGrid(),
                    spacerH(20),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.block, size: 16, color: AppColors.primary),
                          spacerW(10),
                          Expanded(
                            child: Text(
                              AppString.photoGuidelines,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    spacerH(24),
                    Row(
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          size: 16,
                          color: AppColors.textGrey,
                        ),
                        spacerW(6),
                        Expanded(
                          child: Text(
                            AppString.photoTipsTitle,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                    spacerH(14),
                    _tipCard(
                      icon: Icons.wb_sunny_outlined,
                      title: AppString.tipLightingTitle,
                      subtitle: AppString.tipLightingBody,
                    ),
                    spacerH(10),
                    _tipCard(
                      icon: Icons.remove_red_eye_outlined,
                      title: AppString.tipEyesTitle,
                      subtitle: AppString.tipEyesBody,
                    ),
                    spacerH(32),
                    CommonButton(
                      text: _hasAnyPhoto
                          ? AppString.continueText
                          : AppString.continueWithoutPhotos,
                      isLoading: _isLoading,
                      onClick: _onContinue,
                    ),
                    spacerH(40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ).unfocusOnTap().withGlobalBackHandler(context);
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

    return GestureDetector(
      key: BasicsScreen4.photoSlotKey(index),
      onTap: () => photo != null ? _removePhoto(index) : _pickPhoto(index),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: photo != null ? AppColors.primary : AppColors.inputBorder,
            width: photo != null ? 1.5 : 1,
          ),
        ),
        child: photo == null
            ? Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isPrimary) ...[
              Icon(
                Icons.add_a_photo_outlined,
                size: 28,
                color: AppColors.textGrey,
              ),
              spacerH(8),
              Text(
                AppString.photoPrimaryTile,
                style: TextStyle(fontSize: 12, color: AppColors.textGrey),
              ),
            ] else
              Icon(
                Icons.add,
                size: 22,
                color: AppColors.primary.withValues(alpha: 0.6),
              ),
          ],
        )
            : Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: Image.memory(
                photo.bytes,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: AppColors.textGrey,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 6,
              right: 6,
              child: GestureDetector(
                onTap: () => _removePhoto(index),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    size: 14,
                    color: AppColors.onImage,
                  ),
                ),
              ),
            ),
            if (index == 0)
              Positioned(
                bottom: 6,
                left: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    AppString.photoPrimaryBadge,
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.onImage,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _tipCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          spacerW(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                spacerH(3),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: AppColors.primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}