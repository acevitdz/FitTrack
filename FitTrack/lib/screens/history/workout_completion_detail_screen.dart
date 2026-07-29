import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/active_workout.dart';
import '../../theme/app_colors.dart';

class WorkoutCompletionDetailScreen extends StatelessWidget {
  const WorkoutCompletionDetailScreen({super.key, required this.completion});

  final WorkoutCompletion completion;

  @override
  Widget build(BuildContext context) {
    final snapshot = completion.snapshot;
    final cameraEvents = completion.setEvents
        .where((event) => event.cameraEvidence != null)
        .toList(growable: false);
    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết buổi tập')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(
            snapshot.title,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            '${snapshot.programTitle.isEmpty ? 'Chương trình FitTrack' : snapshot.programTitle}'
            '${snapshot.contentVersion.isEmpty ? '' : ' • v${snapshot.contentVersion}'}',
            style: const TextStyle(color: AppColors.textMuted),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(
                avatar: Icon(_statusIcon(completion.status), size: 18),
                label: Text(_statusLabel(completion.status)),
              ),
              Chip(
                avatar: const Icon(Icons.timer_outlined, size: 18),
                label: Text(_duration(completion.actualDurationSeconds)),
              ),
              Chip(
                avatar: const Icon(Icons.task_alt, size: 18),
                label: Text(
                  '${completion.completedSetCount}/${snapshot.totalSetCount} hiệp',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _SectionCard(
            title: 'Phiên tập thực tế',
            children: [
              _DetailRow(
                label: 'Bắt đầu',
                value: DateFormat(
                  'dd/MM/yyyy • HH:mm:ss',
                ).format(completion.actualStartedAt),
              ),
              _DetailRow(
                label: 'Kết thúc',
                value: DateFormat(
                  'dd/MM/yyyy • HH:mm:ss',
                ).format(completion.completedAt),
              ),
              _DetailRow(
                label: 'Đã bỏ qua',
                value: '${completion.skippedSetCount} hiệp',
              ),
              _DetailRow(
                label: 'Làm lại',
                value: '${completion.redoneSetCount} lần',
              ),
              _DetailRow(
                label: 'Program version ID',
                value: completion.programVersionId,
              ),
            ],
          ),
          if (snapshot.readinessChoice != null ||
              snapshot.readinessVariantTitle != null) ...[
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Readiness đã chọn',
              children: [
                _DetailRow(
                  label: 'Lựa chọn',
                  value: _readinessLabel(snapshot.readinessChoice),
                ),
                if (snapshot.readinessVariantTitle case final title?)
                  _DetailRow(label: 'Biến thể', value: title),
                if (snapshot.readinessGuidance case final guidance?)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      guidance,
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          Text(
            'Chi tiết từng bài và từng hiệp',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          for (var index = 0; index < snapshot.exercises.length; index++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ExerciseEventCard(
                exercise: snapshot.exercises[index],
                events: completion.setEvents
                    .where((event) => event.exerciseIndex == index)
                    .toList(growable: false),
              ),
            ),
          if (cameraEvents.isNotEmpty) ...[
            const SizedBox(height: 10),
            _SectionCard(
              title: 'Bằng chứng Camera Coach',
              children: [
                Text(
                  '${cameraEvents.length} hiệp có số liệu AI tổng hợp. '
                  'FitTrack không lưu ảnh, video hoặc tọa độ landmark trong lịch sử.',
                  style: const TextStyle(color: AppColors.textMuted),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Nguồn nội dung',
            children: [
              if (snapshot.sourceRefs.isEmpty)
                const Text(
                  'Không có nguồn được ghi trong snapshot.',
                  style: TextStyle(color: AppColors.textMuted),
                )
              else
                for (final source in snapshot.sourceRefs)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: SelectableText(source),
                  ),
            ],
          ),
        ],
      ),
    );
  }

  static String _duration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainder = seconds % 60;
    if (hours > 0) return '${hours}g ${minutes}p';
    return '${minutes}p ${remainder}g';
  }

  static IconData _statusIcon(WorkoutCompletionStatus status) =>
      switch (status) {
        WorkoutCompletionStatus.completed => Icons.check_circle_outline,
        WorkoutCompletionStatus.partiallyCompleted => Icons.timelapse,
        WorkoutCompletionStatus.abandoned => Icons.block_outlined,
      };

  static String _statusLabel(WorkoutCompletionStatus status) =>
      switch (status) {
        WorkoutCompletionStatus.completed => 'Hoàn tất',
        WorkoutCompletionStatus.partiallyCompleted => 'Hoàn tất một phần',
        WorkoutCompletionStatus.abandoned => 'Bỏ dở',
      };

  static String _readinessLabel(String? value) => switch (value) {
    'ready' => 'Sẵn sàng',
    'reduceToday' => 'Giảm tải hôm nay',
    'recovery' => 'Phục hồi',
    null || '' => 'Không ghi nhận',
    _ => value,
  };
}

class _ExerciseEventCard extends StatelessWidget {
  const _ExerciseEventCard({required this.exercise, required this.events});

  final WorkoutExerciseSnapshot exercise;
  final List<SetEvent> events;

  @override
  Widget build(BuildContext context) => Card(
    child: ExpansionTile(
      initiallyExpanded: true,
      leading: CircleAvatar(
        child: Text('${events.where(_isCompleted).length}'),
      ),
      title: Text(exercise.name),
      subtitle: Text(
        '${exercise.setCount} hiệp • ${exercise.target.label}'
        '${exercise.isAlternative ? ' • bài thay thế' : ''}',
      ),
      children: [
        if (exercise.isAlternative)
          ListTile(
            dense: true,
            leading: const Icon(Icons.swap_horiz),
            title: const Text('Đã thay bài được kê ban đầu'),
            subtitle: Text('ID gốc: ${exercise.prescribedExerciseId}'),
          ),
        if (events.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Không có sự kiện hiệp được ghi nhận.',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
          )
        else
          for (var index = 0; index < events.length; index++) ...[
            _SetEventTile(
              event: events[index],
              exerciseName: _exerciseNameFor(events[index].exerciseId),
            ),
            if (index < events.length - 1) const Divider(height: 1),
          ],
      ],
    ),
  );

  bool _isCompleted(SetEvent event) => event.status == SetEventStatus.completed;

  String _exerciseNameFor(String exerciseId) {
    if (exercise.exerciseId == exerciseId) return exercise.name;
    for (final option in exercise.alternatives) {
      if (option.exerciseId == exerciseId) return option.name;
    }
    return exerciseId;
  }
}

class _SetEventTile extends StatelessWidget {
  const _SetEventTile({required this.event, required this.exerciseName});

  final SetEvent event;
  final String exerciseName;

  @override
  Widget build(BuildContext context) {
    final evidence = event.cameraEvidence;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: _color.withValues(alpha: .12),
        foregroundColor: _color,
        child: Icon(_icon, size: 20),
      ),
      title: Text('Hiệp ${event.setIndex + 1} • ${_statusLabel(event.status)}'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$exerciseName • mục tiêu ${event.targetContext.label}'),
          Text(
            '${_modeLabel(event.confirmationMode)} • '
            '${DateFormat('HH:mm:ss').format(event.completedAt)}',
          ),
          if (event.detectedRepCount case final reps?)
            Text(
              'AI nhận diện: $reps lần'
              '${event.confidence == null ? '' : ' • độ tin cậy ${(event.confidence! * 100).round()}%'}',
            ),
          if (event.timedDurationSeconds case final seconds?)
            Text('Thời gian thực tế: $seconds giây'),
          if (event.skipReason case final reason?)
            Text('Lý do: ${_skipReason(reason)}'),
          if (evidence != null)
            Text(
              'Rule ${evidence.ruleVersionId} • '
              '${evidence.reliableFrameCount}/${evidence.evaluatedFrameCount} khung tin cậy '
              '(${(evidence.reliableFrameRatio * 100).round()}%) • '
              '${evidence.formCueCount} cảnh báo form • '
              'TB ${(evidence.averageConfidence * 100).round()}%',
            ),
        ],
      ),
    );
  }

