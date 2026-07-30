import '../models/exercise.dart';
import '../models/exercise_enums.dart';
import '../models/exercise_set_log.dart';

enum MuscleVolumeLevel { neutral, low, medium, high }

class MuscleSessionPoint {
  const MuscleSessionPoint({required this.date, required this.volumeKg});
  final DateTime date;
  final double volumeKg;
}

class MuscleVolumeSummary {
  const MuscleVolumeSummary({
    required this.muscle,
    required this.weightedVolumeKg,
    required this.baselineVolumeKg,
    required this.lastTrained,
    required this.level,
    required this.sessions,
  });

  final Muscle muscle;
  final double weightedVolumeKg;

  /// This muscle's own average weighted volume per window-length period,
  /// measured over the periods immediately before the current window. 0
  /// means there's no prior history for this muscle to compare against.
  final double baselineVolumeKg;
  final DateTime? lastTrained;
  final MuscleVolumeLevel level;
  final List<MuscleSessionPoint> sessions;

  bool get hasData => lastTrained != null;

  /// How far above/below the muscle's own normal this period is, e.g. 0.45
  /// = 45% above baseline. Only meaningful when [baselineVolumeKg] > 0.
  double get changeFromBaseline =>
      baselineVolumeKg > 0 ? (weightedVolumeKg / baselineVolumeKg) - 1 : 0;
}

class MuscleBalanceResult {
  const MuscleBalanceResult({required this.byMuscle, required this.overtrained});

  final Map<Muscle, MuscleVolumeSummary> byMuscle;

  /// Muscle to flag in the imbalance banner, or null if nothing stands out
  /// enough to warrant a warning (§5: "không có dữ liệu → neutral, không
  /// suy diễn kết luận mất cân bằng" applies just as much to "no baseline to
  /// compare against" as it does to "no data at all").
  final Muscle? overtrained;
}

/// §5 business rules:
/// - primary muscle trọng số 1, secondary muscle trọng số 0.5 (tùy chọn bật).
/// - chỉ completed set mới tính.
/// - không có dữ liệu cho 1 nhóm cơ → level neutral, không suy diễn.
///
/// Mức độ (Cao/Thấp/Trung bình) so sánh khối lượng của MỘT nhóm cơ trong kỳ
/// hiện tại với chính "mức bình thường" của nhóm cơ đó — trung bình
/// [baselinePeriods] kỳ liền trước, cùng độ dài với kỳ đang xem. Trước đây
/// bản đầu so các nhóm cơ với NHAU trong cùng 1 kỳ, nên hôm nào chỉ tập 2
/// nhóm thì nhóm nào nhỉnh hơn một chút cũng bị gắn "Cao" dù cả hai đều bình
/// thường — không phản ánh đúng "mất cân bằng". So với baseline của chính
/// nhóm cơ đó tránh được lỗi này.
MuscleBalanceResult computeMuscleBalance({
  required List<ExerciseSetLog> logs,
  required Map<String, Exercise> exercisesById,
  required DateTime windowStart,
  DateTime? now,
  bool includeSecondary = true,
  int baselinePeriods = 3,
}) {
  final windowEnd = now ?? DateTime.now();
  final windowLength = windowEnd.difference(windowStart);
  final baselineStart = windowStart.subtract(windowLength * baselinePeriods);

  final current = _accumulate(
    logs: logs,
    exercisesById: exercisesById,
    start: windowStart,
    end: windowEnd,
    includeSecondary: includeSecondary,
  );
  final baseline = _accumulate(
    logs: logs,
    exercisesById: exercisesById,
    start: baselineStart,
    end: windowStart,
    includeSecondary: includeSecondary,
  );

  final byMuscle = <Muscle, MuscleVolumeSummary>{};
  for (final muscle in Muscle.values) {
    final cur = current[muscle];
    final volume = cur?.volume ?? 0;
    final lastTrained = cur?.lastTrained;
    final baselinePerWindow = (baseline[muscle]?.volume ?? 0) / baselinePeriods;

    final level = lastTrained == null
        ? MuscleVolumeLevel.neutral
        : baselinePerWindow <= 0
        ? MuscleVolumeLevel.medium
        : volume >= baselinePerWindow * 1.3
        ? MuscleVolumeLevel.high
        : volume <= baselinePerWindow * 0.7
        ? MuscleVolumeLevel.low
        : MuscleVolumeLevel.medium;

    byMuscle[muscle] = MuscleVolumeSummary(
      muscle: muscle,
      weightedVolumeKg: volume,
      baselineVolumeKg: baselinePerWindow,
      lastTrained: lastTrained,
      level: level,
      sessions: cur?.sessionPoints() ?? const [],
    );
  }

  // Pick the muscle furthest above its own normal, not just the muscle with
  // the largest absolute volume (which would just always be Ngực/Đùi).
  Muscle? overtrained;
  final highs = byMuscle.values.where((s) => s.level == MuscleVolumeLevel.high).toList()
    ..sort((a, b) => b.changeFromBaseline.compareTo(a.changeFromBaseline));
  if (highs.isNotEmpty) overtrained = highs.first.muscle;

  return MuscleBalanceResult(byMuscle: byMuscle, overtrained: overtrained);
}

class _MuscleAccumulation {
  double volume = 0;
  DateTime? lastTrained;
  final Map<String, double> _sessionVolume = {};
  final Map<String, DateTime> _sessionDate = {};

  void add(String completionId, DateTime date, double amount) {
    volume += amount;
    _sessionVolume.update(completionId, (v) => v + amount, ifAbsent: () => amount);
    _sessionDate[completionId] = date;
    if (lastTrained == null || date.isAfter(lastTrained!)) lastTrained = date;
  }

  List<MuscleSessionPoint> sessionPoints() {
    final entries = _sessionVolume.entries.toList()
      ..sort((a, b) => _sessionDate[a.key]!.compareTo(_sessionDate[b.key]!));
    return [
      for (final e in entries)
        MuscleSessionPoint(date: _sessionDate[e.key]!, volumeKg: e.value),
    ];
  }
}

/// Weighted volume per muscle for completed sets with `start <= date < end`.
Map<Muscle, _MuscleAccumulation> _accumulate({
  required List<ExerciseSetLog> logs,
  required Map<String, Exercise> exercisesById,
  required DateTime start,
  required DateTime end,
  required bool includeSecondary,
}) {
  final byCompletion = <String, List<ExerciseSetLog>>{};
  for (final log in logs) {
    if (!log.completed) continue;
    if (log.date.isBefore(start) || !log.date.isBefore(end)) continue;
    byCompletion.putIfAbsent(log.completionId, () => []).add(log);
  }

  final result = <Muscle, _MuscleAccumulation>{};
  void add(Muscle muscle, String completionId, DateTime date, double amount) {
    result.putIfAbsent(muscle, () => _MuscleAccumulation()).add(completionId, date, amount);
  }

  for (final entry in byCompletion.entries) {
    final date = entry.value.first.date;
    for (final log in entry.value) {
      final exercise = exercisesById[log.exerciseId];
      if (exercise == null) continue;
      add(exercise.primaryMuscle, entry.key, date, log.volumeKg);
      if (includeSecondary) {
        for (final secondary in exercise.secondaryMuscles) {
          add(secondary, entry.key, date, log.volumeKg * 0.5);
        }
      }
    }
  }
  return result;
}
