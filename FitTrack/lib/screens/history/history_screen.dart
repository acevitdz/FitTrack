import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/active_workout.dart';
import '../../models/measurement_units.dart';
import '../../models/program.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common_widgets.dart';
import '../health/weight_screen.dart';
import 'workout_completion_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, required this.state});

  final AppState state;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  var _periodDays = 30;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final allCompletions = state.completedTargetWorkouts;
    final start = _periodStart(_periodDays);
    final reportOccurrences = _occurrencesInPeriod(state, start);
    final reportOccurrenceIds = reportOccurrences
        .map((item) => item.id)
        .toSet();
    final completions = start == null
        ? allCompletions
        : allCompletions
              .where((item) => !item.completedAt.isBefore(start))
              .toList(growable: false);
    final scheduledCount = start == null
        ? _occurrencesInPeriod(state, null).length
        : reportOccurrences.length;
    final participatingOccurrenceIds = allCompletions
        .where((item) => item.hasParticipation)
        .map((item) => item.occurrenceId)
        .toSet();
    final attendedCount = reportOccurrenceIds
        .where(participatingOccurrenceIds.contains)
        .length;
    final fullyCompletedCount = completions
        .where((item) => item.status == WorkoutCompletionStatus.completed)
        .length;
    final partialCount = completions
        .where(
          (item) => item.status == WorkoutCompletionStatus.partiallyCompleted,
        )
        .length;
    final abandonedCount = completions
        .where((item) => item.status == WorkoutCompletionStatus.abandoned)
        .length;
    final participatingCompletions = completions
        .where((item) => item.hasParticipation)
        .toList(growable: false);
    final completedSetCount = participatingCompletions.fold<int>(
      0,
      (total, item) => total + item.completedSetCount,
    );
    final topExercises = _topExercises(participatingCompletions);
    final muscleBalance = _muscleBalance(participatingCompletions);
    final measurementUnit = MeasurementUnitSystem.fromStored(state.unit);
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          const SliverAppBar.large(pinned: true, title: Text('Tiến độ')),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            sliver: SliverList.list(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: MetricCard(
                        label: 'Buổi có tham gia',
                        value: '${fullyCompletedCount + partialCount}',
                        icon: Icons.task_alt,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: MetricCard(
                        label: 'Thời gian trong kỳ',
                        value: _totalDuration(
                          participatingCompletions.fold<Duration>(
                            Duration.zero,
                            (total, item) =>
                                total +
                                Duration(seconds: item.actualDurationSeconds),
                          ),
                        ),
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
                        label: 'Hiệp hoàn tất',
                        value: '$completedSetCount',
                        icon: Icons.fitness_center,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: MetricCard(
                        label: 'Streak tập luyện',
                        value: '${state.targetWorkoutStreak} ngày',
                        icon: Icons.local_fire_department,
                        color: AppColors.warning,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: MetricCard(
                        label: 'Streak nhập cân',
                        value: '${state.currentStreak} ngày',
                        icon: Icons.monitor_weight_outlined,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: MetricCard(
                        label: 'Streak nhập cân dài nhất',
                        value: '${state.longestStreak} ngày',
                        icon: Icons.workspace_premium_outlined,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _PeriodReportCard(
                  periodDays: _periodDays,
                  completedCount: attendedCount,
                  scheduledCount: scheduledCount,
                  fullyCompletedCount: fullyCompletedCount,
                  partialCount: partialCount,
                  abandonedCount: abandonedCount,
                  onPeriodChanged: (value) =>
                      setState(() => _periodDays = value),
                ),
                const SizedBox(height: 12),
                _StreakSummaryCard(state: state),
                const SizedBox(height: 12),
                _ActivityHeatmap(
                  weightDays: state.activeDays,
                  workoutDays: state.workoutDays,
                ),
                const SizedBox(height: 12),
                _RankedMetricCard(
                  title: 'Bài tập thường xuyên nhất',
                  emptyMessage:
                      'Hoàn thành buổi tập để xem các bài được thực hiện nhiều nhất.',
                  values: topExercises,
                  icon: Icons.star_outline,
                ),
                const SizedBox(height: 12),
                _RankedMetricCard(
                  title: 'Tỷ lệ phân bổ nhóm cơ',
                  emptyMessage:
                      'Chưa đủ set hoàn thành để tính phân bổ nhóm cơ.',
                  values: muscleBalance,
                  icon: Icons.accessibility_new,
                ),
                const SizedBox(height: 18),
                Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppColors.paleBlue,
                      child: Icon(Icons.monitor_weight_outlined),
                    ),
                    title: const Text('Chỉ số cơ thể'),
                    subtitle: Text(
                      '${measurementUnit.formatWeight(state.profile.currentWeightKg)} • '
                      'BMI ${state.profile.bmi.toStringAsFixed(1)} • '
                      'streak ${state.currentStreak} ngày',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => WeightScreen(state: state),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  'Lịch sử buổi tập trong kỳ',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                if (completions.isEmpty)
                  const EmptyState(
                    icon: Icons.history,
                    title: 'Chưa có dữ liệu',
                    message:
                        'Kết quả sẽ xuất hiện tự động sau khi bạn hoàn tất Active Workout.',
                  )
                else
                  for (final completion in completions)
                    _CompletionTile(completion: completion),
                if (state.completions.isNotEmpty || state.plans.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Card(
                    color: AppColors.input,
                    child: const ListTile(
                      leading: Icon(Icons.archive_outlined),
                      title: Text('Dữ liệu phiên bản cũ'),
                      subtitle: Text(
                        'Kế hoạch và kết quả thủ công cũ được giữ ở chế độ chỉ đọc; không dùng để kê đơn mới.',
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _totalDuration(Duration value) {
    if (value.inHours > 0) {
      return '${value.inHours}g ${value.inMinutes.remainder(60)}p';
    }
    return '${value.inMinutes} phút';
  }

  DateTime? _periodStart(int days) {
    if (days == 0) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return today.subtract(Duration(days: days - 1));
  }

  List<WorkoutOccurrence> _occurrencesInPeriod(
    AppState state,
    DateTime? start,
  ) {
    final now = DateTime.now();
    return state.occurrences
        .where((occurrence) {
          final date = occurrence.scheduledDate;
          if (date.isAfter(now)) return false;
          if (start != null && date.isBefore(start)) return false;
          return occurrence.status != WorkoutOccurrenceStatus.cancelled;
        })
        .toList(growable: false);
  }

  List<_RankedMetric> _topExercises(List<WorkoutCompletion> completions) {
    final names = <String, String>{};
    final counts = <String, int>{};
    for (final completion in completions) {
      for (final exercise in completion.snapshot.exercises) {
        names[exercise.exerciseId] = exercise.name;
      }
      for (final event in completion.setEvents) {
        if (event.status != SetEventStatus.completed) continue;
        counts.update(
          event.exerciseId,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
      }
    }
    return counts.entries
        .map(
          (entry) => _RankedMetric(
            label: names[entry.key] ?? entry.key,
            value: entry.value,
          ),
        )
        .toList()
      ..sort((left, right) => right.value.compareTo(left.value));
  }

  List<_RankedMetric> _muscleBalance(List<WorkoutCompletion> completions) {
    final counts = <String, int>{};
    for (final completion in completions) {
      final groups = {
        for (final exercise in completion.snapshot.exercises)
          exercise.exerciseId: exercise.muscleGroup.trim().isEmpty
              ? 'Chưa phân nhóm'
              : exercise.muscleGroup,
      };
      for (final event in completion.setEvents) {
        if (event.status != SetEventStatus.completed) continue;
        final group = groups[event.exerciseId] ?? 'Chưa phân nhóm';
        counts.update(group, (value) => value + 1, ifAbsent: () => 1);
      }
    }
    return counts.entries
        .map((entry) => _RankedMetric(label: entry.key, value: entry.value))
        .toList()
      ..sort((left, right) => right.value.compareTo(left.value));
  }
}

class _PeriodReportCard extends StatelessWidget {
  const _PeriodReportCard({
    required this.periodDays,
    required this.completedCount,
    required this.scheduledCount,
    required this.fullyCompletedCount,
    required this.partialCount,
    required this.abandonedCount,
    required this.onPeriodChanged,
  });

  final int periodDays;
  final int completedCount;
  final int scheduledCount;
  final int fullyCompletedCount;
  final int partialCount;
  final int abandonedCount;
  final ValueChanged<int> onPeriodChanged;

  @override
  Widget build(BuildContext context) {
    final attendance = scheduledCount == 0
        ? null
        : (completedCount / scheduledCount).clamp(0, 1).toDouble();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Báo cáo', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            SegmentedButton<int>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 7, label: Text('7 ngày')),
                ButtonSegment(value: 30, label: Text('30 ngày')),
                ButtonSegment(value: 0, label: Text('Tất cả')),
              ],
              selected: {periodDays},
              onSelectionChanged: (values) => onPeriodChanged(values.first),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(child: Text('Độ chuyên cần')),
                Text(
                  attendance == null
                      ? 'Chưa đo'
                      : '${(attendance * 100).round()}%',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: attendance ?? 0),
            const SizedBox(height: 8),
            Text(
              scheduledCount == 0
                  ? 'Chưa có occurrence đến hạn trong kỳ đã chọn.'
                  : '$completedCount/$scheduledCount buổi đến hạn có ít nhất một hiệp hoàn tất.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Hoàn tất đủ: $fullyCompletedCount • Một phần: $partialCount'
              ' • 0 hiệp/bỏ dở: $abandonedCount',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _StreakSummaryCard extends StatelessWidget {
  const _StreakSummaryCard({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hai loại streak',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 14),
          _StreakRow(
            icon: Icons.monitor_weight_outlined,
            label: 'Nhập cân nặng',
            current: state.currentStreak,
            longest: state.longestStreak,
            totalDays: state.activeDays.length,
            color: AppColors.primary,
          ),
          const Divider(height: 24),
          _StreakRow(
            icon: Icons.fitness_center,
            label: 'Tập luyện',
            current: state.targetWorkoutStreak,
            longest: state.longestWorkoutStreak,
            totalDays: state.workoutDays.length,
            color: AppColors.warning,
          ),
        ],
      ),
    ),
  );
}

class _StreakRow extends StatelessWidget {
  const _StreakRow({
    required this.icon,
    required this.label,
    required this.current,
    required this.longest,
    required this.totalDays,
    required this.color,
  });

  final IconData icon;
  final String label;
  final int current;
  final int longest;
  final int totalDays;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      CircleAvatar(
        backgroundColor: color.withValues(alpha: .12),
        foregroundColor: color,
        child: Icon(icon),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.titleMedium),
            Text(
              'Hiện tại $current ngày • dài nhất $longest ngày • tổng $totalDays ngày',
            ),
          ],
        ),
      ),
    ],
  );
}

class _ActivityHeatmap extends StatelessWidget {
  const _ActivityHeatmap({required this.weightDays, required this.workoutDays});

  final Set<String> weightDays;
  final Set<String> workoutDays;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = [
      for (var offset = 27; offset >= 0; offset--)
        today.subtract(Duration(days: offset)),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hoạt động 28 ngày',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Mỗi ô dùng ngày địa phương; một ngày chỉ được tính một lần cho từng streak.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            _HeatmapRow(
              label: 'Cân nặng',
              days: days,
              activeDays: weightDays,
              color: AppColors.primary,
            ),
            const SizedBox(height: 10),
            _HeatmapRow(
              label: 'Tập luyện',
              days: days,
              activeDays: workoutDays,
              color: AppColors.warning,
            ),
          ],
        ),
      ),
    );
  }
}

