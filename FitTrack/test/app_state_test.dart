import 'package:fittrack/data/seed_data.dart';
import 'package:fittrack/models/active_workout.dart';
import 'package:fittrack/models/exercise.dart';
import 'package:fittrack/models/progression.dart';
import 'package:fittrack/models/program.dart';
import 'package:fittrack/services/active_workout_draft_store.dart';
import 'package:fittrack/services/bundled_exercise_catalog.dart';
import 'package:fittrack/services/local_store.dart';
import 'package:fittrack/services/notification_service.dart';
import 'package:fittrack/services/program_matcher.dart';
import 'package:fittrack/services/progression_engine.dart';
import 'package:fittrack/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MemoryStore extends LocalStore {
  Map<String, dynamic>? data;
  bool authenticated = false;
  String? authenticatedUid;

  @override
  Future<Map<String, dynamic>?> loadState() async => data;

  @override
  Future<void> saveState(Map<String, dynamic> value) async => data = value;

  @override
  Future<bool> loadAuthenticated() async => authenticated;

  @override
  Future<void> saveAuthenticated(bool value) async => authenticated = value;

  @override
  Future<String?> loadAuthenticatedUid() async => authenticatedUid;

  @override
  Future<void> saveAuthenticatedUid(String? uid) async {
    authenticatedUid = uid;
  }

  @override
  Future<void> clear() async {
    data = null;
    authenticated = false;
    authenticatedUid = null;
  }
}

class MemoryWorkoutDraftStore extends ActiveWorkoutDraftStore {
  final Map<String, ActiveWorkoutDraft> drafts = {};

  @override
  Future<ActiveWorkoutDraft?> load(String userId) async => drafts[userId];

  @override
  Future<void> save(String userId, ActiveWorkoutDraft draft) async {
    if (draft.userId != userId) throw ArgumentError('UID mismatch');
    drafts[userId] = draft;
  }

  @override
  Future<bool> contains(String userId) async => drafts.containsKey(userId);

  @override
  Future<void> clear(String userId) async => drafts.remove(userId);
}

class FakeNotifications extends NotificationService {
  @override
  Future<void> initialize() async {}
}

late List<Exercise> testExerciseCatalog;

