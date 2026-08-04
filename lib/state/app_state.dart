import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../data/program_seed_data.dart';
import '../data/seed_data.dart';
import '../models/active_workout.dart' as target;
import '../models/exercise.dart';
import '../models/health_models.dart';
import '../models/measurement_units.dart';
import '../models/program.dart';
import '../models/user_profile.dart';
import '../models/workout_completion.dart';
import '../models/workout_plan.dart';
import '../models/workout_schedule.dart';
import '../services/firebase_gateway.dart';
import '../services/active_workout_controller.dart';
import '../services/active_workout_draft_store.dart';
import '../services/local_store.dart';
import '../services/notification_service.dart';
import '../services/program_matcher.dart';
import '../services/speech_cue_service.dart';

class AppState extends ChangeNotifier {
  AppState({
    required this.firebaseAvailable,
    required NotificationService notificationService,
    LocalStore? localStore,
    ActiveWorkoutDraftStore? workoutDraftStore,
    SpeechCueService? speechCueService,
  }) : _notifications = notificationService,
       _store = localStore ?? LocalStore(),
       _workoutDraftStore = workoutDraftStore ?? ActiveWorkoutDraftStore(),
       _speech = speechCueService ?? const SpeechCueService(),
       _firebase = FirebaseGateway(available: firebaseAvailable) {
    _notifications.setPayloadHandler(_handleNotificationPayload);
  }

  final bool firebaseAvailable;
  final NotificationService _notifications;
  final LocalStore _store;
  final ActiveWorkoutDraftStore _workoutDraftStore;
  final SpeechCueService _speech;
  final FirebaseGateway _firebase;

  bool isAuthenticated = false;
  bool busy = false;
  String? errorMessage;
  ThemeMode themeMode = ThemeMode.system;
  bool notificationsEnabled = false;
  bool notificationPermissionRequested = false;
  bool notificationPermissionGranted = false;
  int programReminderHour = 18;
  int programReminderMinute = 30;
  int programReminderMinutesBefore = 60;
  bool voiceCoachEnabled = false;
  double voiceCoachRate = .48;
  bool hapticsEnabled = true;
  String unit = MeasurementUnitSystem.metric.storageKey;
  String uid = 'demo-user';
  String? _pendingNotificationPayload;

  String? takePendingNotificationPayload() {
    final value = _pendingNotificationPayload;
    _pendingNotificationPayload = null;
    return value;
  }