class _HeatmapRow extends StatelessWidget {
  const _HeatmapRow({
    required this.label,
    required this.days,
    required this.activeDays,
    required this.color,
  });

  final String label;
  final List<DateTime> days;
  final Set<String> activeDays;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(height: 6),
      LayoutBuilder(
        builder: (context, constraints) {
          const spacing = 3.0;
          final size = ((constraints.maxWidth - spacing * 13) / 14)
              .clamp(8.0, 22.0)
              .toDouble();
          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              for (final day in days)
                Tooltip(
                  message: DateFormat('dd/MM/yyyy').format(day),
                  child: Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      color: activeDays.contains(_dayKey(day))
                          ? color
                          : Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    ],
  );

  String _dayKey(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';
}

class _RankedMetric {
  const _RankedMetric({required this.label, required this.value});

  final String label;
  final int value;
}

class _RankedMetricCard extends StatelessWidget {
  const _RankedMetricCard({
    required this.title,
    required this.emptyMessage,
    required this.values,
    required this.icon,
  });

  final String title;
  final String emptyMessage;
  final List<_RankedMetric> values;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final visible = values.take(5).toList(growable: false);
    final maximum = visible.isEmpty ? 1 : visible.first.value;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 12),
            if (visible.isEmpty)
              Text(emptyMessage)
            else
              for (final item in visible) ...[
                Row(
                  children: [
                    Expanded(child: Text(item.label)),
                    Text('${item.value} hiệp'),
                  ],
                ),
                const SizedBox(height: 5),
                LinearProgressIndicator(value: item.value / maximum),
                const SizedBox(height: 10),
              ],
          ],
        ),
      ),
    );
  }
}

