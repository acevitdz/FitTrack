import '../models/exercise_set_log.dart';

/// docs/TV2_TASKS.md §4.5: PR gồm 3 loại độc lập — tạ nặng nhất (1 set),
/// số reps nhiều nhất (1 set), và volume cao nhất (1 buổi tập).
enum PrType { weight, reps, volume }

class SessionSummary {
  const SessionSummary({
    required this.date,
    required this.maxWeightKg,
    required this.maxSetReps,
    required this.totalReps,
    required this.setCount,
    required this.volumeKg,
    required this.achievedPrTypes,
  });

  final DateTime date;
  final double maxWeightKg;
  final int maxSetReps;
  final int totalReps;
  final int setCount;
  final double volumeKg;

  /// Which PR record(s), if any, were first set in this session. A session
  /// can achieve more than one at once (e.g. a heaviest-ever set that's also
  /// the highest-volume session).
  final Set<PrType> achievedPrTypes;

  bool get isPr => achievedPrTypes.isNotEmpty;
}

class ExerciseProgressStats {
  const ExerciseProgressStats({
    required this.prWeightKg,
    required this.prWeightDate,
    required this.prReps,
    required this.prRepsDate,
    required this.prVolumeKg,
    required this.prVolumeDate,
    required this.totalSessions,
    required this.averageVolumeKg,
    required this.recentSessions,
  });

  final double prWeightKg;
  final DateTime? prWeightDate;
  final int prReps;
  final DateTime? prRepsDate;
  final double prVolumeKg;
  final DateTime? prVolumeDate;

  /// Số buổi tập và volume trung bình chỉ tính trong khung thời gian đang
  /// xem (7 ngày/30 ngày/3 tháng) — khác với 3 PR ở trên, luôn tính trên
  /// toàn bộ lịch sử vì "kỷ lục cá nhân" không thể phụ thuộc bộ lọc thời gian.
  final int totalSessions;
  final double averageVolumeKg;
  final List<SessionSummary> recentSessions;

  static const empty = ExerciseProgressStats(
    prWeightKg: 0,
    prWeightDate: null,
    prReps: 0,
    prRepsDate: null,
    prVolumeKg: 0,
    prVolumeDate: null,
    totalSessions: 0,
    averageVolumeKg: 0,
    recentSessions: [],
  );
}

class _SessionAccum {
  _SessionAccum(this.completionId, this.date);

  final String completionId;
  final DateTime date;
  double maxWeightKg = 0;
  int maxSetReps = 0;
  int totalReps = 0;
  int setCount = 0;
  double volumeKg = 0;
}

List<_SessionAccum> _buildSessions(String exerciseId, List<ExerciseSetLog> logs) {
  final byCompletion = <String, _SessionAccum>{};
  for (final log in logs) {
    if (log.exerciseId != exerciseId || !log.completed) continue;
    final session = byCompletion.putIfAbsent(
      log.completionId,
      () => _SessionAccum(log.completionId, log.date),
    );
    session.maxWeightKg = session.maxWeightKg > log.weightKg
        ? session.maxWeightKg
        : log.weightKg;
    session.maxSetReps = session.maxSetReps > log.reps ? session.maxSetReps : log.reps;
    session.totalReps += log.reps;
    session.setCount += 1;
    session.volumeKg += log.volumeKg;
  }
  return byCompletion.values.toList();
}

/// §5 business rules: only `completed == true` sets count; multiple sets in
/// the same completion increase session frequency by 1, not by set count.
///
/// [allLogs] is the exercise's full history — the 3 PR values are always
/// computed from this, never from [windowedLogs], because a "kỷ lục cá
/// nhân" can't logically change depending on which time filter is selected.
/// [windowedLogs] (a subset of allLogs restricted to the selected 7-day/
/// 30-day/3-month range) drives totalSessions/averageVolumeKg/recentSessions.
ExerciseProgressStats computeExerciseProgress({
  required String exerciseId,
  required List<ExerciseSetLog> allLogs,
  required List<ExerciseSetLog> windowedLogs,
}) {
  final fullSessions = _buildSessions(exerciseId, allLogs)
    ..sort((a, b) => a.date.compareTo(b.date));
  if (fullSessions.isEmpty) return ExerciseProgressStats.empty;

  // Scan chronologically so a tie keeps the date the record was FIRST set,
  // not the most recent repeat of the same number.
  var prWeight = 0.0;
  String? prWeightCompletionId;
  var prReps = 0;
  String? prRepsCompletionId;
  var prVolume = 0.0;
  String? prVolumeCompletionId;

  for (final s in fullSessions) {
    if (s.maxWeightKg > prWeight) {
      prWeight = s.maxWeightKg;
      prWeightCompletionId = s.completionId;
    }
    if (s.maxSetReps > prReps) {
      prReps = s.maxSetReps;
      prRepsCompletionId = s.completionId;
    }
    if (s.volumeKg > prVolume) {
      prVolume = s.volumeKg;
      prVolumeCompletionId = s.completionId;
    }
  }

  DateTime? dateOf(String? completionId) => completionId == null
      ? null
      : fullSessions.firstWhere((s) => s.completionId == completionId).date;

  final windowedSessions = _buildSessions(exerciseId, windowedLogs)
    ..sort((a, b) => b.date.compareTo(a.date));

  final averageVolume = windowedSessions.isEmpty
      ? 0.0
      : windowedSessions.fold(0.0, (sum, s) => sum + s.volumeKg) /
            windowedSessions.length;

  return ExerciseProgressStats(
    prWeightKg: prWeight,
    prWeightDate: dateOf(prWeightCompletionId),
    prReps: prReps,
    prRepsDate: dateOf(prRepsCompletionId),
    prVolumeKg: prVolume,
    prVolumeDate: dateOf(prVolumeCompletionId),
    totalSessions: windowedSessions.length,
    averageVolumeKg: averageVolume,
    recentSessions: [
      for (final s in windowedSessions)
        SessionSummary(
          date: s.date,
          maxWeightKg: s.maxWeightKg,
          maxSetReps: s.maxSetReps,
          totalReps: s.totalReps,
          setCount: s.setCount,
          volumeKg: s.volumeKg,
          achievedPrTypes: {
            if (s.completionId == prWeightCompletionId) PrType.weight,
            if (s.completionId == prRepsCompletionId) PrType.reps,
            if (s.completionId == prVolumeCompletionId) PrType.volume,
          },
        ),
    ],
  );
}
