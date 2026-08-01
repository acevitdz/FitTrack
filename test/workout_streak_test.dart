import 'package:fittrack/models/active_workout.dart';
import 'package:fittrack/models/program.dart';
import 'package:fittrack/services/active_workout_controller.dart';
import 'package:fittrack/services/notification_service.dart';
import 'package:fittrack/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AppState> createCleanAccount() async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState(
      firebaseAvailable: false,
      notificationService: NotificationService(),
    );
    await state.initialize();
    final registered = await state.register(
      'Người kiểm thử',
      'workout-streak@fittrack.vn',
      'FitTrack123!',
    );
    expect(registered, isTrue);
    return state;
  }

  Future<void> finishWorkoutAt(
    AppState state,
    DateTime completedAt, {
    required String id,
  }) async {
    const versionId = 'test-version';
    final occurrenceId = 'occurrence-$id';
    state.occurrences.add(
      WorkoutOccurrence(
        id: occurrenceId,
        enrollmentId: 'test-enrollment',
        programVersionId: versionId,
        sessionId: 'test-session',
        weekNumber: 1,
        scheduledDate: completedAt,
        status: WorkoutOccurrenceStatus.inProgress,
        startedAt: completedAt.subtract(const Duration(minutes: 30)),
      ),
    );

    final controller = ActiveWorkoutController.create(
      sessionId: 'active-$id',
      userId: state.uid,
      occurrenceId: occurrenceId,
      programVersionId: versionId,
      snapshot: WorkoutSessionSnapshot(
        programSessionId: 'test-session',
        title: 'Buổi tập kiểm thử',
        exercises: [
          WorkoutExerciseSnapshot(
            exerciseId: 'squat',
            name: 'Squat',
            setCount: 1,
            target: const WorkoutTargetContext(
              type: 'repetitions',
              label: '10 lần',
              minimum: 10,
              maximum: 10,
            ),
            restSeconds: 0,
          ),
        ],
      ),
      clock: () => completedAt,
    );
    controller.start();
    controller.completeSet();
    await state.finishWorkout(controller);
  }

  test('multiple completed workouts on the same day count once', () async {
    final state = await createCleanAccount();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 12);

    await finishWorkoutAt(state, today, id: 'morning');
    await finishWorkoutAt(
      state,
      today.add(const Duration(hours: 4)),
      id: 'afternoon',
    );

    expect(state.workoutCompletions, hasLength(2));
    expect(state.workoutDays, hasLength(1));
    expect(state.currentWorkoutStreak, 1);
    expect(state.longestWorkoutStreak, 1);
  });

  test('consecutive completed workout days build a streak', () async {
    final state = await createCleanAccount();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 12);

    await finishWorkoutAt(
      state,
      today.subtract(const Duration(days: 2)),
      id: 'day-1',
    );
    await finishWorkoutAt(
      state,
      today.subtract(const Duration(days: 1)),
      id: 'day-2',
    );
    await finishWorkoutAt(state, today, id: 'day-3');

    expect(state.currentWorkoutStreak, 3);
    expect(state.longestWorkoutStreak, 3);
  });

  test('a missed workout day starts a new current streak', () async {
    final state = await createCleanAccount();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 12);

    await finishWorkoutAt(
      state,
      today.subtract(const Duration(days: 3)),
      id: 'old',
    );
    await finishWorkoutAt(state, today, id: 'today');

    expect(state.currentWorkoutStreak, 1);
    expect(state.longestWorkoutStreak, 1);
  });

  test('workout streak survives local sign-out and sign-in', () async {
    final state = await createCleanAccount();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 12);

    await finishWorkoutAt(
      state,
      today.subtract(const Duration(days: 1)),
      id: 'yesterday',
    );
    await finishWorkoutAt(state, today, id: 'today');
    await state.signOut();

    final signedIn = await state.signIn(
      'workout-streak@fittrack.vn',
      'FitTrack123!',
    );

    expect(signedIn, isTrue);
    expect(state.currentWorkoutStreak, 2);
    expect(state.longestWorkoutStreak, 2);
    expect(state.workoutDays, hasLength(2));
  });
}
