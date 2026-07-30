/// Placeholder shape for a single completed set, standing in for TV3's real
/// `WorkoutCompletion` (docs/TV2_TASKS.md §7: "Nhận từ TV3 — WorkoutCompletion
/// (completed sets) — Dùng cho Tính PR, Muscle Balance"). Not confirmed as of
/// writing — once TV3's real type lands, map it to this shape (or replace
/// this shape outright) rather than rewriting pr_calculator/muscle_balance_
/// calculator, which only depend on this minimal interface.
class ExerciseSetLog {
  const ExerciseSetLog({
    required this.completionId,
    required this.exerciseId,
    required this.date,
    required this.weightKg,
    required this.reps,
    required this.completed,
  });

  /// Groups sets from the same workout session — §5: "một bài có nhiều set
  /// trong cùng 1 completion chỉ tăng tần suất buổi tập 1 lần".
  final String completionId;
  final String exerciseId;
  final DateTime date;
  final double weightKg;
  final int reps;
  final bool completed;

  double get volumeKg => weightKg * reps;
}
