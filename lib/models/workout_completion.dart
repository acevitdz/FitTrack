import 'workout_plan.dart';

enum CompletionStatus { completed, partiallyCompleted }

class CompletedSet {
  const CompletedSet({
    required this.setNumber,
    required this.actualReps,
    required this.actualWeightKg,
    required this.isCompleted,
  });

  final int setNumber;
  final int actualReps;
  final double actualWeightKg;
  final bool isCompleted;

  double get volume => isCompleted ? actualReps * actualWeightKg : 0;

  CompletedSet copyWith({
    int? actualReps,
    double? actualWeightKg,
    bool? isCompleted,
  }) => CompletedSet(
    setNumber: setNumber,
    actualReps: actualReps ?? this.actualReps,
    actualWeightKg: actualWeightKg ?? this.actualWeightKg,
    isCompleted: isCompleted ?? this.isCompleted,
  );

  Map<String, dynamic> toJson() => {
    'setNumber': setNumber,
    'actualReps': actualReps,
    'actualWeightKg': actualWeightKg,
    'isCompleted': isCompleted,
  };

  factory CompletedSet.fromJson(Map<String, dynamic> json) => CompletedSet(
    setNumber: json['setNumber'] as int,
    actualReps: json['actualReps'] as int? ?? json['reps'] as int? ?? 0,
    actualWeightKg:
        (json['actualWeightKg'] as num? ?? json['weight'] as num? ?? 0)
            .toDouble(),
    isCompleted:
        json['isCompleted'] as bool? ?? json['completed'] as bool? ?? false,
  );
}

class CompletedExercise {
  const CompletedExercise({
    required this.exerciseId,
    required this.exerciseName,
    required this.muscleGroup,
    required this.equipment,
    required this.targetSets,
    required this.targetMinReps,
    required this.targetMaxReps,
    required this.targetWeightKg,
    required this.sets,
    this.skipped = false,
    this.note = '',
  });

  final String exerciseId;
  final String exerciseName;
  final String muscleGroup;
  final String equipment;
  final int targetSets;
  final int targetMinReps;
  final int targetMaxReps;
  final double targetWeightKg;
  final List<CompletedSet> sets;
  final bool skipped;
  final String note;

  int get completedSetCount => sets.where((set) => set.isCompleted).length;
  double get totalVolume => sets.fold(0.0, (sum, set) => sum + set.volume);

  CompletedExercise copyWith({
    List<CompletedSet>? sets,
    bool? skipped,
    String? note,
  }) => CompletedExercise(
    exerciseId: exerciseId,
    exerciseName: exerciseName,
    muscleGroup: muscleGroup,
    equipment: equipment,
    targetSets: targetSets,
    targetMinReps: targetMinReps,
    targetMaxReps: targetMaxReps,
    targetWeightKg: targetWeightKg,
    sets: sets ?? this.sets,
    skipped: skipped ?? this.skipped,
    note: note ?? this.note,
  );

  Map<String, dynamic> toJson() => {
    'exerciseId': exerciseId,
    'exerciseName': exerciseName,
    'muscleGroup': muscleGroup,
    'equipment': equipment,
    'targetSets': targetSets,
    'targetMinReps': targetMinReps,
    'targetMaxReps': targetMaxReps,
    'targetWeightKg': targetWeightKg,
    'sets': sets.map((set) => set.toJson()).toList(),
    'skipped': skipped,
    'note': note,
  };

  factory CompletedExercise.fromJson(Map<String, dynamic> json) =>
      CompletedExercise(
        exerciseId: json['exerciseId'] as String,
        exerciseName: json['exerciseName'] as String? ?? 'Bài tập',
        muscleGroup: json['muscleGroup'] as String? ?? 'Toàn thân',
        equipment: json['equipment'] as String? ?? 'Không dụng cụ',
        targetSets: json['targetSets'] as int? ?? 1,
        targetMinReps: json['targetMinReps'] as int? ?? 1,
        targetMaxReps: json['targetMaxReps'] as int? ?? 1,
        targetWeightKg: (json['targetWeightKg'] as num? ?? 0).toDouble(),
        sets: (json['sets'] as List? ?? const [])
            .map((item) => CompletedSet.fromJson(item as Map<String, dynamic>))
            .toList(),
        skipped: json['skipped'] as bool? ?? false,
        note: json['note'] as String? ?? '',
      );
}

