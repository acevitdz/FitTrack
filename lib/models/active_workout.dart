import 'dart:convert';

import '../services/execution_config_resolver.dart';
import 'exercise.dart';
import 'program.dart';

/// Sentinel shared with controllers that need to forward an omitted nullable
/// argument through [ActiveWorkoutDraft.copyWith].
const Object activeWorkoutUnset = _ActiveWorkoutUnset();

class _ActiveWorkoutUnset {
  const _ActiveWorkoutUnset();
}

/// The lifecycle of one guided workout session.
enum WorkoutPhase {
  preparing,
  countingDown,
  working,
  resting,
  paused,
  finishing,
  completed,
  discarded,
}

enum WorkoutConfirmationMode { aiCamera, guided }

enum SetEventStatus { completed, redone, skipped }

enum SetCompletionStatus { completed, completedEarly, skipped }

enum WorkoutCompletionStatus { completed, partiallyCompleted, abandoned }

enum ExerciseProgressOutcome { easy, appropriate, failed, discomfort }

/// Prescribed context shown to the user. It is deliberately display-oriented:
/// it is not an actual-result input and contains no external load or volume.
class WorkoutTargetContext {
  const WorkoutTargetContext({
    required this.type,
    required this.label,
    this.minimum,
    this.maximum,
  });

  final String type;
  final String label;
  final int? minimum;
  final int? maximum;

  Map<String, dynamic> toJson() => {
    'type': type,
    'label': label,
    'minimum': minimum,
    'maximum': maximum,
  };

  factory WorkoutTargetContext.fromJson(Map<String, dynamic> json) =>
      WorkoutTargetContext(
        type: json['type'] as String? ?? 'unknown',
        label: json['label'] as String? ?? '',
        minimum: (json['minimum'] as num?)?.toInt(),
        maximum: (json['maximum'] as num?)?.toInt(),
      );
}

int _defaultGuidedWorkSeconds(WorkoutTargetContext target) {
  if (const {
    'duration_seconds',
    'durationSeconds',
    'duration',
  }.contains(target.type)) {
    return target.minimum ?? target.maximum ?? 30;
  }
  // Guided sets run on a timer. Repetition prescriptions remain visible for
  // Camera Coach and history, while a conservative three-second tempo turns
  // the upper rep target into an authored runtime fallback.
  final repetitions = target.maximum ?? target.minimum ?? 10;
  return (repetitions * 3).clamp(20, 60);
}

class WorkoutExerciseAlternativeSnapshot {
  const WorkoutExerciseAlternativeSnapshot({
    required this.exerciseId,
    required this.name,
    this.muscleGroup = '',
    this.secondaryMuscles = const [],
    this.equipment = '',
    this.instructions = const [],
    this.commonMistakes = const [],
    this.mediaUrl,
    this.mediaAltText,
  });

  final String exerciseId;
  final String name;
  final String muscleGroup;
  final List<String> secondaryMuscles;
  final String equipment;
  final List<String> instructions;
  final List<String> commonMistakes;
  final String? mediaUrl;
  final String? mediaAltText;

  Map<String, dynamic> toJson() => {
    'exerciseId': exerciseId,
    'name': name,
    'muscleGroup': muscleGroup,
    'secondaryMuscles': secondaryMuscles,
    'equipment': equipment,
    'instructions': instructions,
    'commonMistakes': commonMistakes,
    'mediaUrl': mediaUrl,
    'mediaAltText': mediaAltText,
  };

  factory WorkoutExerciseAlternativeSnapshot.fromJson(
    Map<String, dynamic> json,
  ) => WorkoutExerciseAlternativeSnapshot(
    exerciseId: json['exerciseId'] as String,
    name: json['name'] as String,
    muscleGroup: json['muscleGroup'] as String? ?? '',
    secondaryMuscles: List<String>.from(
      json['secondaryMuscles'] as List? ?? const [],
    ),
    equipment: json['equipment'] as String? ?? '',
    instructions: List<String>.from(json['instructions'] as List? ?? const []),
    commonMistakes: List<String>.from(
      json['commonMistakes'] as List? ?? const [],
    ),
    mediaUrl: json['mediaUrl'] as String?,
    mediaAltText: json['mediaAltText'] as String?,
  );
}