  void _handleNotificationPayload(String payload) {
    if (!payload.startsWith('today:') && !payload.startsWith('active:')) {
      return;
    }
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

  List<Exercise> exercises = List.of(SeedData.exercises);
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

  List<target.WorkoutCompletion> get completedTargetWorkouts =>
      List.of(workoutCompletions)
        ..sort((a, b) => b.completedAt.compareTo(a.completedAt));

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
    return available.firstOrNull;
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
              currentOccurrenceIds.contains(item.occurrenceId),
        )
        .length;
  }

  Duration get targetWorkoutDuration => workoutCompletions.fold(
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
      .where((exercise) => !exercise.isPersonal && exercise.isActive)
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
    // Create the UID-scoped cloud profile before loading large shared catalogs.
    await _commit();
    await _refreshRemoteDomain();
    await _refreshTemplateExercises();
    activeWorkoutDraft = await _workoutDraftStore.load(uid);
    if (profile.onboardingCompleted) {
      await ensureProgramEnrollment(persist: false);
    }
    await _initializeMessagingIfOptedIn();
    await _commit();
  }

  void _prepareAccountState({
    required String accountUid,
    required String email,
    required String name,
    required bool onboardingCompleted,
    bool includeSamples = false,
  }) {
    uid = accountUid;
    themeMode = ThemeMode.system;
    notificationsEnabled = false;
    notificationPermissionRequested = false;
    notificationPermissionGranted = false;
    programReminderHour = 18;
    programReminderMinute = 30;
    programReminderMinutesBefore = 60;
    voiceCoachEnabled = false;
    voiceCoachRate = .48;
    hapticsEnabled = true;
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
    exercises = List.of(SeedData.exercises);
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
          ? await _firebase.register(
              email.trim(),
              password,
              displayName: displayName,
            )
          : await _firebase.signIn(email.trim(), password);
      uid = signedInUid;
      _store.scopeTo(uid);

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
        Map<String, dynamic>? saved;
        if (firebaseAvailable) {
          saved = await _firebase.loadSnapshot(uid);
        }
        saved ??= await _store.loadState();
        if (saved == null) {
          _prepareAccountState(
            accountUid: uid,
            email: email.trim(),
            name: email.split('@').first,
            onboardingCompleted: !firebaseAvailable,
            includeSamples: !firebaseAvailable,
          );
        } else {
          _restore(saved);
        }
      }

      profile = profile.copyWith(id: uid, email: email.trim());
      await _mergeRemoteActivityDays();
      isAuthenticated = true;
      await _store.saveAuthenticated(true);
      await _store.saveAuthenticatedUid(uid);
      // Persist the account immediately; remote catalogs can be loaded after.
      await _commit();
      await _refreshRemoteDomain();
      await _refreshTemplateExercises();
      activeWorkoutDraft = await _workoutDraftStore.load(uid);
      if (profile.onboardingCompleted) {
        await ensureProgramEnrollment(persist: false);
      }
      await _initializeMessagingIfOptedIn();
      await _commit();
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

  Future<void> resetPassword(String email) async {
    await _firebase.resetPassword(email.trim());
  }

  Future<void> _refreshTemplateExercises() async {
    if (!firebaseAvailable || uid == 'demo-user') return;
    try {
      final templates = await _firebase.loadTemplateExercises();
      final personal = exercises
          .where((exercise) => exercise.ownerId == uid)
          .toList();
      exercises = [...templates, ...personal];
    } on Object {
      // Keep the last local template cache while offline.
    }
  }

  Future<void> _refreshRemoteDomain() async {
    if (!firebaseAvailable || uid == 'demo-user') return;
    try {
      final remotePrograms = await _firebase.loadPrograms();
      final remoteVersions = await _firebase.loadProgramVersions();
      programs = remotePrograms;
      programVersions = remoteVersions;
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

  Future<void> requestDataExport() => _firebase.requestDataExport();

  Future<void> deleteAccountData() async {
    await _speech.stop();
    await _notifications.cancelAll();
    await _workoutDraftStore.clear(uid);
    await _firebase.deleteCurrentAccount();
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
        workoutCompletions.map(
          (completion) => _dateKey(completion.completedAt),
        ),
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
    if (value.name.trim().isEmpty) {
      throw ArgumentError('Họ tên không được để trống.');
    }
    if (value.heightCm < 100 || value.heightCm > 250) {
      throw ArgumentError('Chiều cao phải từ 100 đến 250 cm.');
    }
    if (value.currentWeightKg <= 0 || value.currentWeightKg > 500) {
      throw ArgumentError('Cân nặng phải lớn hơn 0 và không quá 500 kg.');
    }
    if (value.weeklyWorkoutGoal < 1 || value.weeklyWorkoutGoal > 7) {
      throw ArgumentError('Mục tiêu tuần phải từ 1 đến 7 buổi.');
    }
    final birthDate = value.dateOfBirth;
    if (birthDate != null) {
      final today = DateTime.now();
      final earliest = DateTime(today.year - 120, today.month, today.day);
      if (birthDate.isAfter(today) || birthDate.isBefore(earliest)) {
        throw ArgumentError('Ngày sinh không hợp lệ.');
      }
    }
    final targetWeight = value.targetWeightKg;
    if (targetWeight != null && (targetWeight <= 0 || targetWeight > 500)) {
      throw ArgumentError(
        'Cân nặng mục tiêu phải lớn hơn 0 và không quá 500 kg.',
      );
    }
    profile = value.copyWith(name: value.name.trim());
    await _commit();
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
  }) async {
    if (!firebaseAvailable && programs.isEmpty) {
      programs = List.of(ProgramSeedData.programs);
    }
    if (!firebaseAvailable && programVersions.isEmpty) {
      programVersions = List.of(ProgramSeedData.versions);
    }
    final current = enrollment;
    if (current != null &&
        current.status == ProgramEnrollmentStatus.active &&
        programVersions.any(
          (version) =>
              version.id == current.programVersionId && version.isPublished,
        )) {
      final version = programVersions.firstWhere(
        (item) => item.id == current.programVersionId,
      );
      final result = ProgramMatchResult(
        status: ProgramMatchStatus.matched,
        candidate: ProgramMatchCandidate(
          version: version,
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

    final result = const ProgramMatcher().match(
      preferences: trainingPreferences,
      catalog: programVersions,
      fallbackProgramVersionId: ProgramSeedData.defaultFallbackProgramVersionId,
    );
    lastProgramMatchStatus = result.status;
    final version = result.version;
    if (version == null) {
      await _cancelOpenOccurrences(enrollment?.id);
      enrollment = null;
      if (persist) await _commit();
      return result;
    }

    final now = DateTime.now();
    await _cancelOpenOccurrences(enrollment?.id);
    enrollment = ProgramEnrollment(
      id: 'enrollment-$uid-${version.id}-${now.microsecondsSinceEpoch}',
      userId: uid,
      programVersionId: version.id,
      startedAt: now,
      status: ProgramEnrollmentStatus.active,
    );
    occurrences.addAll(_buildOccurrences(version, enrollment!, now));
    await _syncProgramNotifications();
    if (persist) await _commit();
    return result;
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
      await _notifications.cancelProgramOccurrence(occurrence.id);
      _replaceOccurrence(occurrence, status: WorkoutOccurrenceStatus.cancelled);
    }
  }

  List<WorkoutOccurrence> _buildOccurrences(
    ProgramVersion version,
    ProgramEnrollment targetEnrollment,
    DateTime start,
  ) {
    final startDay = DateTime(start.year, start.month, start.day);
    final weekdays = <int>[
      ...(version.cadence.preferredWeekdays.isEmpty
          ? const [1, 3, 5]
          : version.cadence.preferredWeekdays),
    ]..sort();
    final result = <WorkoutOccurrence>[];
    var cursor = startDay;
    final weeks = [...version.weeks]
      ..sort((a, b) => a.weekNumber.compareTo(b.weekNumber));
    for (final week in weeks) {
      final sessions = [...week.sessions]
        ..sort((a, b) => a.order.compareTo(b.order));
      for (final session in sessions) {
        var scheduled = cursor;
        while (!weekdays.contains(scheduled.weekday)) {
          scheduled = scheduled.add(const Duration(days: 1));
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
          ),
        );
        cursor = scheduled.add(
          Duration(days: version.cadence.minimumRestDays + 1),
        );
      }
    }
    return result;
  }

  Future<void> chooseReadiness(
    WorkoutOccurrence occurrence,
    ReadinessChoice choice,
  ) async {
    _replaceOccurrence(
      occurrence,
      status: occurrence.status,
      readinessChoice: choice,
    );
    await _syncProgramNotifications();
    await _commit();
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
    _replaceOccurrence(
      occurrence,
      status: WorkoutOccurrenceStatus.postponed,
      scheduledDate: next,
      originalScheduledDate:
          occurrence.originalScheduledDate ?? occurrence.scheduledDate,
    );
    await _syncProgramNotifications();
    await _commit();
  }

  Future<void> skipOccurrence(WorkoutOccurrence occurrence) async {
    _replaceOccurrence(
      occurrence,
      status: WorkoutOccurrenceStatus.skipped,
      completedAt: DateTime.now(),
    );
    await _notifications.cancelProgramOccurrence(occurrence.id);
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
    if (version == null || session == null || !version.isPublished) {
      throw StateError('Phiên bản chương trình không còn khả dụng.');
    }
    final choice = occurrence.readinessChoice ?? ReadinessChoice.ready;
    final variant = session.readinessVariantFor(choice);
    if (variant?.stopWorkout ?? false) {
      throw StateError(
        variant?.safetyMessage ?? 'Hãy dừng tập và tìm hỗ trợ phù hợp.',
      );
    }
    final blocks = choice == ReadinessChoice.ready || variant == null
        ? session.blocks
        : variant.blocks;
    final prescriptions = [
      for (final block in [
        ...blocks,
      ]..sort((a, b) => a.order.compareTo(b.order)))
        ...([...block.prescriptions]
          ..sort((a, b) => a.order.compareTo(b.order))),
    ];
    if (prescriptions.isEmpty) {
      throw StateError('Buổi tập chưa có prescription hợp lệ.');
    }
    final snapshot = target.WorkoutSessionSnapshot(
      programSessionId: session.id,
      title: session.title,
      programTitle: activeProgram?.title ?? 'FitTrack Program',
      contentVersion: version.version,
      sourceRefs: version.sourceRefs.map((item) => item.url).toList(),
      exercises: prescriptions.map((item) {
        final exercise = exercises
            .where((candidate) => candidate.id == item.exerciseId)
            .firstOrNull;
        return target.WorkoutExerciseSnapshot(
          exerciseId: item.exerciseId,
          name: _resolveExerciseName(item.exerciseId, exercise?.name),
          muscleGroup: exercise?.muscleGroup ?? 'Toàn thân',
          equipment: exercise?.equipment ?? 'Không dụng cụ',
          setCount: item.sets,
          target: target.WorkoutTargetContext(
            type: item.targetType.name,
            label: item.targetLabel,
            minimum: item.targetRange.minimum,
            maximum: item.targetRange.maximum,
          ),
          restSeconds: item.restSeconds,
          cues: item.cues,
          mediaUrl: exercise?.imageUrl,
          mediaAltText: exercise?.description,
          poseRuleVersionId: item.poseRuleVersionId,
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
    await _notifications.cancelProgramOccurrence(occurrence.id);
    await _workoutDraftStore.save(uid, activeWorkoutDraft!);
    await _commit();
    return controller;
  }

  Future<void> checkpointWorkout(ActiveWorkoutController controller) async {
    activeWorkoutDraft = controller.checkpoint();
    await _workoutDraftStore.save(uid, activeWorkoutDraft!);
    await _notifications.cancelRestSession(controller.draft.sessionId);
    if (notificationsEnabled &&
        controller.phase == target.WorkoutPhase.resting &&
        controller.draft.restEndsAt != null) {
      await _notifications.scheduleRestEnd(
        sessionId: controller.draft.sessionId,
        phaseId: controller.phaseId,
        restEndsAt: controller.draft.restEndsAt!,
      );
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
      await _notifications.cancelRestSession(controller.draft.sessionId);
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
      status: WorkoutOccurrenceStatus.completed,
      completedAt: completion.completedAt,
    );
    await _recordWorkoutActivity(completion.completedAt);
    _unlockAchievements();
    await _commit();
    controller.markCompletionSaved(idempotencyKey: completion.idempotencyKey);
    await _workoutDraftStore.clear(uid);
    await _notifications.cancelRestSession(controller.draft.sessionId);
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
    await _notifications.cancelRestSession(controller.draft.sessionId);
    activeWorkoutDraft = null;
    await _commit();
  }

  void _replaceOccurrence(
    WorkoutOccurrence current, {
    required WorkoutOccurrenceStatus status,
    DateTime? scheduledDate,
    DateTime? originalScheduledDate,
    ReadinessChoice? readinessChoice,
    DateTime? startedAt,
    DateTime? completedAt,
  }) {
    final index = occurrences.indexWhere((item) => item.id == current.id);
    if (index < 0) return;
    occurrences[index] = WorkoutOccurrence(
      id: current.id,
      enrollmentId: current.enrollmentId,
      programVersionId: current.programVersionId,
      sessionId: current.sessionId,
      weekNumber: current.weekNumber,
      scheduledDate: scheduledDate ?? current.scheduledDate,
      status: status,
      originalScheduledDate:
          originalScheduledDate ?? current.originalScheduledDate,
      readinessChoice: readinessChoice ?? current.readinessChoice,
      startedAt: startedAt ?? current.startedAt,
      completedAt: completedAt ?? current.completedAt,
    );
  }

  Future<void> updateBodyMetrics({
    required double heightCm,
    required double weightKg,
    DateTime? recordedAt,
    String note = '',
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
    profile = profile.copyWith(heightCm: heightCm, currentWeightKg: weightKg);
    weightEntries.add(
      WeightEntry(
        id: _newId('body'),
        weightKg: weightKg,
        heightCm: heightCm,
        recordedAt: moment,
        note: note.trim(),
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
    notificationPermissionGranted = await _notifications.requestPermission();
    if (firebaseAvailable && notificationPermissionGranted) {
      await _notifications.initializeFirebaseMessaging(
        isEnabled: () => notificationsEnabled,
      );
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
      await _notifications.cancelAll();
    } else {
      await _initializeMessagingIfOptedIn();
    }
    for (final reminder in reminders) {
      if (value) {
        await _notifications.schedule(reminder);
      } else {
        await _notifications.cancel(reminder.id);
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

  Future<void> _syncProgramNotifications() async {
    for (final occurrence in occurrences) {
      await _notifications.cancelProgramOccurrence(occurrence.id);
      if (!notificationsEnabled ||
          !notificationPermissionGranted ||
          occurrence.status == WorkoutOccurrenceStatus.completed ||
          occurrence.status == WorkoutOccurrenceStatus.skipped ||
          occurrence.status == WorkoutOccurrenceStatus.cancelled ||
          occurrence.status == WorkoutOccurrenceStatus.inProgress) {
        continue;
      }
      final session = sessionForOccurrence(occurrence);
      final scheduledAt = DateTime(
        occurrence.scheduledDate.year,
        occurrence.scheduledDate.month,
        occurrence.scheduledDate.day,
        programReminderHour,
        programReminderMinute,
      );
      await _notifications.scheduleProgramOccurrence(
        occurrenceId: occurrence.id,
        title: session?.title ?? 'Buổi tập FitTrack',
        scheduledAt: scheduledAt,
        minutesBefore: programReminderMinutesBefore,
      );
    }
  }

  Future<void> _initializeMessagingIfOptedIn() async {
    if (!firebaseAvailable ||
        !notificationsEnabled ||
        !notificationPermissionGranted) {
      return;
    }
    await _notifications.initializeFirebaseMessaging(
      isEnabled: () => notificationsEnabled,
    );
  }

  Future<void> setThemeMode(ThemeMode value) async {
    themeMode = value;
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

  Future<void> setHapticsEnabled(bool value) async {
    hapticsEnabled = value;
    await _commit();
  }

  void _unlockAchievements() {
    final completed = workoutCompletions.length;
    // Achievement eligibility may use the better independent streak, but the
    // weight-entry and workout day sets are never combined into one sequence.
    final bestStreak = longestStreak > longestWorkoutStreak
        ? longestStreak
        : longestWorkoutStreak;
    final conditions = <String, bool>{
      'first_workout': completed >= 1,
      'streak_3': bestStreak >= 3,
      'streak_7': bestStreak >= 7,
      'workout_50': completed >= 50,
    };
    achievements = achievements.map((achievement) {
      if (!achievement.unlocked && (conditions[achievement.id] ?? false)) {
        return achievement.copyWith(unlockedAt: DateTime.now());
      }
      return achievement;
    }).toList();
  }

  Future<void> _commit() async {
    // Both streaks are time-dependent even when no new event is added.
    _recalculateWeightStreak();
    _recalculateWorkoutStreak();
    await _store.saveState(_toJson());
    try {
      await _firebase.syncSnapshot(uid, _toJson());
    } on Object {
      // Local persistence is authoritative while offline; Firebase retries can
      // be added with a durable sync queue after project configuration.
    }
    notifyListeners();
  }

  Map<String, dynamic> _toJson() => {
    'profile': profile.toJson(),
    'exercises': exercises.map((item) => item.toJson()).toList(),
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
      'hapticsEnabled': hapticsEnabled,
      'unit': unit,
    },
    'target': {
      'trainingPreferences': trainingPreferences.toJson(),
      'programs': programs.map((item) => item.toJson()).toList(),
      'programVersions': programVersions.map((item) => item.toJson()).toList(),
      'enrollment': enrollment?.toJson(),
      'occurrences': occurrences.map((item) => item.toJson()).toList(),
      'workoutCompletions': workoutCompletions
          .map((item) => item.toJson())
          .toList(),
      'lastProgramMatchStatus': lastProgramMatchStatus?.name,
    },
  };

  void _restore(Map<String, dynamic> json) {
    profile = UserProfile.fromJson(json['profile'] as Map<String, dynamic>);
    if (json['exercises'] case final List<dynamic> savedExercises) {
      exercises = savedExercises
          .map((item) => Exercise.fromJson(item as Map<String, dynamic>))
          .toList();
    }
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
    final storedAchievements = (json['achievements'] as List? ?? [])
        .map((item) => Achievement.fromJson(item as Map<String, dynamic>))
        .toList();
    final storedAchievementsById = {
      for (final achievement in storedAchievements) achievement.id: achievement,
    };
    achievements = SeedData.achievements()
        .map((achievement) {
          final unlockedAt = storedAchievementsById[achievement.id]?.unlockedAt;
          return unlockedAt == null
              ? achievement
              : achievement.copyWith(unlockedAt: unlockedAt);
        })
        .toList(growable: false);
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
    themeMode = ThemeMode.values.byName(
      settings['themeMode'] as String? ?? 'system',
    );
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
    hapticsEnabled = settings['hapticsEnabled'] as bool? ?? true;
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
      lastProgramMatchStatus = null;
    } else {
      trainingPreferences = targetState['trainingPreferences'] == null
          ? const UserTrainingPreferences.defaults()
          : UserTrainingPreferences.fromJson(
              Map<String, dynamic>.from(
                targetState['trainingPreferences'] as Map,
              ),
            );
      final storedPrograms = targetState['programs'] as List?;
      programs = storedPrograms == null
          ? List.of(ProgramSeedData.programs)
          : storedPrograms
                .map(
                  (item) =>
                      Program.fromJson(Map<String, dynamic>.from(item as Map)),
                )
                .toList();
      final storedVersions = targetState['programVersions'] as List?;
      programVersions = storedVersions == null
          ? List.of(ProgramSeedData.versions)
          : storedVersions
                .map(
                  (item) => ProgramVersion.fromJson(
                    Map<String, dynamic>.from(item as Map),
                  ),
                )
                .toList();
      enrollment = targetState['enrollment'] == null
          ? null
          : ProgramEnrollment.fromJson(
              Map<String, dynamic>.from(targetState['enrollment'] as Map),
            );
      occurrences
        ..clear()
        ..addAll(
          (targetState['occurrences'] as List? ?? const []).map(
            (item) => WorkoutOccurrence.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          ),
        );
      workoutCompletions
        ..clear()
        ..addAll(
          (targetState['workoutCompletions'] as List? ?? const []).map(
            (item) => target.WorkoutCompletion.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          ),
        );
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
    final message = error.toString().toLowerCase();
    if (message.contains('wrong-password') ||
        message.contains('invalid-credential')) {
      return 'Email hoặc mật khẩu không đúng.';
    }
    if (message.contains('email-already-in-use')) {
      return 'Email này đã được sử dụng.';
    }
    if (message.contains('network')) {
      return 'Không thể kết nối mạng. Hãy thử lại.';
    }
    return 'Không thể hoàn thành thao tác. Hãy kiểm tra dữ liệu và thử lại.';
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
      _ => rawName ?? id,
    };
  }
}