class WorkoutPlanSnapshot {
  const WorkoutPlanSnapshot({
    required this.planId,
    required this.name,
    required this.description,
    required this.exercises,
    this.adjusted = false,
    this.adjustmentReasons = const [],
  });

  final String planId;
  final String name;
  final String description;
  final List<PlanExercise> exercises;
  final bool adjusted;
  final List<String> adjustmentReasons;

  factory WorkoutPlanSnapshot.fromPlan(WorkoutPlan plan) => WorkoutPlanSnapshot(
    planId: plan.id,
    name: plan.name,
    description: plan.description,
    exercises: plan.exercises
        .map((exercise) => exercise.copyWith())
        .toList(growable: false),
  );

  int get estimatedDurationMinutes {
    final seconds = exercises.fold<int>(
      0,
      (sum, item) => sum + item.sets * 45 + item.sets * item.restSeconds,
    );
    return (seconds / 60).ceil();
  }

  int get totalTargetSets => exercises.fold(0, (sum, item) => sum + item.sets);

  WorkoutPlanSnapshot copyWith({
    List<PlanExercise>? exercises,
    bool? adjusted,
    List<String>? adjustmentReasons,
  }) => WorkoutPlanSnapshot(
    planId: planId,
    name: name,
    description: description,
    exercises: exercises ?? this.exercises,
    adjusted: adjusted ?? this.adjusted,
    adjustmentReasons: adjustmentReasons ?? this.adjustmentReasons,
  );

  Map<String, dynamic> toJson() => {
    'planId': planId,
    'name': name,
    'description': description,
    'exercises': exercises.map((item) => item.toJson()).toList(),
    'adjusted': adjusted,
    'adjustmentReasons': adjustmentReasons,
  };

  factory WorkoutPlanSnapshot.fromJson(Map<String, dynamic> json) =>
      WorkoutPlanSnapshot(
        planId: json['planId'] as String,
        name: json['name'] as String,
        description: json['description'] as String? ?? '',
        exercises: (json['exercises'] as List? ?? const [])
            .map((item) => PlanExercise.fromJson(item as Map<String, dynamic>))
            .toList(),
        adjusted: json['adjusted'] as bool? ?? false,
        adjustmentReasons: List<String>.from(
          json['adjustmentReasons'] as List? ?? const [],
        ),
      );
}

class WorkoutCompletion {
  const WorkoutCompletion({
    required this.id,
    required this.userId,
    required this.planId,
    required this.occurrenceDate,
    required this.planSnapshot,
    required this.exerciseResults,
    required this.status,
    required this.actualDuration,
    required this.completedAt,
    this.scheduleId,
    this.perceivedDifficulty,
    this.note = '',
  });

  final String id;
  final String userId;
  final String planId;
  final String? scheduleId;
  final DateTime occurrenceDate;
  final WorkoutPlanSnapshot planSnapshot;
  final List<CompletedExercise> exerciseResults;
  final CompletionStatus status;
  final Duration actualDuration;
  final int? perceivedDifficulty;
  final String note;
  final DateTime completedAt;

  String get planName => planSnapshot.name;
  DateTime get startedAt => occurrenceDate;
  Duration get duration => actualDuration;
  int get completedSetCount => exerciseResults.fold(
    0,
    (sum, exercise) => sum + exercise.completedSetCount,
  );
  double get totalVolume =>
      exerciseResults.fold(0.0, (sum, exercise) => sum + exercise.totalVolume);
  Iterable<CompletedSet> get completedSets => exerciseResults
      .expand((exercise) => exercise.sets)
      .where((set) => set.isCompleted);

