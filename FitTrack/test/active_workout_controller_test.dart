import 'package:fittrack/models/active_workout.dart';
import 'package:fittrack/models/exercise.dart';
import 'package:fittrack/services/active_workout_controller.dart';
import 'package:fittrack/services/active_workout_draft_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeClock {
  FakeClock(this.now);

  DateTime now;

  void advance(Duration duration) => now = now.add(duration);

  DateTime call() => now;
}

WorkoutSessionSnapshot buildSnapshot({
  int restSeconds = 30,
  int? transitionAfterExerciseSeconds,
}) => WorkoutSessionSnapshot(
  programSessionId: 'program-session-1',
  title: 'Full body A',
  programTitle: 'Starter',
  contentVersion: '1.0.0',
  sourceRefs: const ['source-1'],
  exercises: [
    WorkoutExerciseSnapshot(
      exerciseId: 'squat',
      name: 'Squat',
      setCount: 2,
      target: const WorkoutTargetContext(
        type: 'repetitions',
        label: '8-12 reps',
      ),
      restSeconds: restSeconds,
      preparationSeconds: 0,
      transitionAfterExerciseSeconds: transitionAfterExerciseSeconds,
      muscleGroup: 'legs',
      cues: const ['Keep a comfortable tempo'],
      poseRuleVersionId: 'squat_pose_v1',
      cameraTargetReps: 10,
    ),
    WorkoutExerciseSnapshot(
      exerciseId: 'plank',
      name: 'Plank',
      setCount: 1,
      target: const WorkoutTargetContext(type: 'duration', label: '30 seconds'),
      restSeconds: 0,
      preparationSeconds: 0,
      muscleGroup: 'core',
    ),
  ],
);

ActiveWorkoutController buildController(
  FakeClock clock, {
  int restSeconds = 30,
  int? transitionAfterExerciseSeconds,
  WorkoutConfirmationMode confirmationMode = WorkoutConfirmationMode.aiCamera,
}) => ActiveWorkoutController.create(
  sessionId: 'active-1',
  userId: 'user-1',
  occurrenceId: 'occurrence-1',
  programVersionId: 'program-version-1',
  snapshot: buildSnapshot(
    restSeconds: restSeconds,
    transitionAfterExerciseSeconds: transitionAfterExerciseSeconds,
  ),
  confirmationMode: confirmationMode,
  clock: clock.call,
);

