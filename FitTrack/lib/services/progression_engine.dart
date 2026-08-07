import 'dart:math' as math;

import '../models/active_workout.dart';
import '../models/progression.dart';
import '../models/program.dart';

class ProgressionEngine {
  const ProgressionEngine();

  static const policyVersion = 'progression_v1';

  ProgressionDecision evaluate({
    required String enrollmentId,
    required String programVersionId,
    required String prescriptionId,
    required String progressionKey,
    required int sourceWeek,
    required int targetWeek,
    required bool isBeginner,
    required int sessionsPerWeek,
    required ProgressionTarget baselineTarget,
    required ProgressionTarget previousTarget,
    required List<ExerciseProgressEvidence> evidence,
    required List<SetEvent> setEvents,
    required bool readinessReduced,
    bool safetyFlagged = false,
    DateTime? createdAt,
  }) {
    final decisionId =
        '$enrollmentId:week:$targetWeek:$progressionKey:$policyVersion';
    final now = createdAt ?? DateTime.now();
    final scheduledSets = evidence.fold<int>(
      0,
      (sum, item) => sum + item.scheduledSets,
    );
    final completedSets = evidence.fold<int>(
      0,
      (sum, item) => sum + item.completedSets,
    );
    final adherenceRate = scheduledSets == 0
        ? null
        : completedSets / scheduledSets;

    ProgressionDecision result(
      ProgressionDecisionKind kind,
      ProgressionTarget nextTarget,
      List<String> reasons, {
      String? changedVariable,
    }) => ProgressionDecision(
      id: decisionId,
      policyVersion: policyVersion,
      enrollmentId: enrollmentId,
      programVersionId: programVersionId,
      prescriptionId: prescriptionId,
      progressionKey: progressionKey,
      sourceWeek: sourceWeek,
      targetWeek: targetWeek,
      kind: kind,
      adherenceRate: adherenceRate,
      previousTarget: previousTarget,
      nextTarget: nextTarget,
      changedVariable: changedVariable,
      reasonCodes: reasons,
      createdAt: now,
    );

    final hasDiscomfort =
        safetyFlagged ||
        evidence.any(
          (item) => item.outcome == ExerciseProgressOutcome.discomfort,
        ) ||
        setEvents.any((event) => event.skipReason == 'discomfort');
    if (hasDiscomfort) {
      return result(ProgressionDecisionKind.safetyHold, previousTarget, const [
        'pain_or_discomfort_reported',
      ]);
    }

    final isDeloadWeek = !isBeginner && (targetWeek == 4 || targetWeek == 8);
    if (isDeloadWeek) {
      final reduced = _deload(previousTarget, sessionsPerWeek);
      return result(
        ProgressionDecisionKind.deload,
        reduced,
        const ['scheduled_deload'],
        changedVariable: reduced.sets != previousTarget.sets
            ? 'sets'
            : previousTarget.targetType == PrescriptionTargetType.repetitions
            ? 'repetitions'
            : 'durationSeconds',
      );
    }

    if (evidence.isEmpty) {
      return result(ProgressionDecisionKind.hold, previousTarget, const [
        'insufficient_evidence',
      ]);
    }

    if (evidence.any((item) => item.usedAlternative)) {
      return result(ProgressionDecisionKind.hold, previousTarget, const [
        'alternative_exercise_used',
      ]);
    }

    final failed = evidence.any(
      (item) => item.outcome == ExerciseProgressOutcome.failed,
    );
    if (failed || (adherenceRate != null && adherenceRate < .7)) {
      final regressed = _regress(previousTarget, baselineTarget);
      if (_sameTarget(regressed, previousTarget)) {
        return result(ProgressionDecisionKind.hold, previousTarget, const [
          'performance_below_threshold_at_safe_floor',
        ]);
      }
      return result(
        ProgressionDecisionKind.regress,
        regressed,
        [
          if (failed) 'performance_target_not_met',
          if (adherenceRate != null && adherenceRate < .7)
            'completion_below_regress_threshold',
        ],
        changedVariable: regressed.sets != previousTarget.sets
            ? 'sets'
            : 'target',
      );
    }

    if (readinessReduced) {
      return result(ProgressionDecisionKind.hold, previousTarget, const [
        'readiness_reduced',
      ]);
    }

    if (adherenceRate == null || adherenceRate < .9) {
      return result(ProgressionDecisionKind.hold, previousTarget, const [
        'adherence_below_increase_threshold',
      ]);
    }

    final increased = _increase(
      previousTarget,
      baselineTarget,
      isBeginner: isBeginner,
      targetWeek: targetWeek,
    );
    if (_sameTarget(increased, previousTarget)) {
      return result(ProgressionDecisionKind.hold, previousTarget, const [
        'cycle_cap_reached',
      ]);
    }
    return result(
      ProgressionDecisionKind.increase,
      increased,
      const ['target_met_without_safety_flags'],
      changedVariable: increased.sets != previousTarget.sets
          ? 'sets'
          : previousTarget.targetType == PrescriptionTargetType.repetitions
          ? 'repetitions'
          : 'durationSeconds',
    );
  }

