import 'dart:math' as math;

import 'package:fittrack/models/pose_coach.dart';
import 'package:fittrack/services/pose_detection_service.dart';
import 'package:fittrack/services/pose_rule_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PoseRuleEngine Squat', () {
    late DateTime timestamp;
    late PoseRuleEngine engine;

    setUp(() {
      timestamp = DateTime.utc(2026, 7, 24, 12);
      engine = PoseRuleEngine(
        configuration: const SquatRuleConfiguration(
          smoothingAlpha: 1,
          stableFramesForTransition: 2,
        ),
      );
    });

    PoseCoachResult send(
      double angle, {
      double confidence = .95,
      double visibility = .95,
    }) {
      timestamp = timestamp.add(const Duration(milliseconds: 33));
      final frame = _squatFrame(
        angle: angle,
        capturedAt: timestamp,
        confidence: confidence,
        visibility: visibility,
      );
      return engine.evaluate(frame, evaluatedAt: timestamp);
    }

    void repeat(double angle, int count) {
      for (var index = 0; index < count; index++) {
        send(angle);
      }
    }

    test('counts one rep only after a complete stable phase cycle', () {
      repeat(175, 2); // Calibrate in standing.
      repeat(145, 2); // standing -> descending
      repeat(90, 2); // descending -> bottom
      repeat(125, 2); // bottom -> ascending
      final beforeStanding = send(172);
      final completed = send(172); // ascending -> standing

      expect(beforeStanding.repCount, 0);
      expect(completed.status, PoseCoachStatus.good);
      expect(completed.phase, SquatPhase.standing);
      expect(completed.repCount, 1);
      expect(completed.repEvent?.repNumber, 1);
      expect(completed.repEvent?.occurredAt, timestamp);

      final nextFrame = send(175);
      expect(nextFrame.repCount, 1);
      expect(nextFrame.repEvent, isNull);
    });

    test('low confidence is uncertain and cannot advance phases', () {
      repeat(175, 2);

      final lowConfidence = send(90, confidence: .3);
      expect(lowConfidence.status, PoseCoachStatus.uncertain);
      expect(lowConfidence.feedbackCode, PoseFeedbackCode.lowConfidence);
      expect(lowConfidence.phase, SquatPhase.standing);
      expect(lowConfidence.repCount, 0);

      // A second valid low-angle frame is only candidate 1 of 2. The rejected
      // frame above must not count toward the transition.
      final firstValid = send(90);
      expect(firstValid.phase, SquatPhase.standing);
      expect(send(90).phase, SquatPhase.descending);
      expect(engine.repCount, 0);
    });

    test('missing or invisible landmarks return notVisible', () {
      timestamp = timestamp.add(const Duration(milliseconds: 33));
      final missing = engine.evaluate(
        PoseFrame(
          capturedAt: timestamp,
          landmarks: {
            PoseLandmarkType.leftHip: const NormalizedPoseLandmark(
              type: PoseLandmarkType.leftHip,
              x: .5,
              y: .5,
              confidence: .95,
            ),
          },
        ),
        evaluatedAt: timestamp,
      );
      expect(missing.status, PoseCoachStatus.notVisible);
      expect(missing.feedbackCode, PoseFeedbackCode.positionFullBody);
      expect(missing.repCount, 0);
    });

    test('stale and out-of-order frames do not mutate state', () {
      repeat(175, 2);
      final acceptedTimestamp = timestamp;

      final delayedTimestamp = timestamp.add(const Duration(milliseconds: 33));
      final delayed = engine.evaluate(
        _squatFrame(angle: 90, capturedAt: delayedTimestamp),
        evaluatedAt: delayedTimestamp.add(const Duration(seconds: 2)),
      );
      expect(delayed.status, PoseCoachStatus.uncertain);
      expect(delayed.feedbackCode, PoseFeedbackCode.staleFrame);
      expect(delayed.phase, SquatPhase.standing);

      final outOfOrder = engine.evaluate(
        _squatFrame(angle: 90, capturedAt: acceptedTimestamp),
        evaluatedAt: delayedTimestamp,
      );
      expect(outOfOrder.status, PoseCoachStatus.uncertain);
      expect(outOfOrder.phase, SquatPhase.standing);
      expect(engine.repCount, 0);
    });

    test('single noisy threshold crossings cannot create a rep', () {
      repeat(175, 2);

      // Every threshold-crossing sample is followed by a sample on the other
      // side, so no transition remains stable for two frames.
      for (final angle in [154.0, 158.0, 153.0, 160.0, 154.0, 159.0]) {
        send(angle);
      }
      expect(engine.phase, SquatPhase.standing);

      // Even a single deep outlier cannot move standing -> bottom or count.
      send(88);
      send(170);
      expect(engine.phase, SquatPhase.standing);
      expect(engine.repCount, 0);
    });

    test('partial squat emits a debounced lower-hips cue, not a rep', () {
      repeat(175, 2);
      repeat(145, 2);
      final firstReturn = send(172);
      final partial = send(172);

      expect(firstReturn.phase, SquatPhase.descending);
      expect(partial.phase, SquatPhase.standing);
      expect(partial.status, PoseCoachStatus.needsCue);
      expect(partial.feedbackCode, PoseFeedbackCode.lowerHips);
      expect(partial.announceFeedback, isTrue);
      expect(partial.repCount, 0);

      repeat(145, 2);
      send(172);
      final repeatedPartial = send(172);
      expect(repeatedPartial.status, PoseCoachStatus.needsCue);
      expect(repeatedPartial.feedbackCode, PoseFeedbackCode.lowerHips);
      expect(repeatedPartial.announceFeedback, isFalse);
    });
  });

  test('Web fallback reports unavailable without retaining input', () async {
    final service = UnavailablePoseDetectionService<Object>.web();
    final capability = await service.checkCapability();
    final capturedAt = DateTime.utc(2026, 7, 24);
    final result = await service.detect(Object(), capturedAt: capturedAt);

    expect(capability.isAvailable, isFalse);
    expect(capability.unavailableReason, PoseCapabilityUnavailableReason.web);
    expect(result.status, PoseDetectionStatus.unavailable);
    expect(result.frame, isNull);
    expect(result.unavailableReason, PoseCapabilityUnavailableReason.web);
  });

  test('multiple people is a distinct frame-free detection state', () {
    final capturedAt = DateTime.utc(2026, 7, 24, 12);
    final result = PoseDetectionResult.multiplePoses(capturedAt);

    expect(result.status, PoseDetectionStatus.multiplePoses);
    expect(result.capturedAt, capturedAt);
    expect(result.frame, isNull);
    expect(result.errorCode, isNull);
  });
}