  Color get _color => switch (event.status) {
    SetEventStatus.completed => AppColors.success,
    SetEventStatus.redone => AppColors.primary,
    SetEventStatus.skipped => AppColors.warning,
  };

  IconData get _icon => switch (event.status) {
    SetEventStatus.completed => Icons.check,
    SetEventStatus.redone => Icons.replay,
    SetEventStatus.skipped => Icons.skip_next,
  };

  String _statusLabel(SetEventStatus status) => switch (status) {
    SetEventStatus.completed => 'Hoàn tất',
    SetEventStatus.redone => 'Làm lại',
    SetEventStatus.skipped => 'Bỏ qua',
  };

  String _modeLabel(WorkoutConfirmationMode mode) => switch (mode) {
    WorkoutConfirmationMode.aiCamera => 'AI Camera Coach',
    WorkoutConfirmationMode.guided => 'Guided Confirmation',
  };

  String _skipReason(String reason) => switch (reason) {
    'discomfort' => 'Cảm thấy khó chịu',
    'equipment_unavailable' => 'Không có dụng cụ',
    'need_recovery' => 'Cần nghỉ thêm',
    _ => reason,
  };
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 126,
          child: Text(
            label,
            style: const TextStyle(color: AppColors.textMuted),
          ),
        ),
        Expanded(child: SelectableText(value)),
      ],
    ),
  );
}