  ProgressionTarget _increase(
    ProgressionTarget current,
    ProgressionTarget baseline, {
    required bool isBeginner,
    required int targetWeek,
  }) {
    if (isBeginner && targetWeek == 4 && current.sets < baseline.sets + 1) {
      return ProgressionTarget(
        sets: current.sets + 1,
        targetType: current.targetType,
        minimum: current.minimum,
        maximum: current.maximum,
      );
    }

    final step = _targetStep(current);
    final maximumDelta =
        current.targetType == PrescriptionTargetType.repetitions
        ? 4
        : baseline.maximum > 90
        ? 240
        : 20;
    final cycleMaximum = baseline.maximum + maximumDelta;
    if (current.maximum < cycleMaximum) {
      final allowedStep = math.min(step, cycleMaximum - current.maximum);
      return ProgressionTarget(
        sets: current.sets,
        targetType: current.targetType,
        minimum: current.minimum + allowedStep,
        maximum: current.maximum + allowedStep,
      );
    }

    if (!isBeginner && targetWeek == 7 && current.sets < baseline.sets + 1) {
      return ProgressionTarget(
        sets: current.sets + 1,
        targetType: current.targetType,
        minimum: current.minimum,
        maximum: current.maximum,
      );
    }
    return current;
  }

  ProgressionTarget _regress(
    ProgressionTarget current,
    ProgressionTarget baseline,
  ) {
    if (current.sets > baseline.sets) {
      return ProgressionTarget(
        sets: current.sets - 1,
        targetType: current.targetType,
        minimum: current.minimum,
        maximum: current.maximum,
      );
    }
    if (current.maximum <= baseline.maximum) return current;
    final step = _targetStep(current);
    return ProgressionTarget(
      sets: current.sets,
      targetType: current.targetType,
      minimum: math.max(baseline.minimum, current.minimum - step),
      maximum: math.max(baseline.maximum, current.maximum - step),
    );
  }

  ProgressionTarget _deload(ProgressionTarget current, int sessionsPerWeek) {
    final factor = sessionsPerWeek == 4 ? .70 : .75;
    final reducedSets = math.max(1, (current.sets * factor).round());
    final setReduction = 1 - (reducedSets / current.sets);
    if (setReduction >= .25 && setReduction <= .30) {
      return ProgressionTarget(
        sets: reducedSets,
        targetType: current.targetType,
        minimum: current.minimum,
        maximum: current.maximum,
      );
    }
    return ProgressionTarget(
      sets: current.sets,
      targetType: current.targetType,
      minimum: math.max(1, (current.minimum * factor).ceil()),
      maximum: math.max(1, (current.maximum * factor).ceil()),
    );
  }

  int _targetStep(ProgressionTarget target) =>
      target.targetType == PrescriptionTargetType.repetitions
      ? 1
      : target.maximum > 90
      ? 60
      : 5;

  bool _sameTarget(ProgressionTarget left, ProgressionTarget right) =>
      left.sets == right.sets &&
      left.targetType == right.targetType &&
      left.minimum == right.minimum &&
      left.maximum == right.maximum;
}
