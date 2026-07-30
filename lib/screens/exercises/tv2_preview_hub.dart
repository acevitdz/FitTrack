import 'package:flutter/material.dart';

import '../../data/in_memory_exercise_repository.dart';
import '../../data/in_memory_favorite_exercise_repository.dart';
import '../../data/in_memory_personal_exercise_repository.dart';
import '../../data/sample_exercises.dart';
import '../../data/sample_workout_logs.dart';
import '../../widgets/design_system.dart';
import 'exercise_library_screen.dart';
import 'exercise_progress_screen.dart';
import 'muscle_balance_screen.dart';
import 'personal_exercise_library_screen.dart';

/// TEMPORARY, for manual review only — not part of the final app navigation.
/// Lets TV2's 8 screens be opened and clicked through without the shared
/// AppState/MainShell (which don't build yet, see docs/TV2_TASKS.md
/// integration notes). Team lead: delete this file once the real screens are
/// wired into MainShell's navigation.
class Tv2PreviewHub extends StatelessWidget {
  const Tv2PreviewHub({super.key});

  static const _uid = 'demo-user';

  @override
  Widget build(BuildContext context) {
    final exerciseRepository = InMemoryExerciseRepository();
    final personalExerciseRepository = InMemoryPersonalExerciseRepository();
    final favoriteRepository = InMemoryFavoriteExerciseRepository();
    final logs = buildSampleWorkoutLogs();

    return FitTrackPage(
      scrollable: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('TV2 — Xem trước màn hình', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          const Text('Tạm thời, chỉ để rà soát trước khi ghép vào MainShell.'),
          const SizedBox(height: 20),
          Expanded(
            child: ListView(
              children: [
                _entry(
                  context,
                  'Thư viện bài tập mẫu',
                  () => ExerciseLibraryScreen(
                    exerciseRepository: exerciseRepository,
                    favoriteRepository: favoriteRepository,
                    uid: _uid,
                  ),
                ),
                _entry(
                  context,
                  'Kho bài tập cá nhân',
                  () => PersonalExerciseLibraryScreen(
                    personalExerciseRepository: personalExerciseRepository,
                    exerciseRepository: exerciseRepository,
                    favoriteRepository: favoriteRepository,
                    uid: _uid,
                  ),
                ),
                _entry(
                  context,
                  'Phân tích bài tập (PR)',
                  () => ExerciseProgressScreen(
                    exercise: sampleExercises.firstWhere(
                      (e) => e.id == 'day-nguc-ta-don-tren-ghe-phang',
                    ),
                    logs: logs,
                  ),
                ),
                _entry(
                  context,
                  'Bản đồ cân bằng cơ',
                  () => MuscleBalanceScreen(
                    exercises: sampleExercises,
                    logs: logs,
                    favoriteRepository: favoriteRepository,
                    uid: _uid,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _entry(BuildContext context, String label, Widget Function() builder) {
    return Card(
      child: ListTile(
        title: Text(label),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => builder()),
        ),
      ),
    );
  }
}
