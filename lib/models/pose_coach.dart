/// A body landmark expressed in preview-independent coordinates.
///
/// [x] and [y] use the normalized range 0..1. The detector adapter is
/// responsible for rotation and mirroring before it creates this model.
enum PoseLandmarkType {
  leftShoulder,
  rightShoulder,
  leftElbow,
  rightElbow,
  leftWrist,
  rightWrist,
  leftHip,
  rightHip,
  leftKnee,
  rightKnee,
  leftAnkle,
  rightAnkle,
}

class NormalizedPoseLandmark {
  const NormalizedPoseLandmark({
    required this.type,
    required this.x,
    required this.y,
    required this.confidence,
    this.visibility,
  }) : assert(x >= 0 && x <= 1),
       assert(y >= 0 && y <= 1),
       assert(confidence >= 0 && confidence <= 1),
       assert(visibility == null || (visibility >= 0 && visibility <= 1));

  final PoseLandmarkType type;
  final double x;
  final double y;

  /// Detector confidence for this landmark, normalized to 0..1.
  final double confidence;

  /// Visibility reported by the provider, normalized to 0..1.
  ///
  /// Providers without a separate visibility score may leave this null. In
  /// that case confidence is also used as the visibility estimate.
  final double? visibility;

  double get effectiveVisibility => visibility ?? confidence;
}

/// Landmark-only detector output. It intentionally contains no image bytes,
/// camera handles, or other data that could retain a source frame.
class PoseFrame {
  PoseFrame({
    required this.capturedAt,
    required Map<PoseLandmarkType, NormalizedPoseLandmark> landmarks,
  }) : landmarks = Map.unmodifiable(landmarks);

  final DateTime capturedAt;
  final Map<PoseLandmarkType, NormalizedPoseLandmark> landmarks;

  NormalizedPoseLandmark? landmark(PoseLandmarkType type) => landmarks[type];
}

enum PoseCoachStatus {
  good('good'),
  needsCue('needs_cue'),
  notVisible('not_visible'),
  uncertain('uncertain');

  const PoseCoachStatus(this.wireValue);

  final String wireValue;
}

enum SquatPhase { standing, descending, bottom, ascending }

/// Stable codes that the UI can localize or send to Voice Coach.
enum PoseFeedbackCode {
  positionFullBody,
  lowConfidence,
  staleFrame,
  standTall,
  lowerHips,
  onePersonOnly,
  detectorUnavailable,
}

class PoseRepEvent {
  const PoseRepEvent({
    required this.repNumber,
    required this.occurredAt,
    required this.confidence,
  });

  final int repNumber;
  final DateTime occurredAt;
  final double confidence;
}

class PoseCoachResult {
  const PoseCoachResult({
    required this.status,
    required this.phase,
    required this.repCount,
    required this.capturedAt,
    required this.isCalibrated,
    this.confidence,
    this.kneeAngleDegrees,
    this.feedbackCode,
    this.announceFeedback = false,
    this.repEvent,
  });

  final PoseCoachStatus status;
  final SquatPhase phase;
  final int repCount;
  final DateTime capturedAt;
  final bool isCalibrated;
  final double? confidence;
  final double? kneeAngleDegrees;

  /// The active feedback, if any. [announceFeedback] is separately debounced
  /// so the visual cue may remain visible without repeatedly speaking it.
  final PoseFeedbackCode? feedbackCode;
  final bool announceFeedback;
  final PoseRepEvent? repEvent;
}