/// Immutable exercise data captured when a session starts. Catalog edits do
/// not change a workout that is already running or its history.
class WorkoutExerciseSnapshot {
  WorkoutExerciseSnapshot({
    required this.exerciseId,
    String? prescriptionId,
    String? progressionKey,
    required this.name,
    required this.setCount,
    required this.target,
    required this.restSeconds,
    this.preparationSeconds = 5,
    int? workDurationSeconds,
    int? transitionAfterExerciseSeconds,
    this.muscleGroup = '',
    List<String> secondaryMuscles = const [],
    this.equipment = '',
    List<String> cues = const [],
    List<String> instructions = const [],
    List<String> commonMistakes = const [],
    this.mediaUrl,
    this.mediaAltText,
    this.poseRuleVersionId,
    this.cameraTargetReps,
    String? prescribedExerciseId,
    List<WorkoutExerciseAlternativeSnapshot> alternatives = const [],
    this.executionMode = ExerciseExecutionMode.repetition,
    this.cueMode = ExerciseCueMode.voice,
    this.tempoUp = 2,
    this.tempoHold = 1,
    this.tempoDown = 2,
  }) : prescriptionId = prescriptionId ?? prescribedExerciseId ?? exerciseId,
       progressionKey = progressionKey ?? prescribedExerciseId ?? exerciseId,
       workDurationSeconds =
           workDurationSeconds ?? _defaultGuidedWorkSeconds(target),
       transitionAfterExerciseSeconds =
           transitionAfterExerciseSeconds ?? restSeconds,
       secondaryMuscles = List.unmodifiable(secondaryMuscles),
       cues = List.unmodifiable(cues),
       instructions = List.unmodifiable(instructions),
       commonMistakes = List.unmodifiable(commonMistakes),
       prescribedExerciseId = prescribedExerciseId ?? exerciseId,
       alternatives = List.unmodifiable(alternatives) {
    if (exerciseId.trim().isEmpty) {
      throw ArgumentError.value(exerciseId, 'exerciseId', 'Must not be empty');
    }
    if (name.trim().isEmpty) {
      throw ArgumentError.value(name, 'name', 'Must not be empty');
    }
    if (setCount < 1) {
      throw ArgumentError.value(setCount, 'setCount', 'Must be at least 1');
    }
    if (restSeconds < 0) {
      throw ArgumentError.value(
        restSeconds,
        'restSeconds',
        'Must not be negative',
      );
    }
    if (preparationSeconds < 0) {
      throw ArgumentError.value(
        preparationSeconds,
        'preparationSeconds',
        'Must not be negative',
      );
    }
    if (this.workDurationSeconds < 1) {
      throw ArgumentError.value(
        this.workDurationSeconds,
        'workDurationSeconds',
        'Must be at least one second',
      );
    }
    if (this.transitionAfterExerciseSeconds < 0) {
      throw ArgumentError.value(
        this.transitionAfterExerciseSeconds,
        'transitionAfterExerciseSeconds',
        'Must not be negative',
      );
    }
    final cameraReps = cameraTargetReps;
    if (cameraReps != null && cameraReps < 1) {
      throw ArgumentError.value(
        cameraReps,
        'cameraTargetReps',
        'Must be at least one repetition',
      );
    }
  }

  final String exerciseId;
  final String prescriptionId;
  final String progressionKey;
  final String prescribedExerciseId;
  final String name;
  final String muscleGroup;
  final List<String> secondaryMuscles;
  final String equipment;
  final int setCount;
  final WorkoutTargetContext target;
  final int preparationSeconds;
  final int workDurationSeconds;
  final int restSeconds;
  int get restBetweenSetsSeconds => restSeconds;
  final int transitionAfterExerciseSeconds;
  final List<String> cues;
  final List<String> instructions;
  final List<String> commonMistakes;
  final String? mediaUrl;
  final String? mediaAltText;
  final String? poseRuleVersionId;
  final int? cameraTargetReps;
  final List<WorkoutExerciseAlternativeSnapshot> alternatives;
  final ExerciseExecutionMode executionMode;
  final ExerciseCueMode cueMode;
  final int tempoUp;
  final int tempoHold;
  final int tempoDown;

  bool get isAlternative => exerciseId != prescribedExerciseId;

  /// Camera AI is intentionally limited to the authored bodyweight squat.
  /// Other exercises whose names contain "squat" are separate catalog items
  /// and must continue to use Guided mode.
  bool get supportsAiCamera =>
      exerciseId == 'squat' &&
      poseRuleVersionId == 'squat_pose_v1' &&
      cameraTargetReps != null;

  factory WorkoutExerciseSnapshot.fromPrescription({
    required ExercisePrescription prescription,
    required ResolvedExecutionConfig resolvedConfig,
    String? exerciseName,
    String? exerciseImageUrl,
  }) => WorkoutExerciseSnapshot(
    exerciseId: prescription.exerciseId,
    prescriptionId: prescription.id,
    progressionKey: prescription.id,
    name: exerciseName ?? prescription.exerciseName ?? 'Bài tập',
    setCount: prescription.sets,
    target: WorkoutTargetContext(
      type: prescription.targetType == PrescriptionTargetType.durationSeconds
          ? 'duration_seconds'
          : 'repetitions',
      label: prescription.targetLabel,
      minimum: prescription.targetRange.minimum,
      maximum: prescription.targetRange.maximum,
    ),
    restSeconds: prescription.restSeconds,
    transitionAfterExerciseSeconds: prescription.transitionAfterExerciseSeconds,
    cues: prescription.cues,
    poseRuleVersionId: prescription.poseRuleVersionId,
    cameraTargetReps: prescription.cameraTargetReps,
    mediaUrl: exerciseImageUrl,
    executionMode: resolvedConfig.executionMode,
    cueMode: resolvedConfig.cueMode,
    tempoUp: resolvedConfig.tempoUp,
    tempoHold: resolvedConfig.tempoHold,
    tempoDown: resolvedConfig.tempoDown,
  );

  WorkoutExerciseSnapshot selectAlternative(
    WorkoutExerciseAlternativeSnapshot alternative,
  ) => WorkoutExerciseSnapshot(
    exerciseId: alternative.exerciseId,
    prescriptionId: prescriptionId,
    progressionKey: progressionKey,
    prescribedExerciseId: prescribedExerciseId,
    name: alternative.name,
    muscleGroup: alternative.muscleGroup,
    secondaryMuscles: alternative.secondaryMuscles,
    equipment: alternative.equipment,
    setCount: setCount,
    target: target,
    preparationSeconds: preparationSeconds,
    workDurationSeconds: workDurationSeconds,
    restSeconds: restSeconds,
    transitionAfterExerciseSeconds: transitionAfterExerciseSeconds,
    cues: cues,
    instructions: alternative.instructions,
    commonMistakes: alternative.commonMistakes,
    mediaUrl: alternative.mediaUrl,
    mediaAltText: alternative.mediaAltText,
    alternatives: alternatives,
    executionMode: executionMode,
    cueMode: cueMode,
    tempoUp: tempoUp,
    tempoHold: tempoHold,
    tempoDown: tempoDown,
  );

