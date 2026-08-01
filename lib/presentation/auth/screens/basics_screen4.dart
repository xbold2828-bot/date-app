import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import 'basics_screen5.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart'; // for kIsWeb
import 'dart:typed_data';

class BasicsScreen4 extends StatefulWidget {
  const BasicsScreen4({super.key});

  @override
  State<BasicsScreen4> createState() => _BasicsScreen4State();
}

class _BasicsScreen4State extends State<BasicsScreen4> {
  // 5 slots: index 0 = primary, rest are additional
 final List<String?> _photoPaths = List.filled(5, null);    // for mobile
  final List<Uint8List?> _photoBytes = List.filled(5, null); // for web
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

   bool get _canContinue =>
      _photoPaths[0] != null || _photoBytes[0] != null;

 // With:
  Future<void> _pickPhoto(int index) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1080,
      );

      if (file != null) {
        if (kIsWeb) {
          // Web: read as bytes
          final bytes = await file.readAsBytes();
          setState(() {
            _photoBytes[index] = bytes;
            _photoPaths[index] = file.name;
          });
        } else {
          // Mobile/Desktop: use file path
          setState(() {
            _photoPaths[index] = file.path;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open gallery. Please try again.')),
        );
      }
    }
  }

  void _removePhoto(int index) {
    setState(() {
      _photoPaths[index] = null;
      _photoBytes[index] = null;
    });
  }

  Future<void> _onContinue() async {
    if (!_canContinue) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload at least one primary photo')),
      );
      return;
    }

    setState(() => _isLoading = true);

    // TODO: ProfileService.uploadPhotos(_photos)
    await Future.delayed(const Duration(milliseconds: 600));

    if (mounted) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const BasicsScreen5()),
  );
}


    setState(() => _isLoading = false);

    // TODO: GoRouter.of(context).go('/home')
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back, color: AppColors.textDark),
                  ),
                  const Expanded(
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.circle, size: 10, color: AppColors.primary),
                          SizedBox(width: 6),
                          Text(
                            'Radius',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                ],
              ),
            ),

            // Progress bar — step 4 of 6
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text(
                        'STEP 4 OF 6',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                          letterSpacing: 1.1,
                        ),
                      ),
                      Text(
                        'IDENTITY',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textGrey,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: 4 / 6,
                      minHeight: 3,
                      backgroundColor: AppColors.inputBorder,
                      valueColor:
                          const AlwaysStoppedAnimation(AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Heading
                    const Text(
                      'Show yourself',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Upload up to 5 photos. One selfie minimum.',
                      style: TextStyle(fontSize: 13, color: AppColors.textGrey),
                    ),

                    const SizedBox(height: 24),

                    // Photo grid
                    // Row 1: primary (tall) + 2 small stacked
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Primary photo — tall
                        Expanded(
                          flex: 5,
                          child: _photoTile(
                            index: 0,
                            height: 220,
                            isPrimary: true,
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Two small slots stacked
                        Expanded(
                          flex: 4,
                          child: Column(
                            children: [
                              _photoTile(index: 1, height: 105),
                              const SizedBox(height: 10),
                              _photoTile(index: 2, height: 105),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Row 2: two equal small slots
                    Row(
                      children: [
                        Expanded(child: _photoTile(index: 3, height: 100)),
                        const SizedBox(width: 10),
                        Expanded(child: _photoTile(index: 4, height: 100)),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // No nudity warning
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppColors.primary.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.block, size: 16, color: AppColors.primary),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'No nudity — keep all photos respectful and SFW.',
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

                    const SizedBox(height: 24),

                    // Tips section
                    Row(
                      children: const [
                        Icon(Icons.lightbulb_outline,
                            size: 16, color: AppColors.textGrey),
                        SizedBox(width: 6),
                        Text(
                          'Tips for a better match',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    _tipCard(
                      icon: Icons.wb_sunny_outlined,
                      title: 'Natural Lighting',
                      subtitle:
                          'Daylight softens features and creates a more authentic presence.',
                    ),

                    const SizedBox(height: 10),

                    _tipCard(
                      icon: Icons.remove_red_eye_outlined,
                      title: 'Eyes Visible',
                      subtitle:
                          'Avoid heavy sunglasses. Direct eye contact increases verification speed.',
                    ),

                    const SizedBox(height: 32),

                    // Continue button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _onContinue,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _canContinue
                              ? AppColors.primary
                              : AppColors.textGrey.withOpacity(0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: AppColors.white)
                            : const Text(
                                'Continue',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.white,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _photoTile({
    required int index,
    required double height,
    bool isPrimary = false,
  }) {
    final hasPhoto = _photoPaths[index] != null || _photoBytes[index] != null;

    return GestureDetector(
      onTap: () => hasPhoto ? _removePhoto(index) : _pickPhoto(index),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasPhoto ? AppColors.primary : AppColors.inputBorder,
            width: hasPhoto ? 1.5 : 1,
          ),
        ),
        child: hasPhoto
            ? Stack(
                fit: StackFit.expand,
                children: [
                  // Show image — web uses bytes, mobile uses file path
                  ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: kIsWeb
                        ? Image.memory(
                            _photoBytes[index]!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: AppColors.primary.withOpacity(0.12),
                              child: const Icon(Icons.broken_image_outlined,
                                  color: AppColors.textGrey),
                            ),
                          )
                        : Image.file(
                            File(_photoPaths[index]!),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: AppColors.primary.withOpacity(0.12),
                              child: const Icon(Icons.broken_image_outlined,
                                  color: AppColors.textGrey),
                            ),
                          ),
                  ),
                  // Remove button
                  Positioned(
                    top: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: () => _removePhoto(index),
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close,
                            size: 14, color: AppColors.white),
                      ),
                    ),
                  ),
                  // Primary badge
                  if (index == 0)
                    Positioned(
                      bottom: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Primary',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isPrimary) ...[
                    const Icon(Icons.add_a_photo_outlined,
                        size: 28, color: AppColors.textGrey),
                    const SizedBox(height: 8),
                    const Text(
                      'Primary Photo',
                      style: TextStyle(fontSize: 12, color: AppColors.textGrey),
                    ),
                  ] else
                    Icon(Icons.add,
                        size: 22,
                        color: AppColors.primary.withOpacity(0.6)),
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
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}