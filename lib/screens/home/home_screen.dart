import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/active_workout.dart';
import '../../models/program.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/design_system.dart';
import '../active/active_workout_screen.dart';
import '../health/weight_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.state,
    required this.onOpenProgram,
    required this.onOpenProfile,
    required this.onOpenHistory,
    this.preferredOccurrenceId,
  });

  final AppState state;
  final VoidCallback onOpenProgram;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenHistory;
  final String? preferredOccurrenceId;

  @override
  Widget build(BuildContext context) {
    final preferred = preferredOccurrenceId == null
        ? null
        : state.occurrenceById(preferredOccurrenceId!);
    final occurrence =
        preferred?.isOpen == true &&
            preferred?.status != WorkoutOccurrenceStatus.inProgress
        ? preferred
        : state.todayOccurrence;
    final session = occurrence == null
        ? null
        : state.sessionForOccurrence(occurrence);
    final next = state.nextOccurrence;
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: state.ensureProgramEnrollment,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Row(
              children: [
                InkWell(
                  onTap: onOpenProfile,
                  borderRadius: BorderRadius.circular(24),
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.paleBlue,
                    child: Text(_initial(state.profile.name)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Trang chủ',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Text(
                        DateFormat('EEEE, dd/MM', 'vi').format(DateTime.now()),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Cập nhật chỉ số cơ thể',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => WeightScreen(state: state),
                    ),
                  ),
                  icon: const Icon(Icons.monitor_weight_outlined),
                ),
              ],
            ),
            const SizedBox(height: 14),
            OfflineBanner(visible: !state.firebaseAvailable),
            if (!state.firebaseAvailable) const SizedBox(height: 12),
            if (state.activeWorkoutDraft != null)
              _ResumeCard(state: state, onOpenHistory: onOpenHistory)
            else if (occurrence == null || session == null)
              _NoSessionCard(
                state: state,
                nextOccurrence: next,
                nextSession: next == null
                    ? null
                    : state.sessionForOccurrence(next),
                onOpenProgram: onOpenProgram,
              )
            else
              _SessionCard(
                state: state,
                occurrence: occurrence,
                session: session,
                onOpenHistory: onOpenHistory,
              ),
            const SizedBox(height: 20),
            Text('Tiến độ tuần', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: MetricCard(
                    label: 'Đã tập tuần này',
                    value:
                        '${state.targetWorkoutsThisWeek}/${state.activeSessionsPerWeek}',
                    icon: Icons.task_alt,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: MetricCard(
                    label: 'Chuỗi ngày tập',
                    value: '${state.targetWorkoutStreak} ngày',
                    icon: Icons.local_fire_department_outlined,
                    color: AppColors.warning,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Card(
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.paleBlue,
                  child: Icon(
                    Icons.local_fire_department_outlined,
                    color: AppColors.warning,
                  ),
                ),
                title: Text('Chuỗi hoạt động: ${state.currentStreak} ngày'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => WeightScreen(state: state)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.paleBlue,
                  child: Icon(Icons.route_outlined, color: AppColors.primary),
                ),
                title: Text(
                  state.activeProgramDisplayTitle,
                ),
                subtitle: Text(
                  state.enrollment == null
                      ? 'Đang chọn chương trình phù hợp'
                      : 'Lịch được tạo tự động từ phiên bản đã phát hành',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: onOpenProgram,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'FitTrack hỗ trợ hướng dẫn luyện tập, không thay thế tư vấn hoặc chẩn đoán y khoa. Dừng tập nếu bạn thấy đau, chóng mặt hoặc khó chịu bất thường.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  String _initial(String name) {
    final trimmed = name.trim();
    return trimmed.isEmpty ? 'F' : trimmed.characters.first.toUpperCase();
  }
}

typedef TodayScreen = HomeScreen;

class _SessionCard extends StatefulWidget {
  const _SessionCard({
    required this.state,
    required this.occurrence,
    required this.session,
    required this.onOpenHistory,
  });

  final AppState state;
  final WorkoutOccurrence occurrence;
  final ProgramSession session;
  final VoidCallback onOpenHistory;

  @override
  State<_SessionCard> createState() => _SessionCardState();
}

class _SessionCardState extends State<_SessionCard> {
  bool _busy = false;

  bool get _isOverdue {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final scheduled = widget.occurrence.scheduledDate;
    return DateTime(
      scheduled.year,
      scheduled.month,
      scheduled.day,
    ).isBefore(today);
  }

  Future<void> _start(WorkoutConfirmationMode mode) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final controller = await widget.state.openWorkout(
        widget.occurrence,
        mode: mode,
      );
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ActiveWorkoutScreen(
            state: widget.state,
            controller: controller,
            onOpenHistory: widget.onOpenHistory,
          ),
        ),
      );
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_message(error))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reschedule() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final scheduled = widget.occurrence.scheduledDate;
    final initialDate = scheduled.isBefore(today) ? today : scheduled;
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour:
            widget.occurrence.scheduledHour ?? widget.state.programReminderHour,
        minute:
            widget.occurrence.scheduledMinute ??
            widget.state.programReminderMinute,
      ),
    );
    if (time == null || !mounted) return;
    final mode = await showModalBottomSheet<OccurrenceRescheduleMode>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.event),
              title: const Text('Chỉ dời buổi này'),
              subtitle: const Text(
                'Giữ nguyên các buổi sau; FitTrack sẽ kiểm tra thời gian nghỉ.',
              ),
              onTap: () =>
                  Navigator.pop(context, OccurrenceRescheduleMode.single),
            ),
            ListTile(
              leading: const Icon(Icons.event_repeat),
              title: const Text('Dời buổi này và các buổi sau'),
              subtitle: const Text(
                'Dịch toàn bộ phần lịch còn lại cùng số ngày.',
              ),
              onTap: () =>
                  Navigator.pop(context, OccurrenceRescheduleMode.cascade),
            ),
          ],
        ),
      ),
    );
    if (mode == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.state.rescheduleOccurrence(
        widget.occurrence,
        scheduledDate: date,
        hour: time.hour,
        minute: time.minute,
        mode: mode,
      );
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_message(error))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final readinessCurrent = widget.state.isReadinessCurrent(widget.occurrence);
    final choice = readinessCurrent ? widget.occurrence.readinessChoice : null;
    final readinessVariant = choice == null
        ? null
        : widget.session.readinessVariantFor(choice);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bolt, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isOverdue ? 'Buổi tập quá hạn' : 'Buổi tập được đề xuất',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Chip(label: Text('Tuần ${widget.occurrence.weekNumber}')),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              AppState.displaySessionTitle(widget.session.title),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            Text(
              '${DateFormat('dd/MM/yyyy').format(widget.occurrence.scheduledDate)}'
              ' • ${TimeOfDay(hour: widget.occurrence.scheduledHour ?? widget.state.programReminderHour, minute: widget.occurrence.scheduledMinute ?? widget.state.programReminderMinute).format(context)}',
              style: TextStyle(
                color: _isOverdue ? AppColors.warning : AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${widget.session.estimatedDurationMinutes} phút • ${widget.session.totalSets} hiệp • ${widget.session.blocks.length} phần',
              style: const TextStyle(color: AppColors.textMuted),
            ),
            const SizedBox(height: 20),
            Text(
              'Hôm nay bạn cảm thấy thế nào?',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            SegmentedButton<ReadinessChoice>(
              showSelectedIcon: false,
              emptySelectionAllowed: true,
              segments: const [
                ButtonSegment(
                  value: ReadinessChoice.ready,
                  icon: Icon(Icons.sentiment_satisfied_alt),
                  label: Text('Sung sức'),
                ),
                ButtonSegment(
                  value: ReadinessChoice.reduceToday,
                  icon: Icon(Icons.tune),
                  label: Text('Hơi mệt (Giảm tải)'),
                ),
                ButtonSegment(
                  value: ReadinessChoice.recovery,
                  icon: Icon(Icons.self_improvement),
                  label: Text('Cần nghỉ ngơi'),
                ),
              ],
              selected: choice == null ? const {} : {choice},
              onSelectionChanged: _busy
                  ? null
                  : (values) {
                      if (values.isEmpty) return;
                      widget.state.chooseReadiness(
                        widget.occurrence,
                        values.first,
                      );
                    },
            ),
            if (readinessVariant != null) ...[
              const SizedBox(height: 12),
              Text(
                readinessVariant.guidance,
                style: const TextStyle(color: AppColors.textMuted),
              ),
              if (readinessVariant.safetyMessage case final warning?) ...[
                const SizedBox(height: 6),
                Text(warning, style: const TextStyle(color: AppColors.warning)),
              ],
            ] else ...[
              const SizedBox(height: 10),
              const Text(
                'Vui lòng đánh giá lại mỗi ngày để FitTrack chọn đúng biến thể buổi tập.',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ],
            const SizedBox(height: 18),
            AppPrimaryButton(
              label: 'Bắt đầu với hướng dẫn',
              icon: Icons.play_arrow_rounded,
              loading: _busy,
              onPressed: readinessCurrent
                  ? () => _start(WorkoutConfirmationMode.guided)
                  : null,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: _busy ? null : _reschedule,
                    icon: const Icon(Icons.event_repeat),
                    label: const Text('Dời lịch'),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: _busy
                        ? null
                        : () async {
                            final confirmed = await confirmAction(
                              context,
                              title: 'Bỏ qua buổi tập?',
                              message:
                                  'Buổi này sẽ được ghi là đã bỏ qua, không tạo kết quả thủ công.',
                              confirmLabel: 'Bỏ qua',
                            );
                            if (confirmed) {
                              if (_isOverdue) {
                                await widget.state.markOccurrenceMissed(
                                  widget.occurrence,
                                );
                              } else {
                                await widget.state.skipOccurrence(
                                  widget.occurrence,
                                );
                              }
                            }
                          },
                    icon: const Icon(Icons.skip_next_outlined),
                    label: Text(_isOverdue ? 'Đã lỡ' : 'Bỏ qua'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _message(Object error) => error
      .toString()
      .replaceFirst('Bad state: ', '')
      .replaceFirst('Invalid argument(s): ', '');
}

class _ResumeCard extends StatefulWidget {
  const _ResumeCard({required this.state, required this.onOpenHistory});
  final AppState state;
  final VoidCallback onOpenHistory;

  @override
  State<_ResumeCard> createState() => _ResumeCardState();
}

class _ResumeCardState extends State<_ResumeCard> {
  bool _busy = false;

  WorkoutOccurrence? _occurrenceForDraft() {
    final draft = widget.state.activeWorkoutDraft;
    if (draft == null) return null;
    return widget.state.occurrences
        .where((item) => item.id == draft.occurrenceId)
        .firstOrNull;
  }

  Future<void> _resume() async {
    final draft = widget.state.activeWorkoutDraft;
    if (draft == null || _busy) return;
    final occurrence = _occurrenceForDraft();
    if (occurrence == null) {
      _showError('Không tìm thấy lịch của buổi tập đang dở.');
      return;
    }
    setState(() => _busy = true);
    try {
      final controller = await widget.state.openWorkout(occurrence);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ActiveWorkoutScreen(
            state: widget.state,
            controller: controller,
            onOpenHistory: widget.onOpenHistory,
          ),
        ),
      );
    } on Object catch (error) {
      _showError(_message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finish() async {
    final draft = widget.state.activeWorkoutDraft;
    final occurrence = _occurrenceForDraft();
    if (draft == null ||
        draft.startedAt == null ||
        occurrence == null ||
        _busy) {
      return;
    }
    final confirmed = await confirmAction(
      context,
      title: 'Hoàn tất buổi tập đang dở?',
      message:
          'FitTrack chỉ ghi nhận các hiệp đã xác nhận. Các hiệp chưa thực hiện không được tính là hoàn thành.',
      confirmLabel: 'Hoàn tất và lưu',
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      final controller = await widget.state.openWorkout(occurrence);
      await widget.state.finishWorkout(controller);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã lưu kết quả buổi tập.')),
        );
      }
    } on Object catch (error) {
      _showError(_message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _discard() async {
    final occurrence = _occurrenceForDraft();
    if (occurrence == null || _busy) return;
    final confirmed = await confirmAction(
      context,
      title: 'Bỏ buổi tập đang dở?',
      message:
          'Bản nháp sẽ bị xóa và lịch được đánh dấu đã bỏ qua. Thao tác này không thể hoàn tác.',
      confirmLabel: 'Bỏ buổi',
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      final controller = await widget.state.openWorkout(occurrence);
      await widget.state.discardWorkout(controller);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã bỏ buổi tập đang dở.')),
        );
      }
    } on Object catch (error) {
      _showError(_message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _message(Object error) => error
      .toString()
      .replaceFirst('Bad state: ', '')
      .replaceFirst('Invalid argument(s): ', '');

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.state.activeWorkoutDraft!;
    final canDiscard =
        draft.phase == WorkoutPhase.preparing ||
        draft.phase == WorkoutPhase.countingDown ||
        draft.phase == WorkoutPhase.working ||
        draft.phase == WorkoutPhase.resting ||
        draft.phase == WorkoutPhase.paused;
    final processedSetCount = draft.setEvents
        .where((event) => event.status != SetEventStatus.redone)
        .length;
    return Card(
      color: AppColors.navy,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Buổi tập đang dở',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 6),
            Text(
              AppState.displaySessionTitle(draft.snapshot.title),
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              '$processedSetCount/${draft.snapshot.totalSetCount} hiệp đã xử lý',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: _busy ? null : _resume,
                icon: const Icon(Icons.restore),
                label: Text(_busy ? 'Đang mở…' : 'Tiếp tục buổi tập'),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                if (canDiscard)
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white54),
                      ),
                      onPressed: _busy ? null : _discard,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Bỏ buổi'),
                    ),
                  ),
                if (draft.startedAt != null) ...[
                  if (canDiscard) const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _finish,
                      icon: const Icon(Icons.flag_outlined),
                      label: Text(
                        draft.phase == WorkoutPhase.finishing
                            ? 'Lưu lại'
                            : 'Hoàn tất',
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NoSessionCard extends StatelessWidget {
  const _NoSessionCard({
    required this.state,
    required this.nextOccurrence,
    required this.nextSession,
    required this.onOpenProgram,
  });

  final AppState state;
  final WorkoutOccurrence? nextOccurrence;
  final ProgramSession? nextSession;
  final VoidCallback onOpenProgram;

  @override
  Widget build(BuildContext context) {
    final completed =
        state.enrollment?.status == ProgramEnrollmentStatus.completed;
    final next = nextOccurrence;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              completed ? Icons.emoji_events_outlined : Icons.event_available,
              size: 52,
              color: AppColors.primary,
            ),
            const SizedBox(height: 12),
            Text(
              completed
                  ? 'Bạn đã kết thúc lộ trình'
                  : 'Không có buổi tập cần làm hôm nay',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              completed
                  ? 'Kết quả cũ vẫn được giữ nguyên. Bạn có thể bắt đầu một enrollment mới.'
                  : next == null
                  ? 'Bạn có thể nghỉ ngơi hoặc xem lại chương trình.'
                  : 'Buổi kế tiếp: ${nextSession?.title ?? 'Buổi tập FitTrack'}'
                        ' • ${DateFormat('dd/MM/yyyy').format(next.scheduledDate)}',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (completed)
              FilledButton.icon(
                onPressed: () async {
                  try {
                    await state.restartProgramEnrollment();
                  } on Object catch (error) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(error.toString())));
                  }
                },
                icon: const Icon(Icons.replay),
                label: const Text('Bắt đầu lộ trình mới'),
              )
            else
              OutlinedButton(
                onPressed: onOpenProgram,
                child: const Text('Xem chương trình'),
              ),
          ],
        ),
      ),
    );
  }
}
