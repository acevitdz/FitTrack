import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/active_workout.dart';
import '../../models/pose_coach.dart';
import '../../services/active_workout_controller.dart';
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
  bool _saving = false;
  bool _aiCompletionInFlight = false;
  bool _finishAttempted = false;
  String? _finishError;
  int? _lastCountdownSecond;
  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;

  ActiveWorkoutController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lifecycleState =
        WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;
    final reconciled = controller.reconcile();
    controller.addListener(_changed);
    if (reconciled) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await widget.state.checkpointWorkout(controller);
        if (_lifecycleState == AppLifecycleState.resumed) {
          await widget.state.speakCue(_workingCue);
        }
      });
    }
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted) return;
      final transitioned = controller.reconcile();
      if (transitioned) {
        _lastCountdownSecond = null;
        await widget.state.checkpointWorkout(controller);
        if (_lifecycleState == AppLifecycleState.resumed) {
          await widget.state.speakCue(_workingCue);
        }
      } else if (controller.phase == WorkoutPhase.resting &&
          _lifecycleState == AppLifecycleState.resumed) {
        final seconds = controller.restRemaining.inSeconds;
        if (seconds >= 1 && seconds <= 3 && seconds != _lastCountdownSecond) {
          _lastCountdownSecond = seconds;
          await widget.state.speakCue('$seconds');
        }
      } else {
        _lastCountdownSecond = null;
      }
      if (mounted) setState(() {});
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
    final transitioned = controller.reconcile();
    if (transitioned) {
      unawaited(widget.state.checkpointWorkout(controller));
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  String get _workingCue {
    final exercise = controller.currentExercise;
    final set = controller.setIndex + 1;
    return '${exercise.name}. Hiệp $set trên ${exercise.setCount}. ${exercise.target.label}.';
  }

  Future<void> _mutate(bool Function() action, {String? cue}) async {
    final changed = action();
    if (!changed) return;
    if (widget.state.hapticsEnabled) HapticFeedback.selectionClick();
    await widget.state.checkpointWorkout(controller);
    if (cue != null) await widget.state.speakCue(cue);
  }

  Future<void> _start() async {
    await _mutate(controller.start, cue: _workingCue);
  }

  Future<void> _completeSet() async {
    await _mutate(controller.completeSet);
    if (controller.phase == WorkoutPhase.resting) {
      await widget.state.speakCue(
        'Nghỉ ${controller.restRemaining.inSeconds} giây.',
      );
    } else if (controller.phase == WorkoutPhase.working) {
      await widget.state.speakCue(_workingCue);
    } else if (controller.phase == WorkoutPhase.finishing) {
      await _finish();
    }
  }

  Future<void> _completeGuidedSet() async {
    if (controller.confirmationMode == WorkoutConfirmationMode.aiCamera) {
      await _useGuidedFallback();
    }
    await _completeSet();
  }

  Future<void> _completeAiSet() async {
    if (_aiCompletionInFlight ||
        controller.phase != WorkoutPhase.working ||
        controller.confirmationMode != WorkoutConfirmationMode.aiCamera) {
      return;
    }
    final result = _lastPoseResult;
    if (result == null) return;
    _aiCompletionInFlight = true;
    try {
      final changed = controller.completeSet(
        detectedRepCount: result.repCount,
        confidence: result.confidence,
      );
      if (!changed) return;
      if (widget.state.hapticsEnabled) HapticFeedback.mediumImpact();
      await widget.state.checkpointWorkout(controller);
      if (controller.phase == WorkoutPhase.resting) {
        await widget.state.speakCue(
          'Đã nhận diện ${result.repCount} lần. Nghỉ ${controller.restRemaining.inSeconds} giây.',
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
    if (controller.phase == WorkoutPhase.working ||
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
    WorkoutPhase.working => _working(),
    WorkoutPhase.resting => _resting(),
    WorkoutPhase.paused => _paused(),
    WorkoutPhase.finishing => _finishing(),
    WorkoutPhase.completed || WorkoutPhase.discarded => const SizedBox.shrink(),
  };

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
                '${snapshot.exercises[index].setCount} hiệp • ${snapshot.exercises[index].target.label}',
              ),
            ),
          const SizedBox(height: 12),
          SegmentedButton<WorkoutConfirmationMode>(
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
                label: Text('AI Camera'),
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
                exercise.target.label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 24),
              if (controller.confirmationMode ==
                      WorkoutConfirmationMode.aiCamera &&
                  cameraSupported)
                CameraCoachPanel(
                  key: ValueKey(
                    '${controller.exerciseIndex}:${controller.setIndex}',
                  ),
                  exerciseId: exercise.exerciseId,
                  targetReps: exercise.target.minimum ?? 1,
                  poseRulePublished:
                      exercise.poseRuleVersionId == 'squat_pose_v1',
                  deviceAllowed: true,
                  onResult: (result) {
                    _lastPoseResult = result;
                    if (result.announceFeedback &&
                        result.feedbackCode != null) {
                      widget.state.speakCue(
                        _poseFeedback(result.feedbackCode!),
                      );
                    }
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
                            'AI Camera chưa hỗ trợ bài này; hiệp hiện tại dùng Guided Confirmation.',
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
              if (controller.confirmationMode ==
                      WorkoutConfirmationMode.aiCamera &&
                  cameraSupported)
                OutlinedButton.icon(
                  onPressed: _useGuidedFallback,
                  icon: const Icon(Icons.touch_app_outlined),
                  label: const Text('Chuyển sang Guided Confirmation'),
                )
              else ...[
                AppPrimaryButton(
                  label: 'Đã hoàn thành hiệp',
                  icon: Icons.check,
                  onPressed: _completeGuidedSet,
                ),
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
            label: 'Còn ${remaining.inSeconds} giây',
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
    final seconds = value.inSeconds < 0 ? 0 : value.inSeconds;
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainder.toString().padLeft(2, '0')}';
  }

  bool _cameraSupported(WorkoutExerciseSnapshot exercise) =>
      exercise.target.type == 'repetitions' &&
      exercise.target.minimum != null &&
      exercise.poseRuleVersionId == 'squat_pose_v1' &&
      CameraCoachPanel.supportsExercise(exercise.exerciseId);

  String _poseFeedback(PoseFeedbackCode code) => switch (code) {
    PoseFeedbackCode.positionFullBody => 'Hãy đưa toàn thân vào khung hình.',
    PoseFeedbackCode.lowConfidence => 'Hãy giữ ổn định và tăng ánh sáng.',
    PoseFeedbackCode.staleFrame => 'Camera chưa theo kịp chuyển động.',
    PoseFeedbackCode.standTall => 'Hãy đứng thẳng để bắt đầu.',
    PoseFeedbackCode.lowerHips => 'Hãy hạ thấp thêm.',
    PoseFeedbackCode.detectorUnavailable =>
      'Camera Coach chưa khả dụng. Chuyển sang hướng dẫn.',
  };
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
    final modes = completion.setEvents
        .map((event) => event.confirmationMode)
        .toSet();

    return Scaffold(
      body: FitTrackPage(
        child: Column(
          children: [
            CircleAvatar(
              radius: 42,
              backgroundColor: partiallyCompleted
                  ? AppColors.warning.withValues(alpha: .14)
                  : const Color(0xFFE1F7EC),
              child: Icon(
                partiallyCompleted ? Icons.flag_outlined : Icons.check,
                size: 48,
                color: partiallyCompleted
                    ? AppColors.warning
                    : AppColors.success,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              partiallyCompleted
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
