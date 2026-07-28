class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.englishName,
    required this.muscleGroup,
    required this.difficulty,
    required this.equipment,
    required this.location,
    required this.instructions,
    required this.commonMistakes,
    required this.suggestedSets,
    required this.suggestedReps,
    this.description = '',
    this.secondaryMuscles = const [],
    this.imageUrl,
    this.ownerId,
    this.isActive = true,
  });

  final String id;
  final String name;
  final String englishName;
  final String muscleGroup;
  final String difficulty;
  final String equipment;
  final String location;
  final List<String> instructions;
  final List<String> commonMistakes;
  final int suggestedSets;
  final int suggestedReps;
  final String description;
  final List<String> secondaryMuscles;
  final String? imageUrl;
  final String? ownerId;
  final bool isActive;

  bool get isPersonal => ownerId != null;

  Exercise copyWith({
    String? id,
    String? name,
    String? englishName,
    String? muscleGroup,
    String? difficulty,
    String? equipment,
    String? location,
    List<String>? instructions,
    List<String>? commonMistakes,
    int? suggestedSets,
    int? suggestedReps,
    String? description,
    List<String>? secondaryMuscles,
    String? imageUrl,
    String? ownerId,
    bool? isActive,
  }) => Exercise(
    id: id ?? this.id,
    name: name ?? this.name,
    englishName: englishName ?? this.englishName,
    muscleGroup: muscleGroup ?? this.muscleGroup,
    difficulty: difficulty ?? this.difficulty,
    equipment: equipment ?? this.equipment,
    location: location ?? this.location,
    instructions: instructions ?? this.instructions,
    commonMistakes: commonMistakes ?? this.commonMistakes,
    suggestedSets: suggestedSets ?? this.suggestedSets,
    suggestedReps: suggestedReps ?? this.suggestedReps,
    description: description ?? this.description,
    secondaryMuscles: secondaryMuscles ?? this.secondaryMuscles,
    imageUrl: imageUrl ?? this.imageUrl,
    ownerId: ownerId ?? this.ownerId,
    isActive: isActive ?? this.isActive,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'englishName': englishName,
    'muscleGroup': muscleGroup,
    'difficulty': difficulty,
    'equipment': equipment,
    'location': location,
    'instructions': instructions,
    'commonMistakes': commonMistakes,
    'suggestedSets': suggestedSets,
    'suggestedReps': suggestedReps,
    'description': description,
    'secondaryMuscles': secondaryMuscles,
    'imageUrl': imageUrl,
    'ownerId': ownerId,
    'isActive': isActive,
  };

  factory Exercise.fromJson(Map<String, dynamic> json) => Exercise(
    id: json['id'] as String,
    name: json['name'] as String,
    englishName: json['englishName'] as String? ?? '',
    muscleGroup: json['muscleGroup'] as String,
    difficulty: json['difficulty'] as String,
    equipment: json['equipment'] as String,
    location: json['location'] as String,
    instructions: List<String>.from(json['instructions'] as List? ?? const []),
    commonMistakes: List<String>.from(
      json['commonMistakes'] as List? ?? const [],
    ),
    suggestedSets: json['suggestedSets'] as int? ?? 3,
    suggestedReps: json['suggestedReps'] as int? ?? 10,
    description: json['description'] as String? ?? '',
    secondaryMuscles: List<String>.from(
      json['secondaryMuscles'] as List? ?? const [],
    ),
    imageUrl: json['imageUrl'] as String?,
    ownerId: json['ownerId'] as String?,
    isActive: json['isActive'] as bool? ?? true,
  );
}
