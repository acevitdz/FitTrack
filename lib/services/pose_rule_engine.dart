import 'dart:math' as math;

import '../models/pose_coach.dart';

/// Deterministic Squat rule engine.
///
/// The engine consumes normalized landmarks, not camera frames. Invalid or
/// low-quality input never advances the state machine or produces a form
/// judgement. Create one instance per active set and call [reset] between sets.
class PoseRuleEngine {
  PoseRuleEngine({
    this.configuration = const SquatRuleConfiguration(),
    int initialRepCount = 0,
  }) : assert(initialRepCount >= 0),
       _repCount = initialRepCount;

  final SquatRuleConfiguration configuration;

  SquatPhase _phase = SquatPhase.standing;
  int _repCount;
  bool _isCalibrated = false;
  int _calibrationFrames = 0;
  double? _smoothedKneeAngle;
  DateTime? _lastFrameTimestamp;
  SquatPhase? _candidatePhase;
  int _candidateFrames = 0;
  final Map<PoseFeedbackCode, DateTime> _lastFeedbackAt = {};

  SquatPhase get phase => _phase;
  int get repCount => _repCount;
  bool get isCalibrated => _isCalibrated;

  void reset({int initialRepCount = 0}) {
    if (initialRepCount < 0) {
      throw ArgumentError.value(
        initialRepCount,
        'initialRepCount',
        'must not be negative',
      );
    }
    _phase = SquatPhase.standing;
    _repCount = initialRepCount;
    _isCalibrated = false;
    _calibrationFrames = 0;
    _smoothedKneeAngle = null;
    _lastFrameTimestamp = null;
    _candidatePhase = null;
    _candidateFrames = 0;
    _lastFeedbackAt.clear();
  }

  PoseCoachResult evaluate(PoseFrame frame, {DateTime? evaluatedAt}) {
    final now = evaluatedAt ?? frame.capturedAt;
    if (_isStale(frame, now)) {
      return _feedbackResult(
        frame: frame,
        now: now,
        status: PoseCoachStatus.uncertain,
        feedbackCode: PoseFeedbackCode.staleFrame,
      );
    }
    _lastFrameTimestamp = frame.capturedAt;

    final observation = _bestSideObservation(frame);
    if (observation == null ||
        observation.minimumVisibility <
            configuration.minimumLandmarkVisibility) {
      return _feedbackResult(
        frame: frame,
        now: now,
        status: PoseCoachStatus.notVisible,
        feedbackCode: PoseFeedbackCode.positionFullBody,
        confidence: observation?.minimumConfidence,
      );
    }
    if (observation.minimumConfidence <
        configuration.minimumLandmarkConfidence) {
      return _feedbackResult(
        frame: frame,
        now: now,
        status: PoseCoachStatus.uncertain,
        feedbackCode: PoseFeedbackCode.lowConfidence,
        confidence: observation.minimumConfidence,
      );
    }

    final rawAngle = _angleDegrees(
      observation.hip,
      observation.knee,
      observation.ankle,
    );
    if (rawAngle == null) {
      return _feedbackResult(
        frame: frame,
        now: now,
        status: PoseCoachStatus.uncertain,
        feedbackCode: PoseFeedbackCode.lowConfidence,
        confidence: observation.minimumConfidence,
      );
    }

    final previousSmoothed = _smoothedKneeAngle;
    final angle = previousSmoothed == null
        ? rawAngle
        : configuration.smoothingAlpha * rawAngle +
              (1 - configuration.smoothingAlpha) * previousSmoothed;
    _smoothedKneeAngle = angle;

    if (!_isCalibrated) {
      return _calibrate(
        frame: frame,
        now: now,
        angle: angle,
        confidence: observation.minimumConfidence,
      );
    }

    final transition = _nextPhase(angle);
    final completedTransition = _considerTransition(transition);
    PoseRepEvent? repEvent;
    PoseFeedbackCode? feedbackCode;
    if (completedTransition != null) {
      final (:from, :to) = completedTransition;
      if (from == SquatPhase.ascending && to == SquatPhase.standing) {
        _repCount++;
        repEvent = PoseRepEvent(
          repNumber: _repCount,
          occurredAt: frame.capturedAt,
          confidence: observation.minimumConfidence,
        );
      } else if (from == SquatPhase.descending && to == SquatPhase.standing) {
        feedbackCode = PoseFeedbackCode.lowerHips;
      }
    }

    if (feedbackCode != null) {
      return _feedbackResult(
        frame: frame,
        now: now,
        status: PoseCoachStatus.needsCue,
        feedbackCode: feedbackCode,
        confidence: observation.minimumConfidence,
        kneeAngleDegrees: angle,
      );
    }
    return PoseCoachResult(
      status: PoseCoachStatus.good,
      phase: _phase,
      repCount: _repCount,
      capturedAt: frame.capturedAt,
      isCalibrated: _isCalibrated,
      confidence: observation.minimumConfidence,
      kneeAngleDegrees: angle,
      repEvent: repEvent,
    );
  }

  PoseCoachResult _calibrate({
    required PoseFrame frame,
    required DateTime now,
    required double angle,
    required double confidence,
  }) {
    if (angle >= configuration.standingEnterAngle) {
      _calibrationFrames++;
      if (_calibrationFrames >= configuration.stableFramesForTransition) {
        _isCalibrated = true;
        _phase = SquatPhase.standing;
        _calibrationFrames = 0;
      }
      return PoseCoachResult(
        status: PoseCoachStatus.good,
        phase: _phase,
        repCount: _repCount,
        capturedAt: frame.capturedAt,
        isCalibrated: _isCalibrated,
        confidence: confidence,
        kneeAngleDegrees: angle,
      );
    }

    _calibrationFrames = 0;
    return _feedbackResult(
      frame: frame,
      now: now,
      status: PoseCoachStatus.needsCue,
      feedbackCode: PoseFeedbackCode.standTall,
      confidence: confidence,
      kneeAngleDegrees: angle,
    );
  }

