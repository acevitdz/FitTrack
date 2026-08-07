import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/pose_coach.dart';
import 'pose_detection_service.dart';
import 'pose_rule_engine.dart';

typedef SquatPoseRuleEngine = PoseRuleEngine;

/// Compile-safe fallback used by Web builds. Web always uses Guided
/// Confirmation and never initializes ML Kit.
final class MlKitPoseDetectionService
    implements PoseDetectionService<CameraImage> {
  const MlKitPoseDetectionService({
    required CameraDescription camera,
    required DeviceOrientation Function() deviceOrientation,
  });

  static bool get isAndroidSupported => false;

  @override
  Future<PoseDetectionCapability> checkCapability() async =>
      PoseDetectionCapability.unavailable(
        kIsWeb
            ? PoseCapabilityUnavailableReason.web
            : PoseCapabilityUnavailableReason.unsupportedPlatform,
      );

  @override
  Future<PoseDetectionResult> detect(
    CameraImage input, {
    required DateTime capturedAt,
  }) async => PoseDetectionResult.unavailable(
    capturedAt,
    kIsWeb
        ? PoseCapabilityUnavailableReason.web
        : PoseCapabilityUnavailableReason.unsupportedPlatform,
  );

  @override
  Future<void> dispose() async {}
}
