import 'package:fittrack/models/active_workout.dart';
import 'package:fittrack/models/exercise.dart';
import 'package:fittrack/screens/active/active_workout_screen.dart';
import 'package:fittrack/services/active_workout_controller.dart';
import 'package:fittrack/services/notification_service.dart';
import 'package:fittrack/state/app_state.dart';
import 'package:fittrack/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeNotifications extends NotificationService {
  @override
  Future<void> initialize() async {}
}

class _RecordingAppState extends AppState {
  _RecordingAppState()
    : super(
        firebaseAvailable: false,
        notificationService: _FakeNotifications(),
      );

  final List<String> spokenCues = [];

  @override
  Future<void> checkpointWorkout(ActiveWorkoutController controller) async {}

  @override
  Future<void> speakCue(String cue) async {
    spokenCues.add(cue);
  }

  @override
  Future<void> stopVoiceCoach() async {}
}

void main() {
  testWidgets(
    'active workout shows exercise instructions and common mistakes',
    (tester) async {
      final state = AppState(
        firebaseAvailable: false,
        notificationService: _FakeNotifications(),
      );
      final controller = ActiveWorkoutController.create(
        sessionId: 'active-screen-test',
        userId: 'user-1',
        occurrenceId: 'occurrence-1',
        programVersionId: 'version-1',
        snapshot: WorkoutSessionSnapshot(
          programSessionId: 'session-1',
          title: 'Workout test',
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
              preparationSeconds: 0,
              workDurationSeconds: 30,
              restSeconds: 0,
              instructions: const [
                'Đứng với hai chân rộng bằng vai.',
                'Hạ hông có kiểm soát rồi đứng lên.',
              ],
              commonMistakes: const [
                'Để đầu gối đổ vào trong.',
                'Nhấc gót chân khỏi sàn.',
              ],
            ),
          ],
        ),
      );
      controller.start();

      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(412, 1100);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: ActiveWorkoutScreen(state: state, controller: controller),
        ),
      );
      await tester.pump();

      expect(controller.phase, WorkoutPhase.working);
      await tester.scrollUntilVisible(
        find.text('Cách thực hiện'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Đứng với hai chân rộng bằng vai.'), findsOneWidget);
      expect(find.text('Lỗi thường gặp'), findsOneWidget);
      expect(find.text('Để đầu gối đổ vào trong.'), findsOneWidget);
      final exception = tester.takeException();
      expect(
        exception,
        isNull,
        reason: exception is FlutterError
            ? exception.toStringDeep()
            : exception?.toString(),
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets('mode selector reports unsupported exercises and stays Guided', (
    tester,
  ) async {
    final state = AppState(
      firebaseAvailable: false,
      notificationService: _FakeNotifications(),
    );
    final controller = ActiveWorkoutController.create(
      sessionId: 'unsupported-camera-screen',
      userId: 'user-1',
      occurrenceId: 'occurrence-unsupported-camera',
      programVersionId: 'version-1',
      snapshot: WorkoutSessionSnapshot(
        programSessionId: 'session-other-squat',
        title: 'Other squat test',
        exercises: [
          WorkoutExerciseSnapshot(
            exerciseId: 'squat-nhay',
            name: 'Squat nhảy',
            setCount: 1,
            target: const WorkoutTargetContext(
              type: 'duration_seconds',
              label: '25 giây',
              minimum: 25,
              maximum: 25,
            ),
            executionMode: ExerciseExecutionMode.timer,
            cueMode: ExerciseCueMode.countdown,
            preparationSeconds: 0,
            workDurationSeconds: 25,
            restSeconds: 0,
          ),
        ],
      ),
    );
    controller.start();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: ActiveWorkoutScreen(state: state, controller: controller),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('workout-confirmation-mode-selector')),
      findsOneWidget,
    );
    await tester.tap(find.text('Camera AI'));
    await tester.pump();

    expect(controller.confirmationMode, WorkoutConfirmationMode.guided);
    expect(
      find.textContaining('Camera AI chỉ hỗ trợ bài Squat không tạ'),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('Guided button switches an AI squat back to Guided', (
    tester,
  ) async {
    final state = AppState(
      firebaseAvailable: false,
      notificationService: _FakeNotifications(),
    );
    final controller = ActiveWorkoutController.create(
      sessionId: 'guided-switch-screen',
      userId: state.uid,
      occurrenceId: 'occurrence-guided-switch',
      programVersionId: 'version-1',
      confirmationMode: WorkoutConfirmationMode.aiCamera,
      snapshot: WorkoutSessionSnapshot(
        programSessionId: 'session-squat',
        title: 'Squat test',
        exercises: [
          WorkoutExerciseSnapshot(
            exerciseId: 'squat',
            name: 'Squat không tạ',
            setCount: 1,
            target: const WorkoutTargetContext(
              type: 'duration_seconds',
              label: '30 giây',
              minimum: 30,
              maximum: 30,
            ),
            executionMode: ExerciseExecutionMode.timer,
            cueMode: ExerciseCueMode.countdown,
            poseRuleVersionId: 'squat_pose_v1',
            cameraTargetReps: 10,
            workDurationSeconds: 30,
            restSeconds: 0,
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: ActiveWorkoutScreen(state: state, controller: controller),
      ),
    );
    await tester.pump();
    expect(controller.confirmationMode, WorkoutConfirmationMode.aiCamera);

    await tester.tap(find.text('Hướng dẫn'));
    await tester.pump();

    expect(controller.confirmationMode, WorkoutConfirmationMode.guided);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('preparation shows exercise media and announces working start', (
    tester,
  ) async {
    final state = _RecordingAppState();
    state.countdownSoundsEnabled = false;
    final controller = ActiveWorkoutController.create(
      sessionId: 'preparation-media-screen',
      userId: state.uid,
      occurrenceId: 'occurrence-preparation-media',
      programVersionId: 'version-1',
      snapshot: WorkoutSessionSnapshot(
        programSessionId: 'session-preparation-media',
        title: 'Preparation media test',
        exercises: [
          WorkoutExerciseSnapshot(
            exerciseId: 'squat',
            name: 'Squat không tạ',
            setCount: 1,
            target: const WorkoutTargetContext(
              type: 'duration_seconds',
              label: '30 giây',
              minimum: 30,
              maximum: 30,
            ),
            executionMode: ExerciseExecutionMode.timer,
            cueMode: ExerciseCueMode.countdown,
            preparationSeconds: 5,
            workDurationSeconds: 30,
            restSeconds: 0,
          ),
        ],
      ),
    );
    controller.start();

    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(412, 1100);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: ActiveWorkoutScreen(state: state, controller: controller),
      ),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(controller.phase, WorkoutPhase.countingDown);
    expect(
      find.byKey(const ValueKey('preparation-exercise-media')),
      findsOneWidget,
    );
    expect(find.text('GIF / Video hướng dẫn: Squat không tạ'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Bắt đầu ngay'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Bắt đầu ngay'));
    await tester.pumpAndSettle();

    expect(controller.phase, WorkoutPhase.working);
    expect(state.spokenCues, contains('Bắt đầu.'));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets(
    'collects perceived outcome and optional load after an exercise',
    (tester) async {
      final state = _RecordingAppState();
      state.countdownSoundsEnabled = false;
      final controller = ActiveWorkoutController.create(
        sessionId: 'progress-feedback-screen',
        userId: state.uid,
        occurrenceId: 'occurrence-progress-feedback',
        programVersionId: 'version-1',
        snapshot: WorkoutSessionSnapshot(
          programSessionId: 'session-progress-feedback',
          title: 'Progress feedback test',
          exercises: [
            WorkoutExerciseSnapshot(
              exerciseId: 'squat',
              name: 'Squat không tạ',
              setCount: 1,
              target: const WorkoutTargetContext(
                type: 'repetitions',
                label: '8 lần',
                minimum: 8,
                maximum: 8,
              ),
              preparationSeconds: 0,
              restSeconds: 0,
              transitionAfterExerciseSeconds: 0,
            ),
            WorkoutExerciseSnapshot(
              exerciseId: 'plank',
              name: 'Plank',
              setCount: 1,
              target: const WorkoutTargetContext(
                type: 'repetitions',
                label: '8 lần',
                minimum: 8,
                maximum: 8,
              ),
              preparationSeconds: 0,
              restSeconds: 0,
            ),
          ],
        ),
      );
      controller.start();
      controller.completeSet();
      expect(controller.pendingFeedbackExerciseIndices, [0]);

      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(412, 1100);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: ActiveWorkoutScreen(state: state, controller: controller),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Bài vừa rồi thế nào?'), findsOneWidget);
      expect(find.text('Squat không tạ'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Mức tạ đã dùng (kg, nếu có)'),
        '12,5',
      );
      await tester.tap(find.text('Đạt vừa sức'));
      await tester.pumpAndSettle();

      expect(controller.exerciseProgressEvidence, hasLength(1));
      expect(
        controller.exerciseProgressEvidence.single.outcome,
        ExerciseProgressOutcome.appropriate,
      );
      expect(controller.exerciseProgressEvidence.single.actualLoadKg, 12.5);
      expect(controller.pendingFeedbackExerciseIndices, isEmpty);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
}
