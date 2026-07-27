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
  }) => ActiveWorkoutController(initialDraft: draft, clock: clock);

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

  Duration get activeDuration => _draft.activeDurationAt(_clock());
  Duration get restRemaining => _draft.restRemainingAt(_clock());
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
      phase: WorkoutPhase.working,
      startedAt: now,
      runningSince: now,
      restEndsAt: null,
      pausedFrom: null,
      pausedRestRemainingMilliseconds: null,
      savedAt: now,
    );
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
    _replace(confirmationMode: mode, savedAt: _clock());
    return true;
  }

  bool completeSet({
    String? expectedPhaseId,
    int? detectedRepCount,
    double? confidence,
  }) {
    if (!_accepts(expectedPhaseId)) return false;
    _requirePhase({WorkoutPhase.working}, 'complete a set');
    _validateDetection(detectedRepCount, confidence);
    _recordAndAdvance(
      SetEventStatus.completed,
      detectedRepCount: detectedRepCount,
      confidence: confidence,
    );
    return true;
  }

  bool redoSet({String? expectedPhaseId}) {
    if (!_accepts(expectedPhaseId)) return false;
    _requirePhase({WorkoutPhase.working}, 'redo a set');
    final now = _clock();
    final event = _buildEvent(status: SetEventStatus.redone, at: now);
    _replace(setEvents: [..._draft.setEvents, event], savedAt: now);
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
    _replace(phase: WorkoutPhase.working, restEndsAt: null, savedAt: _clock());
    return true;
  }

  /// Reconciles a rest deadline after a UI tick, background or process death.
  /// No storage write is needed while the deadline has not elapsed.
  bool reconcile({String? expectedPhaseId}) {
    if (!_accepts(expectedPhaseId)) return false;
    if (_draft.phase != WorkoutPhase.resting) return false;
    final now = _clock();
    if (_draft.restEndsAt!.isAfter(now)) return false;
    _replace(phase: WorkoutPhase.working, restEndsAt: null, savedAt: now);
    return true;
  }

  bool pause({String? expectedPhaseId}) {
    if (!_accepts(expectedPhaseId)) return false;
    _requirePhase({WorkoutPhase.working, WorkoutPhase.resting}, 'pause');
    final now = _clock();
    final previous = _draft.phase;
    final remaining = previous == WorkoutPhase.resting
        ? _draft.restRemainingAt(now).inMilliseconds
        : null;
    _replace(
      phase: WorkoutPhase.paused,
      accumulatedActiveMilliseconds: _activeMillisecondsAt(now),
      runningSince: null,
      restEndsAt: null,
      pausedFrom: previous,
      pausedRestRemainingMilliseconds: remaining,
      savedAt: now,
    );
    return true;
  }

  bool resume({String? expectedPhaseId}) {
    if (!_accepts(expectedPhaseId)) return false;
    _requirePhase({WorkoutPhase.paused}, 'resume');
    final now = _clock();
    final previous = _draft.pausedFrom ?? WorkoutPhase.working;
    if (previous != WorkoutPhase.working && previous != WorkoutPhase.resting) {
      throw StateError(
        'Paused checkpoint has invalid previous phase: $previous',
      );
    }
    final remaining = _draft.pausedRestRemainingMilliseconds ?? 0;
    final resumeIntoRest = previous == WorkoutPhase.resting && remaining > 0;
    _replace(
      phase: resumeIntoRest ? WorkoutPhase.resting : WorkoutPhase.working,
      runningSince: now,
      restEndsAt: resumeIntoRest
          ? now.add(Duration(milliseconds: remaining))
          : null,
      pausedFrom: null,
      pausedRestRemainingMilliseconds: null,
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
      WorkoutPhase.working,
      WorkoutPhase.resting,
      WorkoutPhase.paused,
    }, 'discard');
    final now = _clock();
    final accumulated =
        phase == WorkoutPhase.working || phase == WorkoutPhase.resting
        ? _activeMillisecondsAt(now)
        : _draft.accumulatedActiveMilliseconds;
    _replace(
      phase: WorkoutPhase.discarded,
      accumulatedActiveMilliseconds: accumulated,
      runningSince: null,
      restEndsAt: null,
      pausedFrom: null,
      pausedRestRemainingMilliseconds: null,
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
  }) {
    final now = _clock();
    final event = _buildEvent(
      status: status,
      at: now,
      skipReason: skipReason,
      detectedRepCount: detectedRepCount,
      confidence: confidence,
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
      _replace(setEvents: events, savedAt: now);
      _enterFinishing(now);
      return;
    }

    if (exercise.restSeconds > 0) {
      _replace(
        phase: WorkoutPhase.resting,
        exerciseIndex: nextExerciseIndex,
        setIndex: nextSetIndex,
        restEndsAt: now.add(Duration(seconds: exercise.restSeconds)),
        setEvents: events,
        savedAt: now,
      );
    } else {
      _replace(
        phase: WorkoutPhase.working,
        exerciseIndex: nextExerciseIndex,
        setIndex: nextSetIndex,
        restEndsAt: null,
        setEvents: events,
        savedAt: now,
      );
    }
  }

  SetEvent _buildEvent({
    required SetEventStatus status,
    required DateTime at,
    String? skipReason,
    int? detectedRepCount,
    double? confidence,
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
    completedAt: at,
  );

  void _validateDetection(int? detectedRepCount, double? confidence) {
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
        (detectedRepCount != null || confidence != null)) {
      throw ArgumentError(
        'Guided confirmation must not store inferred numeric results',
      );
    }
  }

  void _enterFinishing(DateTime now) {
    if (phase == WorkoutPhase.finishing || phase == WorkoutPhase.completed) {
      return;
    }
    final accumulated =
        phase == WorkoutPhase.working || phase == WorkoutPhase.resting
        ? _activeMillisecondsAt(now)
        : _draft.accumulatedActiveMilliseconds;
    _replace(
      phase: WorkoutPhase.finishing,
      accumulatedActiveMilliseconds: accumulated,
      runningSince: null,
      restEndsAt: null,
      pausedFrom: null,
      pausedRestRemainingMilliseconds: null,
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
      status: isComplete
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

  void _requirePhase(Set<WorkoutPhase> allowed, String action) {
    if (!allowed.contains(_draft.phase)) {
      throw StateError('Cannot $action while workout is ${_draft.phase.name}');
    }
  }

  void _replace({
    WorkoutPhase? phase,
    int? exerciseIndex,
    int? setIndex,
    Object? startedAt = activeWorkoutUnset,
    Object? runningSince = activeWorkoutUnset,
    int? accumulatedActiveMilliseconds,
    Object? restEndsAt = activeWorkoutUnset,
    WorkoutConfirmationMode? confirmationMode,
    List<SetEvent>? setEvents,
    Object? pausedFrom = activeWorkoutUnset,
    Object? pausedRestRemainingMilliseconds = activeWorkoutUnset,
    Object? finishRequestedAt = activeWorkoutUnset,
    DateTime? savedAt,
  }) {
    final nextSequence = _draft.transitionSequence + 1;
    _draft = _draft.copyWith(
      phase: phase,
      phaseId: '${_draft.sessionId}:$nextSequence',
      transitionSequence: nextSequence,
      exerciseIndex: exerciseIndex,
      setIndex: setIndex,
      startedAt: startedAt,
      runningSince: runningSince,
      accumulatedActiveMilliseconds: accumulatedActiveMilliseconds,
      restEndsAt: restEndsAt,
      confirmationMode: confirmationMode,
      setEvents: setEvents,
      pausedFrom: pausedFrom,
      pausedRestRemainingMilliseconds: pausedRestRemainingMilliseconds,
      finishRequestedAt: finishRequestedAt,
      savedAt: savedAt,
    );
    notifyListeners();
  }
}
