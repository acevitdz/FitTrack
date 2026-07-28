enum ProgramLifecycleStatus { draft, published, retired, recalled }

enum ProgramAudiencePreference { unisex, male, female }

enum ProgramBlockType { warmUp, main, accessory, conditioning, coolDown }

enum PrescriptionTargetType { repetitions, durationSeconds }

enum ReadinessChoice { ready, reduceToday, recovery }

enum ProgramEnrollmentStatus { active, paused, completed, cancelled }

enum WorkoutOccurrenceStatus {
  scheduled,
  postponed,
  inProgress,
  completed,
  abandoned,
  missed,
  skipped,
  cancelled,
}

enum OccurrenceRescheduleMode { single, cascade }

/// Determines how the first occurrence is placed when the user has not
/// explicitly selected weekdays.
enum ProgramStartPolicy { today, nextPreferredDay }

abstract final class TrainingGoalKey {
  static const fatLoss = 'fat_loss';
  static const generalFitness = 'general_fitness';
  static const strength = 'strength';
  static const flexibility = 'flexibility';

  static const labels = <String, String>{
    fatLoss: 'Giảm mỡ',
    generalFitness: 'Thể lực tổng quát',
    strength: 'Tăng sức mạnh',
    flexibility: 'Linh hoạt',
  };

  static const values = <String>[
    fatLoss,
    generalFitness,
    strength,
    flexibility,
  ];

  static String labelFor(String key) => labels[key] ?? 'Thể lực tổng quát';
}

/// One-tap choices used by the deterministic program matcher.
///
/// Equipment keys describe capabilities available to the user. A program's
/// equipment keys are treated as requirements and must be a subset of these
/// values.
class UserTrainingPreferences {
  const UserTrainingPreferences({
    required this.populationKey,
    required this.programAudiencePreference,
    required this.goalKey,
    required this.experienceKey,
    required this.equipmentKeys,
    this.sessionsPerWeek = 3,
    this.preferredWeekdays = const [],
    this.startPolicy = ProgramStartPolicy.today,
  }) : assert(sessionsPerWeek >= 1 && sessionsPerWeek <= 7);

  const UserTrainingPreferences.defaults()
    : populationKey = 'healthy_adult_18_64',
      programAudiencePreference = ProgramAudiencePreference.unisex,
      goalKey = TrainingGoalKey.generalFitness,
      experienceKey = 'beginner',
      equipmentKeys = const ['bodyweight'],
      sessionsPerWeek = 3,
      preferredWeekdays = const [],
      startPolicy = ProgramStartPolicy.today;

  final String populationKey;
  final ProgramAudiencePreference programAudiencePreference;
  final String goalKey;
  final String experienceKey;
  final List<String> equipmentKeys;
  final int sessionsPerWeek;
  final List<int> preferredWeekdays;
  final ProgramStartPolicy startPolicy;

  Map<String, dynamic> toJson() => {
    'populationKey': populationKey,
    'programAudiencePreference': programAudiencePreference.name,
    'goalKey': goalKey,
    'experienceKey': experienceKey,
    'equipmentKeys': equipmentKeys,
    'sessionsPerWeek': sessionsPerWeek,
    'preferredWeekdays': preferredWeekdays,
    'startPolicy': startPolicy.name,
  };

  factory UserTrainingPreferences.fromJson(Map<String, dynamic> json) =>
      UserTrainingPreferences(
        populationKey: json['populationKey'] as String,
        programAudiencePreference: ProgramAudiencePreference.values.byName(
          json['programAudiencePreference'] as String,
        ),
        goalKey: json['goalKey'] as String,
        experienceKey: json['experienceKey'] as String,
        equipmentKeys: _stringList(json['equipmentKeys']),
        sessionsPerWeek:
            (json['sessionsPerWeek'] as num? ??
                    json['weeklyWorkoutGoal'] as num? ??
                    3)
                .toInt(),
        preferredWeekdays: _intList(json['preferredWeekdays']),
        startPolicy: ProgramStartPolicy.values.byName(
          json['startPolicy'] as String? ?? ProgramStartPolicy.today.name,
        ),
      );
}

/// Traceable scientific or professional source used to author a program.
class SourceReference {
  const SourceReference({
    required this.id,
    required this.title,
    required this.publisher,
    required this.url,
    this.publicationYear,
    this.accessedAt,
    this.notes = '',
  });

