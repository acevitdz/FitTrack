import 'package:fittrack/models/active_workout.dart';
import 'package:fittrack/models/progression.dart';
import 'package:fittrack/models/program.dart';
import 'package:fittrack/services/progression_engine.dart';
import 'package:flutter_test/flutter_test.dart';

const _baseline = ProgressionTarget(
  sets: 2,
  targetType: PrescriptionTargetType.repetitions,
  minimum: 8,
  maximum: 10,
);

ExerciseProgressEvidence evidence({
  ExerciseProgressOutcome outcome = ExerciseProgressOutcome.appropriate,
  int scheduledSets = 2,
  int completedSets = 2,
  String performedExerciseId = 'squat',
}) => ExerciseProgressEvidence(
  prescriptionId: 'week-1-squat',
  progressionKey: 'squat',
  prescribedExerciseId: 'squat',
  performedExerciseId: performedExerciseId,
  exerciseIndex: 0,
  scheduledSets: scheduledSets,
  completedSets: completedSets,
  outcome: outcome,
  recordedAt: DateTime.utc(2026, 8, 1),
);

ProgressionDecision evaluate({
  int targetWeek = 2,
  bool isBeginner = true,
  ProgressionTarget previousTarget = _baseline,
  List<ExerciseProgressEvidence>? exerciseEvidence,
  bool readinessReduced = false,
}) => const ProgressionEngine().evaluate(
  enrollmentId: 'enrollment-1',
  programVersionId: 'program-1',
  prescriptionId: 'week-$targetWeek-squat',
  progressionKey: 'squat',
  sourceWeek: targetWeek - 1,
  targetWeek: targetWeek,
  isBeginner: isBeginner,
  sessionsPerWeek: isBeginner ? 3 : 4,
  baselineTarget: _baseline,
  previousTarget: previousTarget,
  evidence: exerciseEvidence ?? [evidence()],
  setEvents: const [],
  readinessReduced: readinessReduced,
  createdAt: DateTime.utc(2026, 8, 2),
);

void main() {
  test('increases one repetition step after complete successful evidence', () {
    final decision = evaluate();

    expect(decision.kind, ProgressionDecisionKind.increase);
    expect(decision.nextTarget.minimum, 9);
    expect(decision.nextTarget.maximum, 11);
    expect(decision.nextTarget.sets, 2);
    expect(decision.adherenceRate, 1);
  });

  test('holds when adherence is below the increase threshold', () {
    final decision = evaluate(
      exerciseEvidence: [evidence(scheduledSets: 4, completedSets: 3)],
    );

    expect(decision.kind, ProgressionDecisionKind.hold);
    expect(
      decision.reasonCodes,
      contains('adherence_below_increase_threshold'),
    );
    expect(decision.nextTarget.maximum, 10);
  });

  test('regresses when completion falls below seventy percent', () {
    const previous = ProgressionTarget(
      sets: 2,
      targetType: PrescriptionTargetType.repetitions,
      minimum: 9,
      maximum: 11,
    );
    final decision = evaluate(
      previousTarget: previous,
      exerciseEvidence: [evidence(scheduledSets: 4, completedSets: 2)],
    );

    expect(decision.kind, ProgressionDecisionKind.regress);
    expect(
      decision.reasonCodes,
      contains('completion_below_regress_threshold'),
    );
    expect(decision.nextTarget.maximum, 10);
  });

  test('regresses toward the safe baseline after a failed outcome', () {
    const previous = ProgressionTarget(
      sets: 2,
      targetType: PrescriptionTargetType.repetitions,
      minimum: 9,
      maximum: 11,
    );
    final decision = evaluate(
      previousTarget: previous,
      exerciseEvidence: [evidence(outcome: ExerciseProgressOutcome.failed)],
    );

    expect(decision.kind, ProgressionDecisionKind.regress);
    expect(decision.nextTarget.minimum, 8);
    expect(decision.nextTarget.maximum, 10);
  });

  test('pain has priority and creates a safety hold', () {
    final decision = evaluate(
      exerciseEvidence: [evidence(outcome: ExerciseProgressOutcome.discomfort)],
    );

    expect(decision.kind, ProgressionDecisionKind.safetyHold);
    expect(decision.reasonCodes, contains('pain_or_discomfort_reported'));
    expect(decision.nextTarget.maximum, 10);
  });

  test('holds when an authored alternative was used', () {
    final decision = evaluate(
      exerciseEvidence: [evidence(performedExerciseId: 'box_squat')],
    );

    expect(decision.kind, ProgressionDecisionKind.hold);
    expect(decision.reasonCodes, contains('alternative_exercise_used'));
  });

  test('advanced week four is a deload instead of another increase', () {
    const previous = ProgressionTarget(
      sets: 4,
      targetType: PrescriptionTargetType.repetitions,
      minimum: 10,
      maximum: 12,
    );
    final decision = evaluate(
      targetWeek: 4,
      isBeginner: false,
      previousTarget: previous,
      exerciseEvidence: const [],
      readinessReduced: true,
    );

    expect(decision.kind, ProgressionDecisionKind.deload);
    expect(decision.nextTarget.sets, 3);
    expect(decision.nextTarget.maximum, 12);
  });
}
