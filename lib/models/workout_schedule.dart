enum ScheduleType { none, once, weekly }

enum OccurrenceStatus { scheduled, completed, partiallyCompleted, overdue }

class WorkoutSchedule {
  const WorkoutSchedule({
    required this.id,
    required this.userId,
    required this.planId,
    required this.type,
    this.scheduledDate,
    this.weekdays = const {},
    this.startDate,
    this.endDate,
    this.hour,
    this.minute,
    this.reminderEnabled = false,
    this.minutesBefore = 15,
    this.isEnabled = true,
  });

  final String id;
  final String userId;
  final String planId;
  final ScheduleType type;
  final DateTime? scheduledDate;
  final Set<int> weekdays;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? hour;
  final int? minute;
  final bool reminderEnabled;
  final int minutesBefore;
  final bool isEnabled;

  bool occursOn(DateTime date) {
    if (!isEnabled || type == ScheduleType.none) return false;
    final day = DateTime(date.year, date.month, date.day);
    if (type == ScheduleType.once) {
      final target = scheduledDate;
      return target != null &&
          DateTime(target.year, target.month, target.day) == day;
    }
    final start = startDate;
    if (start == null || !weekdays.contains(day.weekday)) return false;
    final startDay = DateTime(start.year, start.month, start.day);
    if (day.isBefore(startDay)) return false;
    final end = endDate;
    if (end == null) return true;
    return !day.isAfter(DateTime(end.year, end.month, end.day));
  }

  WorkoutSchedule copyWith({
    String? id,
    String? userId,
    String? planId,
    ScheduleType? type,
    DateTime? scheduledDate,
    Set<int>? weekdays,
    DateTime? startDate,
    DateTime? endDate,
    int? hour,
    int? minute,
    bool? reminderEnabled,
    int? minutesBefore,
    bool? isEnabled,
  }) => WorkoutSchedule(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    planId: planId ?? this.planId,
    type: type ?? this.type,
    scheduledDate: scheduledDate ?? this.scheduledDate,
    weekdays: weekdays ?? this.weekdays,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    hour: hour ?? this.hour,
    minute: minute ?? this.minute,
    reminderEnabled: reminderEnabled ?? this.reminderEnabled,
    minutesBefore: minutesBefore ?? this.minutesBefore,
    isEnabled: isEnabled ?? this.isEnabled,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'planId': planId,
    'type': type.name,
    'scheduledDate': scheduledDate?.toIso8601String(),
    'weekdays': weekdays.toList(),
    'startDate': startDate?.toIso8601String(),
    'endDate': endDate?.toIso8601String(),
    'hour': hour,
    'minute': minute,
    'reminderEnabled': reminderEnabled,
    'minutesBefore': minutesBefore,
    'isEnabled': isEnabled,
  };

  factory WorkoutSchedule.fromJson(Map<String, dynamic> json) =>
      WorkoutSchedule(
        id: json['id'] as String,
        userId: json['userId'] as String? ?? '',
        planId: json['planId'] as String,
        type: ScheduleType.values.byName(json['type'] as String? ?? 'weekly'),
        scheduledDate: json['scheduledDate'] == null
            ? null
            : DateTime.parse(json['scheduledDate'] as String),
        weekdays: Set<int>.from(json['weekdays'] as List? ?? const []),
        startDate: json['startDate'] == null
            ? null
            : DateTime.parse(json['startDate'] as String),
        endDate: json['endDate'] == null
            ? null
            : DateTime.parse(json['endDate'] as String),
        hour: json['hour'] as int?,
        minute: json['minute'] as int?,
        reminderEnabled: json['reminderEnabled'] as bool? ?? false,
        minutesBefore: json['minutesBefore'] as int? ?? 15,
        isEnabled: json['isEnabled'] as bool? ?? true,
      );
}
