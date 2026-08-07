import '../models/active_workout.dart';

enum MuscleRegion {
  chest,
  upperBack,
  lowerBack,
  shoulders,
  biceps,
  triceps,
  forearms,
  quadriceps,
  hamstrings,
  glutes,
  calves,
  core,
  hips,
  other,
}

extension MuscleRegionLabel on MuscleRegion {
  String get label => switch (this) {
    MuscleRegion.chest => 'Ngực',
    MuscleRegion.upperBack => 'Lưng trên',
    MuscleRegion.lowerBack => 'Lưng dưới',
    MuscleRegion.shoulders => 'Vai',
    MuscleRegion.biceps => 'Tay trước',
    MuscleRegion.triceps => 'Tay sau',
    MuscleRegion.forearms => 'Cẳng tay',
    MuscleRegion.quadriceps => 'Đùi trước',
    MuscleRegion.hamstrings => 'Đùi sau',
    MuscleRegion.glutes => 'Mông',
    MuscleRegion.calves => 'Bắp chân',
    MuscleRegion.core => 'Bụng',
    MuscleRegion.hips => 'Hông/đùi trong',
    MuscleRegion.other => 'Toàn thân/khác',
  };
}

MuscleRegion muscleRegionForLabel(String value) {
  final label = value.trim().toLowerCase();
  if (label.isEmpty) return MuscleRegion.other;
  if (label.contains('lưng dưới') ||
      label.contains('lower back') ||
      label.contains('erector')) {
    return MuscleRegion.lowerBack;
  }
  if (label.contains('lưng') ||
      label.contains('xô') ||
      label.contains('cầu vai') ||
      label.contains('lat') ||
      label.contains('trap') ||
      label == 'back') {
    return MuscleRegion.upperBack;
  }
  if (label.contains('ngực') ||
      label.contains('chest') ||
      label.contains('pector')) {
    return MuscleRegion.chest;
  }
  if (label.contains('vai') ||
      label.contains('shoulder') ||
      label.contains('delt')) {
    return MuscleRegion.shoulders;
  }
  if (label.contains('tay trước') || label.contains('bicep')) {
    return MuscleRegion.biceps;
  }
  if (label.contains('tay sau') || label.contains('tricep')) {
    return MuscleRegion.triceps;
  }
  if (label.contains('cẳng tay') || label.contains('forearm')) {
    return MuscleRegion.forearms;
  }
  if (label.contains('đùi trước') ||
      label.contains('quadricep') ||
      label == 'quad' ||
      label == 'chân' ||
      label == 'legs') {
    return MuscleRegion.quadriceps;
  }
  if (label.contains('đùi sau') || label.contains('hamstring')) {
    return MuscleRegion.hamstrings;
  }
  if (label.contains('mông') || label.contains('glute')) {
    return MuscleRegion.glutes;
  }
  if (label.contains('bắp chân') ||
      label.contains('calf') ||
      label.contains('calves')) {
    return MuscleRegion.calves;
  }
  if (label.contains('bụng') ||
      label.contains('abdominal') ||
      label == 'abs' ||
      label == 'core') {
    return MuscleRegion.core;
  }
  if (label.contains('khép') ||
      label.contains('dạng') ||
      label.contains('hông') ||
      label.contains('adductor') ||
      label.contains('abductor') ||
      label.contains('hip')) {
    return MuscleRegion.hips;
  }
  if (label == 'tay' || label == 'arms') return MuscleRegion.biceps;
  return MuscleRegion.other;
}

enum MuscleActivityLevel { neutral, low, medium, high }

class MuscleSessionPoint {
  const MuscleSessionPoint({
    required this.completionId,
    required this.date,
    required this.weightedSets,
  });

  final String completionId;
  final DateTime date;
  final double weightedSets;
}

class MuscleActivitySummary {
  const MuscleActivitySummary({
    required this.region,
    required this.weightedSets,
    required this.baselineSets,
    required this.lastTrained,
    required this.level,
    required this.sessions,
  });

  final MuscleRegion region;
  final double weightedSets;
  final double baselineSets;
  final DateTime? lastTrained;
  final MuscleActivityLevel level;
  final List<MuscleSessionPoint> sessions;

  bool get hasData => lastTrained != null;
  double get changeFromBaseline =>
      baselineSets > 0 ? (weightedSets / baselineSets) - 1 : 0;
}

class MuscleBalanceResult {
  const MuscleBalanceResult({
    required this.byRegion,
    required this.highestRegion,
  });

  final Map<MuscleRegion, MuscleActivitySummary> byRegion;
  final MuscleRegion? highestRegion;
}

MuscleBalanceResult computeMuscleBalance({
  required List<WorkoutCompletion> completions,
  required DateTime windowStart,
  DateTime? now,
  bool includeSecondary = true,
  int baselinePeriods = 3,
}) {
  if (baselinePeriods < 1) {
    throw ArgumentError.value(baselinePeriods, 'baselinePeriods', 'Must be positive');
  }
  final windowEnd = now ?? DateTime.now();
  final windowLength = windowEnd.difference(windowStart);
  if (windowLength <= Duration.zero) {
    throw ArgumentError('windowStart must be before now');
  }
  final baselineStart = windowStart.subtract(windowLength * baselinePeriods);
  final current = _accumulateMuscles(
    completions: completions,
    start: windowStart,
    end: windowEnd,
    includeSecondary: includeSecondary,
  );
  final baseline = _accumulateMuscles(
    completions: completions,
    start: baselineStart,
    end: windowStart,
    includeSecondary: includeSecondary,
  );

  final byRegion = <MuscleRegion, MuscleActivitySummary>{};
  for (final region in MuscleRegion.values) {
    final currentRegion = current[region];
    final weightedSets = currentRegion?.weightedSets ?? 0;
    final baselineSets = (baseline[region]?.weightedSets ?? 0) / baselinePeriods;
    final lastTrained = currentRegion?.lastTrained;
    final level = lastTrained == null
        ? MuscleActivityLevel.neutral
        : baselineSets <= 0
        ? MuscleActivityLevel.medium
        : weightedSets >= baselineSets * 1.3
        ? MuscleActivityLevel.high
        : weightedSets <= baselineSets * .7
        ? MuscleActivityLevel.low
        : MuscleActivityLevel.medium;
    byRegion[region] = MuscleActivitySummary(
      region: region,
      weightedSets: weightedSets,
      baselineSets: baselineSets,
      lastTrained: lastTrained,
      level: level,
      sessions: currentRegion?.sessionPoints() ?? const [],
    );
  }

  final highRegions = byRegion.values
      .where((item) => item.level == MuscleActivityLevel.high)
      .toList()
    ..sort(
      (left, right) =>
          right.changeFromBaseline.compareTo(left.changeFromBaseline),
    );
  return MuscleBalanceResult(
    byRegion: Map.unmodifiable(byRegion),
    highestRegion: highRegions.firstOrNull?.region,
  );
}