PoseFrame _squatFrame({
  required double angle,
  required DateTime capturedAt,
  double confidence = .95,
  double visibility = .95,
}) {
  final radians = angle * math.pi / 180;
  const kneeX = .5;
  const kneeY = .6;
  const segmentLength = .2;
  final hipX = kneeX + math.sin(radians) * segmentLength;
  final hipY = kneeY + math.cos(radians) * segmentLength;

  NormalizedPoseLandmark point(PoseLandmarkType type, double x, double y) {
    return NormalizedPoseLandmark(
      type: type,
      x: x,
      y: y,
      confidence: confidence,
      visibility: visibility,
    );
  }

  return PoseFrame(
    capturedAt: capturedAt,
    landmarks: {
      PoseLandmarkType.leftShoulder: point(
        PoseLandmarkType.leftShoulder,
        hipX,
        (hipY - .15).clamp(0, 1),
      ),
      PoseLandmarkType.leftHip: point(PoseLandmarkType.leftHip, hipX, hipY),
      PoseLandmarkType.leftKnee: point(PoseLandmarkType.leftKnee, kneeX, kneeY),
      PoseLandmarkType.leftAnkle: point(
        PoseLandmarkType.leftAnkle,
        kneeX,
        kneeY + segmentLength,
      ),
    },
  );
}
