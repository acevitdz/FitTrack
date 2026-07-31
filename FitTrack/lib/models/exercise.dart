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
    this.isLibraryVisible = true,
    this.sourceProvider = 'fittrack_authored',
    String? sourceExerciseId,
    this.sourceUrl,
    this.license = 'fittrack-authored',
    this.sourceUpdatedAt,
    this.reviewedAt = '2026-07-20T00:00:00Z',
    this.reviewedBy = 'system_seed',
    this.catalogStatus = 'published',
  }) : sourceExerciseId = sourceExerciseId ?? id;

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
  final bool isLibraryVisible;
  final String sourceProvider;
  final String? sourceExerciseId;
  final String? sourceUrl;
  final String? license;
  final String? sourceUpdatedAt;
  final String? reviewedAt;
  final String? reviewedBy;
  final String catalogStatus;

  bool get isPersonal => ownerId != null;

  bool get isCatalogApproved =>
      isActive &&
      catalogStatus == 'published' &&
      sourceProvider.trim().isNotEmpty &&
      (sourceExerciseId?.trim().isNotEmpty ?? false) &&
      (license?.trim().isNotEmpty ?? false) &&
      (reviewedAt?.trim().isNotEmpty ?? false) &&
      (reviewedBy?.trim().isNotEmpty ?? false);

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
    bool? isLibraryVisible,
    String? sourceProvider,
    String? sourceExerciseId,
    String? sourceUrl,
    String? license,
    String? sourceUpdatedAt,
    String? reviewedAt,
    String? reviewedBy,
    String? catalogStatus,
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
    isLibraryVisible: isLibraryVisible ?? this.isLibraryVisible,
    sourceProvider: sourceProvider ?? this.sourceProvider,
    sourceExerciseId: sourceExerciseId ?? this.sourceExerciseId,
    sourceUrl: sourceUrl ?? this.sourceUrl,
    license: license ?? this.license,
    sourceUpdatedAt: sourceUpdatedAt ?? this.sourceUpdatedAt,
    reviewedAt: reviewedAt ?? this.reviewedAt,
    reviewedBy: reviewedBy ?? this.reviewedBy,
    catalogStatus: catalogStatus ?? this.catalogStatus,
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
    'isLibraryVisible': isLibraryVisible,
    'sourceProvider': sourceProvider,
    'sourceExerciseId': sourceExerciseId,
    'sourceUrl': sourceUrl,
    'license': license,
    'sourceUpdatedAt': sourceUpdatedAt,
    'reviewedAt': reviewedAt,
    'reviewedBy': reviewedBy,
    'catalogStatus': catalogStatus,
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
    isLibraryVisible: json['isLibraryVisible'] as bool? ?? true,
    sourceProvider: json['sourceProvider'] as String? ?? 'fittrack_authored',
    sourceExerciseId: json['sourceExerciseId'] as String?,
    sourceUrl: json['sourceUrl'] as String?,
    license: json['license'] as String?,
    sourceUpdatedAt: json['sourceUpdatedAt'] as String?,
    reviewedAt: json['reviewedAt'] as String?,
    reviewedBy: json['reviewedBy'] as String?,
    catalogStatus: json['catalogStatus'] as String? ?? 'published',
  );
}