  Map<String, dynamic> toJson() => {
    'exerciseId': exerciseId,
    'prescriptionId': prescriptionId,
    'progressionKey': progressionKey,
    'prescribedExerciseId': prescribedExerciseId,
    'name': name,
    'muscleGroup': muscleGroup,
    'secondaryMuscles': secondaryMuscles,
    'equipment': equipment,
    'setCount': setCount,
    'target': target.toJson(),
    'preparationSeconds': preparationSeconds,
    'workDurationSeconds': workDurationSeconds,
    'restSeconds': restSeconds,
    'restBetweenSetsSeconds': restBetweenSetsSeconds,
    'transitionAfterExerciseSeconds': transitionAfterExerciseSeconds,
    'cues': cues,
    'instructions': instructions,
    'commonMistakes': commonMistakes,
    'mediaUrl': mediaUrl,
    'mediaAltText': mediaAltText,
    'poseRuleVersionId': poseRuleVersionId,
    'cameraTargetReps': cameraTargetReps,
    'alternatives': alternatives.map((item) => item.toJson()).toList(),
    'executionMode': executionMode.name,
    'cueMode': cueMode.name,
    'tempoUp': tempoUp,
    'tempoHold': tempoHold,
    'tempoDown': tempoDown,
  };

  factory WorkoutExerciseSnapshot.fromJson(Map<String, dynamic> json) {
    final targetMap = json['target'] as Map<String, dynamic>;
    final targetType = targetMap['type'] as String? ?? '';
    final defaultMode = targetType == 'duration_seconds'
        ? ExerciseExecutionMode.timer
        : ExerciseExecutionMode.repetition;
    final defaultCue = targetType == 'duration_seconds'
        ? ExerciseCueMode.countdown
        : ExerciseCueMode.voice;

    return WorkoutExerciseSnapshot(
      exerciseId: json['exerciseId'] as String,
      prescriptionId: json['prescriptionId'] as String?,
      progressionKey: json['progressionKey'] as String?,
      prescribedExerciseId: json['prescribedExerciseId'] as String?,
      name: json['name'] as String,
      muscleGroup: json['muscleGroup'] as String? ?? '',
      secondaryMuscles: List<String>.from(
        json['secondaryMuscles'] as List? ?? const [],
      ),
      equipment: json['equipment'] as String? ?? '',
      setCount: json['setCount'] as int,
      target: WorkoutTargetContext.fromJson(targetMap),
      preparationSeconds: json['preparationSeconds'] as int? ?? 5,
      workDurationSeconds: json['workDurationSeconds'] as int?,
      restSeconds: json['restSeconds'] as int,
      transitionAfterExerciseSeconds:
          json['transitionAfterExerciseSeconds'] as int?,
      cues: List<String>.from(json['cues'] as List? ?? const []),
      instructions: List<String>.from(
        json['instructions'] as List? ?? const [],
      ),
      commonMistakes: List<String>.from(
        json['commonMistakes'] as List? ?? const [],
      ),
      mediaUrl: json['mediaUrl'] as String?,
      mediaAltText: json['mediaAltText'] as String?,
      poseRuleVersionId: json['poseRuleVersionId'] as String?,
      cameraTargetReps: (json['cameraTargetReps'] as num?)?.toInt(),
      alternatives: (json['alternatives'] as List? ?? const [])
          .map(
            (item) => WorkoutExerciseAlternativeSnapshot.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(),
      executionMode: json['executionMode'] != null
          ? ExerciseExecutionMode.values.byName(json['executionMode'] as String)
          : defaultMode,
      cueMode: json['cueMode'] != null
          ? ExerciseCueMode.values.byName(json['cueMode'] as String)
          : defaultCue,
      tempoUp: json['tempoUp'] as int? ?? 2,
      tempoHold: json['tempoHold'] as int? ?? 1,
      tempoDown: json['tempoDown'] as int? ?? 2,
    );
  }
}

class WorkoutSessionSnapshot {
  WorkoutSessionSnapshot({
    required this.programSessionId,
    required this.title,
    required List<WorkoutExerciseSnapshot> exercises,
    this.programTitle = '',
    this.contentVersion = '',
    this.readinessChoice,
    this.readinessVariantTitle,
    this.readinessGuidance,
    List<String> sourceRefs = const [],
  }) : exercises = List.unmodifiable(exercises),
       sourceRefs = List.unmodifiable(sourceRefs) {
    if (programSessionId.trim().isEmpty) {
      throw ArgumentError.value(
        programSessionId,
        'programSessionId',
        'Must not be empty',
      );
    }
    if (title.trim().isEmpty) {
      throw ArgumentError.value(title, 'title', 'Must not be empty');
    }
    if (exercises.isEmpty) {
      throw ArgumentError.value(exercises, 'exercises', 'Must not be empty');
    }
  }

  final String programSessionId;
  final String title;
  final String programTitle;
  final String contentVersion;
  final String? readinessChoice;
  final String? readinessVariantTitle;
  final String? readinessGuidance;
  final List<String> sourceRefs;
  final List<WorkoutExerciseSnapshot> exercises;

