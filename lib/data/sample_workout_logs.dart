import '../models/exercise_set_log.dart';

/// Demo fixture standing in for TV3's real WorkoutCompletion feed (see
/// lib/models/exercise_set_log.dart doc comment). Dates are relative to
/// "now" so Muscle Balance's 7-day / 30-day windows always have something to
/// show regardless of when this is run.
List<ExerciseSetLog> buildSampleWorkoutLogs() {
  final now = DateTime.now();
  DateTime daysAgo(int days) => DateTime(now.year, now.month, now.day - days);

  // Exercise ids below are the real ids from tools/exercise_seed/exercises_seed.json
  // (e.g. "day-nguc-ta-don-tren-ghe-phang" = Đẩy ngực tạ đòn trên ghế phẳng),
  // so this fixture lines up with the full 151-exercise catalog in
  // sample_exercises.dart instead of a separate made-up id namespace.
  final sessions = <int, Map<String, List<(double, int)>>>{
    0: {
      'day-nguc-ta-don-tren-ghe-phang': [(80, 8), (85, 6), (85, 5)],
      'day-ta-sau-dau-ta-don-hai-tay': [(14, 10), (14, 10)],
    },
    1: {
      'squat-ta-don-sau-gay': [(60, 8), (65, 6), (65, 6)],
      'romanian-deadlift-ta-don': [(40, 10), (40, 10)],
      'nhon-got-dung-ta-don': [(20, 15), (20, 15)],
    },
    2: {
      'keo-xa-don-nam-rong': [(0, 8), (0, 7), (0, 6)],
      'nang-ta-don-gap-nguoi-sau-vai': [(8, 12), (8, 12)],
    },
    3: {
      'day-nguc-ta-don-tren-ghe-phang-2': [(24, 10), (26, 8), (26, 8)],
      'day-vai-ta-don-dung': [(30, 8), (32, 6)],
      'day-ta-sau-dau-ta-don-mot-tay': [(12, 10)],
    },
    4: {
      'gap-bung-crunch': [(0, 20), (0, 20)],
      'gap-bung-cheo-bicycle-crunch': [(0, 15), (0, 15)],
    },
    5: {
      'squat-ta-don-truoc': [(50, 8), (55, 6)],
      'nang-hong-ta-don-hip-thrust': [(70, 8), (75, 6)],
    },
    8: {
      'day-nguc-ta-don-tren-ghe-phang': [(75, 8), (80, 6), (80, 6)],
    },
    12: {
      'day-nguc-ta-don-tren-ghe-phang': [(70, 10), (75, 8)],
    },
    15: {
      'keo-xa-don-nam-nguoc': [(0, 7), (0, 6)],
      'nang-ta-don-sang-ngang': [(6, 12), (6, 12)],
    },
  };

  final logs = <ExerciseSetLog>[];
  sessions.forEach((offset, exercises) {
    final date = daysAgo(offset);
    final completionId = 'demo_completion_$offset';
    exercises.forEach((exerciseId, sets) {
      for (final (weight, reps) in sets) {
        logs.add(
          ExerciseSetLog(
            completionId: completionId,
            exerciseId: exerciseId,
            date: date,
            weightKg: weight,
            reps: reps,
            completed: true,
          ),
        );
      }
    });
  });

  // One incomplete set that must NOT count toward PR/volume/frequency.
  logs.add(
    ExerciseSetLog(
      completionId: 'demo_completion_0',
      exerciseId: 'day-nguc-ta-don-tren-ghe-phang',
      date: daysAgo(0),
      weightKg: 100,
      reps: 1,
      completed: false,
    ),
  );

  return logs;
}
