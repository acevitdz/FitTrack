import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../data/program_seed_data.dart';
import '../data/seed_data.dart';
import '../models/account.dart';
import '../models/active_workout.dart' as target;
import '../models/exercise.dart';
import '../models/health_models.dart';
import '../models/measurement_units.dart';
import '../models/program.dart';
import '../models/progression.dart';
import '../models/user_profile.dart';
import '../models/workout_completion.dart';
import '../models/workout_plan.dart';
import '../models/workout_schedule.dart';
import '../services/firebase_gateway.dart';
import '../services/active_workout_controller.dart';
import '../services/active_workout_draft_store.dart';
import '../services/execution_config_resolver.dart';
import '../services/local_store.dart';
import '../services/notification_service.dart';
import '../services/program_catalog_validator.dart';
import '../services/program_matcher.dart';
import '../services/progression_engine.dart';
import '../services/speech_cue_service.dart';
import '../services/sync_queue.dart';

const Object _appStateUnset = Object();

class AppState extends ChangeNotifier {
  AppState({
    required this.firebaseAvailable,
    required NotificationService notificationService,
    LocalStore? localStore,
    ActiveWorkoutDraftStore? workoutDraftStore,
    SpeechCueService? speechCueService,
    SyncQueue? syncQueue,
    List<Exercise> testExerciseCatalog = const [],
  }) : _notifications = notificationService,
       _store = localStore ?? LocalStore(),
       _workoutDraftStore = workoutDraftStore ?? ActiveWorkoutDraftStore(),
       _speech = speechCueService ?? const SpeechCueService(),
       _syncQueue = syncQueue ?? SyncQueue(),
       _testExerciseCatalog = List.unmodifiable(testExerciseCatalog),
       _firebase = FirebaseGateway(available: firebaseAvailable) {
    exercises = List.of(_testExerciseCatalog);
    _notifications.setPayloadHandler(_handleNotificationPayload);
  }

  final bool firebaseAvailable;
  final NotificationService _notifications;
  final LocalStore _store;
  final ActiveWorkoutDraftStore _workoutDraftStore;
  final SpeechCueService _speech;
  final SyncQueue _syncQueue;
  final List<Exercise> _testExerciseCatalog;
  final FirebaseGateway _firebase;

  bool isAuthenticated = false;
  bool busy = false;
  String? errorMessage;
  ThemeMode themeMode = ThemeMode.light;
  bool notificationsEnabled = false;
  bool notificationPermissionRequested = false;
  bool notificationPermissionGranted = false;
  int programReminderHour = 18;
  int programReminderMinute = 30;
  int programReminderMinutesBefore = 60;
  bool voiceCoachEnabled = false;
  double voiceCoachRate = .48;
  bool countdownSoundsEnabled = true;
  String unit = MeasurementUnitSystem.metric.storageKey;
  String uid = 'demo-user';
  String? _pendingNotificationPayload;
  int _remoteRevision = 0;
  bool _syncing = false;
  AccountAccess accountAccess = const AccountAccess.active();
  DataExportRequest? latestExportRequest;
  String? exerciseCatalogError;
  bool exerciseCatalogLoading = false;

  String? takePendingNotificationPayload() {
    final value = _pendingNotificationPayload;
    _pendingNotificationPayload = null;
    return value;
  }

  void _handleNotificationPayload(String payload) {
    if (decodeFitTrackNotificationPayload(payload) == null) return;
    _pendingNotificationPayload = payload;
    notifyListeners();
  }

  UserProfile profile = const UserProfile(
    id: 'demo-user',
    email: 'demo@fittrack.vn',
    name: 'Người dùng FitTrack',
    heightCm: 170,
    currentWeightKg: 68,
    goal: 'Duy trì sức khỏe',
    weeklyWorkoutGoal: 3,
  );

  late List<Exercise> exercises;
  final Set<String> favoriteExerciseIds = {};
  final List<WorkoutPlan> plans = [];
  final List<WorkoutSchedule> schedules = [];
  final List<WorkoutCompletion> completions = [];
  final List<WeightEntry> weightEntries = [];
  final List<WorkoutReminder> reminders = [];
  List<Achievement> achievements = SeedData.achievements();
  final Set<String> activeDays = {};

  UserTrainingPreferences trainingPreferences =
      const UserTrainingPreferences.defaults();
  List<Program> programs = List.of(ProgramSeedData.programs);
  List<ProgramVersion> programVersions = List.of(ProgramSeedData.versions);
  ProgramEnrollment? enrollment;
  final List<WorkoutOccurrence> occurrences = [];
  final List<target.WorkoutCompletion> workoutCompletions = [];
  final List<ProgressionDecision> progressionDecisions = [];
  target.ActiveWorkoutDraft? activeWorkoutDraft;
  ProgramMatchStatus? lastProgramMatchStatus;

  int longestStreak = 0;
  String? lastActiveDate;
  final Set<String> workoutDays = {};
  int longestWorkoutStreak = 0;
  String? lastWorkoutDate;

  int get currentStreak =>
      _summarizeStreak(activeDays, requireRecentDay: true).current;
  int get currentWorkoutStreak =>
      _summarizeStreak(workoutDays, requireRecentDay: true).current;

  List<WorkoutCompletion> get completedCompletions =>
      List.of(completions)
        ..sort((a, b) => b.completedAt.compareTo(a.completedAt));

  WeightEntry? get latestWeight => weightEntries.isEmpty
      ? null
      : (List<WeightEntry>.of(
          weightEntries,
        )..sort((a, b) => b.recordedAt.compareTo(a.recordedAt))).first;

  ProgramVersion? get activeProgramVersion {
    final versionId = enrollment?.programVersionId;
    if (versionId == null) return null;
    return programVersions.where((item) => item.id == versionId).firstOrNull;
  }

  Program? get activeProgram {
    final programId = activeProgramVersion?.programId;
    if (programId == null) return null;
    return programs.where((item) => item.id == programId).firstOrNull;
  }

  List<ProgramVersion> get catalogProgramVersions {
    final versions =
        programVersions
            .where(
              (version) =>
                  version.status == ProgramLifecycleStatus.published &&
                  version.guidedConfirmationAvailable &&
                  version.cadence.supports(trainingPreferences.sessionsPerWeek),
            )
            .toList()
          ..sort((left, right) {
            final priority = right.matchingPriority.compareTo(
              left.matchingPriority,
            );
            return priority != 0 ? priority : left.id.compareTo(right.id);
          });
    return List.unmodifiable(versions);
  }

  String? programCompatibilityIssue(ProgramVersion version) {
    if (!version.populationKeys.contains(trainingPreferences.populationKey)) {
      return 'Lộ trình này không hỗ trợ nhóm người dùng hiện tại.';
    }
    if (!version.experienceKeys.contains(trainingPreferences.experienceKey)) {
      return 'Hãy chọn lộ trình phù hợp với kinh nghiệm tập hiện tại.';
    }
    if (!version.goalKeys.contains(trainingPreferences.goalKey)) {
      return 'Lộ trình này không hỗ trợ mục tiêu tập hiện tại.';
    }
    if (!version.cadence.supports(trainingPreferences.sessionsPerWeek)) {
      return 'Lộ trình này không hỗ trợ '
          '${trainingPreferences.sessionsPerWeek} buổi mỗi tuần.';
    }
    final availableEquipment = trainingPreferences.equipmentKeys.toSet();
    if (!availableEquipment.containsAll(version.equipmentKeys)) {
      return 'Thiếu dụng cụ bắt buộc: '
          '${version.equipmentKeys.where((item) => !availableEquipment.contains(item)).join(', ')}.';
    }
    return null;
  }

  List<target.WorkoutCompletion> get completedTargetWorkouts =>
      List.of(workoutCompletions)
        ..sort((a, b) => b.completedAt.compareTo(a.completedAt));

  List<target.WorkoutCompletion> get participatingTargetWorkouts =>
      completedTargetWorkouts
          .where((completion) => completion.hasParticipation)
          .toList(growable: false);

  WorkoutOccurrence? occurrenceById(String id) =>
      occurrences.where((item) => item.id == id).firstOrNull;