class SquatRuleConfiguration {
  const SquatRuleConfiguration({
    this.minimumLandmarkConfidence = 0.65,
    this.minimumLandmarkVisibility = 0.6,
    this.standingEnterAngle = 165,
    this.standingExitAngle = 155,
    this.bottomEnterAngle = 100,
    this.bottomExitAngle = 115,
    this.smoothingAlpha = 0.45,
    this.stableFramesForTransition = 2,
    this.maximumFrameAge = const Duration(milliseconds: 750),
    this.feedbackDebounce = const Duration(seconds: 2),
  }) : assert(minimumLandmarkConfidence >= 0 && minimumLandmarkConfidence <= 1),
       assert(minimumLandmarkVisibility >= 0 && minimumLandmarkVisibility <= 1),
       assert(bottomEnterAngle < bottomExitAngle),
       assert(bottomExitAngle < standingExitAngle),
       assert(standingExitAngle < standingEnterAngle),
       assert(smoothingAlpha > 0 && smoothingAlpha <= 1),
       assert(stableFramesForTransition > 0);

  final double minimumLandmarkConfidence;
  final double minimumLandmarkVisibility;

  /// Hysteresis thresholds prevent a noisy angle near a boundary from rapidly
  /// flipping phases.
  final double standingEnterAngle;
  final double standingExitAngle;
  final double bottomEnterAngle;
  final double bottomExitAngle;

  /// Exponential moving average weight applied to the newest observation.
  final double smoothingAlpha;
  final int stableFramesForTransition;
  final Duration maximumFrameAge;
  final Duration feedbackDebounce;
}

enum PoseCapabilityUnavailableReason {
  none,
  web,
  unsupportedPlatform,
  exerciseUnsupported,
  deviceUnsupported,
  permissionDenied,
  cameraUnavailable,
  modelUnavailable,
  trackingUnreliable,
  disposed,
}

class PoseDetectionCapability {
  const PoseDetectionCapability.available()
    : isAvailable = true,
      unavailableReason = PoseCapabilityUnavailableReason.none;

  const PoseDetectionCapability.unavailable(this.unavailableReason)
    : assert(unavailableReason != PoseCapabilityUnavailableReason.none),
      isAvailable = false;

  final bool isAvailable;
  final PoseCapabilityUnavailableReason unavailableReason;
}

enum PoseDetectionStatus {
  detected,
  noPose,
  multiplePoses,
  unavailable,
  busy,
  failure,
}

/// Result returned by a detector adapter. Only normalized landmarks may cross
/// this boundary; the source camera frame remains transient in the adapter.
class PoseDetectionResult {
  const PoseDetectionResult._({
    required this.status,
    required this.capturedAt,
    this.frame,
    this.unavailableReason,
    this.errorCode,
  });

  factory PoseDetectionResult.detected(PoseFrame frame) =>
      PoseDetectionResult._(
        status: PoseDetectionStatus.detected,
        capturedAt: frame.capturedAt,
        frame: frame,
      );

  factory PoseDetectionResult.noPose(DateTime capturedAt) =>
      PoseDetectionResult._(
        status: PoseDetectionStatus.noPose,
        capturedAt: capturedAt,
      );

  factory PoseDetectionResult.multiplePoses(DateTime capturedAt) =>
      PoseDetectionResult._(
        status: PoseDetectionStatus.multiplePoses,
        capturedAt: capturedAt,
      );

  factory PoseDetectionResult.unavailable(
    DateTime capturedAt,
    PoseCapabilityUnavailableReason reason,
  ) => PoseDetectionResult._(
    status: PoseDetectionStatus.unavailable,
    capturedAt: capturedAt,
    unavailableReason: reason,
  );

  factory PoseDetectionResult.busy(DateTime capturedAt) =>
      PoseDetectionResult._(
        status: PoseDetectionStatus.busy,
        capturedAt: capturedAt,
      );

  factory PoseDetectionResult.failure(
    DateTime capturedAt, {
    required String errorCode,
  }) => PoseDetectionResult._(
    status: PoseDetectionStatus.failure,
    capturedAt: capturedAt,
    errorCode: errorCode,
  );

  final PoseDetectionStatus status;
  final DateTime capturedAt;
  final PoseFrame? frame;
  final PoseCapabilityUnavailableReason? unavailableReason;

  /// A non-sensitive stable code. Exceptions and image data are deliberately
  /// not retained in the result model.
  final String? errorCode;
}
