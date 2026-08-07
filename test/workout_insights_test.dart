import 'package:flutter_test/flutter_test.dart';

import 'package:fittrack/models/active_workout.dart';
import 'package:fittrack/services/workout_insights.dart';

void main() {
  final now = DateTime(2026, 7, 31, 12);

  test('muscle balance counts completed sets and weights secondary muscles', () {
    final completions = [
      _completion(
        id: 'baseline',
        date: DateTime(2026, 7, 10, 12),
        setStatuses: [
          SetEventStatus.completed,
          SetEventStatus.completed,
          SetEventStatus.completed,
        ],
      ),
      _completion(
        id: 'current',
        date: DateTime(2026, 7, 30, 12),
        setStatuses: [
          SetEventStatus.completed,
          SetEventStatus.completed,
          SetEventStatus.redone,
        ],
      ),
    ];

    final result = computeMuscleBalance(
      completions: completions,
      windowStart: now.subtract(const Duration(days: 7)),
      now: now,
    );

    final chest = result.byRegion[MuscleRegion.chest]!;
    final triceps = result.byRegion[MuscleRegion.triceps]!;
    expect(chest.weightedSets, 2);
    expect(chest.sessions, hasLength(1));
    expect(chest.level, MuscleActivityLevel.high);
    expect(triceps.weightedSets, 1);
    expect(result.highestRegion, MuscleRegion.chest);
  });

  test('muscle balance can exclude secondary muscles', () {
    final result = computeMuscleBalance(
      completions: [
        _completion(
          id: 'current',
          date: DateTime(2026, 7, 30, 12),
          setStatuses: [SetEventStatus.completed],
        ),
      ],
      windowStart: now.subtract(const Duration(days: 7)),
      now: now,
      includeSecondary: false,
    );

    expect(result.byRegion[MuscleRegion.chest]!.weightedSets, 1);
    expect(result.byRegion[MuscleRegion.triceps]!.weightedSets, 0);
  });

  test('exercise progress counts sessions once and ignores skipped sets', () {
    final stats = computeExerciseProgress(
      exerciseId: 'push',
      completions: [
        _completion(
          id: 'recent-1',
          date: DateTime(2026, 7, 30, 12),
          setStatuses: [
            SetEventStatus.completed,
            SetEventStatus.completed,
            SetEventStatus.skipped,
          ],
        ),
        _completion(
          id: 'recent-2',
          date: DateTime(2026, 7, 25, 12),
          setStatuses: [SetEventStatus.completed],
        ),
        _completion(
          id: 'old',
          date: DateTime(2026, 7, 1, 12),
          setStatuses: [
            SetEventStatus.completed,
            SetEventStatus.completed,
            SetEventStatus.completed,
          ],
        ),
      ],
      windowStart: now.subtract(const Duration(days: 7)),
      now: now,
    );

    expect(stats.totalSessions, 2);
    expect(stats.totalCompletedSets, 3);
    expect(stats.sessionsPerWeek, 2);
    expect(stats.recentSessions.first.completedSets, 2);
  });
}

WorkoutCompletion _completion({
  required String id,
  required DateTime date,
  required List<SetEventStatus> setStatuses,
}) {
  final target = const WorkoutTargetContext(
    type: 'repetitions',
    label: '8–12 lần',
    minimum: 8,
    maximum: 12,
  );
  final snapshot = WorkoutSessionSnapshot(
    programSessionId: 'session-1',
    title: 'Buổi mẫu',
    exercises: [
      WorkoutExerciseSnapshot(
        exerciseId: 'push',
        name: 'Chống đẩy',
        muscleGroup: 'Ngực',
        secondaryMuscles: const ['Tay sau'],
        setCount: setStatuses.length,
        target: target,
        restSeconds: 30,
      ),
    ],
  );
  return WorkoutCompletion(
    id: id,
    idempotencyKey: 'key-$id',
    userId: 'demo-user',
    occurrenceId: 'occ-$id',
    programVersionId: 'program-v1',
    snapshot: snapshot,
    actualStartedAt: date.subtract(const Duration(minutes: 20)),
    actualDurationSeconds: 120,
    setEvents: [
      for (var index = 0; index < setStatuses.length; index++)
        SetEvent(
          id: '$id-set-$index',
          exerciseId: 'push',
          exerciseIndex: 0,
          setIndex: index,
          targetContext: target,
          confirmationMode: WorkoutConfirmationMode.guided,
          status: setStatuses[index],
          completedAt: date,
        ),
    ],
    status: WorkoutCompletionStatus.completed,
    completedAt: date,
  );
}