class _CompletionTile extends StatelessWidget {
  const _CompletionTile({required this.completion});

  final WorkoutCompletion completion;

  @override
  Widget build(BuildContext context) => Card(
    child: ExpansionTile(
      leading: CircleAvatar(
        backgroundColor: switch (completion.status) {
          WorkoutCompletionStatus.completed => const Color(0xFFE1F7EC),
          WorkoutCompletionStatus.partiallyCompleted => const Color(0xFFFFF1D5),
          WorkoutCompletionStatus.abandoned => const Color(0xFFF1F3F5),
        },
        foregroundColor: switch (completion.status) {
          WorkoutCompletionStatus.completed => AppColors.success,
          WorkoutCompletionStatus.partiallyCompleted => AppColors.warning,
          WorkoutCompletionStatus.abandoned => AppColors.textMuted,
        },
        child: Icon(switch (completion.status) {
          WorkoutCompletionStatus.completed => Icons.check,
          WorkoutCompletionStatus.partiallyCompleted => Icons.timelapse,
          WorkoutCompletionStatus.abandoned => Icons.block_outlined,
        }),
      ),
      title: Text(completion.snapshot.title),
      subtitle: Text(
        '${completion.snapshot.programTitle.isEmpty ? 'Chương trình FitTrack' : completion.snapshot.programTitle}'
        '${completion.snapshot.contentVersion.isEmpty ? '' : ' • v${completion.snapshot.contentVersion}'}\n'
        '${DateFormat('dd/MM/yyyy • HH:mm').format(completion.completedAt)} • '
        '${(completion.actualDurationSeconds / 60).ceil()} phút',
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: Text(switch (completion.status) {
                  WorkoutCompletionStatus.completed =>
                    '${completion.completedSetCount} hiệp hoàn tất',
                  WorkoutCompletionStatus.partiallyCompleted =>
                    '${completion.completedSetCount} hiệp • hoàn tất một phần',
                  WorkoutCompletionStatus.abandoned =>
                    'Bỏ dở, không hoàn tất hiệp nào',
                }),
              ),
              if (completion.skippedSetCount > 0)
                Text('${completion.skippedSetCount} hiệp bỏ qua'),
            ],
          ),
        ),
        ListTile(
          dense: true,
          leading: const Icon(Icons.receipt_long_outlined),
          title: const Text('Xem chi tiết từng bài, từng hiệp'),
          subtitle: const Text(
            'Mục tiêu, kết quả thực tế, bài thay thế và bằng chứng AI',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  WorkoutCompletionDetailScreen(completion: completion),
            ),
          ),
        ),
        ListTile(
          dense: true,
          leading: const Icon(Icons.fact_check_outlined),
          title: const Text('Chế độ xác nhận'),
          subtitle: Text(_confirmationModes(completion)),
        ),
        if (_timedEvents(completion) case final timedEvents
            when timedEvents.isNotEmpty)
          ListTile(
            dense: true,
            leading: const Icon(Icons.timer_outlined),
            title: const Text('Hiệp tính giờ'),
            subtitle: Text(
              '${timedEvents.length} hiệp • '
              '${timedEvents.fold<int>(0, (total, event) => total + event.timedDurationSeconds!)} giây thực tế',
            ),
          ),
        if (completion.snapshot.exercises
                .where((exercise) => exercise.isAlternative)
                .toList()
            case final alternatives when alternatives.isNotEmpty)
          ListTile(
            dense: true,
            leading: const Icon(Icons.swap_horiz),
            title: const Text('Bài thay thế đã dùng'),
            subtitle: Text(
              alternatives.map((exercise) => exercise.name).join(', '),
            ),
          ),
        ListTile(
          dense: true,
          leading: const Icon(Icons.account_tree_outlined),
          title: const Text('Phiên bản chương trình'),
          subtitle: Text(completion.programVersionId),
        ),
        ListTile(
          dense: true,
          leading: const Icon(Icons.menu_book_outlined),
          title: const Text('Nguồn nội dung'),
          subtitle: Text(
            completion.snapshot.sourceRefs.isEmpty
                ? 'Chưa đo'
                : completion.snapshot.sourceRefs.join(', '),
          ),
        ),
      ],
    ),
  );

  String _confirmationModes(WorkoutCompletion completion) {
    final modes = completion.setEvents
        .where((event) => event.status == SetEventStatus.completed)
        .map((event) => event.confirmationMode)
        .toSet();
    if (modes.isEmpty) return 'Chưa đo';
    return modes
        .map(
          (mode) => switch (mode) {
            WorkoutConfirmationMode.aiCamera => 'AI Camera Coach',
            WorkoutConfirmationMode.guided => 'Guided Confirmation',
          },
        )
        .join(' + ');
  }

  List<SetEvent> _timedEvents(WorkoutCompletion completion) => completion
      .setEvents
      .where(
        (event) =>
            event.status == SetEventStatus.completed &&
            event.timedDurationSeconds != null,
      )
      .toList(growable: false);
}
