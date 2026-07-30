import 'exercise_enums.dart';

/// Template exercise — `exercises/{exerciseId}` (docs/TV2_TASKS.md §2.1).
/// Shared catalog, admin-write-only; users only ever read `isActive == true`.
class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.primaryMuscle,
    required this.secondaryMuscles,
    required this.equipment,
    required this.difficulty,
    required this.instructions,
    required this.commonMistakes,
    required this.quickTip,
    required this.suggestedRestSeconds,
    required this.imageUrl,
    required this.isActive,
  });

  final String id;
  final String name;
  final Muscle primaryMuscle;
  final List<Muscle> secondaryMuscles;
  final List<Equipment> equipment;
  final Difficulty difficulty;
  final List<String> instructions;
  final List<String> commonMistakes;
  final String quickTip;
  final int suggestedRestSeconds;
  final String imageUrl;
  final bool isActive;

  List<Muscle> get allMuscles => [primaryMuscle, ...secondaryMuscles];

  factory Exercise.fromMap(String id, Map<String, dynamic> map) {
    return Exercise(
      id: id,
      name: map['name'] as String? ?? '',
      primaryMuscle: Muscle.fromKey(map['primaryMuscle'] as String?) ??
          Muscle.nguc,
      secondaryMuscles: _muscleList(map['secondaryMuscles']),
      equipment: _equipmentList(map['equipment']),
      difficulty: Difficulty.fromKey(map['difficulty'] as String?),
      instructions: _stringList(map['instructions']),
      commonMistakes: _stringList(map['commonMistakes']),
      quickTip: map['quickTip'] as String? ?? '',
      suggestedRestSeconds: (map['suggestedRestSeconds'] as num?)?.toInt() ?? 60,
      imageUrl: map['imageUrl'] as String? ?? '',
      isActive: map['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'primaryMuscle': primaryMuscle.key,
      'secondaryMuscles': secondaryMuscles.map((m) => m.key).toList(),
      'equipment': equipment.map((e) => e.key).toList(),
      'difficulty': difficulty.key,
      'instructions': instructions,
      'commonMistakes': commonMistakes,
      'quickTip': quickTip,
      'suggestedRestSeconds': suggestedRestSeconds,
      'imageUrl': imageUrl,
      'isActive': isActive,
    };
  }

  Exercise copyWith({
    String? name,
    Muscle? primaryMuscle,
    List<Muscle>? secondaryMuscles,
    List<Equipment>? equipment,
    Difficulty? difficulty,
    List<String>? instructions,
    List<String>? commonMistakes,
    String? quickTip,
    int? suggestedRestSeconds,
    String? imageUrl,
    bool? isActive,
  }) {
    return Exercise(
      id: id,
      name: name ?? this.name,
      primaryMuscle: primaryMuscle ?? this.primaryMuscle,
      secondaryMuscles: secondaryMuscles ?? this.secondaryMuscles,
      equipment: equipment ?? this.equipment,
      difficulty: difficulty ?? this.difficulty,
      instructions: instructions ?? this.instructions,
      commonMistakes: commonMistakes ?? this.commonMistakes,
      quickTip: quickTip ?? this.quickTip,
      suggestedRestSeconds: suggestedRestSeconds ?? this.suggestedRestSeconds,
      imageUrl: imageUrl ?? this.imageUrl,
      isActive: isActive ?? this.isActive,
    );
  }
}

/// Personal exercise — `users/{uid}/personalExercises/{exerciseId}` (§2.2).
/// Belongs to exactly one uid; no `isActive` (hard-deleted, not soft-deleted).
class PersonalExercise {
  const PersonalExercise({
    required this.id,
    required this.name,
    required this.primaryMuscle,
    required this.secondaryMuscles,
    required this.equipment,
    required this.difficulty,
    required this.instructions,
    required this.personalNote,
    required this.isFavorite,
  });

  final String id;
  final String name;
  final Muscle primaryMuscle;
  final List<Muscle> secondaryMuscles;
  final List<Equipment> equipment;
  final Difficulty difficulty;
  final List<String> instructions;
  final String personalNote;
  final bool isFavorite;

  factory PersonalExercise.fromMap(String id, Map<String, dynamic> map) {
    return PersonalExercise(
      id: id,
      name: map['name'] as String? ?? '',
      primaryMuscle: Muscle.fromKey(map['primaryMuscle'] as String?) ??
          Muscle.nguc,
      secondaryMuscles: _muscleList(map['secondaryMuscles']),
      equipment: _equipmentList(map['equipment']),
      difficulty: Difficulty.fromKey(map['difficulty'] as String?),
      instructions: _stringList(map['instructions']),
      personalNote: map['personalNote'] as String? ?? '',
      isFavorite: map['isFavorite'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'primaryMuscle': primaryMuscle.key,
      'secondaryMuscles': secondaryMuscles.map((m) => m.key).toList(),
      'equipment': equipment.map((e) => e.key).toList(),
      'difficulty': difficulty.key,
      'instructions': instructions,
      'personalNote': personalNote,
      'isFavorite': isFavorite,
    };
  }

  PersonalExercise copyWith({
    String? name,
    Muscle? primaryMuscle,
    List<Muscle>? secondaryMuscles,
    List<Equipment>? equipment,
    Difficulty? difficulty,
    List<String>? instructions,
    String? personalNote,
    bool? isFavorite,
  }) {
    return PersonalExercise(
      id: id,
      name: name ?? this.name,
      primaryMuscle: primaryMuscle ?? this.primaryMuscle,
      secondaryMuscles: secondaryMuscles ?? this.secondaryMuscles,
      equipment: equipment ?? this.equipment,
      difficulty: difficulty ?? this.difficulty,
      instructions: instructions ?? this.instructions,
      personalNote: personalNote ?? this.personalNote,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}

List<String> _stringList(dynamic value) =>
    (value as List?)?.map((e) => e.toString()).toList() ?? const [];

List<Muscle> _muscleList(dynamic value) => (value as List?)
        ?.map((e) => Muscle.fromKey(e as String?))
        .whereType<Muscle>()
        .toList() ??
    const [];

List<Equipment> _equipmentList(dynamic value) => (value as List?)
        ?.map((e) => Equipment.fromKey(e as String?))
        .whereType<Equipment>()
        .toList() ??
    const [];