  int get totalSetCount =>
      exercises.fold(0, (total, exercise) => total + exercise.setCount);

  WorkoutSessionSnapshot replaceExercise(
    int index,
    WorkoutExerciseSnapshot exercise,
  ) {
    if (index < 0 || index >= exercises.length) {
      throw RangeError.index(index, exercises, 'index');
    }
    final updated = [...exercises];
    updated[index] = exercise;
    return WorkoutSessionSnapshot(
      programSessionId: programSessionId,
      title: title,
      programTitle: programTitle,
      contentVersion: contentVersion,
      readinessChoice: readinessChoice,
      readinessVariantTitle: readinessVariantTitle,
      readinessGuidance: readinessGuidance,
      sourceRefs: sourceRefs,
      exercises: updated,
    );
  }

  Map<String, dynamic> toJson() => {
    'programSessionId': programSessionId,
    'title': title,
    'programTitle': programTitle,
    'contentVersion': contentVersion,
    'readinessChoice': readinessChoice,
    'readinessVariantTitle': readinessVariantTitle,
    'readinessGuidance': readinessGuidance,
    'sourceRefs': sourceRefs,
    'exercises': exercises.map((exercise) => exercise.toJson()).toList(),
  };

  factory WorkoutSessionSnapshot.fromJson(Map<String, dynamic> json) =>
      WorkoutSessionSnapshot(
        programSessionId: json['programSessionId'] as String,
        title: json['title'] as String,
        programTitle: json['programTitle'] as String? ?? '',
        contentVersion: json['contentVersion'] as String? ?? '',
        readinessChoice: json['readinessChoice'] as String?,
        readinessVariantTitle: json['readinessVariantTitle'] as String?,
        readinessGuidance: json['readinessGuidance'] as String?,
        sourceRefs: List<String>.from(json['sourceRefs'] as List? ?? const []),
        exercises: (json['exercises'] as List)
            .map(
              (item) => WorkoutExerciseSnapshot.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList(),
      );
}

/// Aggregated, frame-free evidence captured by Camera Coach for one set.
/// Raw images and landmarks never enter the persisted workout model.
class CameraSetEvidence {
  const CameraSetEvidence({
    required this.ruleVersionId,
    required this.evaluatedFrameCount,
    required this.reliableFrameCount,
    required this.formCueCount,
    required this.averageConfidence,
    required this.minimumConfidence,
  }) : assert(evaluatedFrameCount >= 0),
       assert(reliableFrameCount >= 0),
       assert(formCueCount >= 0),
       assert(reliableFrameCount <= evaluatedFrameCount),
       assert(averageConfidence >= 0 && averageConfidence <= 1),
       assert(minimumConfidence >= 0 && minimumConfidence <= 1);

  final String ruleVersionId;
  final int evaluatedFrameCount;
  final int reliableFrameCount;
  final int formCueCount;
  final double averageConfidence;
  final double minimumConfidence;

  double get reliableFrameRatio =>
      evaluatedFrameCount == 0 ? 0 : reliableFrameCount / evaluatedFrameCount;

  Map<String, dynamic> toJson() => {
    'ruleVersionId': ruleVersionId,
    'evaluatedFrameCount': evaluatedFrameCount,
    'reliableFrameCount': reliableFrameCount,
    'formCueCount': formCueCount,
    'averageConfidence': averageConfidence,
    'minimumConfidence': minimumConfidence,
  };

  factory CameraSetEvidence.fromJson(Map<String, dynamic> json) =>
      CameraSetEvidence(
        ruleVersionId: json['ruleVersionId'] as String? ?? 'unknown',
        evaluatedFrameCount: (json['evaluatedFrameCount'] as num? ?? 0).toInt(),
        reliableFrameCount: (json['reliableFrameCount'] as num? ?? 0).toInt(),
        formCueCount: (json['formCueCount'] as num? ?? 0).toInt(),
        averageConfidence: (json['averageConfidence'] as num? ?? 0).toDouble(),
        minimumConfidence: (json['minimumConfidence'] as num? ?? 0).toDouble(),
      );
}

class ExerciseProgressEvidence {
  const ExerciseProgressEvidence({
    required this.prescriptionId,
    required this.progressionKey,
    required this.prescribedExerciseId,
    required this.performedExerciseId,
    required this.exerciseIndex,
    required this.scheduledSets,
    required this.completedSets,
    required this.outcome,
    required this.recordedAt,
    this.actualLoadKg,
  }) : assert(exerciseIndex >= 0),
       assert(scheduledSets > 0),
       assert(completedSets >= 0),
       assert(completedSets <= scheduledSets),
       assert(actualLoadKg == null || actualLoadKg >= 0);

  final String prescriptionId;
  final String progressionKey;
  final String prescribedExerciseId;
  final String performedExerciseId;
  final int exerciseIndex;
  final int scheduledSets;
  final int completedSets;
  final ExerciseProgressOutcome outcome;
  final double? actualLoadKg;
  final DateTime recordedAt;

  bool get usedAlternative => performedExerciseId != prescribedExerciseId;

  Map<String, dynamic> toJson() => {
    'prescriptionId': prescriptionId,
    'progressionKey': progressionKey,
    'prescribedExerciseId': prescribedExerciseId,
    'performedExerciseId': performedExerciseId,
    'exerciseIndex': exerciseIndex,
    'scheduledSets': scheduledSets,
    'completedSets': completedSets,
    'outcome': outcome.name,
    'actualLoadKg': actualLoadKg,
    'recordedAt': recordedAt.toIso8601String(),
  };

