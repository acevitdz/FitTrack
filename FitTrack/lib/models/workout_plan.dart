class PlanExercise {
  const PlanExercise({
    required this.exerciseId,
    required this.exerciseName,
    required this.sets,
    required this.targetReps,
    required this.targetWeight,
    required this.restSeconds,
    required this.order,
    this.maxReps,
    this.note = '',
    this.muscleGroup = 'Toàn thân',
    this.equipment = 'Không dụng cụ',
  });

  final String exerciseId;
  final String exerciseName;
  final int sets;
  final int targetReps;
  final int? maxReps;
  final double targetWeight;
  final int restSeconds;
  final int order;
  final String note;
  final String muscleGroup;
  final String equipment;

  int get targetSets => sets;
  int get minReps => targetReps;
  int get targetMaxReps => maxReps ?? targetReps;
  double get targetWeightKg => targetWeight;

  PlanExercise copyWith({
    String? exerciseId,
    String? exerciseName,
    int? sets,
    int? targetReps,
    int? maxReps,
    double? targetWeight,
    int? restSeconds,
    int? order,
    String? note,
    String? muscleGroup,
    String? equipment,
  }) => PlanExercise(
    exerciseId: exerciseId ?? this.exerciseId,
    exerciseName: exerciseName ?? this.exerciseName,
    sets: sets ?? this.sets,
    targetReps: targetReps ?? this.targetReps,
    maxReps: maxReps ?? this.maxReps,
    targetWeight: targetWeight ?? this.targetWeight,
    restSeconds: restSeconds ?? this.restSeconds,
    order: order ?? this.order,
    note: note ?? this.note,
    muscleGroup: muscleGroup ?? this.muscleGroup,
    equipment: equipment ?? this.equipment,
  );

  Map<String, dynamic> toJson() => {
    'exerciseId': exerciseId,
    'exerciseName': exerciseName,
    'sets': sets,
    'targetSets': sets,
    'targetReps': targetReps,
    'minReps': targetReps,
    'maxReps': maxReps ?? targetReps,
    'targetWeight': targetWeight,
    'targetWeightKg': targetWeight,
    'restSeconds': restSeconds,
    'order': order,
    'note': note,
    'muscleGroup': muscleGroup,
    'equipment': equipment,
  };

  factory PlanExercise.fromJson(Map<String, dynamic> json) => PlanExercise(
    exerciseId: json['exerciseId'] as String,
    exerciseName: json['exerciseName'] as String? ?? 'Bài tập',
    sets: json['targetSets'] as int? ?? json['sets'] as int? ?? 1,
    targetReps: json['minReps'] as int? ?? json['targetReps'] as int? ?? 1,
    maxReps: json['maxReps'] as int?,
    targetWeight:
        (json['targetWeightKg'] as num? ?? json['targetWeight'] as num? ?? 0)
            .toDouble(),
    restSeconds: json['restSeconds'] as int? ?? 0,
    order: json['order'] as int? ?? 0,
    note: json['note'] as String? ?? '',
    muscleGroup: json['muscleGroup'] as String? ?? 'Toàn thân',
    equipment: json['equipment'] as String? ?? 'Không dụng cụ',
  );
}

class WorkoutPlan {
  const WorkoutPlan({
    required this.id,
    required this.name,
    required this.exercises,
    required this.createdAt,
    this.userId = '',
    this.description = '',
    this.isActive = true,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final String name;
  final String description;
  final List<PlanExercise> exercises;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isActive;

  int get estimatedDurationMinutes {
    final workingSeconds = exercises.fold<int>(
      0,
      (sum, exercise) =>
          sum + exercise.sets * 45 + exercise.sets * exercise.restSeconds,
    );
    return (workingSeconds / 60).ceil();
  }

  WorkoutPlan copyWith({
    String? id,
    String? userId,
    String? name,
    String? description,
    List<PlanExercise>? exercises,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
  }) => WorkoutPlan(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    name: name ?? this.name,
    description: description ?? this.description,
    exercises: exercises ?? this.exercises,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    isActive: isActive ?? this.isActive,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'name': name,
    'description': description,
    'exercises': exercises.map((item) => item.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
    'isActive': isActive,
  };

  factory WorkoutPlan.fromJson(Map<String, dynamic> json) => WorkoutPlan(
    id: json['id'] as String,
    userId: json['userId'] as String? ?? '',
    name: json['name'] as String,
    description: json['description'] as String? ?? '',
    exercises: (json['exercises'] as List? ?? const [])
        .map((item) => PlanExercise.fromJson(item as Map<String, dynamic>))
        .toList(),
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: json['updatedAt'] == null
        ? null
        : DateTime.parse(json['updatedAt'] as String),
    isActive: json['isActive'] as bool? ?? true,
  );
}
