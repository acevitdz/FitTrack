import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/active_workout.dart';
import '../../models/pose_coach.dart';
import '../../services/active_workout_controller.dart';
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
  final _timerCueTracker = WorkoutTimerCueTracker();
  bool _saving = false;
  bool _aiCompletionInFlight = false;
  bool _tickInFlight = false;
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
    if (reconciled) {
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
          await _afterSetAdvanced();
        } else if (controller.phase == WorkoutPhase.countingDown &&
            _lifecycleState == AppLifecycleState.resumed) {
          _playTimerCueFor(controller.preparationRemaining);
        } else if (controller.phase == WorkoutPhase.working &&
            controller.isTimedSetRunning &&
            _lifecycleState == AppLifecycleState.resumed) {
          _playTimerCueFor(controller.timedSetRemaining);
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
    widget.state.stopVoiceCoach();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
    if (state != AppLifecycleState.resumed) return;
    final transitioned =
        controller.reconcile() || controller.reconcileTimedSet();
    if (transitioned) {
      unawaited(_afterSetAdvanced());
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  String get _workingCue {
    final exercise = controller.currentExercise;
    final set = controller.setIndex + 1;
    final cue = StringBuffer(
      '${exercise.name}. Hiệp $set trên ${exercise.setCount}. '
      '${controller.confirmationMode == WorkoutConfirmationMode.aiCamera ? exercise.target.label : 'Tập ${exercise.workDurationSeconds} giây'}.',
    );
    if (set == exercise.setCount) {
      cue.write(' Đây là hiệp cuối của bài này.');
    }
    if (controller.exerciseIndex ==
            controller.draft.snapshot.exercises.length - 1 &&
        set == exercise.setCount) {
      cue.write(' Đây là hiệp cuối của buổi tập.');
    }
    return cue.toString();
  }

  String get _preparationCue {
    final exercise = controller.currentExercise;
    return 'Chuẩn bị ${exercise.name}, hiệp ${controller.setIndex + 1} trên '
        '${exercise.setCount}. Bắt đầu sau ${exercise.preparationSeconds} giây.';
  }

  void _playTimerCueFor(Duration remaining) {
    final seconds = _remainingSeconds(remaining);
    final cue = _timerCueTracker.next(seconds);
    if (cue != null) unawaited(_playTimerCue(cue, seconds));
  }

  Future<void> _playTimerCue(WorkoutTimerCue cue, int seconds) async {
    if (widget.state.countdownSoundsEnabled) {
      try {
        await SystemSound.play(
          cue == WorkoutTimerCue.tick
              ? SystemSoundType.click
              : SystemSoundType.alert,
        );
      } on MissingPluginException {
        // The visual timer and optional voice remain authoritative.
      } on PlatformException {
        // System sound is an enhancement and must never block a workout.
      }
    }
    if (cue == WorkoutTimerCue.tick) return;
    if (widget.state.hapticsEnabled) {
      if (seconds == 1) {
        await HapticFeedback.mediumImpact();
      } else {
        await HapticFeedback.lightImpact();
      }
    }
    await widget.state.speakCue('$seconds');
  }

  Future<void> _mutate(bool Function() action, {String? cue}) async {
    final changed = action();
    if (!changed) return;
    _timerCueTracker.reset();
    if (widget.state.hapticsEnabled) HapticFeedback.selectionClick();
    await widget.state.checkpointWorkout(controller);
    if (cue != null) await widget.state.speakCue(cue);
  }

  Future<void> _start() async {
    await _mutate(controller.start, cue: _preparationCue);
  }

  Future<void> _afterSetAdvanced({String? completionCue}) async {
    await widget.state.checkpointWorkout(controller);
    if (controller.phase == WorkoutPhase.finishing) {
      await _finish();
      return;
    }
    if (_lifecycleState != AppLifecycleState.resumed) return;
    if (controller.phase == WorkoutPhase.countingDown) {
      await widget.state.speakCue(_preparationCue);
    } else if (controller.phase == WorkoutPhase.resting) {
      final prefix = completionCue == null ? '' : '$completionCue ';
      await widget.state.speakCue(
        '${prefix}Nghỉ ${_remainingSeconds(controller.restRemaining)} giây.',
      );
    } else if (controller.phase == WorkoutPhase.working) {
      if (widget.state.countdownSoundsEnabled) {
        try {
          await SystemSound.play(SystemSoundType.alert);
        } on Object {
          // Voice and the visual state remain authoritative.
        }
      }
      await widget.state.speakCue(_workingCue);
    }
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
        controller.confirmationMode != WorkoutConfirmationMode.aiCamera) {
      return;
    }
    final result = _lastPoseResult;
    final exercise = controller.currentExercise;
    final evidence = _cameraEvidence.build(
      setKey: _cameraSetKey,
      ruleVersionId: exercise.poseRuleVersionId ?? 'unknown',
    );
    final requiredReps = exercise.target.minimum ?? 1;
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
      if (widget.state.hapticsEnabled) HapticFeedback.mediumImpact();
      await widget.state.checkpointWorkout(controller);
      if (controller.phase == WorkoutPhase.resting) {
        await widget.state.speakCue(
          'Đã nhận diện ${result.repCount} lần. Nghỉ ${_remainingSeconds(controller.restRemaining)} giây.',
        );
      } else if (controller.phase == WorkoutPhase.working) {
        await widget.state.speakCue(_workingCue);
      } else if (controller.phase == WorkoutPhase.finishing) {
        await _finish();
      }
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
    if (controller.phase == WorkoutPhase.finishing) await _finish();
  }

  Future<void> _finish() async {
    if (_saving || _completion != null) return;
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
          title: Text(controller.draft.snapshot.title),
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
            '${controller.confirmationMode == WorkoutConfirmationMode.aiCamera ? exercise.target.label : '${exercise.workDurationSeconds} giây'}',
            style: const TextStyle(color: AppColors.textMuted),
          ),
          const SizedBox(height: 24),
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
            onPressed: () =>
                _mutate(controller.skipPreparation, cue: _workingCue),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _mutate(controller.pause),
            icon: const Icon(Icons.pause),
            label: const Text('Tạm dừng'),
          ),
        ],
      ),
    );
  }

  Widget _preparing() {
    final snapshot = controller.draft.snapshot;
    final cameraAvailable =
        CameraCoachPanel.platformSupported &&
        snapshot.exercises.any(
          (exercise) => CameraCoachPanel.supportsRule(
            exercise.exerciseId,
            exercise.poseRuleVersionId,
          ),
        );
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
                '${controller.confirmationMode == WorkoutConfirmationMode.aiCamera ? snapshot.exercises[index].target.label : '${snapshot.exercises[index].workDurationSeconds} giây/hiệp'}',
              ),
            ),
          const SizedBox(height: 12),
          SegmentedButton<WorkoutConfirmationMode>(
            showSelectedIcon: false,
            segments: [
              const ButtonSegment(
                value: WorkoutConfirmationMode.guided,
                icon: Icon(Icons.touch_app_outlined),
                label: Text('Hướng dẫn'),
              ),
              ButtonSegment(
                value: WorkoutConfirmationMode.aiCamera,
                icon: Icon(Icons.camera_alt_outlined),
                label: Text('AI Camera'),
                enabled: cameraAvailable,
              ),
            ],
            selected: {controller.confirmationMode},
            onSelectionChanged: (values) async {
              final requested = values.first;
              await _mutate(() => controller.setConfirmationMode(requested));
            },
          ),
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
              Row(
                children: [
                  Chip(
                    avatar: Icon(
                      controller.confirmationMode ==
                              WorkoutConfirmationMode.aiCamera
                          ? Icons.camera_alt_outlined
                          : Icons.touch_app_outlined,
                      size: 18,
                    ),
                    label: Text(
                      controller.confirmationMode ==
                              WorkoutConfirmationMode.aiCamera
                          ? 'AI Camera Coach'
                          : 'Guided Confirmation',
                    ),
                  ),
                  const Spacer(),
                  Text(_duration(controller.activeDuration)),
                ],
              ),
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
                controller.confirmationMode == WorkoutConfirmationMode.aiCamera
                    ? exercise.target.label
                    : 'Tập trong ${exercise.workDurationSeconds} giây',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              if (controller.usesGuidedTimer) ...[
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
              if (controller.confirmationMode ==
                      WorkoutConfirmationMode.aiCamera &&
                  cameraSupported)
                CameraCoachPanel(
                  key: ValueKey('$_cameraSetKey:${exercise.exerciseId}'),
                  exerciseId: exercise.exerciseId,
                  poseRuleVersionId: exercise.poseRuleVersionId,
                  targetReps: exercise.target.minimum ?? 1,
                  poseRulePublished:
                      exercise.poseRuleVersionId == 'squat_pose_v1',
                  deviceAllowed: true,
                  onResult: (result) {
                    _lastPoseResult = result;
                    _cameraEvidence.observe(_cameraSetKey, result);
                    if (result.announceFeedback &&
                        result.feedbackCode != null) {
                      widget.state.speakCue(
                        _poseFeedback(result.feedbackCode!),
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
                )
              else
                Card(
                  color: AppColors.paleBlue.withValues(alpha: .45),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (controller.confirmationMode ==
                                WorkoutConfirmationMode.aiCamera &&
                            !cameraSupported) ...[
                          const Text(
                            'Camera Coach chưa hỗ trợ bài này. Chế độ Camera Coach vẫn được giữ; hãy bấm chuyển sang Hướng dẫn nếu muốn tiếp tục hiệp này.',
                            style: TextStyle(color: AppColors.warning),
                          ),
                          const SizedBox(height: 8),
                        ],
                        Text(
                          'Gợi ý kỹ thuật',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        for (final cue in exercise.cues.take(3))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.check_circle_outline,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(child: Text(cue)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 22),
              if (controller.usesGuidedTimer)
                Card(
                  color: AppColors.paleBlue.withValues(alpha: .45),
                  child: const ListTile(
                    leading: Icon(Icons.autorenew),
                    title: Text('Đồng hồ đang tự chạy'),
                    subtitle: Text(
                      'Hết thời gian, FitTrack sẽ tự chuyển sang nghỉ.',
                    ),
                  ),
                )
              else if (controller.confirmationMode ==
                  WorkoutConfirmationMode.aiCamera)
                OutlinedButton.icon(
                  onPressed: _useGuidedFallback,
                  icon: const Icon(Icons.touch_app_outlined),
                  label: const Text('Chuyển sang Guided Confirmation'),
                )
              else ...[
                if (cameraSupported) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => _mutate(
                      () => controller.setConfirmationMode(
                        WorkoutConfirmationMode.aiCamera,
                      ),
                    ),
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Dùng AI Camera cho hiệp này'),
                  ),
                ],
              ],
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
                      onPressed: _skipSet,
                      icon: const Icon(Icons.skip_next),
                      label: const Text('Bỏ qua'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _mutate(controller.pause),
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
                  onPressed: () =>
                      _mutate(controller.skipRest, cue: _workingCue),
                  child: const Text('Tập tiếp'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: () => _mutate(controller.pause),
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
          onPressed: () => _mutate(controller.resume, cue: _workingCue),
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
    if (!_saving && !_finishAttempted) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _finish());
    }
    if (_saving) return const Center(child: CircularProgressIndicator());
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
      exercise.target.type == 'repetitions' &&
      exercise.target.minimum != null &&
      CameraCoachPanel.supportsRule(
        exercise.exerciseId,
        exercise.poseRuleVersionId,
      );

  String get _cameraSetKey =>
      '${controller.exerciseIndex}:${controller.setIndex}';

  void _resetCameraEvidence() {
    _lastPoseResult = null;
    _cameraEvidence.reset();
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
      'Camera Coach chưa khả dụng. Bạn có thể thử lại hoặc tự chuyển sang Hướng dẫn.',
  };

  String _cameraUnavailable(PoseCapabilityUnavailableReason reason) =>
      switch (reason) {
        PoseCapabilityUnavailableReason.permissionDenied =>
          'Chưa có quyền camera. Chế độ Camera Coach vẫn được giữ.',
        PoseCapabilityUnavailableReason.trackingUnreliable =>
          'Nhận diện chưa ổn định. Hãy chỉnh ánh sáng hoặc vị trí camera; chế độ sẽ không tự thay đổi.',
        PoseCapabilityUnavailableReason.exerciseUnsupported =>
          'Bài tập này chưa có rule Camera Coach đã xuất bản.',
        _ =>
          'Camera Coach chưa khả dụng. Hãy thử lại hoặc bấm chuyển sang Hướng dẫn.',
      };
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
            Text(completion.snapshot.title, textAlign: TextAlign.center),
            if (completion.snapshot.programTitle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '${completion.snapshot.programTitle} • ${completion.snapshot.contentVersion}',
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
                    label: Text('Guided Confirmation'),
                  ),
                if (modes.contains(WorkoutConfirmationMode.aiCamera))
                  const Chip(
                    avatar: Icon(Icons.camera_alt_outlined, size: 18),
                    label: Text('AI Camera Coach'),
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
                      'Phiên bản nội dung: ${completion.snapshot.contentVersion.isEmpty ? completion.programVersionId : completion.snapshot.contentVersion}',
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
                        'Với Guided Confirmation, số lần/thời gian hiển thị là mục tiêu được kê trong chương trình, không phải kết quả được camera đo.',
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

class _ExerciseMediaBox extends StatelessWidget {
  const _ExerciseMediaBox({required this.exercise});
  final WorkoutExerciseSnapshot exercise;

  @override
  Widget build(BuildContext context) {
    final imageProvider = fitTrackImageProvider(exercise.mediaUrl);
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.navy, AppColors.action],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              image: imageProvider == null
                  ? null
                  : DecorationImage(image: imageProvider, fit: BoxFit.cover),
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