  final String id;
  final String title;
  final String publisher;
  final String url;
  final int? publicationYear;
  final DateTime? accessedAt;
  final String notes;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'publisher': publisher,
    'url': url,
    'publicationYear': publicationYear,
    'accessedAt': accessedAt?.toIso8601String(),
    'notes': notes,
  };

  factory SourceReference.fromJson(Map<String, dynamic> json) =>
      SourceReference(
        id: json['id'] as String,
        title: json['title'] as String,
        publisher: json['publisher'] as String,
        url: json['url'] as String,
        publicationYear: json['publicationYear'] as int?,
        accessedAt: _dateTimeOrNull(json['accessedAt']),
        notes: json['notes'] as String? ?? '',
      );
}

/// Published weekly schedule. Weekdays use ISO values (Monday = 1).
class TrainingCadence {
  const TrainingCadence({
    required this.sessionsPerWeek,
    required this.preferredWeekdays,
    this.minimumRestDays = 0,
    this.supportedSessionsPerWeek = const [],
    this.weekdayOptions = const {},
  }) : assert(sessionsPerWeek > 0),
       assert(minimumRestDays >= 0);

  final int sessionsPerWeek;
  final List<int> preferredWeekdays;
  final int minimumRestDays;
  final List<int> supportedSessionsPerWeek;
  final Map<int, List<int>> weekdayOptions;

  List<int> get supportedFrequencies {
    final result = supportedSessionsPerWeek.isEmpty
        ? <int>[sessionsPerWeek]
        : supportedSessionsPerWeek.toSet().toList();
    result.sort();
    return result;
  }

  bool supports(int frequency) => supportedFrequencies.contains(frequency);

  int resolveFrequency(int requested) {
    final options = supportedFrequencies;
    options.sort((left, right) {
      final gap = (left - requested).abs().compareTo((right - requested).abs());
      return gap != 0 ? gap : right.compareTo(left);
    });
    return options.first;
  }

  List<int> weekdaysFor(int frequency) {
    final configured = weekdayOptions[frequency];
    if (configured != null && configured.length >= frequency) {
      return configured.take(frequency).toList(growable: false);
    }
    if (preferredWeekdays.length >= frequency) {
      return preferredWeekdays.take(frequency).toList(growable: false);
    }
    return [
      for (var index = 0; index < frequency; index++)
        1 + ((index * 7) ~/ frequency),
    ];
  }

  Map<String, dynamic> toJson() => {
    'sessionsPerWeek': sessionsPerWeek,
    'preferredWeekdays': preferredWeekdays,
    'minimumRestDays': minimumRestDays,
    'supportedSessionsPerWeek': supportedFrequencies,
    'weekdayOptions': {
      for (final entry in weekdayOptions.entries)
        entry.key.toString(): entry.value,
    },
  };

  factory TrainingCadence.fromJson(Map<String, dynamic> json) =>
      TrainingCadence(
        sessionsPerWeek: json['sessionsPerWeek'] as int,
        preferredWeekdays: _intList(json['preferredWeekdays']),
        minimumRestDays: json['minimumRestDays'] as int? ?? 0,
        supportedSessionsPerWeek: _intList(json['supportedSessionsPerWeek']),
        weekdayOptions: _weekdayOptionsFromJson(json['weekdayOptions']),
      );
}