  SquatPhase? _nextPhase(double angle) {
    return switch (_phase) {
      SquatPhase.standing =>
        angle <= configuration.standingExitAngle ? SquatPhase.descending : null,
      SquatPhase.descending =>
        angle <= configuration.bottomEnterAngle
            ? SquatPhase.bottom
            : angle >= configuration.standingEnterAngle
            ? SquatPhase.standing
            : null,
      SquatPhase.bottom =>
        angle >= configuration.bottomExitAngle ? SquatPhase.ascending : null,
      SquatPhase.ascending =>
        angle >= configuration.standingEnterAngle
            ? SquatPhase.standing
            : angle <= configuration.bottomEnterAngle
            ? SquatPhase.bottom
            : null,
    };
  }

  ({SquatPhase from, SquatPhase to})? _considerTransition(SquatPhase? target) {
    if (target == null || target == _phase) {
      _candidatePhase = null;
      _candidateFrames = 0;
      return null;
    }
    if (_candidatePhase == target) {
      _candidateFrames++;
    } else {
      _candidatePhase = target;
      _candidateFrames = 1;
    }
    if (_candidateFrames < configuration.stableFramesForTransition) {
      return null;
    }

    final from = _phase;
    _phase = target;
    _candidatePhase = null;
    _candidateFrames = 0;
    return (from: from, to: target);
  }

  bool _isStale(PoseFrame frame, DateTime now) {
    final lastTimestamp = _lastFrameTimestamp;
    if (lastTimestamp != null && !frame.capturedAt.isAfter(lastTimestamp)) {
      return true;
    }
    final age = now.difference(frame.capturedAt);
    return age > configuration.maximumFrameAge;
  }

  PoseCoachResult _feedbackResult({
    required PoseFrame frame,
    required DateTime now,
    required PoseCoachStatus status,
    required PoseFeedbackCode feedbackCode,
    double? confidence,
    double? kneeAngleDegrees,
  }) {
    final previous = _lastFeedbackAt[feedbackCode];
    final announce =
        previous == null ||
        now.difference(previous) >= configuration.feedbackDebounce;
    if (announce) {
      _lastFeedbackAt[feedbackCode] = now;
    }
    return PoseCoachResult(
      status: status,
      phase: _phase,
      repCount: _repCount,
      capturedAt: frame.capturedAt,
      isCalibrated: _isCalibrated,
      confidence: confidence,
      kneeAngleDegrees: kneeAngleDegrees,
      feedbackCode: feedbackCode,
      announceFeedback: announce,
    );
  }

  _SideObservation? _bestSideObservation(PoseFrame frame) {
    final observations = <_SideObservation>[];
    final left = _sideObservation(frame, left: true);
    final right = _sideObservation(frame, left: false);
    if (left != null) observations.add(left);
    if (right != null) observations.add(right);
    if (observations.isEmpty) return null;
    observations.sort((a, b) => b.quality.compareTo(a.quality));
    return observations.first;
  }

  _SideObservation? _sideObservation(PoseFrame frame, {required bool left}) {
    final shoulder = frame.landmark(
      left ? PoseLandmarkType.leftShoulder : PoseLandmarkType.rightShoulder,
    );
    final hip = frame.landmark(
      left ? PoseLandmarkType.leftHip : PoseLandmarkType.rightHip,
    );
    final knee = frame.landmark(
      left ? PoseLandmarkType.leftKnee : PoseLandmarkType.rightKnee,
    );
    final ankle = frame.landmark(
      left ? PoseLandmarkType.leftAnkle : PoseLandmarkType.rightAnkle,
    );
    if (shoulder == null || hip == null || knee == null || ankle == null) {
      return null;
    }
    return _SideObservation(
      shoulder: shoulder,
      hip: hip,
      knee: knee,
      ankle: ankle,
    );
  }

  double? _angleDegrees(
    NormalizedPoseLandmark first,
    NormalizedPoseLandmark vertex,
    NormalizedPoseLandmark last,
  ) {
    final ax = first.x - vertex.x;
    final ay = first.y - vertex.y;
    final bx = last.x - vertex.x;
    final by = last.y - vertex.y;
    final magnitudeA = math.sqrt(ax * ax + ay * ay);
    final magnitudeB = math.sqrt(bx * bx + by * by);
    if (magnitudeA < 0.000001 || magnitudeB < 0.000001) return null;
    final cosine = ((ax * bx + ay * by) / (magnitudeA * magnitudeB)).clamp(
      -1.0,
      1.0,
    );
    return math.acos(cosine) * 180 / math.pi;
  }
}

class _SideObservation {
  const _SideObservation({
    required this.shoulder,
    required this.hip,
    required this.knee,
    required this.ankle,
  });

  final NormalizedPoseLandmark shoulder;
  final NormalizedPoseLandmark hip;
  final NormalizedPoseLandmark knee;
  final NormalizedPoseLandmark ankle;

  Iterable<NormalizedPoseLandmark> get _landmarks => [
    shoulder,
    hip,
    knee,
    ankle,
  ];

  double get minimumConfidence =>
      _landmarks.map((landmark) => landmark.confidence).reduce(math.min);

  double get minimumVisibility => _landmarks
      .map((landmark) => landmark.effectiveVisibility)
      .reduce(math.min);

  double get quality => math.min(minimumConfidence, minimumVisibility);
}
