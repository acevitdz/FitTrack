import 'package:flutter_test/flutter_test.dart';
import 'package:fittrack/models/exercise.dart';
import 'package:fittrack/models/program.dart';
import 'package:fittrack/services/execution_config_resolver.dart';

void main() {
  group('ExecutionConfigResolver', () {
    const exerciseRep = Exercise(
      id: 'squat',
      name: 'Squat',
      englishName: 'Squat',
      muscleGroup: 'legs',
      difficulty: 'beginner',
      equipment: 'bodyweight',
      location: 'home',
      instructions: [],
      commonMistakes: [],
      suggestedSets: 3,
      suggestedReps: 10,
      executionMode: ExerciseExecutionMode.repetition,
      cueMode: ExerciseCueMode.voice,
      tempoUp: 2,
      tempoHold: 1,
      tempoDown: 2,
    );

    const exerciseTimer = Exercise(
      id: 'plank',
      name: 'Plank',
      englishName: 'Plank',
      muscleGroup: 'core',
      difficulty: 'beginner',
      equipment: 'bodyweight',
      location: 'home',
      instructions: [],
      commonMistakes: [],
      suggestedSets: 3,
      suggestedReps: 30,
      executionMode: ExerciseExecutionMode.timer,
      cueMode: ExerciseCueMode.countdown,
    );

    test('infers repetition mode when no overrides exist on prescription or exercise', () {
      const prescription = ExercisePrescription(
        id: 'p1',
        exerciseId: 'squat',
        order: 0,
        sets: 3,
        targetType: PrescriptionTargetType.repetitions,
        targetRange: PrescriptionTargetRange(minimum: 10, maximum: 10),
        restSeconds: 45,
        cues: [],
        alternativeExerciseIds: [],
        prescriptionVersion: 'v1',
        mediaVersion: 'v1',
        cueVersion: 'v1',
      );

      final config = resolveExecutionConfig(prescription: prescription);
      expect(config.executionMode, ExerciseExecutionMode.repetition);
      expect(config.cueMode, ExerciseCueMode.voice);
      expect(config.tempoUp, 2);
      expect(config.tempoHold, 1);
      expect(config.tempoDown, 2);
    });

    test('infers timer mode when targetType is durationSeconds', () {
      const prescription = ExercisePrescription(
        id: 'p2',
        exerciseId: 'plank',
        order: 0,
        sets: 3,
        targetType: PrescriptionTargetType.durationSeconds,
        targetRange: PrescriptionTargetRange(minimum: 30, maximum: 30),
        restSeconds: 45,
        cues: [],
        alternativeExerciseIds: [],
        prescriptionVersion: 'v1',
        mediaVersion: 'v1',
        cueVersion: 'v1',
      );

      final config = resolveExecutionConfig(prescription: prescription);
      expect(config.executionMode, ExerciseExecutionMode.timer);
      expect(config.cueMode, ExerciseCueMode.countdown);
    });

    test('uses Exercise default when prescription has no overrides', () {
      const prescription = ExercisePrescription(
        id: 'p3',
        exerciseId: 'plank',
        order: 0,
        sets: 3,
        targetType: PrescriptionTargetType.repetitions,
        targetRange: PrescriptionTargetRange(minimum: 10, maximum: 10),
        restSeconds: 45,
        cues: [],
        alternativeExerciseIds: [],
        prescriptionVersion: 'v1',
        mediaVersion: 'v1',
        cueVersion: 'v1',
      );

      final config = resolveExecutionConfig(
        prescription: prescription,
        exercise: exerciseTimer,
      );
      expect(config.executionMode, ExerciseExecutionMode.timer);
      expect(config.cueMode, ExerciseCueMode.countdown);
    });

    test('prescription override takes precedence over Exercise default', () {
      const prescription = ExercisePrescription(
        id: 'p4',
        exerciseId: 'squat',
        order: 0,
        sets: 3,
        targetType: PrescriptionTargetType.repetitions,
        targetRange: PrescriptionTargetRange(minimum: 10, maximum: 10),
        restSeconds: 45,
        cues: [],
        alternativeExerciseIds: [],
        prescriptionVersion: 'v1',
        mediaVersion: 'v1',
        cueVersion: 'v1',
        executionMode: ExerciseExecutionMode.timer,
        cueMode: ExerciseCueMode.countdown,
        tempoUp: 3,
        tempoHold: 2,
        tempoDown: 3,
      );

      final config = resolveExecutionConfig(
        prescription: prescription,
        exercise: exerciseRep,
      );
      expect(config.executionMode, ExerciseExecutionMode.timer);
      expect(config.cueMode, ExerciseCueMode.countdown);
      expect(config.tempoUp, 3);
      expect(config.tempoHold, 2);
      expect(config.tempoDown, 3);
    });

    test('resolveDurationSeconds returns minimum seconds', () {
      const prescription = ExercisePrescription(
        id: 'p5',
        exerciseId: 'plank',
        order: 0,
        sets: 3,
        targetType: PrescriptionTargetType.durationSeconds,
        targetRange: PrescriptionTargetRange(minimum: 45, maximum: 45),
        restSeconds: 45,
        cues: [],
        alternativeExerciseIds: [],
        prescriptionVersion: 'v1',
        mediaVersion: 'v1',
        cueVersion: 'v1',
      );

      expect(resolveDurationSeconds(prescription), 45);
    });
  });
}
