import '../models/exercise.dart';
import '../models/program.dart';

class InvalidPrescriptionException implements Exception {
  const InvalidPrescriptionException(this.message);
  final String message;

  @override
  String toString() => 'InvalidPrescriptionException: $message';
}

class ResolvedExecutionConfig {
  const ResolvedExecutionConfig({
    required this.executionMode,
    required this.cueMode,
    required this.tempoUp,
    required this.tempoHold,
    required this.tempoDown,
  })  : assert(tempoUp >= 0),
        assert(tempoHold >= 0),
        assert(tempoDown >= 0);

  final ExerciseExecutionMode executionMode;
  final ExerciseCueMode cueMode;
  final int tempoUp;
  final int tempoHold;
  final int tempoDown;

  int get totalTempoSeconds => tempoUp + tempoHold + tempoDown;
}

/// Resolves execution configuration using precedence:
/// 1. Prescription override
/// 2. Exercise default
/// 3. Prescription target type inference
ResolvedExecutionConfig resolveExecutionConfig({
  required ExercisePrescription prescription,
  Exercise? exercise,
}) {
  final inferredMode =
      prescription.targetType == PrescriptionTargetType.durationSeconds
          ? ExerciseExecutionMode.timer
          : ExerciseExecutionMode.repetition;

  final mode =
      prescription.executionMode ?? exercise?.executionMode ?? inferredMode;

  final defaultCueMode = mode == ExerciseExecutionMode.timer
      ? ExerciseCueMode.countdown
      : ExerciseCueMode.voice;

  final cueMode =
      prescription.cueMode ?? exercise?.cueMode ?? defaultCueMode;

  final tempoUp = prescription.tempoUp ?? exercise?.tempoUp ?? 2;
  final tempoHold = prescription.tempoHold ?? exercise?.tempoHold ?? 1;
  final tempoDown = prescription.tempoDown ?? exercise?.tempoDown ?? 2;

  return ResolvedExecutionConfig(
    executionMode: mode,
    cueMode: cueMode,
    tempoUp: tempoUp,
    tempoHold: tempoHold,
    tempoDown: tempoDown,
  );
}

int resolveDurationSeconds(ExercisePrescription prescription) {
  return prescription.targetRange.minimum;
}