  factory ExerciseProgressEvidence.fromJson(Map<String, dynamic> json) {
    final prescribedExerciseId =
        json['prescribedExerciseId'] as String? ??
        json['performedExerciseId'] as String? ??
        'unknown';
    return ExerciseProgressEvidence(
      prescriptionId: json['prescriptionId'] as String? ?? prescribedExerciseId,
      progressionKey: json['progressionKey'] as String? ?? prescribedExerciseId,
      prescribedExerciseId: prescribedExerciseId,
      performedExerciseId:
          json['performedExerciseId'] as String? ?? prescribedExerciseId,
      exerciseIndex: (json['exerciseIndex'] as num? ?? 0).toInt(),
      scheduledSets: (json['scheduledSets'] as num? ?? 1).toInt(),
      completedSets: (json['completedSets'] as num? ?? 0).toInt(),
      outcome: ExerciseProgressOutcome.values.byName(
        json['outcome'] as String? ?? ExerciseProgressOutcome.appropriate.name,
      ),
      actualLoadKg: (json['actualLoadKg'] as num?)?.toDouble(),
      recordedAt: DateTime.parse(json['recordedAt'] as String),
    );
  }
}

/// A user or AI confirmation concerning the current prescribed set.
///
/// [detectedRepCount] is optional evidence from the on-device coach. It is
/// never filled from the prescribed target and remains null in guided mode.
class SetEvent {
  const SetEvent({
    required this.id,
    required this.exerciseId,
    String? prescriptionId,
    String? progressionKey,
    required this.exerciseIndex,
    required this.setIndex,
    required this.targetContext,
    required this.confirmationMode,
    required this.status,
    required this.completedAt,
    this.skipReason,
    this.detectedRepCount,
    this.confidence,
    this.timedDurationSeconds,
    this.cameraEvidence,
  }) : prescriptionId = prescriptionId ?? exerciseId,
       progressionKey = progressionKey ?? exerciseId;

  final String id;
  final String exerciseId;
  final String prescriptionId;
  final String progressionKey;
  final int exerciseIndex;

  /// Zero-based set position in the session snapshot.
  final int setIndex;
  final WorkoutTargetContext targetContext;
  final WorkoutConfirmationMode confirmationMode;
  final SetEventStatus status;
  final String? skipReason;
  final int? detectedRepCount;
  final double? confidence;
  final int? timedDurationSeconds;
  final CameraSetEvidence? cameraEvidence;
  final DateTime completedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'exerciseId': exerciseId,
    'prescriptionId': prescriptionId,
    'progressionKey': progressionKey,
    'exerciseIndex': exerciseIndex,
    'setIndex': setIndex,
    'targetContext': targetContext.toJson(),
    'confirmationMode': confirmationMode.name,
    'status': status.name,
    'skipReason': skipReason,
    'detectedRepCount': detectedRepCount,
    'confidence': confidence,
    'timedDurationSeconds': timedDurationSeconds,
    'cameraEvidence': cameraEvidence?.toJson(),
    'completedAt': completedAt.toIso8601String(),
  };

  factory SetEvent.fromJson(Map<String, dynamic> json) => SetEvent(
    id: json['id'] as String,
    exerciseId: json['exerciseId'] as String,
    prescriptionId: json['prescriptionId'] as String?,
    progressionKey: json['progressionKey'] as String?,
    exerciseIndex: (json['exerciseIndex'] as num).toInt(),
    setIndex: (json['setIndex'] as num).toInt(),
    targetContext: WorkoutTargetContext.fromJson(
      Map<String, dynamic>.from(json['targetContext'] as Map),
    ),
    confirmationMode: WorkoutConfirmationMode.values.byName(
      json['confirmationMode'] as String,
    ),
    status: SetEventStatus.values.byName(json['status'] as String),
    skipReason: json['skipReason'] as String?,
    detectedRepCount: (json['detectedRepCount'] as num?)?.toInt(),
    confidence: (json['confidence'] as num?)?.toDouble(),
    timedDurationSeconds: (json['timedDurationSeconds'] as num?)?.toInt(),
    cameraEvidence: json['cameraEvidence'] == null
        ? null
        : CameraSetEvidence.fromJson(
            Map<String, dynamic>.from(json['cameraEvidence'] as Map),
          ),
    completedAt: DateTime.parse(json['completedAt'] as String),
  );
}

class WorkoutCompletion {
  WorkoutCompletion({
    required this.id,
    required this.idempotencyKey,
    required this.userId,
    required this.occurrenceId,
    required this.programVersionId,
    required this.snapshot,
    required this.actualStartedAt,
    required this.actualDurationSeconds,
    required List<SetEvent> setEvents,
    List<ExerciseProgressEvidence> exerciseProgressEvidence = const [],
    required this.status,
    required this.completedAt,
  }) : setEvents = List.unmodifiable(setEvents),
       exerciseProgressEvidence = List.unmodifiable(exerciseProgressEvidence);

  final String id;
  final String idempotencyKey;
  final String userId;
  final String occurrenceId;
  final String programVersionId;
  final WorkoutSessionSnapshot snapshot;
  final DateTime actualStartedAt;
  final int actualDurationSeconds;
  final List<SetEvent> setEvents;
  final List<ExerciseProgressEvidence> exerciseProgressEvidence;
  final WorkoutCompletionStatus status;
  final DateTime completedAt;

