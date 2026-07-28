import 'dart:convert';

/// Sentinel shared with controllers that need to forward an omitted nullable
/// argument through [ActiveWorkoutDraft.copyWith].
const Object activeWorkoutUnset = _ActiveWorkoutUnset();

class _ActiveWorkoutUnset {
  const _ActiveWorkoutUnset();
}

/// The lifecycle of one guided workout session.
enum WorkoutPhase {
  preparing,
  working,
  resting,
  paused,
  finishing,
  completed,
  discarded,
}

enum WorkoutConfirmationMode { aiCamera, guided }

enum SetEventStatus { completed, redone, skipped }

enum WorkoutCompletionStatus { completed, partiallyCompleted }

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

/// Immutable exercise data captured when a session starts. Catalog edits do
/// not change a workout that is already running or its history.
class WorkoutExerciseSnapshot {
  WorkoutExerciseSnapshot({
    required this.exerciseId,
    required this.name,
    required this.setCount,
    required this.target,
    required this.restSeconds,
    this.muscleGroup = '',
    this.equipment = '',
    List<String> cues = const [],
    this.mediaUrl,
    this.mediaAltText,
    this.poseRuleVersionId,
  }) : cues = List.unmodifiable(cues) {
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
  }

  final String exerciseId;
  final String name;
  final String muscleGroup;
  final String equipment;
  final int setCount;
  final WorkoutTargetContext target;
  final int restSeconds;
  final List<String> cues;
  final String? mediaUrl;
  final String? mediaAltText;
  final String? poseRuleVersionId;

  Map<String, dynamic> toJson() => {
    'exerciseId': exerciseId,
    'name': name,
    'muscleGroup': muscleGroup,
    'equipment': equipment,
    'setCount': setCount,
    'target': target.toJson(),
    'restSeconds': restSeconds,
    'cues': cues,
    'mediaUrl': mediaUrl,
    'mediaAltText': mediaAltText,
    'poseRuleVersionId': poseRuleVersionId,
  };

  factory WorkoutExerciseSnapshot.fromJson(Map<String, dynamic> json) =>
      WorkoutExerciseSnapshot(
        exerciseId: json['exerciseId'] as String,
        name: json['name'] as String,
        muscleGroup: json['muscleGroup'] as String? ?? '',
        equipment: json['equipment'] as String? ?? '',
        setCount: (json['setCount'] as num).toInt(),
        target: WorkoutTargetContext.fromJson(
          Map<String, dynamic>.from(json['target'] as Map),
        ),
        restSeconds: (json['restSeconds'] as num? ?? 0).toInt(),
        cues: List<String>.from(json['cues'] as List? ?? const []),
        mediaUrl: json['mediaUrl'] as String?,
        mediaAltText: json['mediaAltText'] as String?,
        poseRuleVersionId: json['poseRuleVersionId'] as String?,
      );
}

