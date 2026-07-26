class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.englishName,
    required this.muscleGroup,
    required this.difficulty,
    required this.equipment,
    required this.description,
    required this.instructions,
    required this.commonMistakes,
    required this.isActive,
    this.imageUrl,
  });

  final String id;
  final String name;
  final String englishName;
  final String muscleGroup;
  final String difficulty;
  final String equipment;
  final String description;
  final List<String> instructions;
  final List<String> commonMistakes;
  final bool isActive;
  final String? imageUrl;

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: json['id'] as String,
      name: json['name'] as String,
      englishName: json['englishName'] as String? ?? '',
      muscleGroup: json['muscleGroup'] as String,
      difficulty: json['difficulty'] as String,
      equipment: json['equipment'] as String,
      description: json['description'] as String? ?? '',
      instructions: List<String>.from(
        json['instructions'] as List? ?? const [],
      ),
      commonMistakes: List<String>.from(
        json['commonMistakes'] as List? ?? const [],
      ),
      isActive: json['isActive'] as bool? ?? true,
      imageUrl: json['imageUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'englishName': englishName,
      'muscleGroup': muscleGroup,
      'difficulty': difficulty,
      'equipment': equipment,
      'description': description,
      'instructions': instructions,
      'commonMistakes': commonMistakes,
      'isActive': isActive,
      if (imageUrl != null) 'imageUrl': imageUrl,
    };
  }

  Exercise copyWith({
    String? id,
    String? name,
    String? englishName,
    String? muscleGroup,
    String? difficulty,
    String? equipment,
    String? description,
    List<String>? instructions,
    List<String>? commonMistakes,
    bool? isActive,
    String? imageUrl,
  }) {
    return Exercise(
      id: id ?? this.id,
      name: name ?? this.name,
      englishName: englishName ?? this.englishName,
      muscleGroup: muscleGroup ?? this.muscleGroup,
      difficulty: difficulty ?? this.difficulty,
      equipment: equipment ?? this.equipment,
      description: description ?? this.description,
      instructions: instructions ?? this.instructions,
      commonMistakes: commonMistakes ?? this.commonMistakes,
      isActive: isActive ?? this.isActive,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Exercise &&
        other.id == id &&
        other.name == name &&
        other.englishName == englishName &&
        other.muscleGroup == muscleGroup &&
        other.difficulty == difficulty &&
        other.equipment == equipment &&
        other.description == description &&
        _listEquals(other.instructions, instructions) &&
        _listEquals(other.commonMistakes, commonMistakes) &&
        other.isActive == isActive &&
        other.imageUrl == imageUrl;
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    englishName,
    muscleGroup,
    difficulty,
    equipment,
    description,
    Object.hashAll(instructions),
    Object.hashAll(commonMistakes),
    isActive,
    imageUrl,
  );

  @override
  String toString() => 'Exercise($id, $name)';
}

bool _listEquals(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

abstract final class ExerciseDifficulty {
  static const beginner = 'Cơ bản';
  static const intermediate = 'Trung bình';
  static const advanced = 'Nâng cao';

  static const values = [beginner, intermediate, advanced];
}