class _MuscleAccumulation {
  double weightedSets = 0;
  DateTime? lastTrained;
  final Map<String, double> _setsByCompletion = {};
  final Map<String, DateTime> _dateByCompletion = {};

  void add(String completionId, DateTime date, double amount) {
    weightedSets += amount;
    _setsByCompletion.update(
      completionId,
      (value) => value + amount,
      ifAbsent: () => amount,
    );
    _dateByCompletion[completionId] = date;
    if (lastTrained == null || date.isAfter(lastTrained!)) lastTrained = date;
  }

  List<MuscleSessionPoint> sessionPoints() {
    final entries = _setsByCompletion.entries.toList()
      ..sort(
        (left, right) => _dateByCompletion[left.key]!.compareTo(
          _dateByCompletion[right.key]!,
        ),
      );
    return List.unmodifiable([
      for (final entry in entries)
        MuscleSessionPoint(
          completionId: entry.key,
          date: _dateByCompletion[entry.key]!,
          weightedSets: entry.value,
        ),
    ]);
  }
}

Map<MuscleRegion, _MuscleAccumulation> _accumulateMuscles({
  required List<WorkoutCompletion> completions,
  required DateTime start,
  required DateTime end,
  required bool includeSecondary,
}) {
  final result = <MuscleRegion, _MuscleAccumulation>{};
  void add(
    MuscleRegion region,
    String completionId,
    DateTime date,
    double amount,
  ) {
    result
        .putIfAbsent(region, _MuscleAccumulation.new)
        .add(completionId, date, amount);
  }

  for (final completion in completions) {
    if (completion.completedAt.isBefore(start) ||
        !completion.completedAt.isBefore(end)) {
      continue;
    }
    final exercises = {
      for (final exercise in completion.snapshot.exercises)
        exercise.exerciseId: exercise,
    };
    for (final event in completion.setEvents) {
      if (event.status != SetEventStatus.completed) continue;
      final exercise = exercises[event.exerciseId];
      if (exercise == null) continue;
      final primary = muscleRegionForLabel(exercise.muscleGroup);
      add(primary, completion.id, completion.completedAt, 1);
      if (!includeSecondary) continue;
      final secondaryRegions = exercise.secondaryMuscles
          .map(muscleRegionForLabel)
          .where((region) => region != primary && region != MuscleRegion.other)
          .toSet();
      for (final secondary in secondaryRegions) {
        add(secondary, completion.id, completion.completedAt, .5);
      }
    }
  }
  return result;
}

class ExerciseSessionSummary {
  const ExerciseSessionSummary({
    required this.completionId,
    required this.date,
    required this.completedSets,
  });

  final String completionId;
  final DateTime date;
  final int completedSets;
}

class ExerciseProgressStats {
  const ExerciseProgressStats({
    required this.totalSessions,
    required this.totalCompletedSets,
    required this.sessionsPerWeek,
    required this.recentSessions,
  });

  final int totalSessions;
  final int totalCompletedSets;
  final double sessionsPerWeek;
  final List<ExerciseSessionSummary> recentSessions;
}

ExerciseProgressStats computeExerciseProgress({
  required String exerciseId,
  required List<WorkoutCompletion> completions,
  required DateTime windowStart,
  DateTime? now,
}) {
  final windowEnd = now ?? DateTime.now();
  final windowLength = windowEnd.difference(windowStart);
  if (windowLength <= Duration.zero) {
    throw ArgumentError('windowStart must be before now');
  }
  final sessions = <ExerciseSessionSummary>[];
  for (final completion in completions) {
    if (completion.completedAt.isBefore(windowStart) ||
        !completion.completedAt.isBefore(windowEnd)) {
      continue;
    }
    final completedSets = completion.setEvents
        .where(
          (event) =>
              event.exerciseId == exerciseId &&
              event.status == SetEventStatus.completed,
        )
        .length;
    if (completedSets == 0) continue;
    sessions.add(
      ExerciseSessionSummary(
        completionId: completion.id,
        date: completion.completedAt,
        completedSets: completedSets,
      ),
    );
  }
  sessions.sort((left, right) => right.date.compareTo(left.date));
  final totalSets = sessions.fold<int>(
    0,
    (total, session) => total + session.completedSets,
  );
  final weeks = windowLength.inMilliseconds /
      const Duration(days: 7).inMilliseconds;
  return ExerciseProgressStats(
    totalSessions: sessions.length,
    totalCompletedSets: totalSets,
    sessionsPerWeek: weeks <= 0 ? 0 : sessions.length / weeks,
    recentSessions: List.unmodifiable(sessions),
  );
}
