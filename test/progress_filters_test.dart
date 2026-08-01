import 'package:fittrack/models/active_workout.dart';
import 'package:fittrack/screens/history/progress_screen.dart';
import 'package:fittrack/services/notification_service.dart';
import 'package:fittrack/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AppState> createState() async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState(
      firebaseAvailable: false,
      notificationService: NotificationService(),
    );
    await state.initialize();
    return state;
  }

  Future<void> pumpProgress(WidgetTester tester, AppState state) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ProgressScreen(state: state)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('filters 7 days, 30 days, all and ignores duplicate records', (
    tester,
  ) async {
    final state = await createState();
    final today = DateTime.now();

    state.workoutCompletions.addAll([
      completion(
        id: 'current',
        key: 'current-key',
        completedAt: today,
        durationSeconds: 3600,
        completedSets: 2,
      ),
      completion(
        id: 'duplicate-current',
        key: 'current-key',
        completedAt: today.subtract(const Duration(minutes: 1)),
        durationSeconds: 3600,
        completedSets: 2,
      ),
      completion(
        id: 'day-seven-boundary',
        key: 'day-seven-key',
        completedAt: today.subtract(const Duration(days: 7)),
        durationSeconds: 1800,
        completedSets: 1,
      ),
      completion(
        id: 'older-than-thirty',
        key: 'old-key',
        completedAt: today.subtract(const Duration(days: 40)),
        durationSeconds: 1200,
        completedSets: 1,
      ),
    ]);

    await pumpProgress(tester, state);

    expect(find.text('1g 0p'), findsOneWidget);

    await tester.tap(find.text('30 ngày'));
    await tester.pumpAndSettle();
    expect(find.text('1g 30p'), findsOneWidget);

    await tester.tap(find.text('Tất cả'));
    await tester.pumpAndSettle();
    expect(find.text('1g 50p'), findsOneWidget);
  });

  testWidgets('shows an empty message for the selected period only', (
    tester,
  ) async {
    final state = await createState();
    state.workoutCompletions.add(
      completion(
        id: 'old-completion',
        key: 'old-completion-key',
        completedAt: DateTime.now().subtract(const Duration(days: 40)),
        durationSeconds: 1200,
        completedSets: 1,
      ),
    );

    await pumpProgress(tester, state);

    expect(find.text('Không có dữ liệu trong khoảng này'), findsOneWidget);
    expect(find.text('Buổi tập old-completion'), findsNothing);

    await tester.tap(find.text('Tất cả'));
    await tester.pumpAndSettle();
    expect(find.text('Không có dữ liệu trong khoảng này'), findsNothing);
    expect(find.text('Buổi tập old-completion'), findsOneWidget);
    expect(find.text('20 phút'), findsNWidgets(2));
  });

  testWidgets('shows the initial empty report message', (tester) async {
    final state = await createState();

    await pumpProgress(tester, state);

    expect(find.text('Chưa có dữ liệu tiến độ'), findsOneWidget);
  });
}

WorkoutCompletion completion({
  required String id,
  required String key,
  required DateTime completedAt,
  required int durationSeconds,
  required int completedSets,
}) {
  const target = WorkoutTargetContext(type: 'repetitions', label: '10 lần');
  return WorkoutCompletion(
    id: id,
    idempotencyKey: key,
    userId: 'progress-test-user',
    occurrenceId: 'occurrence-$id',
    programVersionId: 'program-version',
    snapshot: WorkoutSessionSnapshot(
      programSessionId: 'session-$id',
      title: 'Buổi tập $id',
      exercises: [
        WorkoutExerciseSnapshot(
          exerciseId: 'squat',
          name: 'Squat',
          setCount: completedSets,
          target: target,
          restSeconds: 0,
          muscleGroup: 'Chân',
        ),
      ],
    ),
    actualStartedAt: completedAt.subtract(Duration(seconds: durationSeconds)),
    actualDurationSeconds: durationSeconds,
    setEvents: List.generate(
      completedSets,
      (index) => SetEvent(
        id: '$id-set-$index',
        exerciseId: 'squat',
        exerciseIndex: 0,
        setIndex: index,
        targetContext: target,
        confirmationMode: WorkoutConfirmationMode.guided,
        status: SetEventStatus.completed,
        completedAt: completedAt,
      ),
    ),
    status: WorkoutCompletionStatus.completed,
    completedAt: completedAt,
  );
}