AppState createState({
  MemoryStore? store,
  MemoryWorkoutDraftStore? draftStore,
}) => AppState(
  firebaseAvailable: false,
  notificationService: FakeNotifications(),
  localStore: store ?? MemoryStore(),
  workoutDraftStore: draftStore ?? MemoryWorkoutDraftStore(),
  testExerciseCatalog: testExerciseCatalog,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    testExerciseCatalog = [
      ...SeedData.exercises,
      ...await const BundledExerciseCatalog().load(),
    ];
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'does not expose a local exercise catalog without an explicit fixture',
    () async {
      final state = AppState(
        firebaseAvailable: false,
        notificationService: FakeNotifications(),
        localStore: MemoryStore(),
        workoutDraftStore: MemoryWorkoutDraftStore(),
      );

      await state.initialize();
      final result = await state.ensureProgramEnrollment();

      expect(state.exercises, isEmpty);
      expect(state.templateExercises, isEmpty);
      expect(result.status, ProgramMatchStatus.noSupportedProgram);
      expect(result.reasons, contains('exercise_catalog_unavailable'));
    },
  );

  test(
    'daily streak only increments once per local day and resets after a gap',
    () async {
      final state = createState();
      await state.initialize();
      state.weightEntries.clear();
      state.activeDays.clear();

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));

      await state.updateBodyMetrics(
        heightCm: 170,
        weightKg: 70,
        recordedAt: yesterday.add(const Duration(hours: 8)),
      );
      await state.updateBodyMetrics(
        heightCm: 170,
        weightKg: 70,
        recordedAt: yesterday.add(const Duration(hours: 21)),
      );
      expect(state.currentStreak, 1);

      await state.updateBodyMetrics(
        heightCm: 170,
        weightKg: 70,
        recordedAt: now,
      );
      expect(state.currentStreak, 2);
      expect(state.longestStreak, 2);
    },
  );

  test(
    'program enrollment is version-pinned and creates an automatic schedule',
    () async {
      final state = createState();
      await state.initialize();

      // The target state starts without any user-authored plan or schedule.
      expect(state.plans, isEmpty);
      expect(state.schedules, isEmpty);

      final result = await state.ensureProgramEnrollment();
      final enrollment = state.enrollment!;
      final version = state.activeProgramVersion!;

      expect(
        result.status,
        anyOf(ProgramMatchStatus.matched, ProgramMatchStatus.fallback),
      );
      expect(enrollment.userId, state.uid);
      expect(enrollment.programVersionId, version.id);
      expect(version.status, ProgramLifecycleStatus.published);
      expect(state.occurrences, hasLength(version.allSessions.length));
      expect(
        state.occurrences.every(
          (item) =>
              item.enrollmentId == enrollment.id &&
              item.programVersionId == version.id &&
              state.sessionForOccurrence(item) != null,
        ),
        isTrue,
      );

      final existingId = enrollment.id;
      await state.ensureProgramEnrollment();
      expect(state.enrollment?.id, existingId);
      expect(state.occurrences, hasLength(version.allSessions.length));
    },
  );

  test('body metrics validate height and weight and derive BMI', () async {
    final state = createState();
    await state.initialize();
    final recordedAt = DateTime.now().subtract(const Duration(minutes: 5));

    await state.updateBodyMetrics(
      heightCm: 180,
      weightKg: 81,
      recordedAt: recordedAt,
    );

    expect(state.profile.heightCm, 180);
    expect(state.profile.currentWeightKg, 81);
    expect(state.profile.bmi, closeTo(25, .001));
    expect(state.latestWeight?.heightCm, 180);
    expect(state.latestWeight?.bmi, closeTo(25, .001));
    expect(state.latestWeight?.recordedAt, recordedAt);

    expect(
      () => state.updateBodyMetrics(heightCm: 99, weightKg: 60),
      throwsArgumentError,
    );
    expect(
      () => state.updateBodyMetrics(heightCm: 170, weightKg: 0),
      throwsArgumentError,
    );

    await state.updateBodyMetrics(
      heightCm: 181,
      weightKg: 82,
      recordedAt: recordedAt.add(const Duration(minutes: 2)),
    );
    await state.updateBodyMetrics(
      heightCm: 165,
      weightKg: 60,
      recordedAt: recordedAt.subtract(const Duration(days: 2)),
    );
    expect(state.profile.heightCm, 181);
    expect(state.profile.currentWeightKg, 82);
    expect(state.latestWeight?.weightKg, 82);

    expect(
      () => state.updateBodyMetrics(
        heightCm: 170,
        weightKg: 70,
        recordedAt: DateTime.now().add(const Duration(minutes: 2)),
      ),
      throwsArgumentError,
    );
  });

  test('new onboarding schedule starts with a workout today', () async {
    final state = createState();
    await state.initialize();
    state.enrollment = null;
    state.occurrences.clear();

    await state.updateTrainingPreferences(
      const UserTrainingPreferences(
        populationKey: 'healthy_adult_18_64',
        programAudiencePreference: ProgramAudiencePreference.unisex,
        goalKey: TrainingGoalKey.generalFitness,
        experienceKey: 'beginner',
        equipmentKeys: ['bodyweight'],
        sessionsPerWeek: 3,
        preferredWeekdays: [],
        startPolicy: ProgramStartPolicy.today,
      ),
      rematch: false,
    );
    await state.ensureProgramEnrollment();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    expect(state.occurrences.first.scheduledDate, today);
  });

  test('invalid explicit weekdays are rejected instead of replaced', () async {
    final state = createState();
    await state.initialize();
    final before = state.trainingPreferences;

    expect(
      () => state.updateTrainingPreferences(
        const UserTrainingPreferences(
          populationKey: 'healthy_adult_18_64',
          programAudiencePreference: ProgramAudiencePreference.unisex,
          goalKey: TrainingGoalKey.generalFitness,
          experienceKey: 'beginner',
          equipmentKeys: ['bodyweight'],
          sessionsPerWeek: 3,
          preferredWeekdays: [
            DateTime.monday,
            DateTime.tuesday,
            DateTime.wednesday,
          ],
        ),
      ),
      throwsStateError,
    );
    expect(state.trainingPreferences, same(before));
  });

  test(
    'AppState checkpoints and idempotently finishes target workout',
    () async {
      final drafts = MemoryWorkoutDraftStore();
      final state = createState(draftStore: drafts);
      await state.initialize();
      await state.ensureProgramEnrollment();
      final occurrence = state.occurrences.first;
      await state.chooseReadiness(occurrence, ReadinessChoice.ready);
      final assessedOccurrence = state.occurrenceById(occurrence.id)!;

      final controller = await state.openWorkout(assessedOccurrence);
      expect(controller.phase, WorkoutPhase.preparing);
      expect(state.activeWorkoutDraft?.occurrenceId, occurrence.id);
      expect(await drafts.contains(state.uid), isTrue);
      final catalogExercise = state.exercises.singleWhere(
        (exercise) =>
            exercise.id == controller.currentExercise.exerciseId &&
            !exercise.isPersonal,
      );
      expect(
        controller.currentExercise.instructions,
        catalogExercise.instructions,
      );
      expect(
        controller.currentExercise.commonMistakes,
        catalogExercise.commonMistakes,
      );
      final restoredDraft = ActiveWorkoutDraft.fromJsonString(
        controller.checkpoint().toJsonString(),
      );
      expect(
        restoredDraft.snapshot.exercises.first.instructions,
        catalogExercise.instructions,
      );
      expect(
        restoredDraft.snapshot.exercises.first.commonMistakes,
        catalogExercise.commonMistakes,
      );

      controller.setConfirmationMode(WorkoutConfirmationMode.aiCamera);
      controller.start();
      controller.skipPreparation();
      controller.skipSet(reason: 'test_finish_transaction');
      await state.checkpointWorkout(controller);
      expect(state.activeWorkoutDraft?.setEvents, hasLength(1));

      final completion = await state.finishWorkout(controller);
      expect(completion.occurrenceId, occurrence.id);
      expect(completion.snapshot.programSessionId, occurrence.sessionId);
      expect(state.workoutCompletions, hasLength(1));
      expect(state.activeWorkoutDraft, isNull);
      expect(await drafts.contains(state.uid), isFalse);
      expect(
        state.occurrences
            .singleWhere((item) => item.id == occurrence.id)
            .status,
        WorkoutOccurrenceStatus.abandoned,
      );

      final retry = await state.finishWorkout(controller);
      expect(retry.idempotencyKey, completion.idempotencyKey);
      expect(state.workoutCompletions, hasLength(1));
    },
  );

  test('opening a new week applies its persisted progression decision', () async {
    final state = createState();
    await state.initialize();
    await state.ensureProgramEnrollment();

    final occurrence = state.occurrences.firstWhere(
      (item) => item.weekNumber == 2,
    );
    for (var index = 0; index < state.occurrences.length; index++) {
      final item = state.occurrences[index];
      if (item.weekNumber == 1) {
        state.occurrences[index] = item.copyWith(
          status: WorkoutOccurrenceStatus.skipped,
          completedAt: DateTime.utc(2026, 8, 1),
        );
      }
    }
    final version = state.activeProgramVersion!;
    final session = version.sessionById(occurrence.sessionId)!;
    final prescription = session.blocks
        .expand((block) => block.prescriptions)
        .first;
    final prescriptionBlock = session.blocks.firstWhere(
      (block) => block.prescriptions.contains(prescription),
    );
    final progressionKey =
        'session:${session.order}:block:${prescriptionBlock.order}:'
        'prescription:${prescription.order}:${prescription.exerciseId}';
    final previousTarget = ProgressionTarget(
      sets: prescription.sets,
      targetType: prescription.targetType,
      minimum: prescription.targetRange.minimum,
      maximum: prescription.targetRange.maximum,
    );
    final personalizedTarget = ProgressionTarget(
      sets: prescription.sets + 1,
      targetType: prescription.targetType,
      minimum: prescription.targetRange.minimum + 1,
      maximum: prescription.targetRange.maximum + 1,
    );
    state.progressionDecisions.add(
      ProgressionDecision(
        id: '${state.enrollment!.id}:week:2:$progressionKey:${ProgressionEngine.policyVersion}',
        policyVersion: ProgressionEngine.policyVersion,
        enrollmentId: state.enrollment!.id,
        programVersionId: version.id,
        prescriptionId: prescription.id,
        progressionKey: progressionKey,
        sourceWeek: 1,
        targetWeek: 2,
        kind: ProgressionDecisionKind.increase,
        previousTarget: previousTarget,
        nextTarget: personalizedTarget,
        reasonCodes: const ['test_personalization'],
        createdAt: DateTime.utc(2026, 8, 1),
      ),
    );
    expect(
      state.progressionDecisionForPrescription(
        occurrence: occurrence,
        session: session,
        block: prescriptionBlock,
        prescription: prescription,
      ),
      isNotNull,
    );

    await state.chooseReadiness(occurrence, ReadinessChoice.ready);
    final controller = await state.openWorkout(
      state.occurrenceById(occurrence.id)!,
    );
    final personalizedExercise = controller.draft.snapshot.exercises.firstWhere(
      (item) => item.prescribedExerciseId == prescription.exerciseId,
    );

    expect(personalizedExercise.prescriptionId, prescription.id);
    expect(personalizedExercise.setCount, personalizedTarget.sets);
    expect(personalizedExercise.target.minimum, personalizedTarget.minimum);
    expect(personalizedExercise.target.maximum, personalizedTarget.maximum);
  });

  test(
    'malformed legacy progress records do not invalidate the session',
    () async {
      final store = MemoryStore();
      final source = createState(store: store);
      await source.initialize();
      await source.ensureProgramEnrollment();

      final snapshot = Map<String, dynamic>.from(store.data!);
      final target = Map<String, dynamic>.from(snapshot['target'] as Map);
      target['occurrences'] = [
        ...(target['occurrences'] as List),
        {'id': 'broken-occurrence'},
      ];
      target['workoutCompletions'] = [
        {'id': 'broken-completion'},
      ];
      store
        ..data = {...snapshot, 'target': target}
        ..authenticated = true
        ..authenticatedUid = source.uid;

      final restored = createState(store: store);
      await restored.initialize();

      expect(restored.isAuthenticated, isTrue);
      expect(restored.errorMessage, isNull);
      expect(restored.enrollment, isNotNull);
      expect(restored.occurrences, isNotEmpty);
      expect(restored.workoutCompletions, isEmpty);
    },
  );
}
