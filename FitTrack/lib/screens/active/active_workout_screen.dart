import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/active_workout.dart';
import '../../models/exercise.dart';
import '../../models/pose_coach.dart';
import '../../services/active_workout_controller.dart';
import '../../services/pose_feedback_voice_gate.dart';
import '../../services/repetition_cue_scheduler.dart';
import '../../services/voice_cue_service.dart';
import '../../services/workout_timer_cue.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/camera_coach_panel.dart';
import '../../widgets/design_system.dart';

class ActiveWorkoutScreen extends StatefulWidget {
  const ActiveWorkoutScreen({
    super.key,
    required this.state,
    required this.controller,
    this.onOpenHistory,
  });

  final AppState state;
  final ActiveWorkoutController controller;
  final VoidCallback? onOpenHistory;

  @override
  State<ActiveWorkoutScreen> createState() => _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends State<ActiveWorkoutScreen>
    with WidgetsBindingObserver {
  Timer? _ticker;
  WorkoutCompletion? _completion;
  PoseCoachResult? _lastPoseResult;
  final _cameraEvidence = _CameraEvidenceAccumulator();
  final _poseFeedbackVoiceGate = PoseFeedbackVoiceGate();
  final _timerCueTracker = WorkoutTimerCueTracker();
  final _voiceCueService = VoiceCueService();
  RepetitionCueScheduler? _repScheduler;
  bool _saving = false;
  bool _aiCompletionInFlight = false;
  bool _tickInFlight = false;
  bool _collectingFeedback = false;
  bool _finishAttempted = false;
  String? _finishError;
  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;

  ActiveWorkoutController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lifecycleState =
        WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;
    final reconciled = controller.reconcile() || controller.reconcileTimedSet();
    controller.addListener(_changed);
    if (reconciled || controller.pendingFeedbackExerciseIndices.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await _afterSetAdvanced();
      });
    }
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted || _tickInFlight) return;
      _tickInFlight = true;
      try {
        final transitioned =
            controller.reconcile() || controller.reconcileTimedSet();
        if (transitioned) {
          _timerCueTracker.reset();
          _repScheduler = null;
          await _afterSetAdvanced();
        } else if (controller.phase == WorkoutPhase.countingDown &&
            _lifecycleState == AppLifecycleState.resumed) {
          _playTimerCueFor(controller.preparationRemaining);
        } else if (controller.phase == WorkoutPhase.working &&
            controller.usesGuidedRepetition &&
            _lifecycleState == AppLifecycleState.resumed) {
          _ensureRepSchedulerInitialized();
          if (_repScheduler != null &&
              !_repScheduler!.isPaused &&
              !_repScheduler!.isCompleted) {
            _speakCurrentRepetitionPhase();
            final phaseChanged = _repScheduler!.tick(1000);
            if (phaseChanged) _speakCurrentRepetitionPhase();
            if (_repScheduler!.isCompleted) {
              await _completeRepetitionSet();
            }
          }
        } else if (controller.phase == WorkoutPhase.working &&
            controller.isTimedSetRunning &&
            _lifecycleState == AppLifecycleState.resumed) {
          final remaining = controller.timedSetRemaining;
          _playTimerCueFor(remaining);
        } else if (controller.phase == WorkoutPhase.resting &&
            _lifecycleState == AppLifecycleState.resumed) {
          _playTimerCueFor(controller.restRemaining);
        } else {
          _timerCueTracker.reset();
        }
        if (mounted) setState(() {});
      } finally {
        _tickInFlight = false;
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    controller.removeListener(_changed);
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_voiceCueService.cancelPendingSpeech());
    widget.state.stopVoiceCoach();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
    controller.handleLifecycleState(state);
    if (state != AppLifecycleState.resumed) {
      unawaited(_voiceCueService.cancelPendingSpeech());
      _repScheduler?.pause();
      return;
    }
    final transitioned =
        controller.reconcile() || controller.reconcileTimedSet();
    if (transitioned || controller.pendingFeedbackExerciseIndices.isNotEmpty) {
      unawaited(_afterSetAdvanced());
    }
  }

  void _ensureRepSchedulerInitialized() {
    final exercise = controller.currentExercise;
    final targetReps = exercise.target.maximum ?? exercise.target.minimum ?? 10;
    if (_repScheduler == null || _repScheduler!.targetReps != targetReps) {
      _repScheduler = RepetitionCueScheduler(
        targetReps: targetReps,
        tempoUp: exercise.tempoUp,
        tempoHold: exercise.tempoHold,
        tempoDown: exercise.tempoDown,
      );
    }
  }

  Future<void> _completeRepetitionSet({
    bool isEarly = false,
    bool isSkip = false,
  }) async {
    final actualReps = _repScheduler?.completedReps ?? 0;
    final minimumReps = controller.currentExercise.target.minimum ?? 1;
    if (isEarly && actualReps < minimumReps) return;

    await _voiceCueService.cancelPendingSpeech();

    if (isSkip) {
      _repScheduler?.skip();
      controller.skipSet(reason: 'Người dùng bỏ qua');
    } else {
      if (isEarly) _repScheduler?.completeEarly();
      controller.completeSet();
    }

    _repScheduler = null;
    await _afterSetAdvanced(completionCue: isSkip ? null : 'Hoàn thành.');
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _playTimerCueFor(Duration remaining) {
    final seconds = _remainingSeconds(remaining);
    final cue = _timerCueTracker.next(seconds);
    if (cue != null) unawaited(_playTimerCue(cue, seconds));
  }

  Future<void> _playTimerCue(WorkoutTimerCue cue, int seconds) async {
    if (cue == WorkoutTimerCue.tick) return;
    if (widget.state.countdownSoundsEnabled) {
      try {
        await SystemSound.play(
          seconds == 1 ? SystemSoundType.alert : SystemSoundType.click,
        );
      } on MissingPluginException {
        // The visual timer and optional voice remain authoritative.
      } on PlatformException {
        // System sound is an enhancement and must never block a workout.
      }
    }
    await widget.state.speakCue('$seconds');
  }

  Future<void> _mutate(bool Function() action, {String? cue}) async {
    final changed = action();
    if (!changed) return;
    _timerCueTracker.reset();
    await widget.state.checkpointWorkout(controller);
    if (cue != null) await widget.state.speakCue(cue);
  }

  Future<void> _start() async {
    await _voiceCueService.cancelPendingSpeech();
    await widget.state.stopVoiceCoach();
    await _mutate(controller.start);
    if (controller.phase == WorkoutPhase.working) {
      await _afterSetAdvanced();
    }
  }

  Future<void> _afterSetAdvanced({
    String? completionCue,
    bool announceWorkingStart = true,
  }) async {
    await widget.state.checkpointWorkout(controller);
    await _collectPendingExerciseFeedback();
    if (controller.pendingFeedbackExerciseIndices.isNotEmpty) return;
    if (controller.phase == WorkoutPhase.finishing) {
      await _finish();
      return;
    }
    if (_lifecycleState != AppLifecycleState.resumed) return;
    if (controller.phase == WorkoutPhase.countingDown) {
      await _voiceCueService.cancelPendingSpeech();
      await widget.state.stopVoiceCoach();
    } else if (controller.phase == WorkoutPhase.resting) {
      await _voiceCueService.cancelPendingSpeech();
      final prefix = completionCue == null ? '' : '$completionCue ';
      await widget.state.speakCue(
        '${prefix}Nghỉ ${_remainingSeconds(controller.restRemaining)} giây.',
      );
    } else if (controller.phase == WorkoutPhase.working) {
      await widget.state.stopVoiceCoach();
      if (widget.state.countdownSoundsEnabled) {
        try {
          await SystemSound.play(SystemSoundType.alert);
        } on Object {
          // Voice and the visual state remain authoritative.
        }
      }
      if (announceWorkingStart) {
        await widget.state.speakCue('Bắt đầu.');
      }
      if (controller.usesGuidedRepetition) {
        _ensureRepSchedulerInitialized();
      }
    }
  }

  Future<void> _collectPendingExerciseFeedback() async {
    if (_collectingFeedback ||
        !mounted ||
        _lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    _collectingFeedback = true;
    try {
      while (mounted && controller.pendingFeedbackExerciseIndices.isNotEmpty) {
        final exerciseIndex = controller.pendingFeedbackExerciseIndices.first;
        final exercise = controller.draft.snapshot.exercises[exerciseIndex];
        var loadText = '';
        if (!mounted) return;
        final feedback = await showModalBottomSheet<_ExerciseFeedbackInput>(
          context: context,
          isDismissible: false,
          enableDrag: false,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (context) => SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                4,
                20,
                20 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Bài vừa rồi thế nào?',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      exercise.name,
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      onChanged: (value) => loadText = value,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Mức tạ đã dùng (kg, nếu có)',
                        hintText: 'Có thể để trống',
                        prefixIcon: Icon(Icons.fitness_center),
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final option in const [
                      (
                        ExerciseProgressOutcome.easy,
                        Icons.sentiment_very_satisfied_outlined,
                        'Đạt dễ dàng',
                        'Còn dư sức và giữ đúng kỹ thuật',
                      ),
                      (
                        ExerciseProgressOutcome.appropriate,
                        Icons.sentiment_satisfied_outlined,
                        'Đạt vừa sức',
                        'Hoàn thành mục tiêu với kỹ thuật ổn định',
                      ),
                      (
                        ExerciseProgressOutcome.failed,
                        Icons.trending_down,
                        'Chưa đạt mục tiêu',
                        'Thiếu số lần, thời gian hoặc mất kỹ thuật',
                      ),
                      (
                        ExerciseProgressOutcome.discomfort,
                        Icons.health_and_safety_outlined,
                        'Đau hoặc khó chịu',
                        'Không tăng bài này ở tuần kế tiếp',
                      ),
                    ])
                      Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Icon(option.$2),
                          title: Text(option.$3),
                          subtitle: Text(option.$4),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            final normalized = loadText.trim().replaceAll(
                              ',',
                              '.',
                            );
                            Navigator.pop(
                              context,
                              _ExerciseFeedbackInput(
                                outcome: option.$1,
                                actualLoadKg: normalized.isEmpty
                                    ? null
                                    : double.tryParse(normalized),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
        if (feedback == null || !mounted) return;
        controller.recordExerciseFeedback(
          exerciseIndex: exerciseIndex,
          outcome: feedback.outcome,
          actualLoadKg: feedback.actualLoadKg,
        );
        await widget.state.checkpointWorkout(controller);
      }
    } finally {
      _collectingFeedback = false;
    }
  }

  void _speakCurrentRepetitionPhase() {
    final scheduler = _repScheduler;
    if (scheduler == null ||
        scheduler.isCompleted ||
        scheduler.hasSpokenCurrentPhaseCue ||
        !widget.state.voiceCoachEnabled) {
      return;
    }
    scheduler.markPhaseCueSpoken();
    final cue = scheduler.currentPhaseCueLabel;
    if (cue.isNotEmpty) unawaited(_voiceCueService.speak(cue));
  }

  Future<void> _pauseWorkout() async {
    _repScheduler?.pause();
    await _voiceCueService.cancelPendingSpeech();
    await widget.state.stopVoiceCoach();
    await _mutate(controller.pause);
  }

  Future<void> _resumeWorkout() async {
    await _mutate(controller.resume);
    _repScheduler?.resume();
    await _afterSetAdvanced(announceWorkingStart: false);
  }

  Future<void> _skipPreparation() async {
    await _mutate(controller.skipPreparation);
    await _afterSetAdvanced();
  }

  Future<void> _skipRest() async {
    await _mutate(controller.skipRest);
    await _afterSetAdvanced();
  }

  Future<void> _selectAlternative() async {
    final exercise = controller.currentExercise;
    final selectedId = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Chọn bài thay thế',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            for (final option in exercise.alternatives)
              ListTile(
                leading: Icon(
                  option.exerciseId == exercise.exerciseId
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                ),
                title: Text(option.name),
                subtitle: Text(
                  [
                    option.muscleGroup,
                    option.equipment,
                  ].where((value) => value.trim().isNotEmpty).join(' • '),
                ),
                onTap: () => Navigator.pop(context, option.exerciseId),
              ),
          ],
        ),
      ),
    );
    if (selectedId == null || selectedId == exercise.exerciseId) return;
    await _mutate(() => controller.selectAlternative(selectedId));
  }

  Future<void> _completeAiSet() async {
    if (_aiCompletionInFlight ||
        controller.phase != WorkoutPhase.working ||
        !controller.usesAiCamera) {
      return;
    }
    final result = _lastPoseResult;
    final exercise = controller.currentExercise;
    final evidence = _cameraEvidence.build(
      setKey: _cameraSetKey,
      ruleVersionId: exercise.poseRuleVersionId ?? 'unknown',
    );
    final requiredReps = exercise.cameraTargetReps ?? 1;
    if (result == null ||
        !result.isCalibrated ||
        result.repCount < requiredReps ||
        evidence == null ||
        evidence.reliableFrameCount < 4 ||
        evidence.reliableFrameRatio < .5 ||
        evidence.averageConfidence < .65) {
      return;
    }
    _aiCompletionInFlight = true;
    try {
      final changed = controller.completeSet(
        detectedRepCount: result.repCount,
        confidence: result.confidence,
        cameraEvidence: evidence,
      );
      if (!changed) return;
      _resetCameraEvidence();
      await _afterSetAdvanced(
        completionCue: 'Đã nhận diện ${result.repCount} lần.',
      );
    } finally {
      _aiCompletionInFlight = false;
    }
  }

  Future<void> _useGuidedFallback() async {
    if (controller.phase != WorkoutPhase.working &&
        controller.phase != WorkoutPhase.preparing &&
        controller.phase != WorkoutPhase.resting) {
      return;
    }
    _resetCameraEvidence();
    await _mutate(
      () => controller.setConfirmationMode(WorkoutConfirmationMode.guided),
      cue: 'Đã chuyển sang xác nhận có hướng dẫn.',
    );
  }

  Future<void> _selectConfirmationMode(
    WorkoutConfirmationMode requested,
  ) async {
    if (requested == WorkoutConfirmationMode.guided) {
      await _useGuidedFallback();
      return;
    }

    final exercise = controller.currentExercise;
    if (!exercise.supportsAiCamera) {
      _showCameraModeMessage(
        'Camera AI chỉ hỗ trợ bài Squat không tạ có mã “squat”. '
        'Bài ${exercise.name} sẽ tiếp tục tập theo Hướng dẫn.',
      );
      return;
    }
    if (!CameraCoachPanel.platformSupported) {
      _showCameraModeMessage(
        'Camera AI cho bài Squat chỉ khả dụng trên thiết bị Android được hỗ trợ.',
      );
      return;
    }

    _resetCameraEvidence();
    _repScheduler = null;
    await _voiceCueService.cancelPendingSpeech();
    await _mutate(
      () => controller.setConfirmationMode(WorkoutConfirmationMode.aiCamera),
      cue: 'Đã chuyển sang Camera AI. Hoàn thành đủ số lần được nhận diện.',
    );
  }

  void _showCameraModeMessage(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _skipSet() async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Lý do bỏ qua', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            for (final item in const [
              ('discomfort', 'Cảm thấy khó chịu'),
              ('equipment_unavailable', 'Không có dụng cụ'),
              ('need_recovery', 'Cần nghỉ thêm'),
            ])
              ListTile(
                title: Text(item.$2),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pop(context, item.$1),
              ),
          ],
        ),
      ),
    );
    if (reason == null) return;
    await _mutate(() => controller.skipSet(reason: reason));
    await _afterSetAdvanced(announceWorkingStart: false);
  }

  Future<void> _finish() async {
    if (_saving || _completion != null) return;
    if (controller.pendingFeedbackExerciseIndices.isNotEmpty) {
      await _collectPendingExerciseFeedback();
      if (controller.pendingFeedbackExerciseIndices.isNotEmpty) return;
    }
    setState(() {
      _saving = true;
      _finishAttempted = true;
      _finishError = null;
    });
    try {
      final completion = await widget.state.finishWorkout(controller);
      if (!mounted) return;
      setState(() => _completion = completion);
      await widget.state.speakCue('Buổi tập đã hoàn tất. Làm tốt lắm!');
    } on Object catch (error) {
      if (mounted) {
        setState(() => _finishError = error.toString());
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Chưa thể lưu kết quả: $error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _discard() async {
    final confirmed = await confirmAction(
      context,
      title: 'Bỏ buổi tập?',
      message:
          'Tiến độ buổi này sẽ bị xóa và lịch được đánh dấu đã bỏ qua. Thao tác này không thể hoàn tác.',
      confirmLabel: 'Bỏ buổi',
    );
    if (!confirmed) return;
    await widget.state.discardWorkout(controller);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _finishEarly() async {
    final confirmed = await confirmAction(
      context,
      title: 'Kết thúc buổi tập?',
      message:
          'FitTrack chỉ tổng hợp các hiệp bạn đã xác nhận. Các hiệp còn lại không được xem là đã hoàn thành.',
      confirmLabel: 'Kết thúc',
    );
    if (confirmed) await _finish();
  }

  Future<bool> _leave() async {
    if (_completion != null || controller.isTerminal) return true;
    if (controller.phase == WorkoutPhase.countingDown ||
        controller.phase == WorkoutPhase.working ||
        controller.phase == WorkoutPhase.resting) {
      controller.pause();
      await widget.state.checkpointWorkout(controller);
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    if (_completion case final completion?) {
      return _SummaryScreen(
        completion: completion,
        onDone: () => Navigator.pop(context, completion),
        onOpenHistory: widget.onOpenHistory == null
            ? null
            : () {
                Navigator.pop(context, completion);
                widget.onOpenHistory!();
              },
      );
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        final canLeave = await _leave();
        if (!mounted || !canLeave) return;
        navigator.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            AppState.displaySessionTitle(controller.draft.snapshot.title),
          ),
          leading: IconButton(
            tooltip: 'Rời và lưu nháp',
            onPressed: () async {
              final navigator = Navigator.of(context);
              final canLeave = await _leave();
              if (!mounted || !canLeave) return;
              navigator.pop();
            },
            icon: const Icon(Icons.close),
          ),
          actions: [
            IconButton(
              tooltip: 'Bỏ buổi tập',
              onPressed: controller.phase == WorkoutPhase.finishing
                  ? null
                  : _discard,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
        body: SafeArea(child: _phaseContent()),
      ),
    );
  }

  Widget _phaseContent() => switch (controller.phase) {
    WorkoutPhase.preparing => _preparing(),
    WorkoutPhase.countingDown => _countingDown(),
    WorkoutPhase.working => _working(),
    WorkoutPhase.resting => _resting(),
    WorkoutPhase.paused => _paused(),
    WorkoutPhase.finishing => _finishing(),
    WorkoutPhase.completed || WorkoutPhase.discarded => const SizedBox.shrink(),
  };

  Widget _countingDown() {
    final exercise = controller.currentExercise;
    final seconds = _remainingSeconds(controller.preparationRemaining);
    return FitTrackPage(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.hourglass_top_rounded,
            size: 64,
            color: AppColors.primary,
          ),
          const SizedBox(height: 16),
          Text('Chuẩn bị', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            exercise.name,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Hiệp ${controller.setIndex + 1}/${exercise.setCount} • '
            '${_exerciseTargetLabel(exercise)}',
            style: const TextStyle(color: AppColors.textMuted),
          ),
          _ExerciseMediaBox(
            key: const ValueKey('preparation-exercise-media'),
            exercise: exercise,
            aspectRatio: 16 / 9,
          ),
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            label: 'Bắt đầu sau $seconds giây',
            child: Text(
              '$seconds',
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                color: seconds <= 3 ? AppColors.warning : AppColors.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text('Vào tư thế an toàn và sẵn sàng bắt đầu.'),
          const SizedBox(height: 28),
          AppPrimaryButton(
            label: 'Bắt đầu ngay',
            icon: Icons.play_arrow,
            onPressed: _skipPreparation,
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _pauseWorkout,
            icon: const Icon(Icons.pause),
            label: const Text('Tạm dừng'),
          ),
        ],
      ),
    );
  }

  Widget _preparing() {
    final snapshot = controller.draft.snapshot;
    return FitTrackPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.directions_run, size: 56, color: AppColors.primary),
          const SizedBox(height: 16),
          Text(
            'Chuẩn bị buổi tập',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 6),
          Text(
            '${snapshot.totalSetCount} hiệp • ${snapshot.exercises.length} bài tập',
            style: const TextStyle(color: AppColors.textMuted),
          ),
          const SizedBox(height: 20),
          for (var index = 0; index < snapshot.exercises.length; index++)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(child: Text('${index + 1}')),
              title: Text(snapshot.exercises[index].name),
              subtitle: Text(
                '${snapshot.exercises[index].setCount} hiệp • '
                '${_exerciseTargetLabel(snapshot.exercises[index])}/hiệp',
              ),
            ),
          const SizedBox(height: 12),
          _confirmationModeSelector(controller.currentExercise),
          const SizedBox(height: 12),
          const Text(
            'Camera chỉ xử lý khung hình tạm thời để nhận diện tư thế; FitTrack không lưu video. AI có thể sai, hãy ưu tiên cảm nhận an toàn của bạn.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 24),
          AppPrimaryButton(
            label: 'Bắt đầu',
            icon: Icons.play_arrow,
            onPressed: _start,
          ),
        ],
      ),
    );
  }

  Widget _confirmationModeSelector(WorkoutExerciseSnapshot exercise) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Chế độ tập', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SegmentedButton<WorkoutConfirmationMode>(
          key: const ValueKey('workout-confirmation-mode-selector'),
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(
              value: WorkoutConfirmationMode.guided,
              icon: Icon(Icons.touch_app_outlined),
              label: Text('Hướng dẫn'),
            ),
            ButtonSegment(
              value: WorkoutConfirmationMode.aiCamera,
              icon: Icon(Icons.camera_alt_outlined),
              label: Text('Camera AI'),
            ),
          ],
          selected: {controller.confirmationMode},
          onSelectionChanged: (values) {
            unawaited(_selectConfirmationMode(values.first));
          },
        ),
        if (!exercise.supportsAiCamera) ...[
          const SizedBox(height: 6),
          const Text(
            'Camera AI chỉ hỗ trợ Squat không tạ (mã squat).',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
      ],
    );
  }

  Widget _working() {
    final exercise = controller.currentExercise;
    final cameraSupported = _cameraSupported(exercise);
    final processedSetCount = controller.draft.setEvents
        .where((event) => event.status != SetEventStatus.redone)
        .length;
    final progress =
        (processedSetCount / controller.draft.snapshot.totalSetCount).clamp(
          0.0,
          1.0,
        );
    return Column(
      children: [
        LinearProgressIndicator(value: progress, minHeight: 6),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _confirmationModeSelector(exercise),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: Text(_duration(controller.activeDuration)),
              ),
              const SizedBox(height: 10),
              _ExerciseMediaBox(exercise: exercise),
              const SizedBox(height: 24),
              Text(
                exercise.name,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              if (exercise.isAlternative) ...[
                const SizedBox(height: 6),
                const Chip(
                  avatar: Icon(Icons.swap_horiz, size: 18),
                  label: Text('Đang dùng bài thay thế'),
                ),
              ],
              if (exercise.alternatives.length > 1) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed:
                      controller.isTimedSetRunning ||
                          controller.draft.timedSetElapsedMilliseconds > 0
                      ? null
                      : _selectAlternative,
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('Đổi bài tương đương'),
                ),
              ],
              const SizedBox(height: 10),
              Text(
                'Hiệp ${controller.setIndex + 1}/${exercise.setCount}',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(color: AppColors.primary),
              ),
              const SizedBox(height: 10),
              Text(
                _exerciseTargetLabel(exercise),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              if (controller.usesGuidedRepetition) ...[
                const SizedBox(height: 14),
                Text(
                  'Lần ${(_repScheduler?.currentRepIndex ?? 0) + 1} / ${exercise.target.maximum ?? exercise.target.minimum ?? 10}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Chip(
                  avatar: const Icon(Icons.fitness_center, size: 18),
                  label: Text(
                    _repScheduler?.currentPhaseUiLabel ?? 'Nâng / Đẩy',
                  ),
                ),
              ],
              if (controller.usesActiveTimer) ...[
                const SizedBox(height: 14),
                Semantics(
                  liveRegion: true,
                  label:
                      'Còn ${_remainingSeconds(controller.timedSetRemaining)} giây',
                  child: Text(
                    _duration(controller.timedSetRemaining),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              _ExerciseGuidanceCard(exercise: exercise),
              const SizedBox(height: 16),
              if (controller.confirmationMode ==
                      WorkoutConfirmationMode.aiCamera &&
                  cameraSupported)
                CameraCoachPanel(
                  key: ValueKey('$_cameraSetKey:${exercise.exerciseId}'),
                  exerciseId: exercise.exerciseId,
                  poseRuleVersionId: exercise.poseRuleVersionId,
                  targetReps: exercise.cameraTargetReps ?? 1,
                  requireUserStart: false,
                  poseRulePublished:
                      exercise.poseRuleVersionId == 'squat_pose_v1',
                  deviceAllowed: true,
                  onResult: (result) {
                    _lastPoseResult = result;
                    _cameraEvidence.observe(_cameraSetKey, result);
                    final feedbackCode = result.feedbackCode;
                    if (_poseFeedbackVoiceGate.shouldSpeak(
                      setKey: _cameraSetKey,
                      feedbackCode: feedbackCode,
                    )) {
                      unawaited(
                        widget.state.speakCue(_poseFeedback(feedbackCode!)),
                      );
                    }
                  },
                  onUnavailable: (reason) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(_cameraUnavailable(reason))),
                    );
                  },
                  onFallbackRequested: _useGuidedFallback,
                  onTargetReached: _completeAiSet,
                ),
              const SizedBox(height: 22),
              if (controller.usesGuidedRepetition) ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          _repScheduler?.repeatBeat();
                          setState(() {});
                        },
                        icon: const Icon(Icons.replay_5),
                        label: const Text('Lặp lại nhịp'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppPrimaryButton(
                        label: 'Xong sớm',
                        icon: Icons.check_circle_outline,
                        onPressed:
                            (_repScheduler?.completedReps ?? 0) >=
                                (exercise.target.minimum ?? 1)
                            ? () => _completeRepetitionSet(isEarly: true)
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ] else if (controller.usesActiveTimer)
                Card(
                  color: AppColors.paleBlue.withValues(alpha: .45),
                  child: const ListTile(
                    leading: Icon(Icons.autorenew),
                    title: Text('Đồng hồ đang tự chạy'),
                    subtitle: Text(
                      'Hết thời gian, FitTrack sẽ tự chuyển sang nghỉ.',
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _mutate(controller.redoSet),
                      icon: const Icon(Icons.replay),
                      label: const Text('Làm lại'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => controller.usesGuidedRepetition
                          ? _completeRepetitionSet(isSkip: true)
                          : _skipSet(),
                      icon: const Icon(Icons.skip_next),
                      label: const Text('Bỏ qua'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _pauseWorkout,
                icon: const Icon(Icons.pause),
                label: const Text('Tạm dừng'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _resting() {
    final remaining = controller.restRemaining;
    final next = controller.currentExercise;
    return FitTrackPage(
      child: Column(
        children: [
          const Icon(Icons.timer_outlined, size: 64, color: AppColors.primary),
          const SizedBox(height: 12),
          Text(
            'Nghỉ giữa hiệp',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          Semantics(
            liveRegion: true,
            label: 'Còn ${_remainingSeconds(remaining)} giây',
            child: Text(
              _duration(remaining),
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Tiếp theo: ${next.name} • hiệp ${controller.setIndex + 1}/${next.setCount}',
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _mutate(controller.extendRest),
                  child: const Text('+15 giây'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: _skipRest,
                  child: const Text('Tập tiếp'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: _pauseWorkout,
            icon: const Icon(Icons.pause),
            label: const Text('Tạm dừng'),
          ),
        ],
      ),
    );
  }

  Widget _paused() => FitTrackPage(
    child: Column(
      children: [
        const Icon(
          Icons.pause_circle_outline,
          size: 68,
          color: AppColors.primary,
        ),
        const SizedBox(height: 14),
        Text(
          'Buổi tập đang tạm dừng',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text(
          'Tiến độ đã được lưu trên thiết bị. Bạn có thể tiếp tục ngay hoặc quay lại sau.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        AppPrimaryButton(
          label: 'Tiếp tục',
          icon: Icons.play_arrow,
          onPressed: _resumeWorkout,
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _finishEarly,
          icon: const Icon(Icons.stop_circle_outlined),
          label: const Text('Kết thúc với tiến độ hiện tại'),
        ),
        const SizedBox(height: 4),
        TextButton.icon(
          onPressed: _discard,
          icon: const Icon(Icons.delete_outline),
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          label: const Text('Bỏ và xóa buổi tập'),
        ),
      ],
    ),
  );

  Widget _finishing() {
    final pendingFeedback =
        controller.pendingFeedbackExerciseIndices.isNotEmpty;
    if (!_saving && !_finishAttempted && !_collectingFeedback) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => pendingFeedback ? _collectPendingExerciseFeedback() : _finish(),
      );
    }
    if (_saving || pendingFeedback || _collectingFeedback) {
      return const Center(child: CircularProgressIndicator());
    }
    return FitTrackPage(
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 60,
            color: AppColors.warning,
          ),
          const SizedBox(height: 14),
          Text(
            'Kết quả chưa được lưu',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            _finishError ?? 'Hãy thử lại khi thiết bị sẵn sàng.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 22),
          AppPrimaryButton(
            label: 'Thử lưu lại',
            icon: Icons.refresh,
            onPressed: _finish,
          ),
        ],
      ),
    );
  }

  String _duration(Duration value) {
    final seconds = _remainingSeconds(value);
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainder.toString().padLeft(2, '0')}';
  }

  int _remainingSeconds(Duration value) {
    if (value <= Duration.zero) return 0;
    return (value.inMilliseconds + 999) ~/ Duration.millisecondsPerSecond;
  }

  bool _cameraSupported(WorkoutExerciseSnapshot exercise) =>
      CameraCoachPanel.platformSupported &&
      exercise.supportsAiCamera &&
      CameraCoachPanel.supportsRule(
        exercise.exerciseId,
        exercise.poseRuleVersionId,
      );

  String _exerciseTargetLabel(WorkoutExerciseSnapshot exercise) {
    if (controller.confirmationMode == WorkoutConfirmationMode.aiCamera &&
        exercise.supportsAiCamera) {
      return '${exercise.cameraTargetReps} lần';
    }
    if (exercise.executionMode == ExerciseExecutionMode.timer) {
      return '${exercise.workDurationSeconds} giây';
    }
    return exercise.target.label;
  }

  String get _cameraSetKey =>
      '${controller.exerciseIndex}:${controller.setIndex}';

  void _resetCameraEvidence() {
    _lastPoseResult = null;
    _cameraEvidence.reset();
    _poseFeedbackVoiceGate.reset();
  }

  String _poseFeedback(PoseFeedbackCode code) => switch (code) {
    PoseFeedbackCode.positionFullBody => 'Hãy đưa toàn thân vào khung hình.',
    PoseFeedbackCode.lowConfidence => 'Hãy giữ ổn định và tăng ánh sáng.',
    PoseFeedbackCode.staleFrame => 'Camera chưa theo kịp chuyển động.',
    PoseFeedbackCode.standTall => 'Hãy đứng thẳng để bắt đầu.',
    PoseFeedbackCode.lowerHips => 'Hãy hạ thấp thêm.',
    PoseFeedbackCode.onePersonOnly =>
      'Chỉ để một người trong khung hình để tránh nhận nhầm.',
    PoseFeedbackCode.detectorUnavailable =>
      'Hướng dẫn bằng camera chưa khả dụng. Bạn có thể thử lại hoặc chuyển sang tự xác nhận.',
  };

  String _cameraUnavailable(
    PoseCapabilityUnavailableReason reason,
  ) => switch (reason) {
    PoseCapabilityUnavailableReason.permissionDenied =>
      'Chưa có quyền camera. Chế độ hướng dẫn bằng camera vẫn được giữ.',
    PoseCapabilityUnavailableReason.trackingUnreliable =>
      'Nhận diện chưa ổn định. Hãy chỉnh ánh sáng hoặc vị trí camera; chế độ sẽ không tự thay đổi.',
    PoseCapabilityUnavailableReason.exerciseUnsupported =>
      'Bài tập này chưa có quy tắc nhận diện tư thế đã phát hành.',
    _ =>
      'Hướng dẫn bằng camera chưa khả dụng. Hãy thử lại hoặc chuyển sang tự xác nhận.',
  };
}

class _ExerciseFeedbackInput {
  const _ExerciseFeedbackInput({required this.outcome, this.actualLoadKg});

  final ExerciseProgressOutcome outcome;
  final double? actualLoadKg;
}

class _CameraEvidenceAccumulator {
  String? _setKey;
  int _evaluatedFrames = 0;
  int _reliableFrames = 0;
  int _formCues = 0;
  double _confidenceTotal = 0;
  double? _minimumConfidence;

  void observe(String setKey, PoseCoachResult result) {
    if (_setKey != setKey) {
      reset();
      _setKey = setKey;
    }
    _evaluatedFrames++;
    final confidence = result.confidence;
    final trackable =
        result.isCalibrated &&
        confidence != null &&
        (result.status == PoseCoachStatus.good ||
            result.status == PoseCoachStatus.needsCue);
    if (!trackable) return;
    _reliableFrames++;
    _confidenceTotal += confidence;
    _minimumConfidence = _minimumConfidence == null
        ? confidence
        : (_minimumConfidence! < confidence ? _minimumConfidence : confidence);
    if (result.status == PoseCoachStatus.needsCue) _formCues++;
  }

  CameraSetEvidence? build({
    required String setKey,
    required String ruleVersionId,
  }) {
    if (_setKey != setKey || _reliableFrames == 0) return null;
    return CameraSetEvidence(
      ruleVersionId: ruleVersionId,
      evaluatedFrameCount: _evaluatedFrames,
      reliableFrameCount: _reliableFrames,
      formCueCount: _formCues,
      averageConfidence: _confidenceTotal / _reliableFrames,
      minimumConfidence: _minimumConfidence ?? 0,
    );
  }

  void reset() {
    _setKey = null;
    _evaluatedFrames = 0;
    _reliableFrames = 0;
    _formCues = 0;
    _confidenceTotal = 0;
    _minimumConfidence = null;
  }
}

class _SummaryScreen extends StatelessWidget {
  const _SummaryScreen({
    required this.completion,
    required this.onDone,
    this.onOpenHistory,
  });
  final WorkoutCompletion completion;
  final VoidCallback onDone;
  final VoidCallback? onOpenHistory;

  @override
  Widget build(BuildContext context) {
    final partiallyCompleted =
        completion.status == WorkoutCompletionStatus.partiallyCompleted;
    final abandoned = completion.status == WorkoutCompletionStatus.abandoned;
    final modes = completion.setEvents
        .map((event) => event.confirmationMode)
        .toSet();

    return Scaffold(
      body: FitTrackPage(
        child: Column(
          children: [
            CircleAvatar(
              radius: 42,
              backgroundColor: abandoned
                  ? AppColors.textMuted.withValues(alpha: .12)
                  : partiallyCompleted
                  ? AppColors.warning.withValues(alpha: .14)
                  : const Color(0xFFE1F7EC),
              child: Icon(
                abandoned
                    ? Icons.block_outlined
                    : partiallyCompleted
                    ? Icons.flag_outlined
                    : Icons.check,
                size: 48,
                color: abandoned
                    ? AppColors.textMuted
                    : partiallyCompleted
                    ? AppColors.warning
                    : AppColors.success,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              abandoned
                  ? 'Buổi tập đã kết thúc với 0 hiệp'
                  : partiallyCompleted
                  ? 'Đã lưu phần bạn hoàn thành'
                  : 'Đã hoàn thành!',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              AppState.displaySessionTitle(completion.snapshot.title),
              textAlign: TextAlign.center,
            ),
            if (completion.snapshot.programTitle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '${AppState.displayStoredProgramTitle(completion.snapshot.programTitle)} • ${completion.snapshot.contentVersion}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 18),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                if (modes.contains(WorkoutConfirmationMode.guided))
                  const Chip(
                    avatar: Icon(Icons.touch_app_outlined, size: 18),
                    label: Text('Tự xác nhận có hướng dẫn'),
                  ),
                if (modes.contains(WorkoutConfirmationMode.aiCamera))
                  const Chip(
                    avatar: Icon(Icons.camera_alt_outlined, size: 18),
                    label: Text('Hướng dẫn bằng camera AI'),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: MetricCard(
                    label: 'Hiệp hoàn tất',
                    value: '${completion.completedSetCount}',
                    icon: Icons.task_alt,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: MetricCard(
                    label: 'Thời lượng',
                    value:
                        '${(completion.actualDurationSeconds / 60).ceil()} phút',
                    icon: Icons.timer_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: MetricCard(
                    label: 'Hiệp bỏ qua',
                    value: '${completion.skippedSetCount}',
                    icon: Icons.skip_next_outlined,
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: MetricCard(
                    label: 'Lần làm lại',
                    value: '${completion.redoneSetCount}',
                    icon: Icons.replay_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Chi tiết buổi tập',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: 10),
            for (final exerciseEntry
                in completion.snapshot.exercises.asMap().entries) ...[
              _ExerciseResultCard(
                exercise: exerciseEntry.value,
                events: completion.setEvents
                    .where((event) => event.exerciseIndex == exerciseEntry.key)
                    .toList(),
              ),
              const SizedBox(height: 10),
            ],
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nguồn và cách ghi nhận',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Phiên bản nội dung: ${completion.snapshot.programTitle.isNotEmpty ? '${AppState.displayStoredProgramTitle(completion.snapshot.programTitle)}${completion.snapshot.contentVersion.isEmpty ? '' : ' (v${completion.snapshot.contentVersion})'}' : 'Chương trình tập luyện'}',
                    ),
                    if (completion.snapshot.sourceRefs.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      for (final source in completion.snapshot.sourceRefs)
                        Text(
                          '• $source',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                    if (modes.contains(WorkoutConfirmationMode.guided)) ...[
                      const SizedBox(height: 10),
                      const Text(
                        'Ở chế độ tự xác nhận, số lần hoặc thời gian hiển thị là mục tiêu của chương trình, không phải kết quả do camera đo.',
                      ),
                    ],
                    if (modes.contains(WorkoutConfirmationMode.aiCamera)) ...[
                      const SizedBox(height: 10),
                      const Text(
                        'Số lần và độ tin cậy AI chỉ xuất hiện ở hiệp có dữ liệu nhận diện thực tế; video không được lưu.',
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            AppPrimaryButton(
              label: onOpenHistory == null
                  ? 'Về Trang chủ'
                  : 'Xem lịch sử và tiến độ',
              icon: onOpenHistory == null
                  ? Icons.home_outlined
                  : Icons.insights_outlined,
              onPressed: onOpenHistory ?? onDone,
            ),
            if (onOpenHistory != null)
              TextButton(onPressed: onDone, child: const Text('Về Trang chủ')),
          ],
        ),
      ),
    );
  }
}

class _ExerciseResultCard extends StatelessWidget {
  const _ExerciseResultCard({required this.exercise, required this.events});

  final WorkoutExerciseSnapshot exercise;
  final List<SetEvent> events;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(exercise.name, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            '${exercise.setCount} hiệp • Mục tiêu ${exercise.target.label}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const Divider(height: 22),
          if (events.isEmpty)
            const Text('Chưa thực hiện.')
          else
            for (final event in events)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _statusIcon(event.status),
                      size: 20,
                      color: _statusColor(event.status),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_statusLabel(event.status)} hiệp ${event.setIndex + 1}',
                          ),
                          Text(
                            'Mục tiêu: ${event.targetContext.label}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          if (event.timedDurationSeconds case final seconds?)
                            Text(
                              'Thời gian thực tế: ${seconds}s',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          if (event.confirmationMode ==
                                  WorkoutConfirmationMode.aiCamera &&
                              event.detectedRepCount != null)
                            Text(
                              'AI nhận diện: ${event.detectedRepCount} lần'
                              '${event.confidence == null ? '' : ' • Tin cậy ${(event.confidence! * 100).round()}%'}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          if (event.skipReason?.trim().isNotEmpty == true)
                            Text(
                              'Lý do: ${event.skipReason}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                    Icon(
                      event.confirmationMode == WorkoutConfirmationMode.aiCamera
                          ? Icons.camera_alt_outlined
                          : Icons.touch_app_outlined,
                      size: 18,
                    ),
                  ],
                ),
              ),
        ],
      ),
    ),
  );

  static String _statusLabel(SetEventStatus status) => switch (status) {
    SetEventStatus.completed => 'Hoàn tất',
    SetEventStatus.redone => 'Làm lại',
    SetEventStatus.skipped => 'Bỏ qua',
  };

  static IconData _statusIcon(SetEventStatus status) => switch (status) {
    SetEventStatus.completed => Icons.check_circle_outline,
    SetEventStatus.redone => Icons.replay_outlined,
    SetEventStatus.skipped => Icons.skip_next_outlined,
  };

  static Color _statusColor(SetEventStatus status) => switch (status) {
    SetEventStatus.completed => AppColors.success,
    SetEventStatus.redone => AppColors.primary,
    SetEventStatus.skipped => AppColors.warning,
  };
}

class _ExerciseGuidanceCard extends StatelessWidget {
  const _ExerciseGuidanceCard({required this.exercise});

  final WorkoutExerciseSnapshot exercise;

  @override
  Widget build(BuildContext context) {
    final instructions = exercise.instructions.isNotEmpty
        ? exercise.instructions
        : exercise.cues;
    final programCues = exercise.instructions.isEmpty
        ? const <String>[]
        : exercise.cues
              .where((cue) => !instructions.contains(cue))
              .toList(growable: false);

    return Card(
      key: ValueKey('exercise-guidance-${exercise.exerciseId}'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.menu_book_outlined, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  'Cách thực hiện',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (instructions.isEmpty)
              const Text(
                'Chưa có hướng dẫn chi tiết cho bài tập này.',
                style: TextStyle(color: AppColors.textMuted),
              )
            else
              for (var index = 0; index < instructions.length; index++)
                _GuidanceRow(
                  leading: '${index + 1}',
                  text: instructions[index],
                  color: AppColors.primary,
                ),
            if (programCues.isNotEmpty) ...[
              const Divider(height: 28),
              Text(
                'Gợi ý cho buổi tập',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              for (final cue in programCues)
                _GuidanceRow(
                  icon: Icons.check_circle_outline,
                  text: cue,
                  color: AppColors.success,
                ),
            ],
            if (exercise.commonMistakes.isNotEmpty) ...[
              const Divider(height: 28),
              Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Lỗi thường gặp',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              for (final mistake in exercise.commonMistakes)
                _GuidanceRow(
                  icon: Icons.close_rounded,
                  text: mistake,
                  color: AppColors.warning,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GuidanceRow extends StatelessWidget {
  const _GuidanceRow({
    required this.text,
    required this.color,
    this.leading,
    this.icon,
  });

  final String text;
  final Color color;
  final String? leading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon case final icon?)
          Icon(icon, size: 19, color: color)
        else
          CircleAvatar(
            radius: 10,
            backgroundColor: color.withValues(alpha: .12),
            foregroundColor: color,
            child: Text(
              leading!,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

class _ExerciseMediaBox extends StatelessWidget {
  const _ExerciseMediaBox({
    super.key,
    required this.exercise,
    this.aspectRatio = 4 / 3,
  });
  final WorkoutExerciseSnapshot exercise;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    final imageProvider = fitTrackImageProvider(exercise.mediaUrl);
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.navy, AppColors.action],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              image: imageProvider == null
                  ? null
                  : DecorationImage(image: imageProvider, fit: BoxFit.contain),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (imageProvider == null)
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircleAvatar(
                          radius: 26,
                          backgroundColor: Colors.black45,
                          child: Icon(
                            Icons.play_arrow_rounded,
                            size: 36,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'GIF / Video hướng dẫn: ${exercise.name}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Nhóm cơ: ${exercise.muscleGroup} • Dụng cụ: ${exercise.equipment}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: .7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.videocam_outlined,
                          color: Colors.white,
                          size: 14,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'GIF / VIDEO HƯỚNG DẪN',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
