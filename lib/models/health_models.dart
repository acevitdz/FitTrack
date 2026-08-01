class WeightEntry {
  const WeightEntry({
    required this.id,
    required this.weightKg,
    required this.recordedAt,
    this.heightCm,
    this.note = '',
    this.photoUrl,
  });

  final String id;
  final double weightKg;
  final DateTime recordedAt;

  /// Height snapshot used to keep historical BMI stable when the profile
  /// height changes. Null is accepted only for migrated V1 records.
  final double? heightCm;

  /// Optional context supplied when the measurement is recorded.
  final String note;
  @Deprecated(
    'Legacy V1 field; progress photos are not captured by the target flow.',
  )
  final String? photoUrl;

  double? get bmi {
    final height = heightCm;
    if (height == null || height <= 0 || weightKg <= 0) return null;
    final heightM = height / 100;
    return weightKg / (heightM * heightM);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'weightKg': weightKg,
    'recordedAt': recordedAt.toIso8601String(),
    'heightCm': heightCm,
    'note': note,
    'photoUrl': photoUrl,
  };

  factory WeightEntry.fromJson(Map<String, dynamic> json) => WeightEntry(
    id: json['id'] as String,
    weightKg: (json['weightKg'] as num).toDouble(),
    recordedAt: DateTime.parse(json['recordedAt'] as String),
    heightCm: (json['heightCm'] as num?)?.toDouble(),
    note: json['note'] as String? ?? '',
    photoUrl: json['photoUrl'] as String?,
  );
}

enum ReminderType { once, weekly }

class WorkoutReminder {
  const WorkoutReminder({
    required this.id,
    required this.title,
    required this.weekdays,
    required this.hour,
    required this.minute,
    required this.enabled,
    this.planId,
    this.scheduleId,
    this.type = ReminderType.weekly,
    this.scheduledDate,
    this.minutesBefore = 0,
  });

  final String id;
  final String title;
  final Set<int> weekdays;
  final int hour;
  final int minute;
  final bool enabled;
  final String? planId;
  final String? scheduleId;
  final ReminderType type;
  final DateTime? scheduledDate;
  final int minutesBefore;

  WorkoutReminder copyWith({
    String? title,
    Set<int>? weekdays,
    int? hour,
    int? minute,
    bool? enabled,
    String? planId,
    String? scheduleId,
    ReminderType? type,
    DateTime? scheduledDate,
    int? minutesBefore,
  }) => WorkoutReminder(
    id: id,
    title: title ?? this.title,
    weekdays: weekdays ?? this.weekdays,
    hour: hour ?? this.hour,
    minute: minute ?? this.minute,
    enabled: enabled ?? this.enabled,
    planId: planId ?? this.planId,
    scheduleId: scheduleId ?? this.scheduleId,
    type: type ?? this.type,
    scheduledDate: scheduledDate ?? this.scheduledDate,
    minutesBefore: minutesBefore ?? this.minutesBefore,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'weekdays': weekdays.toList(),
    'hour': hour,
    'minute': minute,
    'enabled': enabled,
    'planId': planId,
    'scheduleId': scheduleId,
    'type': type.name,
    'scheduledDate': scheduledDate?.toIso8601String(),
    'minutesBefore': minutesBefore,
  };

  factory WorkoutReminder.fromJson(Map<String, dynamic> json) =>
      WorkoutReminder(
        id: json['id'] as String,
        title: json['title'] as String,
        weekdays: Set<int>.from(json['weekdays'] as List),
        hour: json['hour'] as int,
        minute: json['minute'] as int,
        enabled: json['enabled'] as bool,
        planId: json['planId'] as String?,
        scheduleId: json['scheduleId'] as String?,
        type: ReminderType.values.byName(json['type'] as String? ?? 'weekly'),
        scheduledDate: json['scheduledDate'] == null
            ? null
            : DateTime.parse(json['scheduledDate'] as String),
        minutesBefore: json['minutesBefore'] as int? ?? 0,
      );
}

class Achievement {
  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.iconCodePoint,
    this.ruleVersion = 'achievement_rules_v1',
    this.unlockedAt,
  });

  final String id;
  final String title;
  final String description;
  final int iconCodePoint;
  final String ruleVersion;
  final DateTime? unlockedAt;

  bool get unlocked => unlockedAt != null;

  Achievement copyWith({DateTime? unlockedAt}) => Achievement(
    id: id,
    title: title,
    description: description,
    iconCodePoint: iconCodePoint,
    ruleVersion: ruleVersion,
    unlockedAt: unlockedAt ?? this.unlockedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'iconCodePoint': iconCodePoint,
    'ruleVersion': ruleVersion,
    'unlockedAt': unlockedAt?.toIso8601String(),
  };

  factory Achievement.fromJson(Map<String, dynamic> json) => Achievement(
    id: json['id'] as String,
    title: json['title'] as String,
    description: json['description'] as String,
    iconCodePoint: json['iconCodePoint'] as int,
    ruleVersion:
        json['ruleVersion'] as String? ?? 'achievement_rules_legacy_v1',
    unlockedAt: json['unlockedAt'] == null
        ? null
        : DateTime.parse(json['unlockedAt'] as String),
  );
}