  int get completedSetCount => setEvents
      .where((event) => event.status == SetEventStatus.completed)
      .length;
  int get redoneSetCount =>
      setEvents.where((event) => event.status == SetEventStatus.redone).length;
  int get skippedSetCount =>
      setEvents.where((event) => event.status == SetEventStatus.skipped).length;
  bool get hasParticipation => completedSetCount > 0;
  bool get isFullyCompleted => status == WorkoutCompletionStatus.completed;

  Map<String, dynamic> toJson() => {
    'id': id,
    'idempotencyKey': idempotencyKey,
    'userId': userId,
    'occurrenceId': occurrenceId,
    'programVersionId': programVersionId,
    'snapshot': snapshot.toJson(),
    'actualStartedAt': actualStartedAt.toIso8601String(),
    'actualDurationSeconds': actualDurationSeconds,
    'setEvents': setEvents.map((event) => event.toJson()).toList(),
    'exerciseProgressEvidence': exerciseProgressEvidence
        .map((item) => item.toJson())
        .toList(),
    'status': status.name,
    'completedAt': completedAt.toIso8601String(),
  };

  factory WorkoutCompletion.fromJson(Map<String, dynamic> json) =>
      WorkoutCompletion(
        id: json['id'] as String,
        idempotencyKey: json['idempotencyKey'] as String,
        userId: json['userId'] as String,
        occurrenceId: json['occurrenceId'] as String,
        programVersionId: json['programVersionId'] as String,
        snapshot: WorkoutSessionSnapshot.fromJson(
          Map<String, dynamic>.from(json['snapshot'] as Map),
        ),
        actualStartedAt: DateTime.parse(json['actualStartedAt'] as String),
        actualDurationSeconds: (json['actualDurationSeconds'] as num).toInt(),
        setEvents: (json['setEvents'] as List? ?? const [])
            .map(
              (item) =>
                  SetEvent.fromJson(Map<String, dynamic>.from(item as Map)),
            )
            .toList(),
        exerciseProgressEvidence:
            (json['exerciseProgressEvidence'] as List? ?? const [])
                .map(
                  (item) => ExerciseProgressEvidence.fromJson(
                    Map<String, dynamic>.from(item as Map),
                  ),
                )
                .toList(),
        status: WorkoutCompletionStatus.values.byName(json['status'] as String),
        completedAt: DateTime.parse(json['completedAt'] as String),
      );
}

/// Persisted checkpoint for one UID. A transition sequence makes phase IDs
/// deterministic across process death and prevents stale async callbacks from
/// mutating a newer phase.
class ActiveWorkoutDraft {
  ActiveWorkoutDraft({
    required this.sessionId,
    required this.userId,
    required this.occurrenceId,
    required this.programVersionId,
    required this.snapshot,
    required this.phase,
    required this.phaseId,
    required this.transitionSequence,
    required this.exerciseIndex,
    required this.setIndex,
    required this.accumulatedActiveMilliseconds,
    required this.confirmationMode,
    required List<SetEvent> setEvents,
    List<ExerciseProgressEvidence> exerciseProgressEvidence = const [],
    required this.savedAt,
    required this.completionIdempotencyKey,
    this.startedAt,
    this.runningSince,
    this.restEndsAt,
    this.preparationEndsAt,
    this.pausedFrom,
    this.pausedRestRemainingMilliseconds,
    this.pausedPreparationRemainingMilliseconds,
    this.finishRequestedAt,
    this.timedSetStartedAt,
    this.timedSetElapsedMilliseconds = 0,
    this.pausedTimedSetWasRunning = false,
  }) : setEvents = List.unmodifiable(setEvents),
       exerciseProgressEvidence = List.unmodifiable(exerciseProgressEvidence) {
    if (sessionId.trim().isEmpty || userId.trim().isEmpty) {
      throw ArgumentError('sessionId and userId must not be empty');
    }
    if (occurrenceId.trim().isEmpty || programVersionId.trim().isEmpty) {
      throw ArgumentError(
        'occurrenceId and programVersionId must not be empty',
      );
    }
    if (transitionSequence < 0 ||
        exerciseIndex < 0 ||
        setIndex < 0 ||
        accumulatedActiveMilliseconds < 0 ||
        timedSetElapsedMilliseconds < 0 ||
        (pausedPreparationRemainingMilliseconds ?? 0) < 0) {
      throw ArgumentError('Workout checkpoint counters must not be negative');
    }
    if (exerciseIndex >= snapshot.exercises.length) {
      throw ArgumentError.value(
        exerciseIndex,
        'exerciseIndex',
        'Outside the session snapshot',
      );
    }
    if (setIndex >= snapshot.exercises[exerciseIndex].setCount) {
      throw ArgumentError.value(
        setIndex,
        'setIndex',
        'Outside the exercise snapshot',
      );
    }
  }

  static const schemaVersion = 4;
  final String sessionId;
  final String userId;
  final String occurrenceId;
  final String programVersionId;
  final WorkoutSessionSnapshot snapshot;
  final WorkoutPhase phase;
  final String phaseId;
  final int transitionSequence;
  final int exerciseIndex;
  final int setIndex;
  final DateTime? startedAt;
  final DateTime? runningSince;
  final int accumulatedActiveMilliseconds;
  final DateTime? restEndsAt;
  final DateTime? preparationEndsAt;
  final WorkoutConfirmationMode confirmationMode;
  final List<SetEvent> setEvents;
  final List<ExerciseProgressEvidence> exerciseProgressEvidence;
  final WorkoutPhase? pausedFrom;
  final int? pausedRestRemainingMilliseconds;
  final int? pausedPreparationRemainingMilliseconds;
  final DateTime? finishRequestedAt;
  final DateTime? timedSetStartedAt;
  final int timedSetElapsedMilliseconds;
  final bool pausedTimedSetWasRunning;
  final DateTime savedAt;
  final String completionIdempotencyKey;