  List<WorkoutOccurrence> get overdueOccurrences {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return occurrences.where((item) {
      final scheduled = DateTime(
        item.scheduledDate.year,
        item.scheduledDate.month,
        item.scheduledDate.day,
      );
      return item.isOpen &&
          item.status != WorkoutOccurrenceStatus.inProgress &&
          scheduled.isBefore(today);
    }).toList()..sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));
  }

  WorkoutOccurrence? get todayOccurrence {
    final today = DateTime.now();
    final day = DateTime(today.year, today.month, today.day);
    final available =
        occurrences
            .where(
              (item) =>
                  item.status == WorkoutOccurrenceStatus.scheduled ||
                  item.status == WorkoutOccurrenceStatus.postponed ||
                  item.status == WorkoutOccurrenceStatus.inProgress,
            )
            .toList()
          ..sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));
    for (final item in available) {
      final scheduled = DateTime(
        item.scheduledDate.year,
        item.scheduledDate.month,
        item.scheduledDate.day,
      );
      if (!scheduled.isAfter(day)) return item;
    }
    return null;
  }

  WorkoutOccurrence? get nextOccurrence {
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    final upcoming = occurrences.where((item) {
      final scheduled = DateTime(
        item.scheduledDate.year,
        item.scheduledDate.month,
        item.scheduledDate.day,
      );
      return item.isOpen &&
          item.status != WorkoutOccurrenceStatus.inProgress &&
          scheduled.isAfter(day);
    }).toList()..sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));
    return upcoming.firstOrNull;
  }

  ProgramSession? sessionForOccurrence(WorkoutOccurrence occurrence) =>
      programVersions
          .where((item) => item.id == occurrence.programVersionId)
          .firstOrNull
          ?.sessionById(occurrence.sessionId);

  int get targetWorkoutsThisWeek {
    final currentEnrollment = enrollment;
    if (currentEnrollment == null) return 0;
    final now = DateTime.now();
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    final currentOccurrenceIds = occurrences
        .where((item) => item.enrollmentId == currentEnrollment.id)
        .map((item) => item.id)
        .toSet();
    return workoutCompletions
        .where(
          (item) =>
              !item.completedAt.isBefore(start) &&
              item.hasParticipation &&
              currentOccurrenceIds.contains(item.occurrenceId),
        )
        .length;
  }

  int get fullyCompletedTargetWorkoutsThisWeek {
    final currentEnrollment = enrollment;
    if (currentEnrollment == null) return 0;
    final now = DateTime.now();
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    final currentOccurrenceIds = occurrences
        .where((item) => item.enrollmentId == currentEnrollment.id)
        .map((item) => item.id)
        .toSet();
    return workoutCompletions
        .where(
          (item) =>
              !item.completedAt.isBefore(start) &&
              item.isFullyCompleted &&
              currentOccurrenceIds.contains(item.occurrenceId),
        )
        .length;
  }

  Duration get targetWorkoutDuration => participatingTargetWorkouts.fold(
    Duration.zero,
    (total, item) => total + Duration(seconds: item.actualDurationSeconds),
  );

  int get targetCompletedSetCount => workoutCompletions.fold(
    0,
    (total, item) => total + item.completedSetCount,
  );

  int get targetWorkoutStreak =>
      _summarizeStreak(workoutDays, requireRecentDay: true).current;

  List<Exercise> get templateExercises => exercises
      .where((exercise) => !exercise.isPersonal && exercise.isCatalogApproved)
      .toList(growable: false);

  List<Exercise> get personalExercises => exercises
      .where((exercise) => exercise.ownerId == uid)
      .toList(growable: false);

  WorkoutPlan? planById(String id) =>
      plans.where((plan) => plan.id == id).firstOrNull;

  List<WorkoutSchedule> schedulesOn(DateTime date) => schedules
      .where((schedule) => schedule.occursOn(date))
      .toList(growable: false);

  OccurrenceStatus occurrenceStatus(WorkoutSchedule schedule, DateTime date) {
    final completion = completionForOccurrence(
      scheduleId: schedule.id,
      date: date,
    );
    if (completion != null) {
      return completion.status == CompletionStatus.completed
          ? OccurrenceStatus.completed
          : OccurrenceStatus.partiallyCompleted;
    }
    final today = DateTime.now();
    final day = DateTime(date.year, date.month, date.day);
    final current = DateTime(today.year, today.month, today.day);
    return day.isBefore(current)
        ? OccurrenceStatus.overdue
        : OccurrenceStatus.scheduled;
  }

  int get workoutsThisWeek {
    final now = DateTime.now();
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    return completedCompletions
        .where((completion) => !completion.occurrenceDate.isBefore(start))
        .length;
  }

  double get weeklyProgress =>
      (workoutsThisWeek / profile.weeklyWorkoutGoal).clamp(0, 1);

  Duration get totalWorkoutDuration => completedCompletions.fold(
    Duration.zero,
    (total, completion) => total + completion.actualDuration,
  );

  double get totalVolume => completedCompletions.fold(
    0.0,
    (total, completion) => total + completion.totalVolume,
  );

  int get workoutStreak => targetWorkoutStreak;

  Future<void> initialize() async {
    final storedSession = await _store.loadAuthenticated();
    String? sessionUid;
    if (firebaseAvailable) {
      sessionUid = _firebase.currentUid;
    } else if (storedSession) {
      sessionUid = await _store.loadAuthenticatedUid();
    }

    if (sessionUid == null) {
      isAuthenticated = false;
      _store.clearScope();
      await _store.saveAuthenticated(false);
      await _store.saveAuthenticatedUid(null);
      _prepareAccountState(
        accountUid: 'demo-user',
        email: 'demo@fittrack.vn',
        name: 'Người dùng FitTrack',
        onboardingCompleted: true,
        includeSamples: true,
      );
      return;
    }

    uid = sessionUid;
    _store.scopeTo(uid);
    if (firebaseAvailable) {
      try {
        accountAccess = await _firebase.loadAccountAccess(uid);
      } on Object {
        accountAccess = const AccountAccess.active();
      }
      if (!accountAccess.canUsePrivateApp) {
        errorMessage = AccountAccessException(accountAccess).toString();
        await _firebase.signOut();
        isAuthenticated = false;
        await _store.saveAuthenticated(false);
        await _store.saveAuthenticatedUid(null);
        _store.clearScope();
        _prepareAccountState(
          accountUid: 'demo-user',
          email: 'demo@fittrack.vn',
          name: 'Người dùng FitTrack',
          onboardingCompleted: true,
          includeSamples: true,
        );
        return;
      }
    }
    final local = await _store.loadState();
    if (local == null) {
      _prepareAccountState(
        accountUid: uid,
        email: 'user@fittrack.local',
        name: 'Người dùng FitTrack',
        onboardingCompleted: !firebaseAvailable,
        includeSamples: !firebaseAvailable,
      );
    } else {
      try {
        _restore(local);
      } on Object {
        _prepareAccountState(
          accountUid: uid,
          email: 'user@fittrack.local',
          name: 'Người dùng FitTrack',
          onboardingCompleted: false,
        );
        errorMessage =
            'Dữ liệu cục bộ không hợp lệ; FitTrack đã tạo hồ sơ sạch.';
      }
    }

    if (firebaseAvailable) {
      try {
        final cloud = await _firebase.loadSnapshot(uid);
        if (cloud != null) {
          _restore(cloud);
        }
      } on Object {
        // Use only the cache already scoped to this UID while offline.
      }
    }
    await _mergeRemoteActivityDays();

    profile = profile.copyWith(id: uid);
    isAuthenticated = true;
    await _store.saveAuthenticated(true);
    await _store.saveAuthenticatedUid(uid);
    await _refreshTemplateExercises();
    await _refreshRemoteDomain();
    if (firebaseAvailable) {
      try {
        latestExportRequest = await _firebase.latestDataExportRequest(uid);
      } on Object {
        // Export status is optional while offline.
      }
    }
    activeWorkoutDraft = await _workoutDraftStore.load(uid);
    if (profile.onboardingCompleted) {
      await ensureProgramEnrollment(persist: false);
    }
    await _initializeMessagingIfOptedIn();
    await _drainSyncQueue();
    await _store.saveState(_toJson());
  }

  void _prepareAccountState({
    required String accountUid,
    required String email,
    required String name,
    required bool onboardingCompleted,
    bool includeSamples = false,
  }) {
    uid = accountUid;
    _remoteRevision = 0;
    accountAccess = const AccountAccess.active();
    latestExportRequest = null;
    exerciseCatalogError = null;
    exerciseCatalogLoading = false;
    themeMode = ThemeMode.light;
    notificationsEnabled = false;
    notificationPermissionRequested = false;
    notificationPermissionGranted = false;
    programReminderHour = 18;
    programReminderMinute = 30;
    programReminderMinutesBefore = 60;
    voiceCoachEnabled = false;
    voiceCoachRate = .48;
    countdownSoundsEnabled = true;
    unit = MeasurementUnitSystem.metric.storageKey;
    profile = UserProfile(
      id: accountUid,
      email: email,
      name: name,
      heightCm: includeSamples ? 170 : 0,
      currentWeightKg: includeSamples ? 68 : 0,
      goal: 'Thể lực tổng quát',
      weeklyWorkoutGoal: 3,
      onboardingCompleted: onboardingCompleted,
    );
    exercises = List.of(_testExerciseCatalog);
    favoriteExerciseIds.clear();
    plans.clear();
    schedules.clear();
    completions.clear();
    weightEntries.clear();
    reminders.clear();
    achievements = SeedData.achievements();
    activeDays.clear();
    trainingPreferences = const UserTrainingPreferences.defaults();
    programs = List.of(ProgramSeedData.programs);
    programVersions = List.of(ProgramSeedData.versions);
    enrollment = null;
    occurrences.clear();
    workoutCompletions.clear();
    progressionDecisions.clear();
    activeWorkoutDraft = null;
    lastProgramMatchStatus = null;
    longestStreak = 0;
    lastActiveDate = null;
    workoutDays.clear();
    longestWorkoutStreak = 0;
    lastWorkoutDate = null;
    if (includeSamples) _seedInitialData();
  }

  void _seedInitialData() {
    plans.clear();
    schedules.clear();
    completions.clear();
    occurrences.clear();
    workoutCompletions.clear();
    progressionDecisions.clear();
    enrollment = null;
    programs = List.of(ProgramSeedData.programs);
    programVersions = List.of(ProgramSeedData.versions);
    final now = DateTime.now();
    weightEntries
      ..clear()
      ..addAll([
        WeightEntry(
          id: 'weight-1',
          weightKg: 70,
          heightCm: profile.heightCm,
          recordedAt: now.subtract(const Duration(days: 28)),
        ),
        WeightEntry(
          id: 'weight-2',
          weightKg: 69.2,
          heightCm: profile.heightCm,
          recordedAt: now.subtract(const Duration(days: 14)),
        ),
        WeightEntry(
          id: 'weight-3',
          weightKg: 68,
          heightCm: profile.heightCm,
          recordedAt: now.subtract(const Duration(days: 2)),
        ),
      ]);
    _rebuildWeightActivityDays();
    _rebuildWorkoutActivityDays();
  }

  Future<bool> signIn(String email, String password) =>
      _authenticate(email, password, register: false);

  Future<bool> register(String name, String email, String password) =>
      _authenticate(email, password, register: true, displayName: name.trim());

  Future<bool> _authenticate(
    String email,
    String password, {
    required bool register,
    String? displayName,
  }) async {
    busy = true;
    errorMessage = null;
    notifyListeners();
    try {
      final signedInUid = register
          ? await _firebase.register(email.trim(), password)
          : await _firebase.signIn(email.trim(), password);
      uid = signedInUid;
      _store.scopeTo(uid);
      accountAccess = register
          ? const AccountAccess.active()
          : await _firebase.loadAccountAccess(uid);
      if (!accountAccess.canUsePrivateApp) {
        throw AccountAccessException(accountAccess);
      }

      if (register) {
        _prepareAccountState(
          accountUid: uid,
          email: email.trim(),
          name: displayName?.trim().isNotEmpty == true
              ? displayName!.trim()
              : 'Người dùng FitTrack',
          onboardingCompleted: false,
        );
      } else {
        // Prefer the UID-scoped local snapshot so returning users do not wait
        // for every Firestore collection before entering the app. A device
        // without a cache still waits for the initial cloud snapshot once.
        var saved = await _store.loadState();
        final restoredFromLocal = saved != null;
        if (saved == null && firebaseAvailable) {
          saved = await _firebase.loadSnapshot(uid);
        }
        if (saved == null) {
          _prepareAccountState(
            accountUid: uid,
            email: email.trim(),
            name: email.split('@').first,
            onboardingCompleted: !firebaseAvailable,
            includeSamples: !firebaseAvailable,
          );
        } else {
          try {
            _restore(saved);
          } on Object {
            // Keep authentication usable even when an old snapshot has an
            // invalid field outside the progress collections.
            _prepareAccountState(
              accountUid: uid,
              email: email.trim(),
              name: email.split('@').first,
              onboardingCompleted: !firebaseAvailable,
              includeSamples: !firebaseAvailable,
            );
            errorMessage =
                'Dữ liệu tài khoản cũ không hợp lệ; đã tạo lại hồ sơ an toàn.';
          }
        }

        if (restoredFromLocal) {
          unawaited(
            _refreshAuthenticatedSnapshotInBackground(
              authenticatedUid: signedInUid,
            ),
          );
        }
      }

      profile = profile.copyWith(id: uid, email: email.trim());
      isAuthenticated = true;
      await _store.saveAuthenticated(true);
      await _store.saveAuthenticatedUid(uid);
      activeWorkoutDraft = await _workoutDraftStore.load(uid);
      if (register) {
        // Registration creates new data, so durably queue the first snapshot.
        // Firestore delivery itself remains a background concern.
        await _commit(waitForRemoteSync: false);
      } else {
        await _store.saveState(_toJson());
      }
      unawaited(
        _finishAuthenticationInBackground(authenticatedUid: signedInUid),
      );
      return true;
    } on Object catch (error) {
      errorMessage = _friendlyError(error);
      try {
        await _firebase.signOut();
      } on Object {
        // Authentication already failed; continue clearing the local session.
      }
      isAuthenticated = false;
      await _store.saveAuthenticated(false);
      await _store.saveAuthenticatedUid(null);
      _store.clearScope();
      _prepareAccountState(
        accountUid: 'demo-user',
        email: 'demo@fittrack.vn',
        name: 'Người dùng FitTrack',
        onboardingCompleted: true,
        includeSamples: true,
      );
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  bool _isCurrentAuthenticatedSession(String authenticatedUid) =>
      isAuthenticated && uid == authenticatedUid;

  Future<void> _refreshAuthenticatedSnapshotInBackground({
    required String authenticatedUid,
  }) async {
    try {
      final remote = await _firebase.loadSnapshot(authenticatedUid);
      if (remote == null || !_isCurrentAuthenticatedSession(authenticatedUid)) {
        return;
      }
      final local = _toJson();
      try {
        _restore(_mergeSnapshots(remote: remote, local: local));
      } on Object {
        // A malformed legacy cloud record must not invalidate the local
        // session or send the user back to the login screen.
        _restore(local);
      }
      if (!_isCurrentAuthenticatedSession(authenticatedUid)) return;
      await _store.saveState(_toJson());
      notifyListeners();
    } on Object {
      // The already restored UID-scoped cache remains usable while offline.
    }
  }

  Future<void> _finishAuthenticationInBackground({
    required String authenticatedUid,
  }) async {
    try {
      await Future.wait([
        _mergeRemoteActivityDays(),
        _refreshCatalogInBackground(),
      ]);
      if (!_isCurrentAuthenticatedSession(authenticatedUid)) return;
      if (profile.onboardingCompleted) {
        await ensureProgramEnrollment(persist: false);
      }
      if (!_isCurrentAuthenticatedSession(authenticatedUid)) return;
      await _initializeMessagingIfOptedIn();
      await _drainSyncQueue();
      if (!_isCurrentAuthenticatedSession(authenticatedUid)) return;
      await _store.saveState(_toJson());
      notifyListeners();
    } on Object {
      // Optional catalog, notification, and sync work must never undo a
      // successful Firebase authentication.
    }
  }

  Future<void> resetPassword(String email) async {
    await _firebase.resetPassword(email.trim());
  }

  Future<bool> _refreshTemplateExercises() async {
    if (!firebaseAvailable || uid == 'demo-user') {
      exercises = List.of(_testExerciseCatalog);
      exerciseCatalogError = _testExerciseCatalog.isEmpty
          ? 'Danh mục bài tập chỉ được tải từ Firebase sau khi đăng nhập.'
          : null;
      return _testExerciseCatalog.isNotEmpty;
    }
    try {
      final templates = await _firebase.loadTemplateExercises();
      final approved = templates
          .where((exercise) => exercise.isCatalogApproved)
          .toList(growable: false);
      if (approved.isEmpty) {
        throw StateError('firebase-exercise-catalog-empty');
      }
      exercises = approved;
      exerciseCatalogError = null;
      return true;
    } on Object {
      exercises = const [];
      exerciseCatalogError =
          'Không thể tải danh mục bài tập từ Firebase. Hãy kiểm tra kết nối và thử lại.';
      return false;
    }
  }

  Future<void> _refreshCatalogInBackground() async {
    await _refreshTemplateExercises();
    await _refreshRemoteDomain();
    notifyListeners();
  }

  Future<void> refreshExerciseCatalog() async {
    if (exerciseCatalogLoading) return;
    exerciseCatalogLoading = true;
    notifyListeners();
    try {
      final loaded = await _refreshTemplateExercises();
      await _refreshRemoteDomain();
      if (loaded && profile.onboardingCompleted && enrollment == null) {
        await ensureProgramEnrollment(persist: false);
      }
    } finally {
      exerciseCatalogLoading = false;
      notifyListeners();
    }
  }

  Future<void> _refreshRemoteDomain() async {
    if (!firebaseAvailable || uid == 'demo-user') return;
    if (templateExercises.isEmpty) {
      programs = const [];
      programVersions = const [];
      return;
    }
    try {
      final bundledMatch = const ProgramMatcher().match(
        preferences: trainingPreferences,
        catalog: ProgramSeedData.versions,
        fallbackProgramVersionId:
            ProgramSeedData.defaultFallbackProgramVersionIdFor(
              trainingPreferences.sessionsPerWeek,
            ),
      );
      final versionIds = <String>{
        ?enrollment?.programVersionId,
        ?bundledMatch.version?.id,
      };
      if (versionIds.isEmpty) return;

      // Never fetch the complete programVersions collection here. The
      // reviewed catalog currently expands to tens of MB and Firestore's
      // Android codec must duplicate that payload before Dart can receive it.
      final remoteVersions = await _firebase.loadProgramVersions(versionIds);
      final validVersions = remoteVersions
          .where(
            (version) => const ProgramCatalogValidator()
                .validate(version, exercises: exercises)
                .isValid,
          )
          .toList(growable: false);
      if (validVersions.isEmpty) return;
      final programIds = validVersions
          .map((version) => version.programId)
          .toSet();
      final remotePrograms = await _firebase.loadPrograms(programIds);
      final programsById = {
        for (final program in ProgramSeedData.programs) program.id: program,
        for (final program in remotePrograms) program.id: program,
      };
      final versionsById = {
        for (final version in ProgramSeedData.versions) version.id: version,
        for (final version in validVersions)
          if (programsById.containsKey(version.programId)) version.id: version,
      };
      programs = programsById.values.toList(growable: false);
      programVersions = versionsById.values.toList(growable: false);
    } on Object {
      // Keep the last verified local cache while offline.
    }
  }

  Future<void> signOut() async {
    await _speech.stop();
    await _notifications.cancelAll();
    await _workoutDraftStore.clear(uid);
    await _firebase.signOut();
    isAuthenticated = false;
    await _store.saveAuthenticated(false);
    await _store.saveAuthenticatedUid(null);
    _store.clearScope();
    _prepareAccountState(
      accountUid: 'demo-user',
      email: 'demo@fittrack.vn',
      name: 'Người dùng FitTrack',
      onboardingCompleted: true,
      includeSamples: true,
    );
    notifyListeners();
  }

  Future<String> requestDataExport() async {
    if (!isAuthenticated) throw StateError('not-authenticated');
    final exportedAt = DateTime.now();
    final export = const JsonEncoder.withIndent('  ').convert({
      'schemaVersion': 1,
      'exportedAt': exportedAt.toIso8601String(),
      'userId': uid,
      'data': _toJson(),
    });
    if (firebaseAvailable && uid != 'demo-user') {
      latestExportRequest = await _firebase.requestDataExport();
    }
    notifyListeners();
    return export;
  }

  int get activeSessionsPerWeek =>
      activeProgramVersion?.cadence.resolveFrequency(
        trainingPreferences.sessionsPerWeek,
      ) ??
      trainingPreferences.sessionsPerWeek;

  Future<void> refreshDataExportStatus() async {
    if (!firebaseAvailable || uid == 'demo-user') return;
    latestExportRequest = await _firebase.latestDataExportRequest(uid);
    notifyListeners();
  }

  Future<String> downloadLatestDataExport() async {
    if (!firebaseAvailable || uid == 'demo-user') {
      throw StateError('data-export-not-available');
    }
    await refreshDataExportStatus();
    final request = latestExportRequest;
    if (request == null || !request.canDownload) {
      throw StateError('data-export-not-ready');
    }
    final bytes = await _firebase.downloadDataExport(request);
    return utf8.decode(bytes);
  }

  Future<void> deleteAccountData() async {
    final deletionRequest = await _firebase.deleteCurrentAccount();
    if (firebaseAvailable && deletionRequest == null) {
      throw StateError('Không thể tạo yêu cầu xóa tài khoản trên hệ thống.');
    }
    await _speech.stop();
    await _notifications.cancelAll();
    await _workoutDraftStore.clear(uid);
    await _syncQueue.clear(uid);
    await _store.clear();
    isAuthenticated = false;
    _store.clearScope();
    _prepareAccountState(
      accountUid: 'demo-user',
      email: 'demo@fittrack.vn',
      name: 'Người dùng FitTrack',
      onboardingCompleted: true,
      includeSamples: true,
    );
    notifyListeners();
  }

  Future<void> recordDailyActivity({DateTime? at}) async {
    final moment = at ?? DateTime.now();
    final dateKey = _dateKey(moment);
    final hasWeightEntry = weightEntries.any(
      (entry) => _dateKey(entry.recordedAt) == dateKey,
    );
    if (!hasWeightEntry || activeDays.contains(dateKey)) return;
    await _recordWeightActivity(moment, persist: true);
  }

  Future<void> _recordWeightActivity(
    DateTime moment, {
    required bool persist,
  }) async {
    final dateKey = _dateKey(moment);
    if (activeDays.contains(dateKey)) return;
    if (firebaseAvailable && uid != 'demo-user') {
      try {
        await _firebase.recordWeightActivityDay(uid: uid, dateKey: dateKey);
      } on Object {
        // The local day remains authoritative until the next snapshot sync.
      }
    }
    activeDays.add(dateKey);
    _recalculateWeightStreak();
    _unlockAchievements();
    if (persist) await _commit();
  }

  Future<void> _recordWorkoutActivity(DateTime moment) async {
    final dateKey = _dateKey(moment);
    if (workoutDays.contains(dateKey)) return;
    if (firebaseAvailable && uid != 'demo-user') {
      try {
        await _firebase.recordWorkoutActivityDay(uid: uid, dateKey: dateKey);
      } on Object {
        // The completion and local day are synced together by the next commit.
      }
    }
    workoutDays.add(dateKey);
    _recalculateWorkoutStreak();
  }

  Future<void> _mergeRemoteActivityDays() async {
    if (!firebaseAvailable || uid == 'demo-user') return;
    try {
      final remoteDays = await Future.wait([
        _firebase.loadActivityDays(
          uid: uid,
          collection: 'weightActivityDays',
          source: 'weight_entry',
        ),
        _firebase.loadActivityDays(
          uid: uid,
          collection: 'workoutActivityDays',
          source: 'workout_completion',
        ),
      ]);
      activeDays.addAll(remoteDays[0]);
      workoutDays.addAll(remoteDays[1]);
      _recalculateWeightStreak();
      _recalculateWorkoutStreak();
      _unlockAchievements();
    } on Object {
      // Keep the UID-scoped snapshot while offline.
    }
  }

  void _rebuildWeightActivityDays() {
    activeDays
      ..clear()
      ..addAll(
        weightEntries
            .where((entry) => entry.id != 'body-restored')
            .map((entry) => _dateKey(entry.recordedAt)),
      );
    _recalculateWeightStreak();
  }

  void _rebuildWorkoutActivityDays() {
    workoutDays
      ..clear()
      ..addAll(
        workoutCompletions
            .where((completion) => completion.hasParticipation)
            .map((completion) => _dateKey(completion.completedAt)),
      );
    _recalculateWorkoutStreak();
  }

  void _recalculateWeightStreak() {
    final summary = _summarizeStreak(activeDays, requireRecentDay: true);
    longestStreak = summary.longest;
    lastActiveDate = summary.lastDate;
  }

  void _recalculateWorkoutStreak() {
    final summary = _summarizeStreak(workoutDays, requireRecentDay: true);
    longestWorkoutStreak = summary.longest;
    lastWorkoutDate = summary.lastDate;
  }

  ({int current, int longest, String? lastDate}) _summarizeStreak(
    Set<String> dayKeys, {
    required bool requireRecentDay,
  }) {
    final days =
        dayKeys.map(_parseDayKey).whereType<DateTime>().toSet().toList()
          ..sort();
    if (days.isEmpty) return (current: 0, longest: 0, lastDate: null);

    var longest = 1;
    var run = 1;
    for (var index = 1; index < days.length; index++) {
      if (days[index].difference(days[index - 1]).inDays == 1) {
        run++;
        if (run > longest) longest = run;
      } else {
        run = 1;
      }
    }

    final now = DateTime.now();
    final today = DateTime.utc(now.year, now.month, now.day);
    var current = 0;
    final latestAge = today.difference(days.last).inDays;
    if (!requireRecentDay || (latestAge >= 0 && latestAge <= 1)) {
      current = 1;
      for (var index = days.length - 1; index > 0; index--) {
        if (days[index].difference(days[index - 1]).inDays != 1) break;
        current++;
      }
    }
    return (current: current, longest: longest, lastDate: _dateKey(days.last));
  }

  DateTime? _parseDayKey(String value) {
    final parts = value.split('-');
    if (parts.length != 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    final result = DateTime.utc(year, month, day);
    if (result.year != year || result.month != month || result.day != day) {
      return null;
    }
    return result;
  }

  Future<void> updateProfile(UserProfile value) async {
    final trimmedName = value.name.trim();
    if (trimmedName.length < 2 || trimmedName.length > 50) {
      throw ArgumentError('Tên hiển thị phải có từ 2 đến 50 ký tự.');
    }
    profile = value.copyWith(name: trimmedName);
    await _commit(waitForRemoteSync: false);
    unawaited(_syncDisplayName(trimmedName));
  }

  Future<void> _syncDisplayName(String name) async {
    try {
      await _firebase.updateDisplayName(name);
    } on Object {
      // The local profile and durable snapshot remain authoritative offline.
    }
  }

  Future<void> completeOnboarding(UserProfile value) async {
    profile = value.copyWith(onboardingCompleted: true);
    await ensureProgramEnrollment(persist: false);
    await _commit();
  }

  Future<void> updateTrainingPreferences(
    UserTrainingPreferences value, {
    bool rematch = true,
  }) async {
    if (rematch && activeWorkoutDraft != null) {
      throw StateError(
        'Hãy hoàn tất hoặc bỏ buổi tập đang dở trước khi đổi chương trình.',
      );
    }
    _validateRequestedSchedule(value);
    trainingPreferences = value;
    profile = profile.copyWith(
      goal: TrainingGoalKey.labelFor(value.goalKey),
      weeklyWorkoutGoal: value.sessionsPerWeek,
    );
    if (rematch) {
      await _cancelOpenOccurrences(enrollment?.id);
      enrollment = null;
      await ensureProgramEnrollment(persist: false);
    }
    await _commit();
  }

  Future<ProgramMatchResult> ensureProgramEnrollment({
    bool persist = true,
    bool forceNew = false,
  }) async {
    if (templateExercises.isEmpty) {
      const result = ProgramMatchResult(
        status: ProgramMatchStatus.noSupportedProgram,
        candidate: null,
        rankedCandidates: [],
        reasons: ['exercise_catalog_unavailable'],
      );
      lastProgramMatchStatus = result.status;
      return result;
    }
    if (!firebaseAvailable && programs.isEmpty) {
      programs = List.of(ProgramSeedData.programs);
    }
    if (!firebaseAvailable && programVersions.isEmpty) {
      programVersions = List.of(ProgramSeedData.versions);
    }
    final current = enrollment;
    final currentVersion = current == null
        ? null
        : programVersions
              .where((version) => version.id == current.programVersionId)
              .firstOrNull;
    if (!forceNew &&
        current != null &&
        currentVersion != null &&
        current.status == ProgramEnrollmentStatus.active &&
        (currentVersion.isPublished ||
            currentVersion.status == ProgramLifecycleStatus.retired)) {
      final result = ProgramMatchResult(
        status: ProgramMatchStatus.matched,
        candidate: ProgramMatchCandidate(
          version: currentVersion,
          score: 0,
          reasons: const ['existing_enrollment'],
        ),
        rankedCandidates: const [],
        reasons: const ['existing_enrollment'],
      );
      lastProgramMatchStatus = result.status;
      await _syncProgramNotifications();
      return result;
    }
    if (!forceNew &&
        current != null &&
        currentVersion != null &&
        current.status == ProgramEnrollmentStatus.completed) {
      final result = ProgramMatchResult(
        status: ProgramMatchStatus.matched,
        candidate: ProgramMatchCandidate(
          version: currentVersion,
          score: 0,
          reasons: const ['completed_enrollment'],
        ),
        rankedCandidates: const [],
        reasons: const ['completed_enrollment'],
      );
      lastProgramMatchStatus = result.status;
      return result;
    }
    if (current != null &&
        currentVersion?.status == ProgramLifecycleStatus.recalled) {
      await _cancelOpenOccurrences(current.id);
      enrollment = current.copyWith(
        status: ProgramEnrollmentStatus.cancelled,
        endedAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      errorMessage =
          'Lộ trình hiện tại đã được thu hồi vì lý do an toàn. Hãy chọn lại lộ trình.';
      if (!forceNew) {
        final result = const ProgramMatchResult(
          status: ProgramMatchStatus.noSupportedProgram,
          candidate: null,
          rankedCandidates: [],
          reasons: ['recalled_enrollment_requires_rematch'],
        );
        lastProgramMatchStatus = result.status;
        if (persist) await _commit();
        return result;
      }
    }

    final result = const ProgramMatcher().match(
      preferences: trainingPreferences,
      catalog: programVersions,
      fallbackProgramVersionId:
          ProgramSeedData.defaultFallbackProgramVersionIdFor(
            trainingPreferences.sessionsPerWeek,
          ),
    );
    lastProgramMatchStatus = result.status;
    final version = result.version;
    if (version == null) {
      await _cancelOpenOccurrences(enrollment?.id);
      enrollment = null;
      if (persist) await _commit();
      return result;
    }

    _resolveScheduleConfiguration(version);

    final now = DateTime.now();
    await _cancelOpenOccurrences(enrollment?.id);
    enrollment = ProgramEnrollment(
      id: 'enrollment-$uid-${version.id}-${now.microsecondsSinceEpoch}',
      userId: uid,
      programVersionId: version.id,
      startedAt: now,
      status: ProgramEnrollmentStatus.active,
      updatedAt: now,
    );
    occurrences.addAll(_buildOccurrences(version, enrollment!, now));
    await _syncProgramNotifications();
    if (persist) await _commit();
    return result;
  }

  Future<ProgramMatchResult> restartProgramEnrollment() =>
      ensureProgramEnrollment(forceNew: true);

  Future<void> enrollInProgramVersion(String versionId) async {
    if (activeWorkoutDraft != null) {
      throw StateError(
        'Hãy hoàn tất hoặc bỏ buổi tập đang dở trước khi đổi lộ trình.',
      );
    }
    final version = programVersions
        .where((item) => item.id == versionId)
        .firstOrNull;
    if (version == null ||
        version.status != ProgramLifecycleStatus.published ||
        !version.guidedConfirmationAvailable) {
      throw StateError('Lộ trình này không còn khả dụng.');
    }
    final issue = programCompatibilityIssue(version);
    if (issue != null) throw StateError(issue);
    _resolveScheduleConfiguration(version);
    if (enrollment?.programVersionId == version.id &&
        enrollment?.status == ProgramEnrollmentStatus.active) {
      return;
    }

    final now = DateTime.now();
    await _cancelOpenOccurrences(enrollment?.id);
    enrollment = ProgramEnrollment(
      id: 'enrollment-$uid-${version.id}-${now.microsecondsSinceEpoch}',
      userId: uid,
      programVersionId: version.id,
      startedAt: now,
      status: ProgramEnrollmentStatus.active,
      updatedAt: now,
    );
    occurrences.addAll(_buildOccurrences(version, enrollment!, now));
    lastProgramMatchStatus = ProgramMatchStatus.matched;
    await _syncProgramNotifications();
    await _commit();
  }

  Future<void> _cancelOpenOccurrences(String? enrollmentId) async {
    if (enrollmentId == null) return;
    final open = occurrences
        .where(
          (item) =>
              item.enrollmentId == enrollmentId &&
              (item.status == WorkoutOccurrenceStatus.scheduled ||
                  item.status == WorkoutOccurrenceStatus.postponed ||
                  item.status == WorkoutOccurrenceStatus.inProgress),
        )
        .toList(growable: false);
    for (final occurrence in open) {
      await _safeCancelProgramOccurrence(occurrence.id);
      if (activeWorkoutDraft?.occurrenceId == occurrence.id) {
        await _safeCancelRestSession(activeWorkoutDraft!.sessionId);
        await _workoutDraftStore.clear(uid);
        activeWorkoutDraft = null;
      }
      _replaceOccurrence(occurrence, status: WorkoutOccurrenceStatus.cancelled);
    }
  }

  List<WorkoutOccurrence> _buildOccurrences(
    ProgramVersion version,
    ProgramEnrollment targetEnrollment,
    DateTime start,
  ) {
    final startDay = DateTime(start.year, start.month, start.day);
    final schedule = _resolveScheduleConfiguration(version);
    final frequency = schedule.frequency;
    final weekdays = schedule.weekdays;
    final result = <WorkoutOccurrence>[];
    var cursor = startDay;
    var shouldStartToday = schedule.startToday;
    final weeks = [...version.weeks]
      ..sort((a, b) => a.weekNumber.compareTo(b.weekNumber));
    for (final week in weeks) {
      final eligibleSessions =
          week.sessions
              .where((session) => session.minimumSessionsPerWeek <= frequency)
              .toList()
            ..sort((a, b) => a.order.compareTo(b.order));
      final sessions = eligibleSessions.take(frequency);
      for (final session in sessions) {
        var scheduled = cursor;
        if (shouldStartToday) {
          shouldStartToday = false;
        } else {
          while (!weekdays.contains(scheduled.weekday)) {
            scheduled = scheduled.add(const Duration(days: 1));
          }
        }
        result.add(
          WorkoutOccurrence(
            id: '${targetEnrollment.id}:${week.weekNumber}:${session.id}',
            enrollmentId: targetEnrollment.id,
            programVersionId: version.id,
            sessionId: session.id,
            weekNumber: week.weekNumber,
            scheduledDate: scheduled,
            status: WorkoutOccurrenceStatus.scheduled,
            updatedAt: start,
          ),
        );
        cursor = scheduled.add(
          Duration(days: version.cadence.minimumRestDays + 1),
        );
      }
    }
    return result;
  }

  void _ensureProgressionForTargetWeek(
    ProgramVersion version,
    String enrollmentId,
    int targetWeek,
  ) {
    if (targetWeek <= 1 || targetWeek > version.weeks.length) return;
    final gateWeek = targetWeek - 1;
    final isAdvancedWeekFive =
        !version.experienceKeys.contains('beginner') && targetWeek == 5;
    final sourceWeek = isAdvancedWeekFive ? 3 : gateWeek;
    final gateOccurrences = occurrences
        .where(
          (item) =>
              item.enrollmentId == enrollmentId && item.weekNumber == gateWeek,
        )
        .toList(growable: false);
    if (gateOccurrences.isEmpty || gateOccurrences.any((item) => item.isOpen)) {
      return;
    }
    final sourceOccurrences = occurrences
        .where(
          (item) =>
              item.enrollmentId == enrollmentId &&
              item.weekNumber == sourceWeek,
        )
        .toList(growable: false);
    if (sourceOccurrences.isEmpty ||
        sourceOccurrences.any((item) => item.isOpen)) {
      return;
    }

    final sourceOccurrenceIds = sourceOccurrences
        .map((item) => item.id)
        .toSet();
    final sourceCompletions = workoutCompletions
        .where((item) => sourceOccurrenceIds.contains(item.occurrenceId))
        .toList(growable: false);
    final gateOccurrenceIds = gateOccurrences.map((item) => item.id).toSet();
    final gateCompletions = sourceWeek == gateWeek
        ? sourceCompletions
        : workoutCompletions
              .where((item) => gateOccurrenceIds.contains(item.occurrenceId))
              .toList(growable: false);
    final targetSessionIds = occurrences
        .where(
          (item) =>
              item.enrollmentId == enrollmentId &&
              item.weekNumber == targetWeek,
        )
        .map((item) => item.sessionId)
        .toSet();
    final targetPrescriptions = _basePrescriptionSlotsForWeek(
      version,
      targetWeek,
      sessionIds: targetSessionIds,
    );
    final seenProgressionKeys = <String>{};
    for (final slot in targetPrescriptions) {
      final prescription = slot.prescription;
      final progressionKey = slot.progressionKey;
      if (!seenProgressionKeys.add(progressionKey)) continue;
      final decisionId =
          '$enrollmentId:week:$targetWeek:$progressionKey:${ProgressionEngine.policyVersion}';
      if (progressionDecisions.any((item) => item.id == decisionId)) continue;

      final baseline =
          _baselineProgressionTarget(version, progressionKey) ??
          _progressionTargetFromPrescription(prescription);
      final previous = _progressionReferenceTarget(
        enrollmentId: enrollmentId,
        progressionKey: progressionKey,
        sourceWeek: sourceWeek,
        baseline: baseline,
      );
      final evidence = [
        for (final completion in sourceCompletions)
          ...completion.exerciseProgressEvidence.where(
            (item) => item.progressionKey == progressionKey,
          ),
      ];
      final setEvents = [
        for (final completion in sourceCompletions)
          ...completion.setEvents.where(
            (item) => item.progressionKey == progressionKey,
          ),
      ];
      final completionOccurrenceIds = sourceCompletions
          .where(
            (completion) => completion.snapshot.exercises.any(
              (exercise) => exercise.progressionKey == progressionKey,
            ),
          )
          .map((item) => item.occurrenceId)
          .toSet();
      final readinessReduced =
          sourceOccurrences.any(
            (item) =>
                completionOccurrenceIds.contains(item.id) &&
                item.readinessChoice != null &&
                item.readinessChoice != ReadinessChoice.ready,
          ) ||
          gateOccurrences.any(
            (item) =>
                item.readinessChoice != null &&
                item.readinessChoice != ReadinessChoice.ready,
          );
      final safetyFlagged = gateCompletions.any(
        (completion) =>
            completion.exerciseProgressEvidence.any(
              (item) =>
                  item.progressionKey == progressionKey &&
                  item.outcome == target.ExerciseProgressOutcome.discomfort,
            ) ||
            completion.setEvents.any(
              (item) =>
                  item.progressionKey == progressionKey &&
                  item.skipReason == 'discomfort',
            ),
      );
      progressionDecisions.add(
        const ProgressionEngine().evaluate(
          enrollmentId: enrollmentId,
          programVersionId: version.id,
          prescriptionId: prescription.id,
          progressionKey: progressionKey,
          sourceWeek: sourceWeek,
          targetWeek: targetWeek,
          isBeginner: version.experienceKeys.contains('beginner'),
          sessionsPerWeek: version.cadence.sessionsPerWeek,
          baselineTarget: baseline,
          previousTarget: previous,
          evidence: evidence,
          setEvents: setEvents,
          readinessReduced: readinessReduced,
          safetyFlagged: safetyFlagged,
        ),
      );
    }
  }

  void _ensureProgressionAfterOccurrence(WorkoutOccurrence occurrence) {
    final version = programVersions
        .where((item) => item.id == occurrence.programVersionId)
        .firstOrNull;
    if (version == null) return;
    _ensureProgressionForTargetWeek(
      version,
      occurrence.enrollmentId,
      occurrence.weekNumber + 1,
    );
  }

  List<({ExercisePrescription prescription, String progressionKey})>
  _basePrescriptionSlotsForWeek(
    ProgramVersion version,
    int weekNumber, {
    Set<String>? sessionIds,
  }) {
    final week = version.weeks
        .where((item) => item.weekNumber == weekNumber)
        .firstOrNull;
    if (week == null) return const [];
    return [
      for (final session in [
        ...week.sessions,
      ]..sort((left, right) => left.order.compareTo(right.order)))
        if (sessionIds == null || sessionIds.contains(session.id))
          for (final block in [
            ...session.blocks,
          ]..sort((left, right) => left.order.compareTo(right.order)))
            for (final prescription in [
              ...block.prescriptions,
            ]..sort((left, right) => left.order.compareTo(right.order)))
              (
                prescription: prescription,
                progressionKey: _progressionKeyFor(
                  sessionOrder: session.order,
                  blockOrder: block.order,
                  prescription: prescription,
                ),
              ),
    ];
  }

  String _progressionKeyFor({
    required int sessionOrder,
    required int blockOrder,
    required ExercisePrescription prescription,
  }) =>
      'session:$sessionOrder:block:$blockOrder:'
      'prescription:${prescription.order}:${prescription.exerciseId}';

  ProgressionTarget? _baselineProgressionTarget(
    ProgramVersion version,
    String progressionKey,
  ) {
    final weeks = [...version.weeks]
      ..sort((left, right) => left.weekNumber.compareTo(right.weekNumber));
    for (final week in weeks) {
      for (final slot in _basePrescriptionSlotsForWeek(
        version,
        week.weekNumber,
      )) {
        if (slot.progressionKey == progressionKey) {
          return _progressionTargetFromPrescription(slot.prescription);
        }
      }
    }
    return null;
  }

  ProgressionTarget _progressionReferenceTarget({
    required String enrollmentId,
    required String progressionKey,
    required int sourceWeek,
    required ProgressionTarget baseline,
  }) {
    final decisions =
        progressionDecisions
            .where(
              (item) =>
                  item.enrollmentId == enrollmentId &&
                  item.progressionKey == progressionKey &&
                  item.targetWeek <= sourceWeek,
            )
            .toList()
          ..sort((left, right) => left.targetWeek.compareTo(right.targetWeek));
    if (decisions.isNotEmpty) {
      return decisions.last.nextTarget;
    }
    return baseline;
  }

  ProgressionDecision? _progressionDecisionFor(
    WorkoutOccurrence occurrence,
    String progressionKey,
  ) => progressionDecisions
      .where(
        (item) =>
            item.enrollmentId == occurrence.enrollmentId &&
            item.targetWeek == occurrence.weekNumber &&
            item.progressionKey == progressionKey,
      )
      .firstOrNull;

  ProgressionDecision? progressionDecisionForPrescription({
    required WorkoutOccurrence occurrence,
    required ProgramSession session,
    required ProgramBlock block,
    required ExercisePrescription prescription,
  }) => _progressionDecisionFor(
    occurrence,
    _progressionKeyFor(
      sessionOrder: session.order,
      blockOrder: block.order,
      prescription: prescription,
    ),
  );

  ProgressionTarget _progressionTargetFromPrescription(
    ExercisePrescription prescription,
  ) => ProgressionTarget(
    sets: prescription.sets,
    targetType: prescription.targetType,
    minimum: prescription.targetRange.minimum,
    maximum: prescription.targetRange.maximum,
  );

  String _progressionTargetLabel(
    ProgressionTarget targetValue, {
    required bool perSide,
  }) {
    final value = targetValue.minimum == targetValue.maximum
        ? '${targetValue.minimum}'
        : '${targetValue.minimum}-${targetValue.maximum}';
    final side = perSide ? '/bên' : '';
    if (targetValue.targetType == PrescriptionTargetType.repetitions) {
      return '$value lần$side';
    }
    if (targetValue.minimum % 60 == 0 && targetValue.maximum % 60 == 0) {
      final minimumMinutes = targetValue.minimum ~/ 60;
      final maximumMinutes = targetValue.maximum ~/ 60;
      final minutes = minimumMinutes == maximumMinutes
          ? '$minimumMinutes'
          : '$minimumMinutes-$maximumMinutes';
      return '$minutes phút$side';
    }
    return '$value giây$side';
  }

  void _validateRequestedSchedule(UserTrainingPreferences preferences) {
    final selected = preferences.preferredWeekdays;
    if (selected.isEmpty) return;
    if (selected.any((day) => day < DateTime.monday || day > DateTime.sunday)) {
      throw StateError('Ngày tập phải nằm trong khoảng thứ Hai đến Chủ nhật.');
    }
    if (selected.toSet().length != preferences.sessionsPerWeek) {
      throw StateError(
        'Hãy chọn đúng ${preferences.sessionsPerWeek} ngày tập khác nhau trong tuần.',
      );
    }
    final match = const ProgramMatcher().match(
      preferences: preferences,
      catalog: programVersions,
      fallbackProgramVersionId:
          ProgramSeedData.defaultFallbackProgramVersionIdFor(
            preferences.sessionsPerWeek,
          ),
    );
    final version = match.version;
    if (version != null) {
      _resolveScheduleConfiguration(version, preferences: preferences);
    }
  }

  ({int frequency, List<int> weekdays, bool startToday})
  _resolveScheduleConfiguration(
    ProgramVersion version, {
    UserTrainingPreferences? preferences,
  }) {
    final requested = preferences ?? trainingPreferences;
    final frequency = version.cadence.resolveFrequency(
      requested.sessionsPerWeek,
    );
    final selected = requested.preferredWeekdays.toSet().toList()..sort();
    if (selected.isNotEmpty) {
      if (selected.length != frequency) {
        throw StateError(
          'Lộ trình này hỗ trợ $frequency buổi/tuần; hãy chọn đúng $frequency ngày.',
        );
      }
      if (!_supportsWeeklyRestGap(selected, version.cadence.minimumRestDays)) {
        throw StateError(
          'Các ngày đã chọn không đủ thời gian nghỉ tối thiểu của lộ trình.',
        );
      }
      return (frequency: frequency, weekdays: selected, startToday: false);
    }
    return (
      frequency: frequency,
      weekdays: version.cadence.weekdaysFor(frequency),
      startToday: requested.startPolicy == ProgramStartPolicy.today,
    );
  }

  bool _supportsWeeklyRestGap(List<int> weekdays, int minimumRestDays) {
    if (weekdays.isEmpty) return false;
    final ordered = [...weekdays]..sort();
    final requiredGap = minimumRestDays + 1;
    for (var index = 0; index < ordered.length; index++) {
      final current = ordered[index];
      final next = index + 1 < ordered.length
          ? ordered[index + 1]
          : ordered.first + DateTime.daysPerWeek;
      if (next - current < requiredGap) return false;
    }
    return true;
  }

  Future<void> chooseReadiness(
    WorkoutOccurrence occurrence,
    ReadinessChoice choice,
  ) async {
    final current = occurrenceById(occurrence.id);
    if (current == null || !current.isOpen) {
      throw StateError('Buổi tập này không còn có thể đánh giá mức sẵn sàng.');
    }
    if (current.status == WorkoutOccurrenceStatus.inProgress) {
      throw StateError('Không thể đổi mức sẵn sàng khi buổi tập đang diễn ra.');
    }
    _replaceOccurrence(
      current,
      status: current.status,
      readinessChoice: choice,
      readinessAssessedAt: DateTime.now(),
    );
    await _syncProgramNotifications();
    await _commit();
  }

  bool isReadinessCurrent(WorkoutOccurrence occurrence, {DateTime? now}) {
    final assessedAt = occurrence.readinessAssessedAt;
    if (occurrence.readinessChoice == null || assessedAt == null) return false;
    return _dateKey(assessedAt) == _dateKey(now ?? DateTime.now());
  }

  Future<void> postponeOccurrence(WorkoutOccurrence occurrence) async {
    var next = occurrence.scheduledDate.add(const Duration(days: 1));
    final occupied = occurrences
        .where((item) => item.id != occurrence.id)
        .map((item) => _dateKey(item.scheduledDate))
        .toSet();
    while (occupied.contains(_dateKey(next))) {
      next = next.add(const Duration(days: 1));
    }
    await rescheduleOccurrence(
      occurrence,
      scheduledDate: next,
      hour: occurrence.scheduledHour ?? programReminderHour,
      minute: occurrence.scheduledMinute ?? programReminderMinute,
    );
  }

  Future<void> rescheduleOccurrence(
    WorkoutOccurrence occurrence, {
    required DateTime scheduledDate,
    required int hour,
    required int minute,
    OccurrenceRescheduleMode mode = OccurrenceRescheduleMode.single,
    String reason = 'user_rescheduled',
  }) async {
    final current = occurrenceById(occurrence.id);
    if (current == null || !current.isOpen) {
      throw StateError('Buổi tập này không còn có thể dời lịch.');
    }
    if (current.status == WorkoutOccurrenceStatus.inProgress) {
      throw StateError('Không thể dời một buổi tập đang diễn ra.');
    }
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      throw ArgumentError('Giờ tập không hợp lệ.');
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDay = DateTime(
      scheduledDate.year,
      scheduledDate.month,
      scheduledDate.day,
    );
    if (targetDay.isBefore(today)) {
      throw ArgumentError('Không thể dời buổi tập sang ngày đã qua.');
    }

    final ordered = _orderedEnrollmentOccurrences(current.enrollmentId)
        .where((item) => item.status != WorkoutOccurrenceStatus.cancelled)
        .toList(growable: false);
    final currentIndex = ordered.indexWhere((item) => item.id == current.id);
    if (currentIndex < 0) {
      throw StateError('Không tìm thấy buổi tập trong lộ trình.');
    }
    final version = programVersions
        .where((item) => item.id == current.programVersionId)
        .firstOrNull;
    final minimumGapDays = (version?.cadence.minimumRestDays ?? 0) + 1;

    if (currentIndex > 0) {
      final previous = ordered[currentIndex - 1];
      final earliest = DateTime(
        previous.scheduledDate.year,
        previous.scheduledDate.month,
        previous.scheduledDate.day,
      ).add(Duration(days: minimumGapDays));
      if (targetDay.isBefore(earliest)) {
        throw StateError('Ngày mới không đủ thời gian nghỉ sau buổi trước.');
      }
    }

    if (mode == OccurrenceRescheduleMode.single) {
      final collision = ordered.any(
        (item) =>
            item.id != current.id &&
            item.isOpen &&
            _dateKey(item.scheduledDate) == _dateKey(targetDay),
      );
      if (collision) {
        throw StateError('Ngày đã chọn đã có một buổi tập khác.');
      }
      if (currentIndex + 1 < ordered.length) {
        final following = ordered[currentIndex + 1];
        final latest = DateTime(
          following.scheduledDate.year,
          following.scheduledDate.month,
          following.scheduledDate.day,
        ).subtract(Duration(days: minimumGapDays));
        if (targetDay.isAfter(latest)) {
          throw StateError(
            'Ngày mới quá gần buổi kế tiếp. Hãy chọn dời cả chuỗi.',
          );
        }
      }
      _replaceOccurrence(
        current,
        status: WorkoutOccurrenceStatus.postponed,
        scheduledDate: targetDay,
        originalScheduledDate:
            current.originalScheduledDate ?? current.scheduledDate,
        readinessChoice: null,
        readinessAssessedAt: null,
        scheduledHour: hour,
        scheduledMinute: minute,
        rescheduleReason: reason,
      );
    } else {
      final currentDay = DateTime(
        current.scheduledDate.year,
        current.scheduledDate.month,
        current.scheduledDate.day,
      );
      final deltaDays = targetDay.difference(currentDay).inDays;
      for (final item
          in ordered.skip(currentIndex).where((item) => item.isOpen)) {
        final shifted = DateTime(
          item.scheduledDate.year,
          item.scheduledDate.month,
          item.scheduledDate.day,
        ).add(Duration(days: deltaDays));
        _replaceOccurrence(
          item,
          status: WorkoutOccurrenceStatus.postponed,
          scheduledDate: shifted,
          originalScheduledDate:
              item.originalScheduledDate ?? item.scheduledDate,
          readinessChoice: null,
          readinessAssessedAt: null,
          scheduledHour: item.id == current.id ? hour : item.scheduledHour,
          scheduledMinute: item.id == current.id
              ? minute
              : item.scheduledMinute,
          rescheduleReason: reason,
        );
      }
    }
    await _syncProgramNotifications();
    await _commit();
  }

  Future<void> skipOccurrence(WorkoutOccurrence occurrence) async {
    if (!occurrence.isOpen ||
        occurrence.status == WorkoutOccurrenceStatus.inProgress) {
      throw StateError('Buổi tập này không thể bỏ qua.');
    }
    _replaceOccurrence(
      occurrence,
      status: WorkoutOccurrenceStatus.skipped,
      completedAt: DateTime.now(),
    );
    await _safeCancelProgramOccurrence(occurrence.id);
    _advanceEnrollmentProgress(occurrence.enrollmentId);
    _ensureProgressionAfterOccurrence(occurrence);
    await _commit();
  }

  Future<void> markOccurrenceMissed(WorkoutOccurrence occurrence) async {
    if (!occurrence.isOpen ||
        occurrence.status == WorkoutOccurrenceStatus.inProgress) {
      throw StateError('Buổi tập này không thể đánh dấu là đã lỡ.');
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final scheduled = DateTime(
      occurrence.scheduledDate.year,
      occurrence.scheduledDate.month,
      occurrence.scheduledDate.day,
    );
    if (!scheduled.isBefore(today)) {
      throw StateError('Chỉ có thể đánh dấu đã lỡ cho buổi quá hạn.');
    }
    _replaceOccurrence(
      occurrence,
      status: WorkoutOccurrenceStatus.missed,
      completedAt: now,
    );
    await _safeCancelProgramOccurrence(occurrence.id);
    _advanceEnrollmentProgress(occurrence.enrollmentId);
    _ensureProgressionAfterOccurrence(occurrence);
    await _commit();
  }

  Future<ActiveWorkoutController> openWorkout(
    WorkoutOccurrence occurrence, {
    target.WorkoutConfirmationMode mode = target.WorkoutConfirmationMode.guided,
  }) async {
    final saved = activeWorkoutDraft;
    if (saved != null && saved.occurrenceId == occurrence.id) {
      return ActiveWorkoutController.restore(saved);
    }
    if (saved != null && saved.occurrenceId != occurrence.id) {
      throw StateError('Hãy hoàn tất hoặc bỏ buổi tập đang mở trước.');
    }
    if (occurrence.status == WorkoutOccurrenceStatus.inProgress) {
      throw StateError(
        'Không tìm thấy bản nháp của buổi đang tập. Hãy bỏ occurrence này trước khi mở lại.',
      );
    }
    if (occurrence.status != WorkoutOccurrenceStatus.scheduled &&
        occurrence.status != WorkoutOccurrenceStatus.postponed) {
      throw StateError('Buổi tập này không còn ở trạng thái có thể bắt đầu.');
    }
    final version = programVersions
        .where((item) => item.id == occurrence.programVersionId)
        .firstOrNull;
    final session = version?.sessionById(occurrence.sessionId);
    if (version == null ||
        session == null ||
        (version.status != ProgramLifecycleStatus.published &&
            version.status != ProgramLifecycleStatus.retired)) {
      throw StateError('Phiên bản chương trình không còn khả dụng.');
    }
    if (occurrence.weekNumber > 1) {
      final previousWeekOccurrences = occurrences
          .where(
            (item) =>
                item.enrollmentId == occurrence.enrollmentId &&
                item.weekNumber == occurrence.weekNumber - 1,
          )
          .toList(growable: false);
      if (previousWeekOccurrences.isEmpty ||
          previousWeekOccurrences.any((item) => item.isOpen)) {
        throw StateError(
          'Hãy hoàn tất các buổi của tuần trước trước khi bắt đầu tuần này.',
        );
      }
      _ensureProgressionForTargetWeek(
        version,
        occurrence.enrollmentId,
        occurrence.weekNumber,
      );
    }
    if (!isReadinessCurrent(occurrence)) {
      throw StateError(
        'Hãy chọn mức sẵn sàng của hôm nay trước khi bắt đầu buổi tập.',
      );
    }
    final choice = occurrence.readinessChoice!;
    final variant = session.readinessVariantFor(choice);
    if (variant?.stopWorkout ?? false) {
      throw StateError(
        variant?.safetyMessage ?? 'Hãy dừng tập và tìm hỗ trợ phù hợp.',
      );
    }
    final blocks = choice == ReadinessChoice.ready || variant == null
        ? session.blocks
        : variant.blocks;
    final prescriptionSlots = [
      for (final block in [
        ...blocks,
      ]..sort((a, b) => a.order.compareTo(b.order)))
        for (final prescription in [
          ...block.prescriptions,
        ]..sort((a, b) => a.order.compareTo(b.order)))
          (
            prescription: prescription,
            progressionKey: _progressionKeyFor(
              sessionOrder: session.order,
              blockOrder: block.order,
              prescription: prescription,
            ),
          ),
    ];
    if (prescriptionSlots.isEmpty) {
      throw StateError('Buổi tập chưa có nội dung bài tập hợp lệ.');
    }
    final snapshot = target.WorkoutSessionSnapshot(
      programSessionId: session.id,
      title: displaySessionTitle(session.title),
      programTitle: displayProgramTitle(version, program: activeProgram),
      contentVersion: version.version,
      readinessChoice: choice.name,
      readinessVariantTitle: variant?.title ?? 'Sẵn sàng',
      readinessGuidance:
          variant?.guidance ?? 'Thực hiện đúng nội dung của buổi tập.',
      sourceRefs: version.sourceRefs.map((item) => item.url).toList(),
      exercises: prescriptionSlots.map((slot) {
        final item = slot.prescription;
        final personalizedTarget = choice == ReadinessChoice.recovery
            ? null
            : _progressionDecisionFor(
                occurrence,
                slot.progressionKey,
              )?.nextTarget;
        final resolvedTarget =
            personalizedTarget != null &&
                personalizedTarget.targetType == item.targetType
            ? personalizedTarget
            : _progressionTargetFromPrescription(item);
        final resolvedSets = personalizedTarget == null
            ? item.sets
            : choice == ReadinessChoice.reduceToday
            ? (resolvedTarget.sets * .7).round().clamp(1, 1 << 20).toInt()
            : resolvedTarget.sets;
        final exercise = exercises
            .where((candidate) => candidate.id == item.exerciseId)
            .firstOrNull;
        final execution = resolveExecutionConfig(
          prescription: item,
          exercise: exercise,
        );
        final selectableExercises = <Exercise>[];
        if (exercise != null && exercise.isActive) {
          selectableExercises.add(exercise);
        }
        for (final alternativeId in item.alternativeExerciseIds) {
          final alternative = exercises
              .where(
                (candidate) =>
                    candidate.id == alternativeId && candidate.isActive,
              )
              .firstOrNull;
          if (alternative != null) selectableExercises.add(alternative);
        }
        return target.WorkoutExerciseSnapshot(
          exerciseId: item.exerciseId,
          prescriptionId: item.id,
          progressionKey: slot.progressionKey,
          prescribedExerciseId: item.exerciseId,
          name: _resolveExerciseName(
            item.exerciseId,
            item.exerciseName ?? exercise?.name,
          ),
          muscleGroup: exercise?.muscleGroup ?? 'Toàn thân',
          secondaryMuscles: exercise?.secondaryMuscles ?? const [],
          equipment: exercise?.equipment ?? 'Không dụng cụ',
          setCount: resolvedSets,
          target: target.WorkoutTargetContext(
            type: switch (item.targetType) {
              PrescriptionTargetType.repetitions => 'repetitions',
              PrescriptionTargetType.durationSeconds => 'duration_seconds',
            },
            label: _progressionTargetLabel(
              resolvedTarget,
              perSide: item.perSide,
            ),
            minimum: resolvedTarget.minimum,
            maximum: resolvedTarget.maximum,
          ),
          restSeconds: item.restSeconds,
          transitionAfterExerciseSeconds: item.transitionAfterExerciseSeconds,
          cues: item.cues,
          instructions: exercise?.instructions ?? const [],
          commonMistakes: exercise?.commonMistakes ?? const [],
          mediaUrl: exercise?.imageUrl,
          mediaAltText: exercise?.description,
          poseRuleVersionId: item.poseRuleVersionId,
          cameraTargetReps: item.cameraTargetReps == null
              ? null
              : resolvedTarget.maximum,
          executionMode: execution.executionMode,
          cueMode: execution.cueMode,
          tempoUp: execution.tempoUp,
          tempoHold: execution.tempoHold,
          tempoDown: execution.tempoDown,
          alternatives: selectableExercises
              .map(
                (candidate) => target.WorkoutExerciseAlternativeSnapshot(
                  exerciseId: candidate.id,
                  name: _resolveExerciseName(candidate.id, candidate.name),
                  muscleGroup: candidate.muscleGroup,
                  secondaryMuscles: candidate.secondaryMuscles,
                  equipment: candidate.equipment,
                  instructions: candidate.instructions,
                  commonMistakes: candidate.commonMistakes,
                  mediaUrl: candidate.imageUrl,
                  mediaAltText: candidate.description,
                ),
              )
              .toList(),
        );
      }).toList(),
    );
    final controller = ActiveWorkoutController.create(
      sessionId: 'active-${occurrence.id}',
      userId: uid,
      occurrenceId: occurrence.id,
      programVersionId: version.id,
      snapshot: snapshot,
      confirmationMode: mode,
    );
    activeWorkoutDraft = controller.checkpoint();
    _replaceOccurrence(
      occurrence,
      status: WorkoutOccurrenceStatus.inProgress,
      startedAt: DateTime.now(),
    );
    await _safeCancelProgramOccurrence(occurrence.id);
    await _workoutDraftStore.save(uid, activeWorkoutDraft!);
    await _commit();
    return controller;
  }

  Future<void> checkpointWorkout(ActiveWorkoutController controller) async {
    activeWorkoutDraft = controller.checkpoint();
    await _workoutDraftStore.save(uid, activeWorkoutDraft!);
    await _safeCancelRestSession(controller.draft.sessionId);
    if (notificationsEnabled &&
        controller.phase == target.WorkoutPhase.resting &&
        controller.draft.restEndsAt != null) {
      try {
        await _notifications.scheduleRestEnd(
          sessionId: controller.draft.sessionId,
          phaseId: controller.phaseId,
          restEndsAt: controller.draft.restEndsAt!,
        );
      } on Object {
        // A notification failure must never block workout checkpointing.
      }
    }
    notifyListeners();
  }

  Future<target.WorkoutCompletion> finishWorkout(
    ActiveWorkoutController controller,
  ) async {
    final savedCompletion = workoutCompletions
        .where(
          (item) =>
              item.idempotencyKey == controller.draft.completionIdempotencyKey,
        )
        .firstOrNull;
    if (savedCompletion != null) {
      if (controller.phase != target.WorkoutPhase.finishing &&
          controller.phase != target.WorkoutPhase.completed) {
        throw StateError(
          'Kết quả đã được lưu nhưng bản nháp không ở trạng thái hoàn tất.',
        );
      }
      controller.markCompletionSaved(
        idempotencyKey: savedCompletion.idempotencyKey,
      );
      await _workoutDraftStore.clear(uid);
      await _safeCancelRestSession(controller.draft.sessionId);
      activeWorkoutDraft = null;
      notifyListeners();
      return savedCompletion;
    }

    final occurrence = occurrences
        .where((item) => item.id == controller.draft.occurrenceId)
        .firstOrNull;
    if (occurrence == null ||
        occurrence.status != WorkoutOccurrenceStatus.inProgress) {
      throw StateError(
        'Occurrence không hợp lệ hoặc đã được xử lý; kết quả không được ghi lặp.',
      );
    }
    final completion = controller.finish();
    workoutCompletions.add(completion);
    _replaceOccurrence(
      occurrence,
      status: completion.status == target.WorkoutCompletionStatus.abandoned
          ? WorkoutOccurrenceStatus.abandoned
          : WorkoutOccurrenceStatus.completed,
      completedAt: completion.completedAt,
    );
    if (completion.hasParticipation) {
      await _recordWorkoutActivity(completion.completedAt);
    }
    _advanceEnrollmentProgress(occurrence.enrollmentId);
    _ensureProgressionAfterOccurrence(occurrence);
    _unlockAchievements();
    await _commit();
    controller.markCompletionSaved(idempotencyKey: completion.idempotencyKey);
    await _workoutDraftStore.clear(uid);
    await _safeCancelRestSession(controller.draft.sessionId);
    activeWorkoutDraft = null;
    notifyListeners();
    return completion;
  }

  Future<void> discardWorkout(ActiveWorkoutController controller) async {
    final occurrence = occurrences
        .where((item) => item.id == controller.draft.occurrenceId)
        .firstOrNull;
    if (occurrence == null ||
        occurrence.status != WorkoutOccurrenceStatus.inProgress) {
      throw StateError(
        'Occurrence không hợp lệ hoặc đã được xử lý; không thể bỏ lại.',
      );
    }
    controller.discard();
    _replaceOccurrence(
      occurrence,
      status: WorkoutOccurrenceStatus.skipped,
      completedAt: DateTime.now(),
    );
    await _workoutDraftStore.clear(uid);
    await _safeCancelRestSession(controller.draft.sessionId);
    activeWorkoutDraft = null;
    _advanceEnrollmentProgress(occurrence.enrollmentId);
    _ensureProgressionAfterOccurrence(occurrence);
    await _commit();
  }

  void _replaceOccurrence(
    WorkoutOccurrence current, {
    required WorkoutOccurrenceStatus status,
    DateTime? scheduledDate,
    Object? originalScheduledDate = _appStateUnset,
    Object? readinessChoice = _appStateUnset,
    Object? readinessAssessedAt = _appStateUnset,
    Object? startedAt = _appStateUnset,
    Object? completedAt = _appStateUnset,
    Object? scheduledHour = _appStateUnset,
    Object? scheduledMinute = _appStateUnset,
    bool? reminderEnabled,
    Object? reminderMinutesBefore = _appStateUnset,
    Object? rescheduleReason = _appStateUnset,
  }) {
    final index = occurrences.indexWhere((item) => item.id == current.id);
    if (index < 0) return;
    final stored = occurrences[index];
    occurrences[index] = stored.copyWith(
      scheduledDate: scheduledDate ?? stored.scheduledDate,
      status: status,
      originalScheduledDate: originalScheduledDate,
      readinessChoice: readinessChoice,
      readinessAssessedAt: readinessAssessedAt,
      startedAt: startedAt,
      completedAt: completedAt,
      scheduledHour: scheduledHour,
      scheduledMinute: scheduledMinute,
      reminderEnabled: reminderEnabled,
      reminderMinutesBefore: reminderMinutesBefore,
      rescheduleReason: rescheduleReason,
      updatedAt: DateTime.now(),
    );
  }

  List<WorkoutOccurrence> _orderedEnrollmentOccurrences(String enrollmentId) {
    final versionId = enrollment?.id == enrollmentId
        ? enrollment?.programVersionId
        : occurrences
              .where((item) => item.enrollmentId == enrollmentId)
              .firstOrNull
              ?.programVersionId;
    final version = programVersions
        .where((item) => item.id == versionId)
        .firstOrNull;
    final sequence = <String, int>{};
    if (version != null) {
      for (var index = 0; index < version.allSessions.length; index++) {
        sequence[version.allSessions[index].id] = index;
      }
    }
    final result = occurrences
        .where((item) => item.enrollmentId == enrollmentId)
        .toList();
    result.sort((left, right) {
      final order = (sequence[left.sessionId] ?? 1 << 30).compareTo(
        sequence[right.sessionId] ?? 1 << 30,
      );
      return order != 0
          ? order
          : left.scheduledDate.compareTo(right.scheduledDate);
    });
    return result;
  }

  void _advanceEnrollmentProgress(String enrollmentId) {
    final current = enrollment;
    if (current == null ||
        current.id != enrollmentId ||
        current.status != ProgramEnrollmentStatus.active) {
      return;
    }
    final ordered = _orderedEnrollmentOccurrences(enrollmentId);
    final nextIndex = ordered.indexWhere((item) => item.isOpen);
    final now = DateTime.now();
    if (nextIndex < 0 && ordered.isNotEmpty) {
      final last = ordered.last;
      enrollment = current.copyWith(
        status: ProgramEnrollmentStatus.completed,
        currentWeekNumber: last.weekNumber,
        nextSessionOrder: ordered.length,
        endedAt: now,
        updatedAt: now,
      );
      return;
    }
    if (nextIndex >= 0) {
      enrollment = current.copyWith(
        currentWeekNumber: ordered[nextIndex].weekNumber,
        nextSessionOrder: nextIndex,
        updatedAt: now,
      );
    }
  }

  Future<void> updateBodyMetrics({
    required double heightCm,
    required double weightKg,
    DateTime? recordedAt,
  }) async {
    if (heightCm < 100 || heightCm > 250) {
      throw ArgumentError('Chiều cao phải từ 100 đến 250 cm.');
    }
    if (weightKg <= 0 || weightKg > 500) {
      throw ArgumentError('Cân nặng phải lớn hơn 0 và không quá 500 kg.');
    }
    final moment = recordedAt ?? DateTime.now();
    if (moment.isAfter(DateTime.now().add(const Duration(minutes: 1)))) {
      throw ArgumentError('Thời điểm đo không được ở tương lai.');
    }
    final previousLatest = latestWeight;
    if (previousLatest == null || !moment.isBefore(previousLatest.recordedAt)) {
      profile = profile.copyWith(heightCm: heightCm, currentWeightKg: weightKg);
    }
    weightEntries.add(
      WeightEntry(
        id: _newId('body'),
        weightKg: weightKg,
        heightCm: heightCm,
        recordedAt: moment,
      ),
    );
    await _recordWeightActivity(moment, persist: false);
    await _commit();
  }

  Future<void> speakCue(String cue) async {
    if (!voiceCoachEnabled) return;
    await _speech.speak(cue, rate: voiceCoachRate);
  }

  Future<void> stopVoiceCoach() => _speech.stop();

  Future<void> updateAvatar(Uint8List bytes, String extension) async {
    if (bytes.length > 5 * 1024 * 1024) {
      throw ArgumentError('Ảnh không được lớn hơn 5 MB.');
    }
    final url = await _firebase.uploadUserImage(
      uid: uid,
      path: 'avatar.$extension',
      bytes: bytes,
      contentType: extension.toLowerCase() == 'png'
          ? 'image/png'
          : 'image/jpeg',
    );
    profile = profile.copyWith(photoUrl: url);
    await _commit();
  }

  void toggleFavorite(String exerciseId) {
    if (!favoriteExerciseIds.add(exerciseId)) {
      favoriteExerciseIds.remove(exerciseId);
    }
    _commit();
  }

  Future<void> savePlan(WorkoutPlan value) async {
    if (_legacyMutationsDisabled) {
      throw UnsupportedError('Kế hoạch thủ công là dữ liệu legacy chỉ đọc.');
    }
    if (value.name.trim().isEmpty || value.exercises.isEmpty) {
      throw ArgumentError('Kế hoạch cần tên và ít nhất một bài tập.');
    }
    for (final exercise in value.exercises) {
      if (exercise.sets < 1 ||
          exercise.targetReps < 1 ||
          exercise.targetMaxReps < exercise.targetReps ||
          exercise.targetWeight < 0 ||
          exercise.restSeconds < 0) {
        throw ArgumentError('Thông số bài tập không hợp lệ.');
      }
    }
    final saved = value.copyWith(userId: uid, updatedAt: DateTime.now());
    final index = plans.indexWhere((plan) => plan.id == saved.id);
    if (index < 0) {
      plans.add(saved);
    } else {
      plans[index] = saved;
    }
    await _commit();
  }

  Future<void> deletePlan(String id) async {
    if (_legacyMutationsDisabled) {
      throw UnsupportedError('Kế hoạch thủ công là dữ liệu legacy chỉ đọc.');
    }
    plans.removeWhere((plan) => plan.id == id);
    schedules.removeWhere((schedule) => schedule.planId == id);
    await _commit();
  }

  Future<void> duplicatePlan(WorkoutPlan plan) async {
    if (_legacyMutationsDisabled) {
      throw UnsupportedError('Kế hoạch thủ công là dữ liệu legacy chỉ đọc.');
    }
    final copy = plan.copyWith(
      id: _newId('plan'),
      name: '${plan.name} (bản sao)',
      userId: uid,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    plans.add(copy);
    await _commit();
  }

  Future<void> saveSchedule(WorkoutSchedule value) async {
    if (_legacyMutationsDisabled) {
      throw UnsupportedError('Lịch thủ công là dữ liệu legacy chỉ đọc.');
    }
    if (!plans.any((plan) => plan.id == value.planId)) {
      throw ArgumentError('Kế hoạch không còn tồn tại.');
    }
    if (value.type == ScheduleType.once && value.scheduledDate == null) {
      throw ArgumentError('Hãy chọn ngày tập.');
    }
    if (value.type == ScheduleType.weekly &&
        (value.weekdays.isEmpty || value.startDate == null)) {
      throw ArgumentError('Lịch hằng tuần cần ngày bắt đầu và ngày tập.');
    }
    if (value.startDate != null &&
        value.endDate != null &&
        value.endDate!.isBefore(value.startDate!)) {
      throw ArgumentError('Ngày kết thúc phải sau ngày bắt đầu.');
    }
    final saved = WorkoutSchedule(
      id: value.id,
      userId: uid,
      planId: value.planId,
      type: value.type,
      scheduledDate: value.scheduledDate,
      weekdays: value.weekdays,
      startDate: value.startDate,
      endDate: value.endDate,
      hour: value.hour,
      minute: value.minute,
      reminderEnabled: value.reminderEnabled,
      minutesBefore: value.minutesBefore,
      isEnabled: value.isEnabled,
    );
    final index = schedules.indexWhere((item) => item.id == saved.id);
    if (index < 0) {
      schedules.add(saved);
    } else {
      schedules[index] = saved;
    }
    await _commit();
  }

  Future<void> deleteSchedule(String id) async {
    if (_legacyMutationsDisabled) {
      throw UnsupportedError('Lịch thủ công là dữ liệu legacy chỉ đọc.');
    }
    schedules.removeWhere((schedule) => schedule.id == id);
    await _commit();
  }

  WorkoutCompletion? completionForOccurrence({
    required String? scheduleId,
    required DateTime date,
    String? planId,
  }) {
    final key = _dateKey(date);
    for (final completion in completions) {
      if (_dateKey(completion.occurrenceDate) == key &&
          (scheduleId != null
              ? completion.scheduleId == scheduleId
              : completion.planId == planId)) {
        return completion;
      }
    }
    return null;
  }

  Future<void> saveCompletion(WorkoutCompletion value) async {
    if (_legacyMutationsDisabled) {
      throw UnsupportedError('Kết quả thủ công là dữ liệu legacy chỉ đọc.');
    }
    if (value.exerciseResults
        .expand((exercise) => exercise.sets)
        .where((set) => set.isCompleted)
        .isEmpty) {
      throw ArgumentError('Hãy đánh dấu ít nhất một hiệp đã hoàn thành.');
    }
    if (value.actualDuration.isNegative ||
        value.exerciseResults
            .expand((item) => item.sets)
            .any((set) => set.actualReps < 0 || set.actualWeightKg < 0)) {
      throw ArgumentError('Thời lượng, số lần lặp và mức tạ không được âm.');
    }
    final duplicate = completions.any(
      (item) =>
          item.id != value.id &&
          item.userId == uid &&
          (value.scheduleId != null
              ? item.scheduleId == value.scheduleId
              : item.scheduleId == null && item.planId == value.planId) &&
          _dateKey(item.occurrenceDate) == _dateKey(value.occurrenceDate),
    );
    if (duplicate) {
      throw StateError('Kết quả của buổi tập này đã được ghi nhận.');
    }
    final saved = WorkoutCompletion(
      id: value.id,
      userId: uid,
      planId: value.planId,
      scheduleId: value.scheduleId,
      occurrenceDate: value.occurrenceDate,
      planSnapshot: value.planSnapshot,
      exerciseResults: value.exerciseResults,
      status: value.status,
      actualDuration: value.actualDuration,
      perceivedDifficulty: value.perceivedDifficulty,
      note: value.note,
      completedAt: value.completedAt,
    );
    final index = completions.indexWhere((item) => item.id == saved.id);
    if (index < 0) {
      completions.add(saved);
    } else {
      completions[index] = saved;
    }
    _unlockAchievements();
    await _commit();
  }

  Future<void> deleteCompletion(String id) async {
    if (_legacyMutationsDisabled) {
      throw UnsupportedError('Kết quả thủ công là dữ liệu legacy chỉ đọc.');
    }
    completions.removeWhere((completion) => completion.id == id);
    await _commit();
  }

  Future<void> addWeight(
    double value,
    String note, {
    DateTime? date,
    Uint8List? photoBytes,
    String photoExtension = 'jpg',
  }) async {
    if (_legacyMutationsDisabled) {
      throw UnsupportedError(
        'Hãy cập nhật chiều cao và cân nặng trong Body Metrics.',
      );
    }
    if (value <= 0 || value > 500) {
      throw ArgumentError('Cân nặng phải lớn hơn 0 và không quá 500 kg.');
    }
    final recordedAt = date ?? DateTime.now();
    if (recordedAt.isAfter(DateTime.now().add(const Duration(minutes: 1)))) {
      throw ArgumentError('Ngày ghi nhận không được nằm trong tương lai.');
    }
    String? photoUrl;
    if (photoBytes != null) {
      if (photoBytes.length > 5 * 1024 * 1024) {
        throw ArgumentError('Ảnh không được lớn hơn 5 MB.');
      }
      photoUrl = await _firebase.uploadUserImage(
        uid: uid,
        path: 'progress/${_newId('weight')}.$photoExtension',
        bytes: photoBytes,
        contentType: photoExtension.toLowerCase() == 'png'
            ? 'image/png'
            : 'image/jpeg',
      );
    }
    weightEntries.add(
      WeightEntry(
        id: _newId('weight'),
        weightKg: value,
        heightCm: profile.heightCm,
        recordedAt: recordedAt,
        note: note.trim(),
        photoUrl: photoUrl,
      ),
    );
    profile = profile.copyWith(currentWeightKg: value);
    await _recordWeightActivity(recordedAt, persist: false);
    await _commit();
  }

  Future<void> deleteWeight(String id) async {
    if (_legacyMutationsDisabled) {
      throw UnsupportedError('Lịch sử Body Metrics là bản ghi chỉ đọc.');
    }
    weightEntries.removeWhere((entry) => entry.id == id);
    if (latestWeight != null) {
      profile = profile.copyWith(currentWeightKg: latestWeight!.weightKg);
    }
    await _commit();
  }

  Future<void> updateWeightEntry(WeightEntry value) async {
    if (_legacyMutationsDisabled) {
      throw UnsupportedError(
        'Hãy tạo lần đo mới thay vì sửa lịch sử Body Metrics.',
      );
    }
    if (value.weightKg <= 0 || value.weightKg > 500) {
      throw ArgumentError('Cân nặng phải lớn hơn 0 và không quá 500 kg.');
    }
    if (value.recordedAt.isAfter(
      DateTime.now().add(const Duration(minutes: 1)),
    )) {
      throw ArgumentError('Ngày ghi nhận không được nằm trong tương lai.');
    }
    final index = weightEntries.indexWhere((entry) => entry.id == value.id);
    if (index < 0) return;
    weightEntries[index] = WeightEntry(
      id: value.id,
      weightKg: value.weightKg,
      heightCm: value.heightCm ?? profile.heightCm,
      recordedAt: value.recordedAt,
      note: value.note,
      photoUrl: value.photoUrl,
    );
    if (latestWeight?.id == value.id) {
      profile = profile.copyWith(currentWeightKg: value.weightKg);
    }
    await _commit();
  }

  Future<void> saveReminder(WorkoutReminder value) async {
    if (_legacyMutationsDisabled) {
      throw UnsupportedError('Nhắc lịch được sinh tự động từ chương trình.');
    }
    if (value.type == ReminderType.weekly && value.weekdays.isEmpty) {
      throw ArgumentError('Hãy chọn ít nhất một ngày nhắc.');
    }
    if (value.type == ReminderType.once && value.scheduledDate == null) {
      throw ArgumentError('Hãy chọn ngày nhắc.');
    }
    final index = reminders.indexWhere((reminder) => reminder.id == value.id);
    if (index < 0) {
      reminders.add(value);
    } else {
      reminders[index] = value;
    }
    if (notificationsEnabled) await _notifications.schedule(value);
    await _commit();
  }

  Future<void> toggleReminder(WorkoutReminder reminder, bool enabled) async {
    if (_legacyMutationsDisabled) {
      throw UnsupportedError(
        'Hãy bật hoặc tắt thông báo chương trình trong Cài đặt.',
      );
    }
    await saveReminder(reminder.copyWith(enabled: enabled));
  }

  Future<void> deleteReminder(String id) async {
    if (_legacyMutationsDisabled) {
      throw UnsupportedError('Nhắc lịch legacy là dữ liệu chỉ đọc.');
    }
    reminders.removeWhere((reminder) => reminder.id == id);
    await _notifications.cancel(id);
    await _commit();
  }

  Future<bool> requestNotificationPermission() async {
    notificationPermissionRequested = true;
    try {
      notificationPermissionGranted = await _notifications.requestPermission();
    } on Object {
      notificationPermissionGranted = false;
    }
    if (firebaseAvailable && notificationPermissionGranted) {
      try {
        await _notifications.initializeFirebaseMessaging(
          isEnabled: () => notificationsEnabled,
        );
      } on Object {
        // Permission can still be stored when FCM setup is temporarily down.
      }
    }
    await _syncProgramNotifications();
    await _commit();
    return notificationPermissionGranted;
  }

  Future<bool> openNotificationSettings() =>
      _notifications.openNotificationSettings();

  Future<void> setNotificationsEnabled(bool value) async {
    notificationsEnabled = value;
    if (!value) {
      try {
        await _notifications.cancelAll();
      } on Object {
        // The preference remains authoritative even if the plugin is down.
      }
    } else {
      await _initializeMessagingIfOptedIn();
    }
    for (final reminder in reminders) {
      try {
        if (value) {
          await _notifications.schedule(reminder);
        } else {
          await _notifications.cancel(reminder.id);
        }
      } on Object {
        // Continue syncing the remaining reminders.
      }
    }
    await _syncProgramNotifications();
    await _commit();
  }

  Future<void> setProgramReminderTime({
    required int hour,
    required int minute,
    int? minutesBefore,
  }) async {
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      throw ArgumentError('Giờ nhắc không hợp lệ.');
    }
    programReminderHour = hour;
    programReminderMinute = minute;
    if (minutesBefore != null) {
      programReminderMinutesBefore = minutesBefore.clamp(0, 1440);
    }
    await _syncProgramNotifications();
    await _commit();
  }

  Future<void> setOccurrenceReminder(
    WorkoutOccurrence occurrence, {
    required bool enabled,
    required int hour,
    required int minute,
    int? minutesBefore,
  }) async {
    final current = occurrenceById(occurrence.id);
    if (current == null || !current.isOpen) {
      throw StateError('Buổi tập này không còn có thể đặt nhắc nhở.');
    }
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      throw ArgumentError('Giờ nhắc không hợp lệ.');
    }
    _replaceOccurrence(
      current,
      status: current.status,
      scheduledHour: hour,
      scheduledMinute: minute,
      reminderEnabled: enabled,
      reminderMinutesBefore: (minutesBefore ?? programReminderMinutesBefore)
          .clamp(0, 1440),
    );
    await _syncProgramNotifications();
    await _commit();
  }

  Future<void> _syncProgramNotifications() async {
    for (final occurrence in occurrences) {
      await _safeCancelProgramOccurrence(occurrence.id);
      if (!notificationsEnabled ||
          !notificationPermissionGranted ||
          !occurrence.reminderEnabled ||
          !occurrence.isOpen ||
          occurrence.status == WorkoutOccurrenceStatus.inProgress) {
        continue;
      }
      final session = sessionForOccurrence(occurrence);
      final scheduledAt = occurrence.scheduledAt(
        fallbackHour: programReminderHour,
        fallbackMinute: programReminderMinute,
      );
      await _safeScheduleProgramOccurrence(
        occurrenceId: occurrence.id,
        title: displaySessionTitle(session?.title ?? 'Buổi tập FitTrack'),
        scheduledAt: scheduledAt,
        minutesBefore:
            occurrence.reminderMinutesBefore ?? programReminderMinutesBefore,
      );
    }
  }

  Future<void> _safeScheduleProgramOccurrence({
    required String occurrenceId,
    required String title,
    required DateTime scheduledAt,
    required int minutesBefore,
  }) async {
    try {
      await _notifications.scheduleProgramOccurrence(
        occurrenceId: occurrenceId,
        title: title,
        scheduledAt: scheduledAt,
        minutesBefore: minutesBefore,
      );
    } on Object {
      // Scheduling is best-effort; the occurrence remains usable.
    }
  }

  Future<void> _safeCancelProgramOccurrence(String occurrenceId) async {
    try {
      await _notifications.cancelProgramOccurrence(occurrenceId);
    } on Object {
      // Notification infrastructure must not block domain mutations.
    }
  }

  Future<void> _safeCancelRestSession(String sessionId) async {
    try {
      await _notifications.cancelRestSession(sessionId);
    } on Object {
      // Notification infrastructure must not block workout persistence.
    }
  }

  Future<void> _initializeMessagingIfOptedIn() async {
    if (!firebaseAvailable ||
        !notificationsEnabled ||
        !notificationPermissionGranted) {
      return;
    }
    try {
      await _notifications.initializeFirebaseMessaging(
        isEnabled: () => notificationsEnabled,
      );
    } on Object {
      // Push messaging is optional; local state and workouts remain available.
    }
  }

  Future<void> setThemeMode(ThemeMode value) async {
    themeMode = value == ThemeMode.dark ? ThemeMode.dark : ThemeMode.light;
    await _commit();
  }

  Future<void> setUnit(String value) async {
    unit = MeasurementUnitSystem.fromStored(value).storageKey;
    await _commit();
  }

  Future<void> setVoiceCoachEnabled(bool value) async {
    voiceCoachEnabled = value;
    if (!value) await _speech.stop();
    await _commit();
  }

  Future<void> setVoiceCoachRate(double value) async {
    voiceCoachRate = value.clamp(.2, .8).toDouble();
    await _commit();
  }

  Future<void> setCountdownSoundsEnabled(bool value) async {
    countdownSoundsEnabled = value;
    await _commit();
  }

  void _unlockAchievements() {
    final completed = workoutCompletions
        .where((item) => item.isFullyCompleted)
        .length;
    // Achievement eligibility may use the better independent streak, but the
    // weight-entry and workout day sets are never combined into one sequence.
    final bestStreak = longestStreak > longestWorkoutStreak
        ? longestStreak
        : longestWorkoutStreak;
    final conditions = <String, bool>{
      'first_workout': completed >= 1,
      'workout_5': completed >= 5,
      'workout_10': completed >= 10,
      'streak_3': bestStreak >= 3,
      'streak_7': bestStreak >= 7,
      'streak_30': bestStreak >= 30,
    };
    achievements = achievements.map((achievement) {
      if (!achievement.unlocked && (conditions[achievement.id] ?? false)) {
        return achievement.copyWith(unlockedAt: DateTime.now());
      }
      return achievement;
    }).toList();
  }

  Map<String, dynamic> _mergeSnapshots({
    required Map<String, dynamic> remote,
    required Map<String, dynamic> local,
  }) {
    final merged = Map<String, dynamic>.from(local);
    merged['weightEntries'] = _mergeRecordLists(
      remote['weightEntries'],
      local['weightEntries'],
      keyOf: (item) => item['id'] as String?,
    );
    merged['completions'] = _mergeRecordLists(
      remote['completions'],
      local['completions'],
      keyOf: (item) => item['id'] as String?,
    );
    merged['achievements'] = _mergeRecordLists(
      remote['achievements'],
      local['achievements'],
      keyOf: (item) => item['id'] as String?,
      choose: (remoteItem, localItem) {
        if (localItem['unlockedAt'] != null) return localItem;
        return remoteItem['unlockedAt'] != null ? remoteItem : localItem;
      },
    );
    merged['weightActivityDays'] = _mergeStringLists(
      remote['weightActivityDays'],
      local['weightActivityDays'],
    );
    merged['workoutDays'] = _mergeStringLists(
      remote['workoutDays'],
      local['workoutDays'],
    );

    final remoteTarget = Map<String, dynamic>.from(
      remote['target'] as Map? ?? const {},
    );
    final localTarget = Map<String, dynamic>.from(
      local['target'] as Map? ?? const {},
    );
    final mergedTarget = Map<String, dynamic>.from(localTarget);
    mergedTarget['occurrences'] = _mergeRecordLists(
      remoteTarget['occurrences'],
      localTarget['occurrences'],
      keyOf: (item) => item['id'] as String?,
      choose: _chooseNewestRecord,
    );
    mergedTarget['workoutCompletions'] = _mergeRecordLists(
      remoteTarget['workoutCompletions'],
      localTarget['workoutCompletions'],
      keyOf: (item) =>
          item['idempotencyKey'] as String? ?? item['id'] as String?,
    );
    mergedTarget['progressionDecisions'] = _mergeRecordLists(
      remoteTarget['progressionDecisions'],
      localTarget['progressionDecisions'],
      keyOf: (item) => item['id'] as String?,
    );
    final remoteEnrollment = remoteTarget['enrollment'];
    final localEnrollment = localTarget['enrollment'];
    if (remoteEnrollment is Map && localEnrollment is Map) {
      mergedTarget['enrollment'] = _chooseNewestRecord(
        Map<String, dynamic>.from(remoteEnrollment),
        Map<String, dynamic>.from(localEnrollment),
      );
    }
    merged['target'] = mergedTarget;
    merged['_sync'] = {
      'remoteRevision':
          ((remote['_sync'] as Map?)?['remoteRevision'] as num?)?.toInt() ?? 0,
    };
    return merged;
  }

  List<Map<String, dynamic>> _mergeRecordLists(
    Object? remoteValue,
    Object? localValue, {
    required String? Function(Map<String, dynamic>) keyOf,
    Map<String, dynamic> Function(
      Map<String, dynamic> remoteItem,
      Map<String, dynamic> localItem,
    )?
    choose,
  }) {
    final records = <String, Map<String, dynamic>>{};
    for (final raw in remoteValue as List? ?? const []) {
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);
      final key = keyOf(item);
      if (key != null) records[key] = item;
    }
    for (final raw in localValue as List? ?? const []) {
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);
      final key = keyOf(item);
      if (key == null) continue;
      final remoteItem = records[key];
      records[key] = remoteItem == null
          ? item
          : (choose?.call(remoteItem, item) ?? item);
    }
    return records.values.toList(growable: false);
  }

  List<String> _mergeStringLists(Object? remoteValue, Object? localValue) => {
    ...(remoteValue as List? ?? const []).whereType<String>(),
    ...(localValue as List? ?? const []).whereType<String>(),
  }.toList(growable: false);

  Map<String, dynamic> _chooseNewestRecord(
    Map<String, dynamic> remoteItem,
    Map<String, dynamic> localItem,
  ) {
    DateTime timestamp(Map<String, dynamic> item) {
      for (final key in const [
        'updatedAt',
        'completedAt',
        'endedAt',
        'startedAt',
        'scheduledDate',
      ]) {
        final value = item[key];
        if (value is String) {
          final parsed = DateTime.tryParse(value);
          if (parsed != null) return parsed;
        }
      }
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    return timestamp(localItem).isBefore(timestamp(remoteItem))
        ? remoteItem
        : localItem;
  }

  Future<void> _commit({bool waitForRemoteSync = true}) async {
    // Both streaks are time-dependent even when no new event is added.
    _recalculateWeightStreak();
    _recalculateWorkoutStreak();
    final snapshot = _toJson();
    await _store.saveState(snapshot);
    if (firebaseAvailable && uid != 'demo-user') {
      await _syncQueue.enqueueLatest(
        uid: uid,
        snapshot: snapshot,
        expectedRemoteRevision: _remoteRevision,
      );
      if (waitForRemoteSync) {
        await _drainSyncQueue();
      } else {
        unawaited(_drainSyncQueue());
      }
    }
    notifyListeners();
  }

  Future<void> _drainSyncQueue() async {
    if (_syncing || !firebaseAvailable || uid == 'demo-user') return;
    _syncing = true;
    try {
      var operation = await _syncQueue.peek(uid);
      if (operation == null) return;
      try {
        final syncedRevision = await _firebase.syncSnapshot(
          uid,
          operation.snapshot,
          expectedRemoteRevision: operation.expectedRemoteRevision,
        );
        _restore(operation.snapshot);
        _remoteRevision = syncedRevision;
        await _syncQueue.clear(uid);
      } on SyncConflictException catch (conflict) {
        final remote = await _firebase.loadSnapshot(uid);
        if (remote == null) return;
        final merged = _mergeSnapshots(
          remote: remote,
          local: operation.snapshot,
        );
        _remoteRevision = conflict.remoteRevision;
        _restore(merged);
        await _store.saveState(_toJson());
        await _syncQueue.enqueueLatest(
          uid: uid,
          snapshot: _toJson(),
          expectedRemoteRevision: _remoteRevision,
        );
        operation = await _syncQueue.peek(uid);
        if (operation == null) return;
        _remoteRevision = await _firebase.syncSnapshot(
          uid,
          operation.snapshot,
          expectedRemoteRevision: operation.expectedRemoteRevision,
        );
        await _syncQueue.clear(uid);
      }
      await _store.saveState(_toJson());
    } on Object {
      // The durable operation stays queued and will be retried next launch or
      // after the next local mutation.
    } finally {
      _syncing = false;
    }
  }

  Map<String, dynamic> _toJson() => {
    '_sync': {'remoteRevision': _remoteRevision},
    'profile': profile.toJson(),
    // Reviewed templates are bundled/remote catalog data, not per-user data.
    // Only personal entries belong in the account snapshot (and Firestore
    // document), keeping sync payloads small and avoiding stale catalog data.
    'exercises': personalExercises.map((item) => item.toJson()).toList(),
    'favoriteExerciseIds': favoriteExerciseIds.toList(),
    'plans': plans.map((item) => item.toJson()).toList(),
    'schedules': schedules.map((item) => item.toJson()).toList(),
    'completions': completions.map((item) => item.toJson()).toList(),
    'weightEntries': weightEntries.map((item) => item.toJson()).toList(),
    'reminders': reminders.map((item) => item.toJson()).toList(),
    'achievements': achievements.map((item) => item.toJson()).toList(),
    'activeDays': activeDays.toList(),
    'weightActivityDays': activeDays.toList(),
    'streak': {
      'current': currentStreak,
      'longest': longestStreak,
      'lastActiveDate': lastActiveDate,
      'source': 'weight_entry',
    },
    'workoutDays': workoutDays.toList(),
    'workoutStreak': {
      'current': currentWorkoutStreak,
      'longest': longestWorkoutStreak,
      'lastWorkoutDate': lastWorkoutDate,
      'source': 'workout_completion',
    },
    'settings': {
      'themeMode': themeMode.name,
      'notificationsEnabled': notificationsEnabled,
      'notificationPermissionRequested': notificationPermissionRequested,
      'notificationPermissionGranted': notificationPermissionGranted,
      'programReminderHour': programReminderHour,
      'programReminderMinute': programReminderMinute,
      'programReminderMinutesBefore': programReminderMinutesBefore,
      'voiceCoachEnabled': voiceCoachEnabled,
      'voiceCoachRate': voiceCoachRate,
      'countdownSoundsEnabled': countdownSoundsEnabled,
      'unit': unit,
    },
    'target': {
      'catalogSchemaVersion': 4,
      'trainingPreferences': trainingPreferences.toJson(),
      'enrollment': enrollment?.toJson(),
      'occurrences': occurrences.map((item) => item.toJson()).toList(),
      'workoutCompletions': workoutCompletions
          .map((item) => item.toJson())
          .toList(),
      'progressionDecisions': progressionDecisions
          .map((item) => item.toJson())
          .toList(),
      'lastProgramMatchStatus': lastProgramMatchStatus?.name,
    },
  };

  void _restore(Map<String, dynamic> json) {
    _remoteRevision =
        ((json['_sync'] as Map?)?['remoteRevision'] as num?)?.toInt() ?? 0;
    profile = UserProfile.fromJson(json['profile'] as Map<String, dynamic>);
    // Exercise content is never restored from a user snapshot. The runtime
    // catalog is replaced only by the reviewed top-level Firestore collection.
    favoriteExerciseIds
      ..clear()
      ..addAll(List<String>.from(json['favoriteExerciseIds'] as List? ?? []));
    final rawPlans = (json['plans'] as List? ?? const []);
    plans
      ..clear()
      ..addAll(
        rawPlans.map(
          (item) => WorkoutPlan.fromJson(item as Map<String, dynamic>),
        ),
      );
    schedules
      ..clear()
      ..addAll(
        (json['schedules'] as List? ?? const []).map(
          (item) => WorkoutSchedule.fromJson(item as Map<String, dynamic>),
        ),
      );
    completions.clear();
    final rawCompletions = json['completions'] as List?;
    if (rawCompletions != null) {
      completions.addAll(
        rawCompletions.map(
          (item) => WorkoutCompletion.fromJson(item as Map<String, dynamic>),
        ),
      );
    } else {
      for (final item in json['sessions'] as List? ?? const []) {
        final legacy = item as Map<String, dynamic>;
        if (legacy['status'] == 'completed') {
          completions.add(
            WorkoutCompletion.fromLegacySessionJson(legacy, userId: uid),
          );
        }
      }
    }
    if (schedules.isEmpty) {
      for (final item in rawPlans.cast<Map<String, dynamic>>()) {
        final weekdays = Set<int>.from(item['weekdays'] as List? ?? const []);
        if (weekdays.isEmpty) continue;
        final createdAt = DateTime.parse(item['createdAt'] as String);
        schedules.add(
          WorkoutSchedule(
            id: 'migrated-${item['id']}',
            userId: uid,
            planId: item['id'] as String,
            type: ScheduleType.weekly,
            weekdays: weekdays,
            startDate: DateTime(createdAt.year, createdAt.month, createdAt.day),
          ),
        );
      }
    }
    weightEntries
      ..clear()
      ..addAll(
        (json['weightEntries'] as List? ?? const []).map(
          (item) => WeightEntry.fromJson(item as Map<String, dynamic>),
        ),
      );
    if (weightEntries.isEmpty &&
        profile.currentWeightKg > 0 &&
        profile.heightCm > 0) {
      weightEntries.add(
        WeightEntry(
          id: 'body-restored',
          weightKg: profile.currentWeightKg,
          heightCm: profile.heightCm,
          recordedAt: DateTime.now(),
        ),
      );
    }
    reminders
      ..clear()
      ..addAll(
        (json['reminders'] as List? ?? []).map(
          (item) => WorkoutReminder.fromJson(item as Map<String, dynamic>),
        ),
      );
    achievements = (json['achievements'] as List? ?? [])
        .map((item) => Achievement.fromJson(item as Map<String, dynamic>))
        .toList();
    if (achievements.isEmpty) achievements = SeedData.achievements();
    // V2 activeDays may contain login-only days. Weight entries are the
    // authoritative migration source, so those legacy days are not reused.
    _rebuildWeightActivityDays();
    final storedWeightStreak = json['streak'] as Map?;
    if (storedWeightStreak?['source'] == 'weight_entry') {
      activeDays.addAll(
        (json['weightActivityDays'] as List? ?? const [])
            .whereType<String>()
            .where((dayKey) => _parseDayKey(dayKey) != null),
      );
      _recalculateWeightStreak();
    }
    final settings = json['settings'] as Map<String, dynamic>? ?? {};
    themeMode = settings['themeMode'] == ThemeMode.dark.name
        ? ThemeMode.dark
        : ThemeMode.light;
    notificationsEnabled = settings['notificationsEnabled'] as bool? ?? false;
    notificationPermissionRequested =
        settings['notificationPermissionRequested'] as bool? ?? false;
    notificationPermissionGranted =
        settings['notificationPermissionGranted'] as bool? ?? false;
    programReminderHour = settings['programReminderHour'] as int? ?? 18;
    programReminderMinute = settings['programReminderMinute'] as int? ?? 30;
    programReminderMinutesBefore =
        settings['programReminderMinutesBefore'] as int? ?? 60;
    voiceCoachEnabled = settings['voiceCoachEnabled'] as bool? ?? false;
    voiceCoachRate = (settings['voiceCoachRate'] as num?)?.toDouble() ?? .48;
    countdownSoundsEnabled =
        settings['countdownSoundsEnabled'] as bool? ?? true;
    unit = MeasurementUnitSystem.fromStored(
      settings['unit'] as String?,
    ).storageKey;

    final targetState = json['target'] as Map<String, dynamic>?;
    if (targetState == null) {
      trainingPreferences = const UserTrainingPreferences.defaults();
      programs = List.of(ProgramSeedData.programs);
      programVersions = List.of(ProgramSeedData.versions);
      enrollment = null;
      occurrences.clear();
      workoutCompletions.clear();
      progressionDecisions.clear();
      lastProgramMatchStatus = null;
    } else {
      trainingPreferences = targetState['trainingPreferences'] == null
          ? const UserTrainingPreferences.defaults()
          : UserTrainingPreferences.fromJson(
              Map<String, dynamic>.from(
                targetState['trainingPreferences'] as Map,
              ),
            );
      // Catalog content is bundled or loaded from the reviewed top-level
      // Firebase collections. Never restore an obsolete catalog copy from a
      // user's mutable snapshot.
      programs = List.of(ProgramSeedData.programs);
      programVersions = List.of(ProgramSeedData.versions);
      enrollment = targetState['enrollment'] == null
          ? null
          : ProgramEnrollment.fromJson(
              Map<String, dynamic>.from(targetState['enrollment'] as Map),
            );
      occurrences.clear();
      for (final item in targetState['occurrences'] as List? ?? const []) {
        if (item is! Map) continue;
        try {
          occurrences.add(
            WorkoutOccurrence.fromJson(Map<String, dynamic>.from(item)),
          );
        } on Object {
          // Skip only the malformed legacy occurrence. Valid progress data
          // remains available instead of making the whole account unusable.
        }
      }
      workoutCompletions.clear();
      for (final item
          in targetState['workoutCompletions'] as List? ?? const []) {
        if (item is! Map) continue;
        try {
          workoutCompletions.add(
            target.WorkoutCompletion.fromJson(Map<String, dynamic>.from(item)),
          );
        } on Object {
          // History can contain records from older schemas. Ignore a broken
          // record rather than crashing when the Progress tab is opened.
        }
      }
      progressionDecisions.clear();
      for (final item
          in targetState['progressionDecisions'] as List? ?? const []) {
        if (item is! Map) continue;
        try {
          progressionDecisions.add(
            ProgressionDecision.fromJson(Map<String, dynamic>.from(item)),
          );
        } on Object {
          // Missing or malformed legacy decisions must default to hold rather
          // than making the account snapshot unreadable.
        }
      }
      final matchStatus = targetState['lastProgramMatchStatus'] as String?;
      lastProgramMatchStatus = matchStatus == null
          ? null
          : ProgramMatchStatus.values.byName(matchStatus);
    }
    _rebuildWorkoutActivityDays();
    final storedWorkoutStreak = json['workoutStreak'] as Map?;
    if (storedWorkoutStreak?['source'] == 'workout_completion') {
      workoutDays.addAll(
        (json['workoutDays'] as List? ?? const []).whereType<String>().where(
          (dayKey) => _parseDayKey(dayKey) != null,
        ),
      );
      _recalculateWorkoutStreak();
    }
  }

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  bool get _legacyMutationsDisabled => true;

  String _newId(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}';

  String _friendlyError(Object error) {
    if (error is AccountAccessException) return error.toString();
    final message = error.toString().toLowerCase();
    if (error is TimeoutException || message.contains('timeout')) {
      return 'Kết nối Firebase quá thời gian. Hãy kiểm tra mạng và thử lại.';
    }
    if (message.contains('wrong-password') ||
        message.contains('invalid-credential')) {
      return 'Email hoặc mật khẩu không đúng.';
    }
    if (message.contains('email-already-in-use')) {
      return 'Email này đã được sử dụng.';
    }
    if (message.contains('operation-not-allowed')) {
      return 'Firebase chưa bật đăng nhập bằng email/mật khẩu.';
    }
    if (message.contains('weak-password')) {
      return 'Mật khẩu chưa đủ mạnh. Hãy dùng ít nhất 8 ký tự.';
    }
    if (message.contains('invalid-email')) {
      return 'Email không hợp lệ.';
    }
    if (message.contains('too-many-requests')) {
      return 'Có quá nhiều lần thử. Hãy đợi một lúc rồi thử lại.';
    }
    if (message.contains('network')) {
      return 'Không thể kết nối mạng. Hãy thử lại.';
    }
    return 'Không thể hoàn thành thao tác. Hãy kiểm tra dữ liệu và thử lại.';
  }

  String resolveExerciseName(String id) {
    final catalogExercise = exercises.where((e) => e.id == id).firstOrNull;
    final resolved = _resolveExerciseName(id, catalogExercise?.name);
    if (resolved == id || resolved.contains('_')) {
      return 'Bài tập';
    }
    return resolved;
  }

  String get activeProgramDisplayTitle {
    final version = activeProgramVersion;
    if (version == null) return 'Chương trình FitTrack';
    return displayProgramTitle(version, program: activeProgram);
  }

  String displayProgramTitle(ProgramVersion version, {Program? program}) {
    final rawTitle = program?.title.trim() ?? '';
    final routeCode = RegExp(
      r'^[A-Z]{2}-(?:NAM|NU)-(?:MOI|DATAP)-(?:NHA|GYM)(?:\s*[—–-]\s*|$)',
    );
    if (rawTitle.isNotEmpty && !routeCode.hasMatch(rawTitle)) {
      return rawTitle;
    }

    final goal = version.goalKeys.isEmpty
        ? 'Luyện tập'
        : TrainingGoalKey.labelFor(version.goalKeys.first);
    final audience =
        version.audienceTags.contains(ProgramAudiencePreference.female)
        ? 'Nữ'
        : 'Nam';
    final experience = version.experienceKeys.contains('intermediate')
        ? 'Đã tập'
        : 'Mới bắt đầu';
    final environment = version.environmentKey == 'gym'
        ? 'Phòng tập'
        : 'Tại nhà';
    return '$goal · $audience · $experience · $environment';
  }

  String resolveProgramVersionLabel(String versionId) {
    final version = programVersions.where((v) => v.id == versionId).firstOrNull;
    if (version != null) {
      final program = programs
          .where((p) => p.id == version.programId)
          .firstOrNull;
      final programTitle = displayProgramTitle(version, program: program);
      return '$programTitle (v${version.version})';
    }
    return 'Chương trình tập luyện';
  }

  static String displaySessionTitle(String title) {
    var result = title.trim().replaceFirst(
      RegExp(r'^(?:[ABCD]|FB[12]|D-[A-Z]{2})\s*[·—:|-]\s*'),
      '',
    );
    result = result.replaceFirst(
      RegExp(r'^Buổi\s+D\s+nhẹ$', caseSensitive: false),
      'Phục hồi nhẹ',
    );
    return result.isEmpty ? 'Buổi tập' : result;
  }

  static String displayStoredProgramTitle(String title) {
    final raw = title.trim();
    if (raw.isEmpty) return 'Chương trình FitTrack';
    final match = RegExp(
      r'^(GM|TC|SM|KD)-(?:NAM|NU)-(?:MOI|DATAP)-(?:NHA|GYM)\s*[—–-]\s*(.+)$',
    ).firstMatch(raw);
    if (match == null) return raw;
    final goal = switch (match.group(1)) {
      'GM' => 'Giảm mỡ',
      'TC' => 'Tăng cơ',
      'SM' => 'Tăng sức mạnh',
      _ => 'Khỏe và dẻo dai',
    };
    return '$goal · ${match.group(2)!}';
  }

  static String humanizeId(String id) {
    if (id.trim().isEmpty) return id;
    final clean = id.replaceAll(RegExp(r'[_-]'), ' ').trim();
    final words = clean.split(RegExp(r'\s+'));
    return words
        .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  static String _resolveExerciseName(String id, String? rawName) {
    if (rawName != null &&
        rawName.isNotEmpty &&
        rawName != id &&
        !rawName.contains('_')) {
      return rawName;
    }
    final normalized = id.trim().toLowerCase();
    return switch (normalized) {
      'squat' || 'squat_bodyweight' || 'ex-squat' => 'Squat (Gập gối)',
      'pushup' || 'push_up' || 'ex-pushup' => 'Chống đẩy',
      'plank' || 'ex-plank' => 'Plank (Giữ cơ bụng)',
      'lunge' || 'lunges' || 'ex-lunge' => 'Lunge (Bước gập gối)',
      'glute_bridge' || 'ex-glute-bridge' => 'Glute Bridge (Nâng hông)',
      'mountain_climber' ||
      'mountain_climbers' ||
      'ex-mountain-climbers' => 'Leo núi tại chỗ',
      'burpee' || 'ex-burpee' => 'Burpee (Bật nhảy toàn thân)',
      'bench_press' || 'ex-bench-press' => 'Đẩy ngực ghế ngang',
      'deadlift' || 'ex-deadlift' => 'Deadlift (Kéo tạ đòn)',
      'lat_pulldown' || 'ex-lat-pulldown' => 'Kéo xô',
      'shoulder_press' || 'ex-shoulder-press' => 'Đẩy vai tạ đơn',
      'bicep_curls' || 'ex-bicep-curls' => 'Cuốn tay trước',
      'tricep_pushdown' || 'ex-tricep-pushdown' => 'Kéo cáp tay sau',
      'leg_press' || 'ex-leg-press' => 'Đạp chân',
      'calf_raises' || 'ex-calf-raises' => 'Nhón bắp chân',
      'crunches' || 'ex-crunches' => 'Gập bụng',
      _ => rawName ?? 'Bài tập',
    };
  }
}
