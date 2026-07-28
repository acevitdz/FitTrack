class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    required this.name,
    required this.heightCm,
    required this.currentWeightKg,
    required this.goal,
    required this.weeklyWorkoutGoal,
    this.gender = '',
    this.photoUrl,
    this.onboardingCompleted = false,
  });

  final String id;
  final String email;
  final String name;
  final double heightCm;
  final double currentWeightKg;
  final String goal;
  final int weeklyWorkoutGoal;
  final String gender;
  final String? photoUrl;
  final bool onboardingCompleted;

  double get bmi {
    if (heightCm <= 0 || currentWeightKg <= 0) return 0;
    final heightMeters = heightCm / 100;
    return currentWeightKg / (heightMeters * heightMeters);
  }

  UserProfile copyWith({
    String? id,
    String? email,
    String? name,
    double? heightCm,
    double? currentWeightKg,
    String? goal,
    int? weeklyWorkoutGoal,
    String? gender,
    Object? photoUrl = _unset,
    bool? onboardingCompleted,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      heightCm: heightCm ?? this.heightCm,
      currentWeightKg: currentWeightKg ?? this.currentWeightKg,
      goal: goal ?? this.goal,
      weeklyWorkoutGoal: weeklyWorkoutGoal ?? this.weeklyWorkoutGoal,
      gender: gender ?? this.gender,
      photoUrl: identical(photoUrl, _unset)
          ? this.photoUrl
          : photoUrl as String?,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'name': name,
    'heightCm': heightCm,
    'currentWeightKg': currentWeightKg,
    'goal': goal,
    'weeklyWorkoutGoal': weeklyWorkoutGoal,
    'gender': gender,
    'photoUrl': photoUrl,
    'onboardingCompleted': onboardingCompleted,
  };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: json['id'] as String? ?? 'demo-user',
    email: json['email'] as String? ?? '',
    name: json['name'] as String? ?? 'Người dùng FitTrack',
    heightCm: (json['heightCm'] as num?)?.toDouble() ?? 0,
    currentWeightKg: (json['currentWeightKg'] as num?)?.toDouble() ?? 0,
    goal: json['goal'] as String? ?? 'Thể lực tổng quát',
    weeklyWorkoutGoal: (json['weeklyWorkoutGoal'] as num?)?.toInt() ?? 3,
    gender: json['gender'] as String? ?? '',
    photoUrl: json['photoUrl'] as String?,
    onboardingCompleted: json['onboardingCompleted'] as bool? ?? false,
  );
}

const Object _unset = Object();
