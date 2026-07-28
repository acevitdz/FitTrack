import 'package:flutter/foundation.dart';

import '../models/active_workout.dart';

typedef WorkoutClock = DateTime Function();

/// Deterministic state machine for a guided workout.
///
/// Device concerns (camera, TTS and notifications) deliberately stay outside
/// this class. Their callbacks must pass [expectedPhaseId], so a late callback
/// cannot mutate a newer phase.
class ActiveWorkoutController extends ChangeNotifier {
  ActiveWorkoutController({
    required ActiveWorkoutDraft initialDraft,
    WorkoutClock? clock,
  }) : _draft = initialDraft,
       _clock = clock ?? DateTime.now;

  factory ActiveWorkoutController.create({
    required String sessionId,
    required String userId,
    required String occurrenceId,
    required String programVersionId,
    required WorkoutSessionSnapshot snapshot,
    WorkoutConfirmationMode confirmationMode = WorkoutConfirmationMode.guided,
    WorkoutClock? clock,
  }) {
    final resolvedClock = clock ?? DateTime.now;
    final now = resolvedClock();
    return ActiveWorkoutController(
      clock: resolvedClock,
      initialDraft: ActiveWorkoutDraft(
        sessionId: sessionId,
        userId: userId,
        occurrenceId: occurrenceId,
        programVersionId: programVersionId,
        snapshot: snapshot,
        phase: WorkoutPhase.preparing,
        phaseId: '$sessionId:0',
        transitionSequence: 0,
        exerciseIndex: 0,
        setIndex: 0,
        accumulatedActiveMilliseconds: 0,
        confirmationMode: confirmationMode,
        setEvents: const [],
        savedAt: now,
        completionIdempotencyKey: '$userId:$occurrenceId:$sessionId',
      ),
    );
  }

  factory ActiveWorkoutController.restore(
    ActiveWorkoutDraft draft, {
    WorkoutClock? clock,
  }) {
    final controller = ActiveWorkoutController(
      initialDraft: draft,
      clock: clock,
    );
    // Migrate a pre-countdown Guided checkpoint that was already in working
    // phase. New checkpoints start the timer when preparation reconciles.
    if (controller.phase == WorkoutPhase.working &&
        controller.usesGuidedTimer &&
        !controller.isTimedSetRunning &&
        controller.draft.timedSetElapsedMilliseconds == 0) {
      controller.startTimedSet();
    }
    return controller;
  }

  ActiveWorkoutDraft _draft;
  final WorkoutClock _clock;

  ActiveWorkoutDraft get draft => _draft;
  WorkoutPhase get phase => _draft.phase;
  String get phaseId => _draft.phaseId;
  int get exerciseIndex => _draft.exerciseIndex;
  int get setIndex => _draft.setIndex;
  WorkoutConfirmationMode get confirmationMode => _draft.confirmationMode;
  List<SetEvent> get setEvents => _draft.setEvents;
  WorkoutExerciseSnapshot get currentExercise =>
      _draft.snapshot.exercises[_draft.exerciseIndex];

  WorkoutExerciseSnapshot? get nextExercise {
    final nextIndex = _draft.exerciseIndex + 1;
    return nextIndex < _draft.snapshot.exercises.length
        ? _draft.snapshot.exercises[nextIndex]
        : null;
  }