  ActiveWorkoutDraft copyWith({
    WorkoutPhase? phase,
    String? phaseId,
    int? transitionSequence,
    int? exerciseIndex,
    int? setIndex,
    Object? startedAt = activeWorkoutUnset,
    Object? runningSince = activeWorkoutUnset,
    int? accumulatedActiveMilliseconds,
    Object? restEndsAt = activeWorkoutUnset,
    Object? preparationEndsAt = activeWorkoutUnset,
    WorkoutConfirmationMode? confirmationMode,
    List<SetEvent>? setEvents,
    List<ExerciseProgressEvidence>? exerciseProgressEvidence,
    Object? pausedFrom = activeWorkoutUnset,
    Object? pausedRestRemainingMilliseconds = activeWorkoutUnset,
    Object? pausedPreparationRemainingMilliseconds = activeWorkoutUnset,
    Object? finishRequestedAt = activeWorkoutUnset,
    Object? timedSetStartedAt = activeWorkoutUnset,
    int? timedSetElapsedMilliseconds,
    bool? pausedTimedSetWasRunning,
    DateTime? savedAt,
    WorkoutSessionSnapshot? snapshot,
  }) => ActiveWorkoutDraft(
    sessionId: sessionId,
    userId: userId,
    occurrenceId: occurrenceId,
    programVersionId: programVersionId,
    snapshot: snapshot ?? this.snapshot,
    phase: phase ?? this.phase,
    phaseId: phaseId ?? this.phaseId,
    transitionSequence: transitionSequence ?? this.transitionSequence,
    exerciseIndex: exerciseIndex ?? this.exerciseIndex,
    setIndex: setIndex ?? this.setIndex,
    startedAt: identical(startedAt, activeWorkoutUnset)
        ? this.startedAt
        : startedAt as DateTime?,
    runningSince: identical(runningSince, activeWorkoutUnset)
        ? this.runningSince
        : runningSince as DateTime?,
    accumulatedActiveMilliseconds:
        accumulatedActiveMilliseconds ?? this.accumulatedActiveMilliseconds,
    restEndsAt: identical(restEndsAt, activeWorkoutUnset)
        ? this.restEndsAt
        : restEndsAt as DateTime?,
    preparationEndsAt: identical(preparationEndsAt, activeWorkoutUnset)
        ? this.preparationEndsAt
        : preparationEndsAt as DateTime?,
    confirmationMode: confirmationMode ?? this.confirmationMode,
    setEvents: setEvents ?? this.setEvents,
    exerciseProgressEvidence:
        exerciseProgressEvidence ?? this.exerciseProgressEvidence,
    pausedFrom: identical(pausedFrom, activeWorkoutUnset)
        ? this.pausedFrom
        : pausedFrom as WorkoutPhase?,
    pausedRestRemainingMilliseconds:
        identical(pausedRestRemainingMilliseconds, activeWorkoutUnset)
        ? this.pausedRestRemainingMilliseconds
        : pausedRestRemainingMilliseconds as int?,
    pausedPreparationRemainingMilliseconds:
        identical(pausedPreparationRemainingMilliseconds, activeWorkoutUnset)
        ? this.pausedPreparationRemainingMilliseconds
        : pausedPreparationRemainingMilliseconds as int?,
    finishRequestedAt: identical(finishRequestedAt, activeWorkoutUnset)
        ? this.finishRequestedAt
        : finishRequestedAt as DateTime?,
    timedSetStartedAt: identical(timedSetStartedAt, activeWorkoutUnset)
        ? this.timedSetStartedAt
        : timedSetStartedAt as DateTime?,
    timedSetElapsedMilliseconds:
        timedSetElapsedMilliseconds ?? this.timedSetElapsedMilliseconds,
    pausedTimedSetWasRunning:
        pausedTimedSetWasRunning ?? this.pausedTimedSetWasRunning,
    savedAt: savedAt ?? this.savedAt,
    completionIdempotencyKey: completionIdempotencyKey,
  );

  Duration activeDurationAt(DateTime now) {
    var milliseconds = accumulatedActiveMilliseconds;
    if (runningSince != null &&
        (phase == WorkoutPhase.countingDown ||
            phase == WorkoutPhase.working ||
            phase == WorkoutPhase.resting)) {
      final runningMilliseconds = now.difference(runningSince!).inMilliseconds;
      if (runningMilliseconds > 0) milliseconds += runningMilliseconds;
    }
    return Duration(milliseconds: milliseconds);
  }

