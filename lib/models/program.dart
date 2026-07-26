enum ProgramAudiencePreference { unisex, male, female }

abstract final class TrainingGoalKey {
  static const generalFitness = 'general_fitness';
  static const fatLoss = 'fat_loss';
  static const muscleGain = 'muscle_gain';
  static const endurance = 'endurance';

  static const labels = <String, String>{
    generalFitness: 'Sức khỏe tổng quát',
    fatLoss: 'Giảm mỡ',
    muscleGain: 'Tăng cơ',
    endurance: 'Sức bền',
  };

  static String labelFor(String key) => labels[key] ?? key;
}

class UserTrainingPreferences {
  const UserTrainingPreferences({
    required this.populationKey,
    required this.programAudiencePreference,
    required this.goalKey,
    required this.experienceKey,
    required this.equipmentKeys,
    required this.sessionsPerWeek,
  });

  final String populationKey;
  final ProgramAudiencePreference programAudiencePreference;
  final String goalKey;
  final String experienceKey;
  final List<String> equipmentKeys;
  final int sessionsPerWeek;

  factory UserTrainingPreferences.fromJson(Map<String, dynamic> json) {
    return UserTrainingPreferences(
      populationKey: json['populationKey'] as String,
      programAudiencePreference: ProgramAudiencePreference.values.byName(
        json['programAudiencePreference'] as String,
      ),
      goalKey: json['goalKey'] as String,
      experienceKey: json['experienceKey'] as String,
      equipmentKeys: List<String>.from(
        json['equipmentKeys'] as List? ?? const [],
      ),
      sessionsPerWeek: json['sessionsPerWeek'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
    'populationKey': populationKey,
    'programAudiencePreference': programAudiencePreference.name,
    'goalKey': goalKey,
    'experienceKey': experienceKey,
    'equipmentKeys': equipmentKeys,
    'sessionsPerWeek': sessionsPerWeek,
  };
}

class SourceRef {
  const SourceRef({
    required this.title,
    required this.publisher,
    this.publicationYear,
  });

  final String title;
  final String publisher;
  final int? publicationYear;

  factory SourceRef.fromJson(Map<String, dynamic> json) {
    return SourceRef(
      title: json['title'] as String,
      publisher: json['publisher'] as String,
      publicationYear: json['publicationYear'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'publisher': publisher,
    if (publicationYear != null) 'publicationYear': publicationYear,
  };
}

class ExercisePrescription {
  const ExercisePrescription({
    required this.exerciseId,
    required this.order,
    required this.sets,
    required this.targetLabel,
  });

  final String exerciseId;
  final int order;
  final int sets;
  final String targetLabel;

  factory ExercisePrescription.fromJson(Map<String, dynamic> json) {
    return ExercisePrescription(
      exerciseId: json['exerciseId'] as String,
      order: json['order'] as int,
      sets: json['sets'] as int,
      targetLabel: json['targetLabel'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'exerciseId': exerciseId,
    'order': order,
    'sets': sets,
    'targetLabel': targetLabel,
  };
}

enum ProgramBlockType { warmUp, main, accessory, conditioning, coolDown }

class ProgramBlock {
  const ProgramBlock({
    required this.type,
    required this.order,
    required this.prescriptions,
  });

  final ProgramBlockType type;
  final int order;
  final List<ExercisePrescription> prescriptions;

  factory ProgramBlock.fromJson(Map<String, dynamic> json) {
    return ProgramBlock(
      type: ProgramBlockType.values.byName(json['type'] as String),
      order: json['order'] as int,
      prescriptions: (json['prescriptions'] as List? ?? const [])
          .map(
            (item) =>
                ExercisePrescription.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'order': order,
    'prescriptions': prescriptions.map((item) => item.toJson()).toList(),
  };
}

class ProgramSession {
  const ProgramSession({
    required this.id,
    required this.order,
    required this.title,
    required this.estimatedDurationMinutes,
    required this.totalSets,
    required this.blocks,
  });

  final String id;
  final int order;
  final String title;
  final int estimatedDurationMinutes;
  final int totalSets;
  final List<ProgramBlock> blocks;

  factory ProgramSession.fromJson(Map<String, dynamic> json) {
    return ProgramSession(
      id: json['id'] as String,
      order: json['order'] as int,
      title: json['title'] as String,
      estimatedDurationMinutes: json['estimatedDurationMinutes'] as int,
      totalSets: json['totalSets'] as int,
      blocks: (json['blocks'] as List? ?? const [])
          .map((item) => ProgramBlock.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'order': order,
    'title': title,
    'estimatedDurationMinutes': estimatedDurationMinutes,
    'totalSets': totalSets,
    'blocks': blocks.map((item) => item.toJson()).toList(),
  };
}

class ProgramWeek {
  const ProgramWeek({required this.weekNumber, required this.sessions});

  final int weekNumber;
  final List<ProgramSession> sessions;

  factory ProgramWeek.fromJson(Map<String, dynamic> json) {
    return ProgramWeek(
      weekNumber: json['weekNumber'] as int,
      sessions: (json['sessions'] as List? ?? const [])
          .map((item) => ProgramSession.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'weekNumber': weekNumber,
    'sessions': sessions.map((item) => item.toJson()).toList(),
  };
}

class ProgramCadence {
  const ProgramCadence({required this.sessionsPerWeek});

  final int sessionsPerWeek;

  factory ProgramCadence.fromJson(Map<String, dynamic> json) {
    return ProgramCadence(sessionsPerWeek: json['sessionsPerWeek'] as int);
  }

  Map<String, dynamic> toJson() => {'sessionsPerWeek': sessionsPerWeek};
}

enum ReadinessKey { ready, reduceToday, recovery }

class ReadinessVariant {
  const ReadinessVariant({
    required this.sessionId,
    required this.readiness,
    required this.blocks,
  });

  final String sessionId;
  final ReadinessKey readiness;
  final List<ProgramBlock> blocks;

  factory ReadinessVariant.fromJson(Map<String, dynamic> json) {
    return ReadinessVariant(
      sessionId: json['sessionId'] as String,
      readiness: ReadinessKey.values.byName(json['readiness'] as String),
      blocks: (json['blocks'] as List? ?? const [])
          .map((item) => ProgramBlock.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'sessionId': sessionId,
    'readiness': readiness.name,
    'blocks': blocks.map((item) => item.toJson()).toList(),
  };
}

enum ProgramVersionStatus { draft, published, retired, recalled }

class ProgramVersion {
  const ProgramVersion({
    required this.id,
    required this.programId,
    required this.version,
    required this.status,
    required this.cadence,
    required this.weeks,
    required this.safetyCopy,
    required this.accessibilityLabel,
    required this.sourceRefs,
    required this.readinessVariants,
    required this.targetPopulationKeys,
    required this.targetGoalKeys,
    required this.targetExperienceKeys,
    required this.requiredEquipmentKeys,
    required this.audiencePreference,
  });

  final String id;
  final String programId;
  final int version;
  final ProgramVersionStatus status;
  final ProgramCadence cadence;
  final List<ProgramWeek> weeks;
  final String safetyCopy;
  final String accessibilityLabel;
  final List<SourceRef> sourceRefs;
  final List<ReadinessVariant> readinessVariants;

  /// Hard gate (FR-04.2): population của người dùng phải nằm trong danh sách này.
  final List<String> targetPopulationKeys;

  /// Hard gate cho match thường, được phép nới khi fallback (FR-04.3).
  final List<String> targetGoalKeys;

  /// Hard gate (FR-04.2).
  final List<String> targetExperienceKeys;

  /// Hard gate (FR-04.2): phải là tập con của
  /// `UserTrainingPreferences.equipmentKeys` của người dùng.
  final List<String> requiredEquipmentKeys;

  /// Dùng để xếp hạng, không phải safety gate (FR-04.4).
  final ProgramAudiencePreference audiencePreference;

  List<ProgramSession> get allSessions =>
      weeks.expand((week) => week.sessions).toList();

  factory ProgramVersion.fromJson(Map<String, dynamic> json) {
    return ProgramVersion(
      id: json['id'] as String,
      programId: json['programId'] as String,
      version: json['version'] as int,
      status: ProgramVersionStatus.values.byName(json['status'] as String),
      cadence: ProgramCadence.fromJson(json['cadence'] as Map<String, dynamic>),
      weeks: (json['weeks'] as List? ?? const [])
          .map((item) => ProgramWeek.fromJson(item as Map<String, dynamic>))
          .toList(),
      safetyCopy: json['safetyCopy'] as String,
      accessibilityLabel: json['accessibilityLabel'] as String,
      sourceRefs: (json['sourceRefs'] as List? ?? const [])
          .map((item) => SourceRef.fromJson(item as Map<String, dynamic>))
          .toList(),
      readinessVariants: (json['readinessVariants'] as List? ?? const [])
          .map(
            (item) => ReadinessVariant.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      targetPopulationKeys: List<String>.from(
        json['targetPopulationKeys'] as List? ?? const [],
      ),
      targetGoalKeys: List<String>.from(
        json['targetGoalKeys'] as List? ?? const [],
      ),
      targetExperienceKeys: List<String>.from(
        json['targetExperienceKeys'] as List? ?? const [],
      ),
      requiredEquipmentKeys: List<String>.from(
        json['requiredEquipmentKeys'] as List? ?? const [],
      ),
      audiencePreference: ProgramAudiencePreference.values.byName(
        json['audiencePreference'] as String,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'programId': programId,
    'version': version,
    'status': status.name,
    'cadence': cadence.toJson(),
    'weeks': weeks.map((item) => item.toJson()).toList(),
    'safetyCopy': safetyCopy,
    'accessibilityLabel': accessibilityLabel,
    'sourceRefs': sourceRefs.map((item) => item.toJson()).toList(),
    'readinessVariants': readinessVariants
        .map((item) => item.toJson())
        .toList(),
    'targetPopulationKeys': targetPopulationKeys,
    'targetGoalKeys': targetGoalKeys,
    'targetExperienceKeys': targetExperienceKeys,
    'requiredEquipmentKeys': requiredEquipmentKeys,
    'audiencePreference': audiencePreference.name,
  };
}

class Program {
  const Program({
    required this.id,
    required this.title,
    required this.description,
  });

  final String id;
  final String title;
  final String description;

  factory Program.fromJson(Map<String, dynamic> json) {
    return Program(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
  };
}

class ProgramEnrollment {
  const ProgramEnrollment({
    required this.id,
    required this.programId,
    required this.programVersionId,
    required this.preferences,
    required this.startedAt,
  });

  final String id;
  final String programId;
  final String programVersionId;
  final UserTrainingPreferences preferences;
  final DateTime startedAt;

  factory ProgramEnrollment.fromJson(Map<String, dynamic> json) {
    return ProgramEnrollment(
      id: json['id'] as String,
      programId: json['programId'] as String,
      programVersionId: json['programVersionId'] as String,
      preferences: UserTrainingPreferences.fromJson(
        json['preferences'] as Map<String, dynamic>,
      ),
      startedAt: DateTime.parse(json['startedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'programId': programId,
    'programVersionId': programVersionId,
    'preferences': preferences.toJson(),
    'startedAt': startedAt.toIso8601String(),
  };
}

enum WorkoutOccurrenceStatus {
  scheduled,
  postponed,
  inProgress,
  completed,
  skipped,
  cancelled,
}

class WorkoutOccurrence {
  const WorkoutOccurrence({
    required this.id,
    required this.enrollmentId,
    required this.sessionId,
    required this.scheduledDate,
    required this.status,
  });

  final String id;
  final String enrollmentId;
  final String sessionId;
  final DateTime scheduledDate;
  final WorkoutOccurrenceStatus status;

  WorkoutOccurrence copyWith({
    DateTime? scheduledDate,
    WorkoutOccurrenceStatus? status,
  }) {
    return WorkoutOccurrence(
      id: id,
      enrollmentId: enrollmentId,
      sessionId: sessionId,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      status: status ?? this.status,
    );
  }

  factory WorkoutOccurrence.fromJson(Map<String, dynamic> json) {
    return WorkoutOccurrence(
      id: json['id'] as String,
      enrollmentId: json['enrollmentId'] as String,
      sessionId: json['sessionId'] as String,
      scheduledDate: DateTime.parse(json['scheduledDate'] as String),
      status: WorkoutOccurrenceStatus.values.byName(json['status'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'enrollmentId': enrollmentId,
    'sessionId': sessionId,
    'scheduledDate': scheduledDate.toIso8601String(),
    'status': status.name,
  };
}