void main() {
  test('uses separate rest values for sets and exercise transitions', () {
    final clock = FakeClock(DateTime.utc(2026, 7, 28, 8));
    final controller = buildController(
      clock,
      restSeconds: 30,
      transitionAfterExerciseSeconds: 12,
    );

    controller.start();
    controller.completeSet();
    expect(controller.restRemaining, const Duration(seconds: 30));

    controller.skipRest();
    controller.completeSet();
    expect(controller.currentExercise.exerciseId, 'plank');
    expect(controller.confirmationMode, WorkoutConfirmationMode.guided);
    expect(controller.restRemaining, const Duration(seconds: 12));
  });

  test('moves through work, rest, skip and two-phase completion', () {
    final clock = FakeClock(DateTime.utc(2026, 7, 24, 8));
    final controller = buildController(clock);

    expect(controller.phase, WorkoutPhase.preparing);
    controller.start();
    expect(controller.phase, WorkoutPhase.working);

    clock.advance(const Duration(seconds: 5));
    controller.redoSet();
    expect(controller.setIndex, 0);
    expect(controller.setEvents.single.status, SetEventStatus.redone);

    clock.advance(const Duration(seconds: 5));
    controller.completeSet();
    expect(controller.phase, WorkoutPhase.resting);
    expect(controller.setIndex, 1);

    controller.skipRest();
    controller.skipSet(reason: 'discomfort');
    expect(controller.phase, WorkoutPhase.resting);
    expect(controller.currentExercise.exerciseId, 'plank');

    controller.skipRest();
    controller.completeSet();
    expect(controller.phase, WorkoutPhase.finishing);

    final first = controller.finish();
    final retry = controller.finish();
    expect(retry.idempotencyKey, first.idempotencyKey);
    expect(retry.completedAt, first.completedAt);
    expect(first.completedSetCount, 2);
    expect(first.redoneSetCount, 1);
    expect(first.skippedSetCount, 1);
    expect(first.status, WorkoutCompletionStatus.partiallyCompleted);

    controller.markCompletionSaved(idempotencyKey: first.idempotencyKey);
    expect(controller.phase, WorkoutPhase.completed);
    final idempotent = controller.markCompletionSaved(
      idempotencyKey: first.idempotencyKey,
    );
    expect(idempotent.id, first.id);
  });

  test(
    'timestamp rest reconciles after background and rejects stale callback',
    () {
      final clock = FakeClock(DateTime.utc(2026, 7, 24, 9));
      final controller = buildController(clock);
      controller.start();
      final workingPhaseId = controller.phaseId;
      controller.completeSet(expectedPhaseId: workingPhaseId);
      final restPhaseId = controller.phaseId;

      expect(controller.restRemaining, const Duration(seconds: 30));
      clock.advance(const Duration(seconds: 10));
      controller.extendRest(expectedPhaseId: restPhaseId);
      expect(controller.restRemaining, const Duration(seconds: 35));

      // The timer callback captured before +15 seconds is now stale.
      clock.advance(const Duration(seconds: 35));
      expect(controller.reconcile(expectedPhaseId: restPhaseId), isFalse);
      expect(controller.phase, WorkoutPhase.resting);
      expect(controller.reconcile(expectedPhaseId: controller.phaseId), isTrue);
      expect(controller.phase, WorkoutPhase.working);
    },
  );

  test('pause freezes active time and resumes a frozen rest deadline', () {
    final clock = FakeClock(DateTime.utc(2026, 7, 24, 10));
    final controller = buildController(clock);
    controller.start();
    clock.advance(const Duration(seconds: 20));
    controller.completeSet();
    clock.advance(const Duration(seconds: 5));

    controller.pause();
    expect(controller.phase, WorkoutPhase.paused);
    expect(controller.activeDuration, const Duration(seconds: 25));
    expect(controller.restRemaining, const Duration(seconds: 25));

    clock.advance(const Duration(minutes: 3));
    expect(controller.activeDuration, const Duration(seconds: 25));
    expect(controller.restRemaining, const Duration(seconds: 25));

    controller.resume();
    expect(controller.phase, WorkoutPhase.resting);
    expect(controller.restRemaining, const Duration(seconds: 25));
    clock.advance(const Duration(seconds: 25));
    controller.reconcile();
    expect(controller.phase, WorkoutPhase.working);
    expect(controller.activeDuration, const Duration(seconds: 50));
  });

  test('checkpoint JSON round trip keeps snapshot, cursor and timestamps', () {
    final clock = FakeClock(DateTime.utc(2026, 7, 24, 11));
    final controller = buildController(clock);
    controller.start();
    clock.advance(const Duration(seconds: 7));
    controller.completeSet();

    final checkpoint = ActiveWorkoutDraft.fromJsonString(
      controller.checkpointJson(),
    );
    final restored = ActiveWorkoutController.restore(
      checkpoint,
      clock: clock.call,
    );

    expect(restored.phase, WorkoutPhase.resting);
    expect(restored.phaseId, controller.phaseId);
    expect(restored.setIndex, 1);
    expect(restored.currentExercise.target.label, '8-12 reps');
    expect(restored.setEvents.single.detectedRepCount, isNull);
    expect(restored.activeDuration, const Duration(seconds: 7));
    expect(restored.restRemaining, const Duration(seconds: 30));
  });

  test(
    'draft store is scoped by UID and preserves another user draft',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = ActiveWorkoutDraftStore();
      final clock = FakeClock(DateTime.utc(2026, 7, 24, 12));
      final first = buildController(clock).checkpoint();
      final secondController = ActiveWorkoutController.create(
        sessionId: 'active-2',
        userId: 'user-2',
        occurrenceId: 'occurrence-2',
        programVersionId: 'program-version-1',
        snapshot: buildSnapshot(),
        clock: clock.call,
      );

      await store.save('user-1', first);
      await store.save('user-2', secondController.checkpoint());
      await store.clear('user-1');

      expect(await store.load('user-1'), isNull);
      expect((await store.load('user-2'))?.sessionId, 'active-2');
    },
  );

  test('AI evidence is optional and guided mode never infers actual reps', () {
    final clock = FakeClock(DateTime.utc(2026, 7, 24, 13));
    final controller = buildController(
      clock,
      restSeconds: 0,
      confirmationMode: WorkoutConfirmationMode.guided,
    );
    controller.start();

    expect(
      () => controller.completeSet(detectedRepCount: 10, confidence: .9),
      throwsArgumentError,
    );
    const evidence = CameraSetEvidence(
      ruleVersionId: 'squat_pose_v1',
      evaluatedFrameCount: 12,
      reliableFrameCount: 10,
      formCueCount: 2,
      averageConfidence: .88,
      minimumConfidence: .72,
    );
    expect(
      () => controller.completeSet(cameraEvidence: evidence),
      throwsArgumentError,
    );
    controller.setConfirmationMode(WorkoutConfirmationMode.aiCamera);
    controller.completeSet(
      detectedRepCount: 10,
      confidence: .9,
      cameraEvidence: evidence,
    );
    expect(controller.setEvents.single.detectedRepCount, 10);
    expect(controller.setEvents.single.confidence, .9);
    expect(
      controller.setEvents.single.cameraEvidence?.ruleVersionId,
      'squat_pose_v1',
    );
    expect(
      controller.setEvents.single.cameraEvidence?.reliableFrameRatio,
      closeTo(10 / 12, .001),
    );

    final restored = ActiveWorkoutDraft.fromJsonString(
      controller.checkpointJson(),
    );
    expect(restored.setEvents.single.cameraEvidence?.formCueCount, 2);
    expect(restored.setEvents.single.cameraEvidence?.minimumConfidence, .72);
  });

  test('timed set persists elapsed time and advances only at target', () {
    final clock = FakeClock(DateTime.utc(2026, 7, 24, 14));
    final controller = ActiveWorkoutController.create(
      sessionId: 'timed-session',
      userId: 'user-1',
      occurrenceId: 'occurrence-timed',
      programVersionId: 'program-version-1',
      snapshot: WorkoutSessionSnapshot(
        programSessionId: 'timed-program-session',
        title: 'Timed core',
        exercises: [
          WorkoutExerciseSnapshot(
            exerciseId: 'plank',
            name: 'Plank',
            setCount: 1,
            target: const WorkoutTargetContext(
              type: 'duration_seconds',
              label: '3 seconds',
              minimum: 3,
              maximum: 3,
            ),
            executionMode: ExerciseExecutionMode.timer,
            cueMode: ExerciseCueMode.countdown,
            restSeconds: 0,
            preparationSeconds: 0,
          ),
        ],
      ),
      clock: clock.call,
    );

    controller.start();
    clock.advance(const Duration(seconds: 2));
    controller.pauseTimedSet();
    expect(controller.timedSetRemaining, const Duration(seconds: 1));
    expect(controller.reconcileTimedSet(), isFalse);

    controller.startTimedSet();
    clock.advance(const Duration(seconds: 1));
    expect(controller.reconcileTimedSet(), isTrue);
    expect(controller.phase, WorkoutPhase.finishing);
    expect(controller.setEvents.single.timedDurationSeconds, 3);
  });

  test('guided workout counts down, auto-runs and enters rest', () {
    final clock = FakeClock(DateTime.utc(2026, 7, 24, 14, 30));
    final controller = ActiveWorkoutController.create(
      sessionId: 'auto-timed-session',
      userId: 'user-1',
      occurrenceId: 'occurrence-auto-timed',
      programVersionId: 'program-version-1',
      snapshot: WorkoutSessionSnapshot(
        programSessionId: 'auto-timed-program-session',
        title: 'Auto timed',
        exercises: [
          WorkoutExerciseSnapshot(
            exerciseId: 'push_up',
            name: 'Chống đẩy',
            setCount: 2,
            target: const WorkoutTargetContext(
              type: 'duration_seconds',
              label: '3 giây',
              minimum: 3,
              maximum: 3,
            ),
            executionMode: ExerciseExecutionMode.timer,
            cueMode: ExerciseCueMode.countdown,
            preparationSeconds: 5,
            workDurationSeconds: 3,
            restSeconds: 4,
          ),
        ],
      ),
      clock: clock.call,
    );

    controller.start();
    expect(controller.phase, WorkoutPhase.countingDown);
    expect(controller.preparationRemaining, const Duration(seconds: 5));
    clock.advance(const Duration(seconds: 4));
    expect(controller.reconcile(), isFalse);
    clock.advance(const Duration(seconds: 1));
    expect(controller.reconcile(), isTrue);
    expect(controller.phase, WorkoutPhase.working);
    expect(controller.isTimedSetRunning, isTrue);

    clock.advance(const Duration(seconds: 3));
    expect(controller.reconcileTimedSet(), isTrue);
    expect(controller.phase, WorkoutPhase.resting);
    expect(controller.restRemaining, const Duration(seconds: 4));
    clock.advance(const Duration(seconds: 4));
    expect(controller.reconcile(), isTrue);
    expect(controller.phase, WorkoutPhase.countingDown);
    expect(controller.currentExercise.exerciseId, 'push_up');
    expect(controller.setIndex, 1);
  });

  test('AI camera squat completes by detected repetitions without timer', () {
    final clock = FakeClock(DateTime.utc(2026, 7, 24, 14, 45));
    final controller = ActiveWorkoutController.create(
      sessionId: 'camera-timed-squat',
      userId: 'user-1',
      occurrenceId: 'occurrence-camera-timed-squat',
      programVersionId: 'program-version-1',
      confirmationMode: WorkoutConfirmationMode.aiCamera,
      snapshot: WorkoutSessionSnapshot(
        programSessionId: 'camera-timed-program-session',
        title: 'Squat camera',
        exercises: [
          WorkoutExerciseSnapshot(
            exerciseId: 'squat',
            name: 'Squat không tạ',
            setCount: 1,
            target: const WorkoutTargetContext(
              type: 'duration_seconds',
              label: '30 giây',
              minimum: 30,
              maximum: 30,
            ),
            executionMode: ExerciseExecutionMode.timer,
            cueMode: ExerciseCueMode.countdown,
            cameraTargetReps: 10,
            poseRuleVersionId: 'squat_pose_v1',
            preparationSeconds: 0,
            workDurationSeconds: 30,
            restSeconds: 0,
          ),
        ],
      ),
      clock: clock.call,
    );

    controller.start();
    expect(controller.usesAiCamera, isTrue);
    expect(controller.usesActiveTimer, isFalse);
    expect(controller.isTimedSetRunning, isFalse);
    expect(controller.currentExercise.cameraTargetReps, 10);

    clock.advance(const Duration(seconds: 12));
    controller.completeSet(detectedRepCount: 7, confidence: .9);

    expect(controller.phase, WorkoutPhase.finishing);
    expect(controller.setEvents.single.detectedRepCount, 7);
    expect(controller.setEvents.single.timedDurationSeconds, isNull);
    expect(controller.setEvents.single.targetContext.label, '30 giây');

    final restored = ActiveWorkoutDraft.fromJsonString(
      controller.checkpointJson(),
    );
    expect(restored.snapshot.exercises.single.cameraTargetReps, 10);
  });

  test('AI camera rejects every exercise id except exact squat', () {
    final clock = FakeClock(DateTime.utc(2026, 7, 24, 14, 50));
    final controller = ActiveWorkoutController.create(
      sessionId: 'camera-other-squat',
      userId: 'user-1',
      occurrenceId: 'occurrence-camera-other-squat',
      programVersionId: 'program-version-1',
      confirmationMode: WorkoutConfirmationMode.aiCamera,
      snapshot: WorkoutSessionSnapshot(
        programSessionId: 'other-squat-session',
        title: 'Other squat',
        exercises: [
          WorkoutExerciseSnapshot(
            exerciseId: 'fedb_Bodyweight_Squat',
            name: 'Split Squat không tạ',
            setCount: 1,
            target: const WorkoutTargetContext(
              type: 'duration_seconds',
              label: '30 giây',
              minimum: 30,
              maximum: 30,
            ),
            executionMode: ExerciseExecutionMode.timer,
            cueMode: ExerciseCueMode.countdown,
            cameraTargetReps: 10,
            poseRuleVersionId: 'squat_pose_v1',
            preparationSeconds: 0,
            workDurationSeconds: 30,
            restSeconds: 0,
          ),
        ],
      ),
      clock: clock.call,
    );

    expect(controller.confirmationMode, WorkoutConfirmationMode.guided);
    expect(
      controller.setConfirmationMode(WorkoutConfirmationMode.aiCamera),
      isFalse,
    );
  });

  test('authored alternative preserves prescription context in snapshot', () {
    final clock = FakeClock(DateTime.utc(2026, 7, 24, 15));
    final controller = ActiveWorkoutController.create(
      sessionId: 'alternative-session',
      userId: 'user-1',
      occurrenceId: 'occurrence-alternative',
      programVersionId: 'program-version-1',
      snapshot: WorkoutSessionSnapshot(
        programSessionId: 'alternative-program-session',
        title: 'Alternative exercise',
        exercises: [
          WorkoutExerciseSnapshot(
            exerciseId: 'squat',
            name: 'Squat',
            setCount: 1,
            target: const WorkoutTargetContext(
              type: 'repetitions',
              label: '8 reps',
              minimum: 8,
              maximum: 8,
            ),
            restSeconds: 0,
            alternatives: const [
              WorkoutExerciseAlternativeSnapshot(
                exerciseId: 'squat',
                name: 'Squat',
              ),
              WorkoutExerciseAlternativeSnapshot(
                exerciseId: 'glute_bridge',
                name: 'Glute bridge',
                instructions: ['Drive through the heels'],
                commonMistakes: ['Arching the lower back'],
              ),
            ],
          ),
        ],
      ),
      clock: clock.call,
    );

    expect(controller.selectAlternative('glute_bridge'), isTrue);
    expect(controller.currentExercise.exerciseId, 'glute_bridge');
    expect(controller.currentExercise.prescribedExerciseId, 'squat');
    expect(controller.currentExercise.target.label, '8 reps');
    expect(controller.currentExercise.isAlternative, isTrue);
    expect(controller.currentExercise.instructions, [
      'Drive through the heels',
    ]);
    expect(controller.currentExercise.commonMistakes, [
      'Arching the lower back',
    ]);
  });

  test('persists one progression feedback record per resolved exercise', () {
    final clock = FakeClock(DateTime.utc(2026, 8, 1, 8));
    final controller = buildController(
      clock,
      restSeconds: 0,
      transitionAfterExerciseSeconds: 0,
      confirmationMode: WorkoutConfirmationMode.guided,
    );

    controller.start();
    controller.completeSet();
    expect(controller.pendingFeedbackExerciseIndices, isEmpty);

    controller.completeSet();
    expect(controller.pendingFeedbackExerciseIndices, [0]);
    controller.recordExerciseFeedback(
      exerciseIndex: 0,
      outcome: ExerciseProgressOutcome.easy,
      actualLoadKg: 20,
    );
    expect(controller.pendingFeedbackExerciseIndices, isEmpty);

    final restored = ActiveWorkoutController.restore(
      ActiveWorkoutDraft.fromJsonString(controller.checkpointJson()),
      clock: clock.call,
    );
    expect(restored.exerciseProgressEvidence, hasLength(1));
    expect(restored.exerciseProgressEvidence.single.progressionKey, 'squat');
    expect(restored.exerciseProgressEvidence.single.actualLoadKg, 20);

    restored.completeSet();
    expect(restored.pendingFeedbackExerciseIndices, [1]);
    restored.recordExerciseFeedback(
      exerciseIndex: 1,
      outcome: ExerciseProgressOutcome.appropriate,
    );
    final completion = restored.finish();

    expect(completion.exerciseProgressEvidence, hasLength(2));
    expect(
      completion.exerciseProgressEvidence.last.outcome,
      ExerciseProgressOutcome.appropriate,
    );
  });
}