  Duration restRemainingAt(DateTime now) {
    if (phase == WorkoutPhase.paused && pausedFrom == WorkoutPhase.resting) {
      return Duration(milliseconds: pausedRestRemainingMilliseconds ?? 0);
    }
    if (phase != WorkoutPhase.resting || restEndsAt == null) {
      return Duration.zero;
    }
    final remaining = restEndsAt!.difference(now);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  Duration preparationRemainingAt(DateTime now) {
    if (phase == WorkoutPhase.paused &&
        pausedFrom == WorkoutPhase.countingDown) {
      return Duration(
        milliseconds: pausedPreparationRemainingMilliseconds ?? 0,
      );
    }
    if (phase != WorkoutPhase.countingDown || preparationEndsAt == null) {
      return Duration.zero;
    }
    final remaining = preparationEndsAt!.difference(now);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  Duration timedSetElapsedAt(DateTime now) {
    var milliseconds = timedSetElapsedMilliseconds;
    final started = timedSetStartedAt;
    if (started != null) {
      final running = now.difference(started).inMilliseconds;
      if (running > 0) milliseconds += running;
    }
    return Duration(milliseconds: milliseconds);
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'sessionId': sessionId,
    'userId': userId,
    'occurrenceId': occurrenceId,
    'programVersionId': programVersionId,
    'snapshot': snapshot.toJson(),
    'phase': phase.name,
    'phaseId': phaseId,
    'transitionSequence': transitionSequence,
    'exerciseIndex': exerciseIndex,
    'setIndex': setIndex,
    'startedAt': startedAt?.toIso8601String(),
    'runningSince': runningSince?.toIso8601String(),
    'accumulatedActiveMilliseconds': accumulatedActiveMilliseconds,
    'restEndsAt': restEndsAt?.toIso8601String(),
    'preparationEndsAt': preparationEndsAt?.toIso8601String(),
    'confirmationMode': confirmationMode.name,
    'setEvents': setEvents.map((event) => event.toJson()).toList(),
    'exerciseProgressEvidence': exerciseProgressEvidence
        .map((item) => item.toJson())
        .toList(),
    'pausedFrom': pausedFrom?.name,
    'pausedRestRemainingMilliseconds': pausedRestRemainingMilliseconds,
    'pausedPreparationRemainingMilliseconds':
        pausedPreparationRemainingMilliseconds,
    'finishRequestedAt': finishRequestedAt?.toIso8601String(),
    'timedSetStartedAt': timedSetStartedAt?.toIso8601String(),
    'timedSetElapsedMilliseconds': timedSetElapsedMilliseconds,
    'pausedTimedSetWasRunning': pausedTimedSetWasRunning,
    'savedAt': savedAt.toIso8601String(),
    'completionIdempotencyKey': completionIdempotencyKey,
  };

  String toJsonString() => jsonEncode(toJson());

  factory ActiveWorkoutDraft.fromJson(Map<String, dynamic> json) {
    final version = (json['schemaVersion'] as num? ?? 1).toInt();
    if (version < 1 || version > schemaVersion) {
      throw FormatException('Unsupported active workout schema: $version');
    }
    return ActiveWorkoutDraft(
      sessionId: json['sessionId'] as String,
      userId: json['userId'] as String,
      occurrenceId: json['occurrenceId'] as String,
      programVersionId: json['programVersionId'] as String,
      snapshot: WorkoutSessionSnapshot.fromJson(
        Map<String, dynamic>.from(json['snapshot'] as Map),
      ),
      phase: WorkoutPhase.values.byName(json['phase'] as String),
      phaseId: json['phaseId'] as String,
      transitionSequence: (json['transitionSequence'] as num).toInt(),
      exerciseIndex: (json['exerciseIndex'] as num).toInt(),
      setIndex: (json['setIndex'] as num).toInt(),
      startedAt: _dateOrNull(json['startedAt']),
      runningSince: _dateOrNull(json['runningSince']),
      accumulatedActiveMilliseconds:
          (json['accumulatedActiveMilliseconds'] as num? ?? 0).toInt(),
      restEndsAt: _dateOrNull(json['restEndsAt']),
      preparationEndsAt: _dateOrNull(json['preparationEndsAt']),
      confirmationMode: WorkoutConfirmationMode.values.byName(
        json['confirmationMode'] as String,
      ),
      setEvents: (json['setEvents'] as List? ?? const [])
          .map(
            (item) => SetEvent.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
      exerciseProgressEvidence:
          (json['exerciseProgressEvidence'] as List? ?? const [])
              .map(
                (item) => ExerciseProgressEvidence.fromJson(
                  Map<String, dynamic>.from(item as Map),
                ),
              )
              .toList(),
      pausedFrom: json['pausedFrom'] == null
          ? null
          : WorkoutPhase.values.byName(json['pausedFrom'] as String),
      pausedRestRemainingMilliseconds:
          (json['pausedRestRemainingMilliseconds'] as num?)?.toInt(),
      pausedPreparationRemainingMilliseconds:
          (json['pausedPreparationRemainingMilliseconds'] as num?)?.toInt(),
      finishRequestedAt: _dateOrNull(json['finishRequestedAt']),
      timedSetStartedAt: _dateOrNull(json['timedSetStartedAt']),
      timedSetElapsedMilliseconds:
          (json['timedSetElapsedMilliseconds'] as num? ?? 0).toInt(),
      pausedTimedSetWasRunning:
          json['pausedTimedSetWasRunning'] as bool? ?? false,
      savedAt: DateTime.parse(json['savedAt'] as String),
      completionIdempotencyKey: json['completionIdempotencyKey'] as String,
    );
  }

  factory ActiveWorkoutDraft.fromJsonString(String value) {
    final decoded = jsonDecode(value);
    if (decoded is! Map) {
      throw const FormatException(
        'Active workout checkpoint must be an object',
      );
    }
    return ActiveWorkoutDraft.fromJson(Map<String, dynamic>.from(decoded));
  }

  static DateTime? _dateOrNull(Object? value) =>
      value == null ? null : DateTime.parse(value as String);
}