/// Stable catalog identity. Prescriptions live in immutable versions below.
class Program {
  const Program({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String description;
  final ProgramLifecycleStatus status;

  /// Identifier of the catalog entry creator.
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'status': status.name,
    'createdBy': createdBy,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Program.fromJson(Map<String, dynamic> json) => Program(
    id: json['id'] as String,
    title: json['title'] as String,
    description: json['description'] as String,
    status: ProgramLifecycleStatus.values.byName(json['status'] as String),
    createdBy: json['createdBy'] as String,
    createdAt: _dateTime(json['createdAt']),
    updatedAt: _dateTime(json['updatedAt']),
  );
}

/// Published numeric target. It deliberately has no load/weight field.
class PrescriptionTargetRange {
  const PrescriptionTargetRange({required this.minimum, required this.maximum})
    : assert(minimum > 0),
      assert(maximum >= minimum);

  final int minimum;
  final int maximum;

  bool get isSingleValue => minimum == maximum;

  Map<String, dynamic> toJson() => {'minimum': minimum, 'maximum': maximum};

  factory PrescriptionTargetRange.fromJson(Map<String, dynamic> json) =>
      PrescriptionTargetRange(
        minimum: json['minimum'] as int,
        maximum: json['maximum'] as int,
      );
}

/// A prescribed exercise target. Users never edit these numeric values.
class ExercisePrescription {
  const ExercisePrescription({
    required this.id,
    required this.exerciseId,
    required this.order,
    required this.sets,
    required this.targetType,
    required this.targetRange,
    required this.restSeconds,
    int? transitionAfterExerciseSeconds,
    required this.cues,
    required this.alternativeExerciseIds,
    required this.prescriptionVersion,
    required this.mediaVersion,
    required this.cueVersion,
    this.poseRuleVersionId,
  }) : transitionAfterExerciseSeconds =
           transitionAfterExerciseSeconds ?? restSeconds,
       assert(order >= 0),
       assert(sets > 0),
       assert(restSeconds >= 0),
       assert(
         transitionAfterExerciseSeconds == null ||
             transitionAfterExerciseSeconds >= 0,
       );

  final String id;
  final String exerciseId;
  final int order;
  final int sets;
  final PrescriptionTargetType targetType;
  final PrescriptionTargetRange targetRange;

  /// Rest after a set when another set of the same exercise remains.
  ///
  /// Kept under the legacy field name for stored-data compatibility.
  final int restSeconds;

  int get restBetweenSetsSeconds => restSeconds;

  /// Rest after the final set before moving to the next exercise.
  final int transitionAfterExerciseSeconds;
  final List<String> cues;
  final List<String> alternativeExerciseIds;

  /// Version/checksum metadata keeps historical workout snapshots traceable.
  final String prescriptionVersion;
  final String mediaVersion;
  final String cueVersion;
  final String? poseRuleVersionId;

  String get targetLabel {
    final value = targetRange.isSingleValue
        ? '${targetRange.minimum}'
        : '${targetRange.minimum}-${targetRange.maximum}';
    return targetType == PrescriptionTargetType.repetitions
        ? '$value lần'
        : '$value giây';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'exerciseId': exerciseId,
    'order': order,
    'sets': sets,
    'targetType': _prescriptionTargetTypeToJson(targetType),
    'targetRange': targetRange.toJson(),
    'restSeconds': restSeconds,
    'restBetweenSetsSeconds': restBetweenSetsSeconds,
    'transitionAfterExerciseSeconds': transitionAfterExerciseSeconds,
    'cues': cues,
    'alternatives': alternativeExerciseIds,
    'prescriptionVersion': prescriptionVersion,
    'mediaVersion': mediaVersion,
    'cueVersion': cueVersion,
    'poseRuleVersionId': poseRuleVersionId,
  };

  factory ExercisePrescription.fromJson(
    Map<String, dynamic> json,
  ) => ExercisePrescription(
    id: json['id'] as String,
    exerciseId: json['exerciseId'] as String,
    order: json['order'] as int,
    sets: json['sets'] as int,
    targetType: _prescriptionTargetTypeFromJson(json['targetType'] as String),
    targetRange: PrescriptionTargetRange.fromJson(
      _jsonMap(json['targetRange']),
    ),
    restSeconds:
        (json['restBetweenSetsSeconds'] as num? ??
                json['restSeconds'] as num? ??
                0)
            .toInt(),
    transitionAfterExerciseSeconds:
        (json['transitionAfterExerciseSeconds'] as num?)?.toInt(),
    cues: _stringList(json['cues']),
    alternativeExerciseIds: _stringList(json['alternatives']),
    prescriptionVersion: json['prescriptionVersion'] as String? ?? 'unknown',
    mediaVersion: json['mediaVersion'] as String? ?? 'unknown',
    cueVersion: json['cueVersion'] as String? ?? 'unknown',
    poseRuleVersionId: json['poseRuleVersionId'] as String?,
  );
}

class ProgramBlock {
  const ProgramBlock({
    required this.id,
    required this.sessionId,
    required this.type,
    required this.order,
    required this.prescriptions,
  }) : assert(order >= 0);

  final String id;
  final String sessionId;
  final ProgramBlockType type;
  final int order;
  final List<ExercisePrescription> prescriptions;

  int get totalSets => prescriptions.fold(0, (sum, item) => sum + item.sets);

  Map<String, dynamic> toJson() => {
    'id': id,
    'sessionId': sessionId,
    'type': _programBlockTypeToJson(type),
    'order': order,
    'prescriptions': prescriptions.map((item) => item.toJson()).toList(),
  };

  factory ProgramBlock.fromJson(Map<String, dynamic> json) => ProgramBlock(
    id: json['id'] as String,
    sessionId: json['sessionId'] as String,
    type: _programBlockTypeFromJson(json['type'] as String),
    order: json['order'] as int,
    prescriptions: _jsonMapList(
      json['prescriptions'],
    ).map(ExercisePrescription.fromJson).toList(),
  );
}

/// A published replacement for a session's base blocks.
///
/// `ready` normally uses the session's base blocks. `reduceToday` and
/// `recovery` may supply their own complete, immutable block lists.
class ReadinessVariant {
  const ReadinessVariant({
    required this.id,
    required this.sessionId,
    required this.choice,
    required this.title,
    required this.guidance,
    required this.blocks,
    this.stopWorkout = false,
    this.safetyMessage,
  });

  final String id;
  final String sessionId;
  final ReadinessChoice choice;
  final String title;
  final String guidance;
  final List<ProgramBlock> blocks;
  final bool stopWorkout;
  final String? safetyMessage;

  int get totalSets => blocks.fold(0, (sum, block) => sum + block.totalSets);

  Map<String, dynamic> toJson() => {
    'id': id,
    'sessionId': sessionId,
    'choice': _readinessChoiceToJson(choice),
    'title': title,
    'guidance': guidance,
    'blocks': blocks.map((item) => item.toJson()).toList(),
    'stopWorkout': stopWorkout,
    'safetyMessage': safetyMessage,
  };

  factory ReadinessVariant.fromJson(Map<String, dynamic> json) =>
      ReadinessVariant(
        id: json['id'] as String,
        sessionId: json['sessionId'] as String,
        choice: _readinessChoiceFromJson(json['choice'] as String),
        title: json['title'] as String,
        guidance: json['guidance'] as String,
        blocks: _jsonMapList(
          json['blocks'],
        ).map(ProgramBlock.fromJson).toList(),
        stopWorkout: json['stopWorkout'] as bool? ?? false,
        safetyMessage: json['safetyMessage'] as String?,
      );
}

class ProgramSession {
  const ProgramSession({
    required this.id,
    required this.weekId,
    required this.title,
    required this.order,
    required this.estimatedDurationMinutes,
    required this.blocks,
    required this.readinessVariants,
    this.minimumSessionsPerWeek = 1,
  }) : assert(order >= 0),
       assert(estimatedDurationMinutes > 0),
       assert(minimumSessionsPerWeek > 0);

  final String id;
  final String weekId;
  final String title;
  final int order;
  final int estimatedDurationMinutes;
  final List<ProgramBlock> blocks;
  final List<ReadinessVariant> readinessVariants;
  final int minimumSessionsPerWeek;

  int get totalSets => blocks.fold(0, (sum, block) => sum + block.totalSets);

  ReadinessVariant? readinessVariantFor(ReadinessChoice choice) {
    for (final variant in readinessVariants) {
      if (variant.choice == choice) return variant;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'weekId': weekId,
    'title': title,
    'order': order,
    'estimatedDurationMinutes': estimatedDurationMinutes,
    'blocks': blocks.map((item) => item.toJson()).toList(),
    'readinessVariants': readinessVariants
        .map((item) => item.toJson())
        .toList(),
    'minimumSessionsPerWeek': minimumSessionsPerWeek,
  };

  factory ProgramSession.fromJson(Map<String, dynamic> json) => ProgramSession(
    id: json['id'] as String,
    weekId: json['weekId'] as String,
    title: json['title'] as String,
    order: json['order'] as int,
    estimatedDurationMinutes: json['estimatedDurationMinutes'] as int,
    blocks: _jsonMapList(json['blocks']).map(ProgramBlock.fromJson).toList(),
    readinessVariants: _jsonMapList(
      json['readinessVariants'],
    ).map(ReadinessVariant.fromJson).toList(),
    minimumSessionsPerWeek: json['minimumSessionsPerWeek'] as int? ?? 1,
  );
}

class ProgramWeek {
  const ProgramWeek({
    required this.id,
    required this.programVersionId,
    required this.weekNumber,
    required this.title,
    required this.sessions,
  }) : assert(weekNumber > 0);

  final String id;
  final String programVersionId;
  final int weekNumber;
  final String title;
  final List<ProgramSession> sessions;

  int get totalSets => sessions.fold(0, (sum, item) => sum + item.totalSets);

  Map<String, dynamic> toJson() => {
    'id': id,
    'programVersionId': programVersionId,
    'weekNumber': weekNumber,
    'title': title,
    'sessions': sessions.map((item) => item.toJson()).toList(),
  };

  factory ProgramWeek.fromJson(Map<String, dynamic> json) => ProgramWeek(
    id: json['id'] as String,
    programVersionId: json['programVersionId'] as String,
    weekNumber: json['weekNumber'] as int,
    title: json['title'] as String,
    sessions: _jsonMapList(
      json['sessions'],
    ).map(ProgramSession.fromJson).toList(),
  );
}

/// Immutable once published. A content change must create a new version.
class ProgramVersion {
  const ProgramVersion({
    required this.id,
    required this.programId,
    required this.version,
    required this.status,
    required this.populationKeys,
    required this.audienceTags,
    required this.goalKeys,
    required this.experienceKeys,
    required this.equipmentKeys,
    required this.cadence,
    required this.sourceRefs,
    required this.changelog,
    required this.safetyCopy,
    required this.accessibilityLabel,
    required this.guidedConfirmationAvailable,
    required this.weeks,
    required this.createdBy,
    required this.createdAt,
    this.matchingPriority = 0,
    this.publishedBy,
    this.publishedAt,
    this.retiredBy,
    this.retiredAt,
    this.recalledBy,
    this.recalledAt,
  });

  final String id;
  final String programId;
  final String version;
  final ProgramLifecycleStatus status;
  final List<String> populationKeys;
  final List<ProgramAudiencePreference> audienceTags;
  final List<String> goalKeys;
  final List<String> experienceKeys;

  /// Equipment required by every occurrence in this version.
  final List<String> equipmentKeys;
  final TrainingCadence cadence;
  final List<SourceReference> sourceRefs;
  final String changelog;
  final String safetyCopy;
  final String accessibilityLabel;
  final bool guidedConfirmationAvailable;
  final List<ProgramWeek> weeks;
  final int matchingPriority;

  /// Actor identifiers record who created or published each version.
  final String createdBy;
  final DateTime createdAt;
  final String? publishedBy;
  final DateTime? publishedAt;
  final String? retiredBy;
  final DateTime? retiredAt;
  final String? recalledBy;
  final DateTime? recalledAt;

  bool get isPublished => status == ProgramLifecycleStatus.published;

  List<ProgramSession> get allSessions {
    final orderedWeeks = [...weeks]
      ..sort((left, right) => left.weekNumber.compareTo(right.weekNumber));
    return [
      for (final week in orderedWeeks)
        ...([...week.sessions]
          ..sort((left, right) => left.order.compareTo(right.order))),
    ];
  }

  ProgramSession? sessionById(String sessionId) {
    for (final session in allSessions) {
      if (session.id == sessionId) return session;
    }
    return null;
  }

  int get estimatedTotalDurationMinutes => allSessions.fold(
    0,
    (sum, session) => sum + session.estimatedDurationMinutes,
  );

  int get totalSets =>
      allSessions.fold(0, (sum, session) => sum + session.totalSets);

  Map<String, dynamic> toJson() => {
    'id': id,
    'programId': programId,
    'version': version,
    'status': status.name,
    'populationKeys': populationKeys,
    'audienceTags': audienceTags.map((item) => item.name).toList(),
    'goalKeys': goalKeys,
    'experienceKeys': experienceKeys,
    'equipmentKeys': equipmentKeys,
    'cadence': cadence.toJson(),
    'sourceRefs': sourceRefs.map((item) => item.toJson()).toList(),
    'changelog': changelog,
    'safetyCopy': safetyCopy,
    'accessibilityLabel': accessibilityLabel,
    'guidedConfirmationAvailable': guidedConfirmationAvailable,
    'weeks': weeks.map((item) => item.toJson()).toList(),
    'matchingPriority': matchingPriority,
    'createdBy': createdBy,
    'createdAt': createdAt.toIso8601String(),
    'publishedBy': publishedBy,
    'publishedAt': publishedAt?.toIso8601String(),
    'retiredBy': retiredBy,
    'retiredAt': retiredAt?.toIso8601String(),
    'recalledBy': recalledBy,
    'recalledAt': recalledAt?.toIso8601String(),
  };

  factory ProgramVersion.fromJson(Map<String, dynamic> json) => ProgramVersion(
    id: json['id'] as String,
    programId: json['programId'] as String,
    version: json['version'] as String,
    status: ProgramLifecycleStatus.values.byName(json['status'] as String),
    populationKeys: _stringList(json['populationKeys']),
    audienceTags: _stringList(
      json['audienceTags'],
    ).map(ProgramAudiencePreference.values.byName).toList(),
    goalKeys: _stringList(json['goalKeys']),
    experienceKeys: _stringList(json['experienceKeys']),
    equipmentKeys: _stringList(json['equipmentKeys']),
    cadence: TrainingCadence.fromJson(_jsonMap(json['cadence'])),
    sourceRefs: _jsonMapList(
      json['sourceRefs'],
    ).map(SourceReference.fromJson).toList(),
    changelog: json['changelog'] as String,
    safetyCopy: json['safetyCopy'] as String,
    accessibilityLabel: json['accessibilityLabel'] as String,
    guidedConfirmationAvailable:
        json['guidedConfirmationAvailable'] as bool? ?? true,
    weeks: _jsonMapList(json['weeks']).map(ProgramWeek.fromJson).toList(),
    matchingPriority: json['matchingPriority'] as int? ?? 0,
    createdBy: json['createdBy'] as String,
    createdAt: _dateTime(json['createdAt']),
    publishedBy: json['publishedBy'] as String?,
    publishedAt: _dateTimeOrNull(json['publishedAt']),
    retiredBy: json['retiredBy'] as String?,
    retiredAt: _dateTimeOrNull(json['retiredAt']),
    recalledBy: json['recalledBy'] as String?,
    recalledAt: _dateTimeOrNull(json['recalledAt']),
  );
}

class ProgramEnrollment {
  const ProgramEnrollment({
    required this.id,
    required this.userId,
    required this.programVersionId,
    required this.startedAt,
    required this.status,
    this.currentWeekNumber = 1,
    this.nextSessionOrder = 0,
    this.endedAt,
    this.updatedAt,
  }) : assert(currentWeekNumber > 0),
       assert(nextSessionOrder >= 0);

  final String id;
  final String userId;

  /// Pinned version identity; catalog updates never rewrite an enrollment.
  final String programVersionId;
  final DateTime startedAt;
  final ProgramEnrollmentStatus status;
  final int currentWeekNumber;
  final int nextSessionOrder;
  final DateTime? endedAt;
  final DateTime? updatedAt;

  ProgramEnrollment copyWith({
    ProgramEnrollmentStatus? status,
    int? currentWeekNumber,
    int? nextSessionOrder,
    Object? endedAt = _programUnset,
    DateTime? updatedAt,
  }) => ProgramEnrollment(
    id: id,
    userId: userId,
    programVersionId: programVersionId,
    startedAt: startedAt,
    status: status ?? this.status,
    currentWeekNumber: currentWeekNumber ?? this.currentWeekNumber,
    nextSessionOrder: nextSessionOrder ?? this.nextSessionOrder,
    endedAt: identical(endedAt, _programUnset)
        ? this.endedAt
        : endedAt as DateTime?,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'programVersionId': programVersionId,
    'startedAt': startedAt.toIso8601String(),
    'status': status.name,
    'currentWeekNumber': currentWeekNumber,
    'nextSessionOrder': nextSessionOrder,
    'endedAt': endedAt?.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };

  factory ProgramEnrollment.fromJson(Map<String, dynamic> json) =>
      ProgramEnrollment(
        id: json['id'] as String,
        userId: json['userId'] as String,
        programVersionId: json['programVersionId'] as String,
        startedAt: _dateTime(json['startedAt']),
        status: ProgramEnrollmentStatus.values.byName(json['status'] as String),
        currentWeekNumber: json['currentWeekNumber'] as int? ?? 1,
        nextSessionOrder: json['nextSessionOrder'] as int? ?? 0,
        endedAt: _dateTimeOrNull(json['endedAt']),
        updatedAt: _dateTimeOrNull(json['updatedAt']),
      );
}

class WorkoutOccurrence {
  const WorkoutOccurrence({
    required this.id,
    required this.enrollmentId,
    required this.programVersionId,
    required this.sessionId,
    required this.weekNumber,
    required this.scheduledDate,
    required this.status,
    this.originalScheduledDate,
    this.readinessChoice,
    this.readinessAssessedAt,
    this.startedAt,
    this.completedAt,
    this.scheduledHour,
    this.scheduledMinute,
    this.reminderEnabled = true,
    this.reminderMinutesBefore,
    this.rescheduleReason,
    this.updatedAt,
  }) : assert(weekNumber > 0);

  final String id;
  final String enrollmentId;
  final String programVersionId;
  final String sessionId;
  final int weekNumber;
  final DateTime scheduledDate;
  final WorkoutOccurrenceStatus status;
  final DateTime? originalScheduledDate;
  final ReadinessChoice? readinessChoice;
  final DateTime? readinessAssessedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final int? scheduledHour;
  final int? scheduledMinute;
  final bool reminderEnabled;
  final int? reminderMinutesBefore;
  final String? rescheduleReason;
  final DateTime? updatedAt;

  bool get isOpen =>
      status == WorkoutOccurrenceStatus.scheduled ||
      status == WorkoutOccurrenceStatus.postponed ||
      status == WorkoutOccurrenceStatus.inProgress;

  bool get isTerminal => !isOpen;

  DateTime scheduledAt({
    required int fallbackHour,
    required int fallbackMinute,
  }) => DateTime(
    scheduledDate.year,
    scheduledDate.month,
    scheduledDate.day,
    scheduledHour ?? fallbackHour,
    scheduledMinute ?? fallbackMinute,
  );

  WorkoutOccurrence copyWith({
    DateTime? scheduledDate,
    WorkoutOccurrenceStatus? status,
    Object? originalScheduledDate = _programUnset,
    Object? readinessChoice = _programUnset,
    Object? readinessAssessedAt = _programUnset,
    Object? startedAt = _programUnset,
    Object? completedAt = _programUnset,
    Object? scheduledHour = _programUnset,
    Object? scheduledMinute = _programUnset,
    bool? reminderEnabled,
    Object? reminderMinutesBefore = _programUnset,
    Object? rescheduleReason = _programUnset,
    DateTime? updatedAt,
  }) => WorkoutOccurrence(
    id: id,
    enrollmentId: enrollmentId,
    programVersionId: programVersionId,
    sessionId: sessionId,
    weekNumber: weekNumber,
    scheduledDate: scheduledDate ?? this.scheduledDate,
    status: status ?? this.status,
    originalScheduledDate: identical(originalScheduledDate, _programUnset)
        ? this.originalScheduledDate
        : originalScheduledDate as DateTime?,
    readinessChoice: identical(readinessChoice, _programUnset)
        ? this.readinessChoice
        : readinessChoice as ReadinessChoice?,
    readinessAssessedAt: identical(readinessAssessedAt, _programUnset)
        ? this.readinessAssessedAt
        : readinessAssessedAt as DateTime?,
    startedAt: identical(startedAt, _programUnset)
        ? this.startedAt
        : startedAt as DateTime?,
    completedAt: identical(completedAt, _programUnset)
        ? this.completedAt
        : completedAt as DateTime?,
    scheduledHour: identical(scheduledHour, _programUnset)
        ? this.scheduledHour
        : scheduledHour as int?,
    scheduledMinute: identical(scheduledMinute, _programUnset)
        ? this.scheduledMinute
        : scheduledMinute as int?,
    reminderEnabled: reminderEnabled ?? this.reminderEnabled,
    reminderMinutesBefore: identical(reminderMinutesBefore, _programUnset)
        ? this.reminderMinutesBefore
        : reminderMinutesBefore as int?,
    rescheduleReason: identical(rescheduleReason, _programUnset)
        ? this.rescheduleReason
        : rescheduleReason as String?,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'enrollmentId': enrollmentId,
    'programVersionId': programVersionId,
    'sessionId': sessionId,
    'weekNumber': weekNumber,
    'scheduledDate': scheduledDate.toIso8601String(),
    'status': _workoutOccurrenceStatusToJson(status),
    'originalScheduledDate': originalScheduledDate?.toIso8601String(),
    'readinessChoice': readinessChoice == null
        ? null
        : _readinessChoiceToJson(readinessChoice!),
    'readinessAssessedAt': readinessAssessedAt?.toIso8601String(),
    'startedAt': startedAt?.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
    'scheduledHour': scheduledHour,
    'scheduledMinute': scheduledMinute,
    'reminderEnabled': reminderEnabled,
    'reminderMinutesBefore': reminderMinutesBefore,
    'rescheduleReason': rescheduleReason,
    'updatedAt': updatedAt?.toIso8601String(),
  };

  factory WorkoutOccurrence.fromJson(Map<String, dynamic> json) =>
      WorkoutOccurrence(
        id: json['id'] as String,
        enrollmentId: json['enrollmentId'] as String,
        programVersionId: json['programVersionId'] as String,
        sessionId: json['sessionId'] as String,
        weekNumber: json['weekNumber'] as int,
        scheduledDate: _dateTime(json['scheduledDate']),
        status: _workoutOccurrenceStatusFromJson(json['status'] as String),
        originalScheduledDate: _dateTimeOrNull(json['originalScheduledDate']),
        readinessChoice: json['readinessChoice'] == null
            ? null
            : _readinessChoiceFromJson(json['readinessChoice'] as String),
        readinessAssessedAt: _dateTimeOrNull(json['readinessAssessedAt']),
        startedAt: _dateTimeOrNull(json['startedAt']),
        completedAt: _dateTimeOrNull(json['completedAt']),
        scheduledHour: (json['scheduledHour'] as num?)?.toInt(),
        scheduledMinute: (json['scheduledMinute'] as num?)?.toInt(),
        reminderEnabled: json['reminderEnabled'] as bool? ?? true,
        reminderMinutesBefore: (json['reminderMinutesBefore'] as num?)?.toInt(),
        rescheduleReason: json['rescheduleReason'] as String?,
        updatedAt: _dateTimeOrNull(json['updatedAt']),
      );
}

String _programBlockTypeToJson(ProgramBlockType value) => switch (value) {
  ProgramBlockType.warmUp => 'warm_up',
  ProgramBlockType.main => 'main',
  ProgramBlockType.accessory => 'accessory',
  ProgramBlockType.conditioning => 'conditioning',
  ProgramBlockType.coolDown => 'cooldown',
};

ProgramBlockType _programBlockTypeFromJson(String value) => switch (value) {
  'warm_up' => ProgramBlockType.warmUp,
  'main' => ProgramBlockType.main,
  'accessory' => ProgramBlockType.accessory,
  'conditioning' => ProgramBlockType.conditioning,
  'cooldown' => ProgramBlockType.coolDown,
  _ => throw FormatException('Unknown program block type: $value'),
};

String _prescriptionTargetTypeToJson(PrescriptionTargetType value) =>
    switch (value) {
      PrescriptionTargetType.repetitions => 'repetitions',
      PrescriptionTargetType.durationSeconds => 'duration_seconds',
    };

PrescriptionTargetType _prescriptionTargetTypeFromJson(String value) =>
    switch (value) {
      'repetitions' => PrescriptionTargetType.repetitions,
      'duration_seconds' => PrescriptionTargetType.durationSeconds,
      _ => throw FormatException('Unknown prescription target type: $value'),
    };

String _readinessChoiceToJson(ReadinessChoice value) => switch (value) {
  ReadinessChoice.ready => 'ready',
  ReadinessChoice.reduceToday => 'reduce_today',
  ReadinessChoice.recovery => 'recovery',
};

ReadinessChoice _readinessChoiceFromJson(String value) => switch (value) {
  'ready' => ReadinessChoice.ready,
  'reduce_today' => ReadinessChoice.reduceToday,
  'recovery' => ReadinessChoice.recovery,
  _ => throw FormatException('Unknown readiness choice: $value'),
};

String _workoutOccurrenceStatusToJson(WorkoutOccurrenceStatus value) =>
    switch (value) {
      WorkoutOccurrenceStatus.scheduled => 'scheduled',
      WorkoutOccurrenceStatus.postponed => 'postponed',
      WorkoutOccurrenceStatus.inProgress => 'in_progress',
      WorkoutOccurrenceStatus.completed => 'completed',
      WorkoutOccurrenceStatus.abandoned => 'abandoned',
      WorkoutOccurrenceStatus.missed => 'missed',
      WorkoutOccurrenceStatus.skipped => 'skipped',
      WorkoutOccurrenceStatus.cancelled => 'cancelled',
    };

WorkoutOccurrenceStatus _workoutOccurrenceStatusFromJson(String value) =>
    switch (value) {
      'scheduled' => WorkoutOccurrenceStatus.scheduled,
      'postponed' => WorkoutOccurrenceStatus.postponed,
      'in_progress' => WorkoutOccurrenceStatus.inProgress,
      'completed' => WorkoutOccurrenceStatus.completed,
      'abandoned' => WorkoutOccurrenceStatus.abandoned,
      'missed' => WorkoutOccurrenceStatus.missed,
      'skipped' => WorkoutOccurrenceStatus.skipped,
      'cancelled' => WorkoutOccurrenceStatus.cancelled,
      _ => throw FormatException('Unknown workout occurrence status: $value'),
    };

List<String> _stringList(Object? value) =>
    List<String>.from(value as List? ?? const []);

List<int> _intList(Object? value) => List<int>.from(value as List? ?? const []);

Map<int, List<int>> _weekdayOptionsFromJson(Object? value) {
  final result = <int, List<int>>{};
  for (final entry in Map<String, dynamic>.from(
    value as Map? ?? const {},
  ).entries) {
    final frequency = int.tryParse(entry.key);
    if (frequency != null) {
      result[frequency] = _intList(entry.value);
    }
  }
  return result;
}

Map<String, dynamic> _jsonMap(Object? value) =>
    Map<String, dynamic>.from(value! as Map);

List<Map<String, dynamic>> _jsonMapList(Object? value) =>
    (value as List? ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();

DateTime _dateTime(Object? value) => switch (value) {
  DateTime dateTime => dateTime,
  String text => DateTime.parse(text),
  _ => throw FormatException('Expected an ISO-8601 date, got $value'),
};

DateTime? _dateTimeOrNull(Object? value) =>
    value == null ? null : _dateTime(value);

const Object _programUnset = Object();
