class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    required this.name,
    required this.heightCm,
    required this.currentWeightKg,
    required this.goal,
    required this.weeklyWorkoutGoal,
    this.targetWeightKg = 0,
    this.dateOfBirth,
    this.gender = 'Không muốn cung cấp',
    this.photoUrl,
    this.onboardingCompleted = true,
  });

  final String id;
  final String email;
  final String name;
  final double heightCm;
  final double currentWeightKg;
  @Deprecated(
    'Kept only to deserialize V1 data; target UI has no target weight.',
  )
  final double targetWeightKg;
  final String goal;
  final int weeklyWorkoutGoal;
  final DateTime? dateOfBirth;
  final String gender;
  final String? photoUrl;
  final bool onboardingCompleted;

  double get bmi {
    if (heightCm <= 0 || currentWeightKg <= 0) return 0;
    final heightM = heightCm / 100;
    return currentWeightKg / (heightM * heightM);
  }

  UserProfile copyWith({
    String? id,
    String? email,
    String? name,
    double? heightCm,
    double? currentWeightKg,
    double? targetWeightKg,
    String? goal,
    int? weeklyWorkoutGoal,
    DateTime? dateOfBirth,
    String? gender,
    String? photoUrl,
    bool? onboardingCompleted,
  }) => UserProfile(
    id: id ?? this.id,
    email: email ?? this.email,
    name: name ?? this.name,
    heightCm: heightCm ?? this.heightCm,
    currentWeightKg: currentWeightKg ?? this.currentWeightKg,
    targetWeightKg: targetWeightKg ?? this.targetWeightKg,
    goal: goal ?? this.goal,
    weeklyWorkoutGoal: weeklyWorkoutGoal ?? this.weeklyWorkoutGoal,
    dateOfBirth: dateOfBirth ?? this.dateOfBirth,
    gender: gender ?? this.gender,
    photoUrl: photoUrl ?? this.photoUrl,
    onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'name': name,
    'heightCm': heightCm,
    'currentWeightKg': currentWeightKg,
    'goal': goal,
    'weeklyWorkoutGoal': weeklyWorkoutGoal,
    'dateOfBirth': dateOfBirth?.toIso8601String(),
    'gender': gender,
    'photoUrl': photoUrl,
    'onboardingCompleted': onboardingCompleted,
  };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: json['id'] as String,
    email: json['email'] as String,
    name: json['name'] as String,
    heightCm: (json['heightCm'] as num).toDouble(),
    currentWeightKg: (json['currentWeightKg'] as num).toDouble(),
    targetWeightKg: (json['targetWeightKg'] as num? ?? 0).toDouble(),
    goal: json['goal'] as String,
    weeklyWorkoutGoal: json['weeklyWorkoutGoal'] as int,
    dateOfBirth: json['dateOfBirth'] == null
        ? null
        : DateTime.parse(json['dateOfBirth'] as String),
    gender: json['gender'] as String? ?? 'Không muốn cung cấp',
    photoUrl: json['photoUrl'] as String?,
    onboardingCompleted: json['onboardingCompleted'] as bool? ?? true,
  );
}
