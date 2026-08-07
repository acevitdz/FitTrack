import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart'
    as mlkit;

import '../models/pose_coach.dart';
import 'pose_detection_service.dart';
import 'pose_rule_engine.dart';

/// Semantic name used by Camera Coach integrations. The implementation lives
/// in [PoseRuleEngine] and is deliberately independent from ML Kit.
typedef SquatPoseRuleEngine = PoseRuleEngine;

/// Android-only ML Kit adapter for transient [CameraImage] frames.
///
/// The adapter creates an [mlkit.InputImage] only for the duration of one
/// inference and returns normalized landmarks. It never stores source bytes,
/// an [mlkit.InputImage], or a raw [CameraImage] in a field.
final class MlKitPoseDetectionService
    extends SingleInferencePoseDetectionService<CameraImage> {
  MlKitPoseDetectionService({
    required this.camera,
    required this.deviceOrientation,
  });

  final CameraDescription camera;
  final DeviceOrientation Function() deviceOrientation;
  mlkit.PoseDetector? _detector;
  bool _closed = false;

  static bool get isAndroidSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<PoseDetectionCapability> checkCapability() async {
    if (_closed) {
      return const PoseDetectionCapability.unavailable(
        PoseCapabilityUnavailableReason.disposed,
      );
    }
    if (kIsWeb) {
      return const PoseDetectionCapability.unavailable(
        PoseCapabilityUnavailableReason.web,
      );
    }
    if (defaultTargetPlatform != TargetPlatform.android) {
      return const PoseDetectionCapability.unavailable(
        PoseCapabilityUnavailableReason.unsupportedPlatform,
      );
    }
    return const PoseDetectionCapability.available();
  }

  @override
  Future<PoseDetectionResult> performDetection(
    CameraImage input, {
    required DateTime capturedAt,
  }) async {
    final converted = _toInputImage(input);
    if (converted == null) {
      return PoseDetectionResult.failure(
        capturedAt,
        errorCode: 'unsupported_camera_image',
      );
    }

    final detector = _detector ??= mlkit.PoseDetector(
      options: mlkit.PoseDetectorOptions(
        model: mlkit.PoseDetectionModel.base,
        mode: mlkit.PoseDetectionMode.stream,
      ),
    );
    final poses = await detector.processImage(converted.inputImage);
    if (poses.isEmpty) return PoseDetectionResult.noPose(capturedAt);
    if (poses.length > 1) {
      return PoseDetectionResult.multiplePoses(capturedAt);
    }

    PoseFrame? bestFrame;
    var bestQuality = -1.0;
    for (final pose in poses) {
      final frame = _normalizePose(
        pose,
        capturedAt: capturedAt,
        imageWidth: converted.imageWidth,
        imageHeight: converted.imageHeight,
        rotation: converted.rotation,
      );
      final quality = frame.landmarks.isEmpty
          ? 0.0
          : frame.landmarks.values
                    .map((landmark) => landmark.confidence)
                    .reduce((a, b) => a + b) /
                frame.landmarks.length;
      if (quality > bestQuality) {
        bestQuality = quality;
        bestFrame = frame;
      }
    }
    return bestFrame == null
        ? PoseDetectionResult.noPose(capturedAt)
        : PoseDetectionResult.detected(bestFrame);
  }

  @override
  Future<void> disposeDetector() async {
    _closed = true;
    final detector = _detector;
    _detector = null;
    if (detector != null) await detector.close();
  }

  _ConvertedInputImage? _toInputImage(CameraImage image) {
    if (!isAndroidSupported || image.planes.isEmpty) return null;

    final rotation = _inputRotation();
    final sourceFormat = mlkit.InputImageFormatValue.fromRawValue(
      image.format.raw,
    );
    if (rotation == null || sourceFormat == null) return null;

    late final Uint8List bytes;
    late final mlkit.InputImageFormat resolvedFormat;
    late final int bytesPerRow;
    if ((sourceFormat == mlkit.InputImageFormat.nv21 ||
            sourceFormat == mlkit.InputImageFormat.yv12) &&
        image.planes.length == 1) {
      bytes = image.planes.first.bytes;
      resolvedFormat = sourceFormat;
      bytesPerRow = image.planes.first.bytesPerRow;
    } else if ((sourceFormat == mlkit.InputImageFormat.yuv_420_888 ||
            sourceFormat == mlkit.InputImageFormat.yv12) &&
        image.planes.length == 3) {
      bytes = _convertYuv420ToNv21(image);
      resolvedFormat = mlkit.InputImageFormat.nv21;
      bytesPerRow = image.width;
    } else {
      return null;
    }

    final inputImage = mlkit.InputImage.fromBytes(
      bytes: bytes,
      metadata: mlkit.InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: resolvedFormat,
        bytesPerRow: bytesPerRow,
      ),
    );
    return _ConvertedInputImage(
      inputImage: inputImage,
      imageWidth: image.width,
      imageHeight: image.height,
      rotation: rotation,
    );
  }

  mlkit.InputImageRotation? _inputRotation() {
    const orientationDegrees = {
      DeviceOrientation.portraitUp: 0,
      DeviceOrientation.landscapeLeft: 90,
      DeviceOrientation.portraitDown: 180,
      DeviceOrientation.landscapeRight: 270,
    };
    final deviceDegrees = orientationDegrees[deviceOrientation()];
    if (deviceDegrees == null) return null;

    final sensorDegrees = camera.sensorOrientation;
    final compensated = camera.lensDirection == CameraLensDirection.front
        ? (sensorDegrees + deviceDegrees) % 360
        : (sensorDegrees - deviceDegrees + 360) % 360;
    return mlkit.InputImageRotationValue.fromRawValue(compensated);
  }

  Uint8List _convertYuv420ToNv21(CameraImage image) {
    final width = image.width;
    final height = image.height;
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];
    final output = Uint8List(width * height + (width * height ~/ 2));

    var destination = 0;
    final yPixelStride = yPlane.bytesPerPixel ?? 1;
    for (var row = 0; row < height; row++) {
      final rowOffset = row * yPlane.bytesPerRow;
      for (var column = 0; column < width; column++) {
        output[destination++] = yPlane.bytes[rowOffset + column * yPixelStride];
      }
    }

    final uPixelStride = uPlane.bytesPerPixel ?? 1;
    final vPixelStride = vPlane.bytesPerPixel ?? 1;
    for (var row = 0; row < height ~/ 2; row++) {
      final uRowOffset = row * uPlane.bytesPerRow;
      final vRowOffset = row * vPlane.bytesPerRow;
      for (var column = 0; column < width ~/ 2; column++) {
        output[destination++] =
            vPlane.bytes[vRowOffset + column * vPixelStride];
        output[destination++] =
            uPlane.bytes[uRowOffset + column * uPixelStride];
      }
    }
    return output;
  }

  PoseFrame _normalizePose(
    mlkit.Pose pose, {
    required DateTime capturedAt,
    required int imageWidth,
    required int imageHeight,
    required mlkit.InputImageRotation rotation,
  }) {
    final quarterTurn =
        rotation == mlkit.InputImageRotation.rotation90deg ||
        rotation == mlkit.InputImageRotation.rotation270deg;
    final coordinateWidth = (quarterTurn ? imageHeight : imageWidth).toDouble();
    final coordinateHeight = (quarterTurn ? imageWidth : imageHeight)
        .toDouble();

    // Use one scale for both axes so joint angles are not distorted by the
    // camera aspect ratio. The shorter axis is centered in the 0..1 square.
    final scale = coordinateWidth > coordinateHeight
        ? coordinateWidth
        : coordinateHeight;
    final xInset = (scale - coordinateWidth) / 2;
    final yInset = (scale - coordinateHeight) / 2;
    final normalized = <PoseLandmarkType, NormalizedPoseLandmark>{};

    for (final entry in _landmarkMapping.entries) {
      final source = pose.landmarks[entry.key];
      if (source == null ||
          !source.x.isFinite ||
          !source.y.isFinite ||
          !source.likelihood.isFinite) {
        continue;
      }
      final displayX = camera.lensDirection == CameraLensDirection.front
          ? coordinateWidth - source.x
          : source.x;
      final x = ((displayX + xInset) / scale).clamp(0.0, 1.0).toDouble();
      final y = ((source.y + yInset) / scale).clamp(0.0, 1.0).toDouble();
      final confidence = source.likelihood.clamp(0.0, 1.0).toDouble();
      normalized[entry.value] = NormalizedPoseLandmark(
        type: entry.value,
        x: x,
        y: y,
        confidence: confidence,
        visibility: confidence,
      );
    }
    return PoseFrame(capturedAt: capturedAt, landmarks: normalized);
  }

  static final _landmarkMapping = {
    mlkit.PoseLandmarkType.leftShoulder: PoseLandmarkType.leftShoulder,
    mlkit.PoseLandmarkType.rightShoulder: PoseLandmarkType.rightShoulder,
    mlkit.PoseLandmarkType.leftElbow: PoseLandmarkType.leftElbow,
    mlkit.PoseLandmarkType.rightElbow: PoseLandmarkType.rightElbow,
    mlkit.PoseLandmarkType.leftWrist: PoseLandmarkType.leftWrist,
    mlkit.PoseLandmarkType.rightWrist: PoseLandmarkType.rightWrist,
    mlkit.PoseLandmarkType.leftHip: PoseLandmarkType.leftHip,
    mlkit.PoseLandmarkType.rightHip: PoseLandmarkType.rightHip,
    mlkit.PoseLandmarkType.leftKnee: PoseLandmarkType.leftKnee,
    mlkit.PoseLandmarkType.rightKnee: PoseLandmarkType.rightKnee,
    mlkit.PoseLandmarkType.leftAnkle: PoseLandmarkType.leftAnkle,
    mlkit.PoseLandmarkType.rightAnkle: PoseLandmarkType.rightAnkle,
  };
}

class _ConvertedInputImage {
  const _ConvertedInputImage({
    required this.inputImage,
    required this.imageWidth,
    required this.imageHeight,
    required this.rotation,
  });

  final mlkit.InputImage inputImage;
  final int imageWidth;
  final int imageHeight;
  final mlkit.InputImageRotation rotation;
}