  bool get isTimedSet => currentExercise.workDurationSeconds > 0;
  bool get usesGuidedTimer =>
      confirmationMode == WorkoutConfirmationMode.guided && isTimedSet;
  bool get isTimedSetRunning => _draft.timedSetStartedAt != null;
  int get timedSetTargetSeconds =>
      isTimedSet ? currentExercise.workDurationSeconds : 0;
  Duration get timedSetRemaining {
    if (!isTimedSet) return Duration.zero;
    final remaining =
        Duration(seconds: timedSetTargetSeconds) -
        _draft.timedSetElapsedAt(_clock());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  Duration get activeDuration => _draft.activeDurationAt(_clock());
  Duration get restRemaining => _draft.restRemainingAt(_clock());
  Duration get preparationRemaining => _draft.preparationRemainingAt(_clock());
  bool get isTerminal =>
      phase == WorkoutPhase.completed || phase == WorkoutPhase.discarded;
  bool get hasPendingCompletion => phase == WorkoutPhase.finishing;

  bool isCurrentPhase(String candidate) => candidate == _draft.phaseId;

  /// Returns a checkpoint without generating timer ticks or changing phase.
  ActiveWorkoutDraft checkpoint() => _draft.copyWith(savedAt: _clock());

  String checkpointJson() => checkpoint().toJsonString();

  bool start({String? expectedPhaseId}) {
    if (!_accepts(expectedPhaseId)) return false;
    _requirePhase({WorkoutPhase.preparing}, 'start');
    final now = _clock();
    _replace(
      phase: WorkoutPhase.countingDown,
      startedAt: now,
      runningSince: now,
      restEndsAt: null,
      preparationEndsAt: now.add(
        Duration(seconds: currentExercise.preparationSeconds),
      ),
      pausedFrom: null,
      pausedRestRemainingMilliseconds: null,
      pausedPreparationRemainingMilliseconds: null,
      savedAt: now,
    );
    if (currentExercise.preparationSeconds == 0) {
      _enterWorking(now);
    }
    return true;
  }

  bool setConfirmationMode(
    WorkoutConfirmationMode mode, {
    String? expectedPhaseId,
  }) {
    if (!_accepts(expectedPhaseId)) return false;
    _requirePhase({
      WorkoutPhase.preparing,
      WorkoutPhase.working,
      WorkoutPhase.resting,
    }, 'change confirmation mode');
    if (mode == _draft.confirmationMode) return false;
    final now = _clock();
    final startGuidedTimer =
        phase == WorkoutPhase.working &&
        mode == WorkoutConfirmationMode.guided &&
        isTimedSet;
    _replace(
      confirmationMode: mode,
      timedSetStartedAt: startGuidedTimer ? now : null,
      timedSetElapsedMilliseconds: 0,
      pausedTimedSetWasRunning: false,
      savedAt: now,
    );
    return true;
  }

  bool selectAlternative(String exerciseId, {String? expectedPhaseId}) {
    if (!_accepts(expectedPhaseId)) return false;
    _requirePhase({
      WorkoutPhase.preparing,
      WorkoutPhase.working,
    }, 'select an alternative');
    if (isTimedSetRunning || _draft.timedSetElapsedMilliseconds > 0) {
      throw StateError('Cannot change exercise after a timed set has started');
    }
    final alternative = currentExercise.alternatives
        .where((item) => item.exerciseId == exerciseId)
        .firstOrNull;
    if (alternative == null) {
      throw ArgumentError.value(
        exerciseId,
        'exerciseId',
        'Not an authored alternative for the current exercise',
      );
    }
    if (currentExercise.exerciseId == exerciseId) return false;
    final snapshot = _draft.snapshot.replaceExercise(
      exerciseIndex,
      currentExercise.selectAlternative(alternative),
    );
    _replace(snapshot: snapshot, savedAt: _clock());
    return true;
  }

  bool startTimedSet({String? expectedPhaseId}) {
    if (!_accepts(expectedPhaseId)) return false;
    _requirePhase({WorkoutPhase.working}, 'start a timed set');
    if (!usesGuidedTimer) {
      throw StateError('The current set is not time-based');
    }
    if (isTimedSetRunning) return false;
    if (timedSetRemaining == Duration.zero) {
      return reconcileTimedSet(expectedPhaseId: expectedPhaseId);
    }
    final now = _clock();
    _replace(timedSetStartedAt: now, savedAt: now);
    return true;
  }

  bool pauseTimedSet({String? expectedPhaseId}) {
    if (!_accepts(expectedPhaseId)) return false;
    _requirePhase({WorkoutPhase.working}, 'pause a timed set');
    if (!usesGuidedTimer || !isTimedSetRunning) return false;
    final now = _clock();
    _replace(
      timedSetStartedAt: null,
      timedSetElapsedMilliseconds: _draft.timedSetElapsedAt(now).inMilliseconds,
      savedAt: now,
    );
    return true;
  }

  bool reconcileTimedSet({String? expectedPhaseId}) {
    if (!_accepts(expectedPhaseId)) return false;
    if (phase != WorkoutPhase.working ||
        !usesGuidedTimer ||
        timedSetRemaining > Duration.zero) {
      return false;
    }
    _recordAndAdvance(SetEventStatus.completed);
    return true;
  }

  bool completeSet({
    String? expectedPhaseId,
    int? detectedRepCount,
    double? confidence,
    CameraSetEvidence? cameraEvidence,
  }) {
    if (!_accepts(expectedPhaseId)) return false;
    _requirePhase({WorkoutPhase.working}, 'complete a set');
    _validateDetection(detectedRepCount, confidence, cameraEvidence);
    if (usesGuidedTimer && timedSetRemaining > Duration.zero) {
      throw StateError('Timed set has not reached its authored duration');
    }
    _recordAndAdvance(
      SetEventStatus.completed,
      detectedRepCount: detectedRepCount,
      confidence: confidence,
      cameraEvidence: cameraEvidence,
    );
    return true;
  }

  bool redoSet({String? expectedPhaseId}) {
    if (!_accepts(expectedPhaseId)) return false;
    _requirePhase({WorkoutPhase.working}, 'redo a set');
    final now = _clock();
    final event = _buildEvent(status: SetEventStatus.redone, at: now);
    _replace(
      phase: WorkoutPhase.countingDown,
      setEvents: [..._draft.setEvents, event],
      preparationEndsAt: now.add(
        Duration(seconds: currentExercise.preparationSeconds),
      ),
      timedSetStartedAt: null,
      timedSetElapsedMilliseconds: 0,
      savedAt: now,
    );
    if (currentExercise.preparationSeconds == 0) _enterWorking(now);
    return true;
  }

  bool skipSet({required String reason, String? expectedPhaseId}) {
    if (!_accepts(expectedPhaseId)) return false;
    _requirePhase({WorkoutPhase.working}, 'skip a set');
    if (reason.trim().isEmpty) {
      throw ArgumentError.value(
        reason,
        'reason',
        'A predefined skip reason is required',
      );
    }
    _recordAndAdvance(SetEventStatus.skipped, skipReason: reason);
    return true;
  }

  bool extendRest({
    Duration by = const Duration(seconds: 15),
    String? expectedPhaseId,
  }) {
    if (!_accepts(expectedPhaseId)) return false;
    _requirePhase({WorkoutPhase.resting}, 'extend rest');
    if (by <= Duration.zero) {
      throw ArgumentError.value(by, 'by', 'Must be positive');
    }
    final now = _clock();
    final end = _draft.restEndsAt!;
    final base = end.isAfter(now) ? end : now;
    _replace(restEndsAt: base.add(by), savedAt: now);
    return true;
  }

  bool skipRest({String? expectedPhaseId}) {
    if (!_accepts(expectedPhaseId)) return false;
    _requirePhase({WorkoutPhase.resting}, 'skip rest');
    _enterPreparation(_clock());
    return true;
  }

  bool skipPreparation({String? expectedPhaseId}) {
    if (!_accepts(expectedPhaseId)) return false;
    _requirePhase({WorkoutPhase.countingDown}, 'skip preparation');
    _enterWorking(_clock());
    return true;
  }

  /// Reconciles rest and preparation deadlines after a UI tick, background or
  /// process death. A backgrounded work interval starts only after the app has
  /// reconciled preparation, so the user never loses exercise time off-screen.
  bool reconcile({String? expectedPhaseId}) {
    if (!_accepts(expectedPhaseId)) return false;
    final now = _clock();
    if (_draft.phase == WorkoutPhase.resting) {
      if (_draft.restEndsAt!.isAfter(now)) return false;
      _enterPreparation(now);
      return true;
    }
    if (_draft.phase == WorkoutPhase.countingDown) {
      if (_draft.preparationEndsAt!.isAfter(now)) return false;
      _enterWorking(now);
      return true;
    }
    return false;
  }

  bool pause({String? expectedPhaseId}) {
    if (!_accepts(expectedPhaseId)) return false;
    _requirePhase({
      WorkoutPhase.countingDown,
      WorkoutPhase.working,
      WorkoutPhase.resting,
    }, 'pause');
    final now = _clock();
    final previous = _draft.phase;
    final timedSetWasRunning =
        previous == WorkoutPhase.working && isTimedSetRunning;
    final remaining = previous == WorkoutPhase.resting
        ? _draft.restRemainingAt(now).inMilliseconds
        : null;
    final preparationRemaining = previous == WorkoutPhase.countingDown
        ? _draft.preparationRemainingAt(now).inMilliseconds
        : null;
    _replace(
      phase: WorkoutPhase.paused,
      accumulatedActiveMilliseconds: _activeMillisecondsAt(now),
      runningSince: null,
      restEndsAt: null,
      preparationEndsAt: null,
      pausedFrom: previous,
      pausedRestRemainingMilliseconds: remaining,
      pausedPreparationRemainingMilliseconds: preparationRemaining,
      timedSetStartedAt: null,
      timedSetElapsedMilliseconds: timedSetWasRunning
          ? _draft.timedSetElapsedAt(now).inMilliseconds
          : _draft.timedSetElapsedMilliseconds,
      pausedTimedSetWasRunning: timedSetWasRunning,
      savedAt: now,
    );
    return true;
  }

  bool resume({String? expectedPhaseId}) {
    if (!_accepts(expectedPhaseId)) return false;
    _requirePhase({WorkoutPhase.paused}, 'resume');
    final now = _clock();
    final previous = _draft.pausedFrom ?? WorkoutPhase.working;
    if (previous != WorkoutPhase.countingDown &&
        previous != WorkoutPhase.working &&
        previous != WorkoutPhase.resting) {
      throw StateError(
        'Paused checkpoint has invalid previous phase: $previous',
      );
    }
    final remaining = _draft.pausedRestRemainingMilliseconds ?? 0;
    final preparationRemaining =
        _draft.pausedPreparationRemainingMilliseconds ?? 0;
    final resumeIntoRest = previous == WorkoutPhase.resting && remaining > 0;
    final resumeIntoPreparation =
        previous == WorkoutPhase.countingDown && preparationRemaining > 0;
    _replace(
      phase: resumeIntoRest
          ? WorkoutPhase.resting
          : resumeIntoPreparation
          ? WorkoutPhase.countingDown
          : WorkoutPhase.working,
      runningSince: now,
      restEndsAt: resumeIntoRest
          ? now.add(Duration(milliseconds: remaining))
          : null,
      preparationEndsAt: resumeIntoPreparation
          ? now.add(Duration(milliseconds: preparationRemaining))
          : null,
      pausedFrom: null,
      pausedRestRemainingMilliseconds: null,
      pausedPreparationRemainingMilliseconds: null,
      timedSetStartedAt:
          !resumeIntoRest &&
              !resumeIntoPreparation &&
              previous == WorkoutPhase.working &&
              _draft.pausedTimedSetWasRunning
          ? now
          : null,
      pausedTimedSetWasRunning: false,
      savedAt: now,
    );
    return true;
  }

  /// Freezes the session and returns the same completion and idempotency key on
  /// every retry. Call [markCompletionSaved] only after durable save succeeds.
  WorkoutCompletion finish({String? expectedPhaseId}) {
    if (!_accepts(expectedPhaseId)) {
      throw StateError('Ignoring finish from stale phase $expectedPhaseId');
    }
    if (phase == WorkoutPhase.completed || phase == WorkoutPhase.finishing) {
      return _buildCompletion();
    }
    _requirePhase({
      WorkoutPhase.working,
      WorkoutPhase.countingDown,
      WorkoutPhase.resting,
      WorkoutPhase.paused,
    }, 'finish');
    _enterFinishing(_clock());
    return _buildCompletion();
  }

  /// Completes the second half of the finish transaction. Repeating this call
  /// with the same key is a no-op; a different key is rejected.
  WorkoutCompletion markCompletionSaved({required String idempotencyKey}) {
    if (idempotencyKey != _draft.completionIdempotencyKey) {
      throw ArgumentError.value(
        idempotencyKey,
        'idempotencyKey',
        'Does not belong to this workout',
      );
    }
    if (phase == WorkoutPhase.completed) return _buildCompletion();
    _requirePhase({WorkoutPhase.finishing}, 'mark completion saved');
    _replace(phase: WorkoutPhase.completed, savedAt: _clock());
    return _buildCompletion();
  }

  bool discard({String? expectedPhaseId}) {
    if (!_accepts(expectedPhaseId)) return false;
    _requirePhase({
      WorkoutPhase.preparing,
      WorkoutPhase.countingDown,
      WorkoutPhase.working,
      WorkoutPhase.resting,
      WorkoutPhase.paused,
    }, 'discard');
    final now = _clock();
    final accumulated =
        phase == WorkoutPhase.countingDown ||
            phase == WorkoutPhase.working ||
            phase == WorkoutPhase.resting
        ? _activeMillisecondsAt(now)
        : _draft.accumulatedActiveMilliseconds;
    _replace(
      phase: WorkoutPhase.discarded,
      accumulatedActiveMilliseconds: accumulated,
      runningSince: null,
      restEndsAt: null,
      preparationEndsAt: null,
      pausedFrom: null,
      pausedRestRemainingMilliseconds: null,
      pausedPreparationRemainingMilliseconds: null,
      timedSetStartedAt: null,
      timedSetElapsedMilliseconds: 0,
      pausedTimedSetWasRunning: false,
      savedAt: now,
    );
    return true;
  }

  bool _accepts(String? expectedPhaseId) =>
      expectedPhaseId == null || expectedPhaseId == _draft.phaseId;

  void _recordAndAdvance(
    SetEventStatus status, {
    String? skipReason,
    int? detectedRepCount,
    double? confidence,
    CameraSetEvidence? cameraEvidence,
  }) {
    final now = _clock();
    final event = _buildEvent(
      status: status,
      at: now,
      skipReason: skipReason,
      detectedRepCount: detectedRepCount,
      confidence: confidence,
      cameraEvidence: cameraEvidence,
    );
    final events = [..._draft.setEvents, event];
    final exercise = currentExercise;
    var nextExerciseIndex = exerciseIndex;
    var nextSetIndex = setIndex + 1;
    if (nextSetIndex >= exercise.setCount) {
      nextExerciseIndex += 1;
      nextSetIndex = 0;
    }

    if (nextExerciseIndex >= _draft.snapshot.exercises.length) {
      _replace(
        setEvents: events,
        timedSetStartedAt: null,
        timedSetElapsedMilliseconds: 0,
        pausedTimedSetWasRunning: false,
        savedAt: now,
      );
      _enterFinishing(now);
      return;
    }

    final isChangingExercise = nextExerciseIndex != exerciseIndex;
    final restSeconds = isChangingExercise
        ? exercise.transitionAfterExerciseSeconds
        : exercise.restBetweenSetsSeconds;
    if (restSeconds > 0) {
      _replace(
        phase: WorkoutPhase.resting,
        exerciseIndex: nextExerciseIndex,
        setIndex: nextSetIndex,
        restEndsAt: now.add(Duration(seconds: restSeconds)),
        preparationEndsAt: null,
        setEvents: events,
        timedSetStartedAt: null,
        timedSetElapsedMilliseconds: 0,
        pausedTimedSetWasRunning: false,
        savedAt: now,
      );
    } else {
      _replace(
        phase: WorkoutPhase.countingDown,
        exerciseIndex: nextExerciseIndex,
        setIndex: nextSetIndex,
        restEndsAt: null,
        preparationEndsAt: now.add(
          Duration(
            seconds:
                _draft.snapshot.exercises[nextExerciseIndex].preparationSeconds,
          ),
        ),
        setEvents: events,
        timedSetStartedAt: null,
        timedSetElapsedMilliseconds: 0,
        pausedTimedSetWasRunning: false,
        savedAt: now,
      );
      if (currentExercise.preparationSeconds == 0) _enterWorking(now);
    }
  }

  SetEvent _buildEvent({
    required SetEventStatus status,
    required DateTime at,
    String? skipReason,
    int? detectedRepCount,
    double? confidence,
    CameraSetEvidence? cameraEvidence,
  }) => SetEvent(
    id: '${_draft.sessionId}:${_draft.phaseId}:${_draft.setEvents.length}',
    exerciseId: currentExercise.exerciseId,
    exerciseIndex: exerciseIndex,
    setIndex: setIndex,
    targetContext: currentExercise.target,
    confirmationMode: confirmationMode,
    status: status,
    skipReason: skipReason,
    detectedRepCount: detectedRepCount,
    confidence: confidence,
    cameraEvidence: cameraEvidence,
    timedDurationSeconds: usesGuidedTimer
        ? _draft.timedSetElapsedAt(at).inMilliseconds ~/
              Duration.millisecondsPerSecond
        : null,
    completedAt: at,
  );

  void _validateDetection(
    int? detectedRepCount,
    double? confidence,
    CameraSetEvidence? cameraEvidence,
  ) {
    if (detectedRepCount != null && detectedRepCount < 0) {
      throw ArgumentError.value(
        detectedRepCount,
        'detectedRepCount',
        'Must not be negative',
      );
    }
    if (confidence != null && (confidence < 0 || confidence > 1)) {
      throw ArgumentError.value(
        confidence,
        'confidence',
        'Must be between 0 and 1',
      );
    }
    if (confirmationMode == WorkoutConfirmationMode.guided &&
        (detectedRepCount != null ||
            confidence != null ||
            cameraEvidence != null)) {
      throw ArgumentError(
        'Guided confirmation must not store inferred numeric results',
      );
    }
    if (cameraEvidence != null &&
        confirmationMode != WorkoutConfirmationMode.aiCamera) {
      throw ArgumentError(
        'Camera evidence is only valid for AI Camera confirmation',
      );
    }
  }

  void _enterFinishing(DateTime now) {
    if (phase == WorkoutPhase.finishing || phase == WorkoutPhase.completed) {
      return;
    }
    final accumulated =
        phase == WorkoutPhase.countingDown ||
            phase == WorkoutPhase.working ||
            phase == WorkoutPhase.resting
        ? _activeMillisecondsAt(now)
        : _draft.accumulatedActiveMilliseconds;
    _replace(
      phase: WorkoutPhase.finishing,
      accumulatedActiveMilliseconds: accumulated,
      runningSince: null,
      restEndsAt: null,
      preparationEndsAt: null,
      pausedFrom: null,
      pausedRestRemainingMilliseconds: null,
      pausedPreparationRemainingMilliseconds: null,
      timedSetStartedAt: null,
      timedSetElapsedMilliseconds: 0,
      pausedTimedSetWasRunning: false,
      finishRequestedAt: now,
      savedAt: now,
    );
  }

  WorkoutCompletion _buildCompletion() {
    if (phase != WorkoutPhase.finishing && phase != WorkoutPhase.completed) {
      throw StateError('Completion is not ready while phase is $phase');
    }
    final terminalEvents = _draft.setEvents.where(
      (event) =>
          event.status == SetEventStatus.completed ||
          event.status == SetEventStatus.skipped,
    );
    final isComplete =
        terminalEvents.length == _draft.snapshot.totalSetCount &&
        terminalEvents.every(
          (event) => event.status == SetEventStatus.completed,
        );
    final completedSetCount = terminalEvents
        .where((event) => event.status == SetEventStatus.completed)
        .length;
    return WorkoutCompletion(
      id: '${_draft.sessionId}:completion',
      idempotencyKey: _draft.completionIdempotencyKey,
      userId: _draft.userId,
      occurrenceId: _draft.occurrenceId,
      programVersionId: _draft.programVersionId,
      snapshot: _draft.snapshot,
      actualStartedAt: _draft.startedAt!,
      actualDurationSeconds:
          _draft.accumulatedActiveMilliseconds ~/
          Duration.millisecondsPerSecond,
      setEvents: _draft.setEvents,
      status: completedSetCount == 0
          ? WorkoutCompletionStatus.abandoned
          : isComplete
          ? WorkoutCompletionStatus.completed
          : WorkoutCompletionStatus.partiallyCompleted,
      completedAt: _draft.finishRequestedAt!,
    );
  }

  int _activeMillisecondsAt(DateTime now) {
    final started = _draft.runningSince;
    if (started == null) return _draft.accumulatedActiveMilliseconds;
    final delta = now.difference(started).inMilliseconds;
    return _draft.accumulatedActiveMilliseconds + (delta > 0 ? delta : 0);
  }

  void _enterPreparation(DateTime now) {
    final seconds = currentExercise.preparationSeconds;
    _replace(
      phase: WorkoutPhase.countingDown,
      restEndsAt: null,
      preparationEndsAt: now.add(Duration(seconds: seconds)),
      pausedFrom: null,
      pausedRestRemainingMilliseconds: null,
      pausedPreparationRemainingMilliseconds: null,
      timedSetStartedAt: null,
      timedSetElapsedMilliseconds: 0,
      pausedTimedSetWasRunning: false,
      savedAt: now,
    );
    if (seconds == 0) _enterWorking(now);
  }

  void _enterWorking(DateTime now) {
    _replace(
      phase: WorkoutPhase.working,
      restEndsAt: null,
      preparationEndsAt: null,
      pausedFrom: null,
      pausedRestRemainingMilliseconds: null,
      pausedPreparationRemainingMilliseconds: null,
      timedSetStartedAt: confirmationMode == WorkoutConfirmationMode.guided
          ? now
          : null,
      timedSetElapsedMilliseconds: 0,
      pausedTimedSetWasRunning: false,
      savedAt: now,
    );
  }

  void _requirePhase(Set<WorkoutPhase> allowed, String action) {
    if (!allowed.contains(_draft.phase)) {
      throw StateError('Cannot $action while workout is ${_draft.phase.name}');
    }
  }

  void _replace({
    WorkoutSessionSnapshot? snapshot,
    WorkoutPhase? phase,
    int? exerciseIndex,
    int? setIndex,
    Object? startedAt = activeWorkoutUnset,
    Object? runningSince = activeWorkoutUnset,
    int? accumulatedActiveMilliseconds,
    Object? restEndsAt = activeWorkoutUnset,
    Object? preparationEndsAt = activeWorkoutUnset,
    WorkoutConfirmationMode? confirmationMode,
    List<SetEvent>? setEvents,
    Object? pausedFrom = activeWorkoutUnset,
    Object? pausedRestRemainingMilliseconds = activeWorkoutUnset,
    Object? pausedPreparationRemainingMilliseconds = activeWorkoutUnset,
    Object? timedSetStartedAt = activeWorkoutUnset,
    int? timedSetElapsedMilliseconds,
    bool? pausedTimedSetWasRunning,
    Object? finishRequestedAt = activeWorkoutUnset,
    DateTime? savedAt,
  }) {
    final nextSequence = _draft.transitionSequence + 1;
    _draft = _draft.copyWith(
      snapshot: snapshot,
      phase: phase,
      phaseId: '${_draft.sessionId}:$nextSequence',
      transitionSequence: nextSequence,
      exerciseIndex: exerciseIndex,
      setIndex: setIndex,
      startedAt: startedAt,
      runningSince: runningSince,
      accumulatedActiveMilliseconds: accumulatedActiveMilliseconds,
      restEndsAt: restEndsAt,
      preparationEndsAt: preparationEndsAt,
      confirmationMode: confirmationMode,
      setEvents: setEvents,
      pausedFrom: pausedFrom,
      pausedRestRemainingMilliseconds: pausedRestRemainingMilliseconds,
      pausedPreparationRemainingMilliseconds:
          pausedPreparationRemainingMilliseconds,
      timedSetStartedAt: timedSetStartedAt,
      timedSetElapsedMilliseconds: timedSetElapsedMilliseconds,
      pausedTimedSetWasRunning: pausedTimedSetWasRunning,
      finishRequestedAt: finishRequestedAt,
      savedAt: savedAt,
    );
    notifyListeners();
  }
}