class WorkoutSessionSnapshot {
  WorkoutSessionSnapshot({
    required this.programSessionId,
    required this.title,
    required List<WorkoutExerciseSnapshot> exercises,
    this.programTitle = '',
    this.contentVersion = '',
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
  final List<String> sourceRefs;
  final List<WorkoutExerciseSnapshot> exercises;

  int get totalSetCount =>
      exercises.fold(0, (total, exercise) => total + exercise.setCount);

  Map<String, dynamic> toJson() => {
    'programSessionId': programSessionId,
    'title': title,
    'programTitle': programTitle,
    'contentVersion': contentVersion,
    'sourceRefs': sourceRefs,
    'exercises': exercises.map((exercise) => exercise.toJson()).toList(),
  };

  factory WorkoutSessionSnapshot.fromJson(Map<String, dynamic> json) =>
      WorkoutSessionSnapshot(
        programSessionId: json['programSessionId'] as String,
        title: json['title'] as String,
        programTitle: json['programTitle'] as String? ?? '',
        contentVersion: json['contentVersion'] as String? ?? '',
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

/// A user or AI confirmation concerning the current prescribed set.
///
/// [detectedRepCount] is optional evidence from the on-device coach. It is
/// never filled from the prescribed target and remains null in guided mode.
class SetEvent {
  const SetEvent({
    required this.id,
    required this.exerciseId,
    required this.exerciseIndex,
    required this.setIndex,
    required this.targetContext,
    required this.confirmationMode,
    required this.status,
    required this.completedAt,
    this.skipReason,
    this.detectedRepCount,
    this.confidence,
  });

  final String id;
  final String exerciseId;
  final int exerciseIndex;

  /// Zero-based set position in the session snapshot.
  final int setIndex;
  final WorkoutTargetContext targetContext;
  final WorkoutConfirmationMode confirmationMode;
  final SetEventStatus status;
  final String? skipReason;
  final int? detectedRepCount;
  final double? confidence;
  final DateTime completedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'exerciseId': exerciseId,
    'exerciseIndex': exerciseIndex,
    'setIndex': setIndex,
    'targetContext': targetContext.toJson(),
    'confirmationMode': confirmationMode.name,
    'status': status.name,
    'skipReason': skipReason,
    'detectedRepCount': detectedRepCount,
    'confidence': confidence,
    'completedAt': completedAt.toIso8601String(),
  };

  factory SetEvent.fromJson(Map<String, dynamic> json) => SetEvent(
    id: json['id'] as String,
    exerciseId: json['exerciseId'] as String,
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
    required this.status,
    required this.completedAt,
  }) : setEvents = List.unmodifiable(setEvents);

  final String id;
  final String idempotencyKey;
  final String userId;
  final String occurrenceId;
  final String programVersionId;
  final WorkoutSessionSnapshot snapshot;
  final DateTime actualStartedAt;
  final int actualDurationSeconds;
  final List<SetEvent> setEvents;
  final WorkoutCompletionStatus status;
  final DateTime completedAt;

  int get completedSetCount => setEvents
      .where((event) => event.status == SetEventStatus.completed)
      .length;
  int get redoneSetCount =>
      setEvents.where((event) => event.status == SetEventStatus.redone).length;
  int get skippedSetCount =>
      setEvents.where((event) => event.status == SetEventStatus.skipped).length;

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
    required this.savedAt,
    required this.completionIdempotencyKey,
    this.startedAt,
    this.runningSince,
    this.restEndsAt,
    this.pausedFrom,
    this.pausedRestRemainingMilliseconds,
    this.finishRequestedAt,
  }) : setEvents = List.unmodifiable(setEvents) {
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
        accumulatedActiveMilliseconds < 0) {
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

  static const schemaVersion = 1;
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
  final WorkoutConfirmationMode confirmationMode;
  final List<SetEvent> setEvents;
  final WorkoutPhase? pausedFrom;
  final int? pausedRestRemainingMilliseconds;
  final DateTime? finishRequestedAt;
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
    WorkoutConfirmationMode? confirmationMode,
    List<SetEvent>? setEvents,
    Object? pausedFrom = activeWorkoutUnset,
    Object? pausedRestRemainingMilliseconds = activeWorkoutUnset,
    Object? finishRequestedAt = activeWorkoutUnset,
    DateTime? savedAt,
  }) => ActiveWorkoutDraft(
    sessionId: sessionId,
    userId: userId,
    occurrenceId: occurrenceId,
    programVersionId: programVersionId,
    snapshot: snapshot,
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
    confirmationMode: confirmationMode ?? this.confirmationMode,
    setEvents: setEvents ?? this.setEvents,
    pausedFrom: identical(pausedFrom, activeWorkoutUnset)
        ? this.pausedFrom
        : pausedFrom as WorkoutPhase?,
    pausedRestRemainingMilliseconds:
        identical(pausedRestRemainingMilliseconds, activeWorkoutUnset)
        ? this.pausedRestRemainingMilliseconds
        : pausedRestRemainingMilliseconds as int?,
    finishRequestedAt: identical(finishRequestedAt, activeWorkoutUnset)
        ? this.finishRequestedAt
        : finishRequestedAt as DateTime?,
    savedAt: savedAt ?? this.savedAt,
    completionIdempotencyKey: completionIdempotencyKey,
  );

  Duration activeDurationAt(DateTime now) {
    var milliseconds = accumulatedActiveMilliseconds;
    if (runningSince != null &&
        (phase == WorkoutPhase.working || phase == WorkoutPhase.resting)) {
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
    'confirmationMode': confirmationMode.name,
    'setEvents': setEvents.map((event) => event.toJson()).toList(),
    'pausedFrom': pausedFrom?.name,
    'pausedRestRemainingMilliseconds': pausedRestRemainingMilliseconds,
    'finishRequestedAt': finishRequestedAt?.toIso8601String(),
    'savedAt': savedAt.toIso8601String(),
    'completionIdempotencyKey': completionIdempotencyKey,
  };

  String toJsonString() => jsonEncode(toJson());

  factory ActiveWorkoutDraft.fromJson(Map<String, dynamic> json) {
    final version = (json['schemaVersion'] as num? ?? 1).toInt();
    if (version != schemaVersion) {
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
      confirmationMode: WorkoutConfirmationMode.values.byName(
        json['confirmationMode'] as String,
      ),
      setEvents: (json['setEvents'] as List? ?? const [])
          .map(
            (item) => SetEvent.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
      pausedFrom: json['pausedFrom'] == null
          ? null
          : WorkoutPhase.values.byName(json['pausedFrom'] as String),
      pausedRestRemainingMilliseconds:
          (json['pausedRestRemainingMilliseconds'] as num?)?.toInt(),
      finishRequestedAt: _dateOrNull(json['finishRequestedAt']),
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
