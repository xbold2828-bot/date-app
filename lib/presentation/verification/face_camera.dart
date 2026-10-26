import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'face_challenge.dart';

/// The front camera and ML Kit's face detector, turned into [FaceSample]s.
///
/// ML Kit runs on the phone: nothing leaves it while the person is following
/// the prompts. Only the four stills [takeStill] returns are uploaded, and
/// only once the challenge is finished.
class FaceCamera {
  FaceCamera._(this.controller, this._detector);

  final CameraController controller;
  final FaceDetector _detector;

  bool _streaming = false;
  bool _busy = false;
  void Function(FaceSample)? _onSample;

  /// Rotation compensation by device orientation, from ML Kit's own example.
  static const _degrees = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  /// Opens the front camera. Throws [CameraException] — `CameraAccessDenied`
  /// and its variants when permission is refused.
  static Future<FaceCamera> open() async {
    final cameras = await availableCameras();
    final front = cameras
        .where((c) => c.lensDirection == CameraLensDirection.front)
        .firstOrNull;
    if (front == null) {
      throw CameraException('NoFrontCamera', 'This phone has no front camera');
    }

    final controller = CameraController(
      front,
      // 480p: plenty for a face that fills a third of the frame, light enough
      // for live analysis on a cheap phone, and small photos to upload.
      ResolutionPreset.medium,
      enableAudio: false,
      // The two formats ML Kit reads straight from bytes.
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );
    try {
      await controller.initialize();
      await controller.setFlashMode(FlashMode.off);
      await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);
    } catch (_) {
      await controller.dispose();
      rethrow;
    }

    final detector = FaceDetector(
      options: FaceDetectorOptions(
        // Eyes-open and smiling probabilities — the blink and the smile.
        enableClassification: true,
        performanceMode: FaceDetectorMode.fast,
        minFaceSize: 0.15,
      ),
    );
    return FaceCamera._(controller, detector);
  }

  /// Analyse frames until [stop]; [onSample] gets one per analysed frame.
  /// Frames that arrive while one is still being analysed are dropped, so a
  /// slow phone analyses fewer frames instead of falling behind.
  Future<void> start(void Function(FaceSample) onSample) async {
    _onSample = onSample;
    if (_streaming) return;
    await controller.startImageStream(_analyse);
    _streaming = true;
  }

  Future<void> stop() async {
    if (!_streaming) return;
    _streaming = false;
    await controller.stopImageStream();
  }

  /// Takes the photo for one step and reads it back with the same detector,
  /// so the challenge can tell whether it caught the pose.
  ///
  /// The temporary file is deleted at once: the bytes are in memory, and a
  /// face photo has no business lingering in the app's cache.
  Future<(Uint8List, FaceSample)> takeStill() async {
    XFile file;
    try {
      file = await controller.takePicture();
    } on CameraException {
      // A few camera stacks refuse to shoot while frames are streaming.
      final listener = _onSample;
      await stop();
      file = await controller.takePicture();
      if (listener != null) await start(listener);
    }
    try {
      final bytes = await file.readAsBytes();
      final faces = await _detector.processImage(
        InputImage.fromFilePath(file.path),
      );
      return (bytes, sampleFrom(faces));
    } finally {
      try {
        await File(file.path).delete();
      } catch (_) {
        // Already gone, or the OS will clear its cache — nothing to do.
      }
    }
  }

  Future<void> dispose() async {
    _onSample = null;
    try {
      await stop();
    } catch (_) {
      // Disposing anyway.
    }
    await controller.dispose();
    await _detector.close();
  }

  Future<void> _analyse(CameraImage image) async {
    if (_busy) return;
    final input = _inputFrom(image);
    if (input == null) return;

    _busy = true;
    try {
      final faces = await _detector.processImage(input);
      _onSample?.call(
        sampleFrom(
          faces,
          shortSide: math.min(image.width, image.height).toDouble(),
        ),
      );
    } catch (_) {
      // On Android the detector comes from Google Play services and throws
      // until it has downloaded; a dropped frame is the right answer to both.
    } finally {
      _busy = false;
    }
  }

  /// Camera bytes as ML Kit wants them — straight from its Flutter example.
  InputImage? _inputFrom(CameraImage image) {
    final sensor = controller.description.sensorOrientation;
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensor);
    } else {
      final device = _degrees[controller.value.deviceOrientation];
      if (device == null) return null;
      // Front camera: the sensor and the screen turn the same way.
      rotation = InputImageRotationValue.fromRawValue((sensor + device) % 360);
    }
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw as int);
    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888) ||
        image.planes.length != 1) {
      return null;
    }

    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }
}

/// What the challenge needs from one detection.
///
/// The largest face is the one that counts — the person holding the phone.
/// [shortSide] is the frame's short side in pixels; without it the face size
/// is left at 0 (a still is judged on angles, not distance).
@visibleForTesting
FaceSample sampleFrom(List<Face> faces, {double? shortSide}) {
  if (faces.isEmpty) return const FaceSample.none();
  final face = faces.reduce(
    (a, b) => a.boundingBox.width >= b.boundingBox.width ? a : b,
  );
  return FaceSample(
    faceCount: faces.length,
    yaw: face.headEulerAngleY ?? 0,
    pitch: face.headEulerAngleX ?? 0,
    roll: face.headEulerAngleZ ?? 0,
    leftEyeOpen: face.leftEyeOpenProbability,
    rightEyeOpen: face.rightEyeOpenProbability,
    smiling: face.smilingProbability,
    widthRatio: shortSide == null || shortSide <= 0
        ? 0
        : face.boundingBox.width / shortSide,
  );
}