  WorkoutCompletion copyWith({
    String? userId,
    List<CompletedExercise>? exerciseResults,
    CompletionStatus? status,
    Duration? actualDuration,
    int? perceivedDifficulty,
    String? note,
    DateTime? completedAt,
  }) => WorkoutCompletion(
    id: id,
    userId: userId ?? this.userId,
    planId: planId,
    scheduleId: scheduleId,
    occurrenceDate: occurrenceDate,
    planSnapshot: planSnapshot,
    exerciseResults: exerciseResults ?? this.exerciseResults,
    status: status ?? this.status,
    actualDuration: actualDuration ?? this.actualDuration,
    perceivedDifficulty: perceivedDifficulty ?? this.perceivedDifficulty,
    note: note ?? this.note,
    completedAt: completedAt ?? this.completedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'planId': planId,
    'scheduleId': scheduleId,
    'occurrenceDate': occurrenceDate.toIso8601String(),
    'planSnapshot': planSnapshot.toJson(),
    'exerciseResults': exerciseResults.map((item) => item.toJson()).toList(),
    'status': status.name,
    'actualDurationMinutes': actualDuration.inMinutes,
    'totalVolume': totalVolume,
    'perceivedDifficulty': perceivedDifficulty,
    'note': note,
    'completedAt': completedAt.toIso8601String(),
  };

  factory WorkoutCompletion.fromJson(Map<String, dynamic> json) =>
      WorkoutCompletion(
        id: json['id'] as String,
        userId: json['userId'] as String? ?? '',
        planId: json['planId'] as String,
        scheduleId: json['scheduleId'] as String?,
        occurrenceDate: DateTime.parse(json['occurrenceDate'] as String),
        planSnapshot: WorkoutPlanSnapshot.fromJson(
          json['planSnapshot'] as Map<String, dynamic>,
        ),
        exerciseResults: (json['exerciseResults'] as List? ?? const [])
            .map(
              (item) =>
                  CompletedExercise.fromJson(item as Map<String, dynamic>),
            )
            .toList(),
        status: CompletionStatus.values.byName(json['status'] as String),
        actualDuration: Duration(
          minutes: json['actualDurationMinutes'] as int? ?? 0,
        ),
        perceivedDifficulty: json['perceivedDifficulty'] as int?,
        note: json['note'] as String? ?? '',
        completedAt: DateTime.parse(json['completedAt'] as String),
      );

  factory WorkoutCompletion.fromLegacySessionJson(
    Map<String, dynamic> json, {
    required String userId,
  }) {
    final records = (json['setRecords'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final record in records) {
      grouped.putIfAbsent(record['exerciseId'] as String, () => []).add(record);
    }
    final planExercises = <PlanExercise>[];
    final results = <CompletedExercise>[];
    var order = 0;
    for (final entry in grouped.entries) {
      final first = entry.value.first;
      final sets = entry.value.map(CompletedSet.fromJson).toList();
      final name = first['exerciseName'] as String? ?? 'Bài tập';
      planExercises.add(
        PlanExercise(
          exerciseId: entry.key,
          exerciseName: name,
          sets: sets.length,
          targetReps: sets.first.actualReps,
          targetWeight: sets.first.actualWeightKg,
          restSeconds: 0,
          order: order++,
        ),
      );
      results.add(
        CompletedExercise(
          exerciseId: entry.key,
          exerciseName: name,
          muscleGroup: 'Toàn thân',
          equipment: 'Không rõ',
          targetSets: sets.length,
          targetMinReps: sets.first.actualReps,
          targetMaxReps: sets.first.actualReps,
          targetWeightKg: sets.first.actualWeightKg,
          sets: sets,
        ),
      );
    }
    final started = DateTime.parse(json['startedAt'] as String);
    final ended = json['endedAt'] == null
        ? started
        : DateTime.parse(json['endedAt'] as String);
    final planId = json['planId'] as String;
    return WorkoutCompletion(
      id: json['id'] as String,
      userId: userId,
      planId: planId,
      occurrenceDate: DateTime(started.year, started.month, started.day),
      planSnapshot: WorkoutPlanSnapshot(
        planId: planId,
        name: json['planName'] as String? ?? 'Kế hoạch',
        description: '',
        exercises: planExercises,
      ),
      exerciseResults: results,
      status: CompletionStatus.completed,
      actualDuration: ended.difference(started),
      completedAt: ended,
      note: json['note'] as String? ?? '',
    );
  }
}
