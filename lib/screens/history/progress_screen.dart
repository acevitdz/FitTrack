import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/active_workout.dart';
import '../../models/program.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common_widgets.dart';
import 'history_screen.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key, required this.state});

  final AppState state;

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  var _periodDays = 7;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final today = _dateOnly(DateTime.now());
    final start = _periodStart(today, _periodDays);
    final previousStart = start?.subtract(Duration(days: _periodDays));
    final allCompletions = state.completedTargetWorkouts;
    final completions = _completionsBetween(
      allCompletions,
      start: start,
      endExclusive: today.add(const Duration(days: 1)),
    );
    final previousCompletions = start == null
        ? const <WorkoutCompletion>[]
        : _completionsBetween(
            allCompletions,
            start: previousStart,
            endExclusive: start,
          );
    final currentAttendance = _attendance(
      state,
      start: start,
      endExclusive: today.add(const Duration(days: 1)),
    );
    final previousAttendance = start == null
        ? null
        : _attendance(state, start: previousStart, endExclusive: start);
    final completedSets = _completedSets(completions);
    final previousSets = _completedSets(previousCompletions);
    final durationSeconds = _durationSeconds(completions);
    final previousDurationSeconds = _durationSeconds(previousCompletions);
    final chartDays = _periodDays == 0 ? 30 : _periodDays;
    final chartStart = today.subtract(Duration(days: chartDays - 1));
    final chartCompletions = _completionsBetween(
      allCompletions,
      start: chartStart,
      endExclusive: today.add(const Duration(days: 1)),
    );
    final activity = _dailyActivity(
      chartCompletions,
      start: chartStart,
      days: chartDays,
    );
    final muscles = _muscleDistribution(completions);

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            centerTitle: true,
            title: const Text('FitTrack'),
            actions: [
              IconButton(
                tooltip: 'Thông báo',
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Không có thông báo tiến độ mới.'),
                  ),
                ),
                icon: const Icon(Icons.notifications_none),
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            sliver: SliverList.list(
              children: [
                Text(
                  'Báo cáo hiệu suất',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _periodDescription(today, start),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                ),
                const SizedBox(height: 16),
                SegmentedButton<int>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 7, label: Text('7 ngày')),
                    ButtonSegment(value: 30, label: Text('30 ngày')),
                    ButtonSegment(value: 0, label: Text('Tất cả')),
                  ],
                  selected: {_periodDays},
                  onSelectionChanged: (values) =>
                      setState(() => _periodDays = values.first),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _ProgressMetricCard(
                        label: 'Số buổi',
                        value: '${completions.length}',
                        icon: Icons.fitness_center,
                        trend: _trend(
                          completions.length,
                          previousCompletions.length,
                          enabled: start != null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ProgressMetricCard(
                        label: 'Thời gian',
                        value: _formatDuration(durationSeconds),
                        icon: Icons.timer_outlined,
                        trend: _trend(
                          durationSeconds,
                          previousDurationSeconds,
                          enabled: start != null,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _ProgressMetricCard(
                        label: 'Hiệp hoàn tất',
                        value: '$completedSets',
                        icon: Icons.repeat_rounded,
                        trend: _trend(
                          completedSets,
                          previousSets,
                          enabled: start != null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ProgressMetricCard(
                        label: 'Chuyên cần',
                        value: currentAttendance == null
                            ? 'Chưa đo'
                            : '${(currentAttendance * 100).round()}%',
                        icon: Icons.event_available_outlined,
                        trend: _trend(
                          currentAttendance,
                          previousAttendance,
                          enabled: start != null,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _ActivityTrendCard(
                  points: activity,
                  periodLabel: _periodDays == 0
                      ? '30 ngày gần nhất'
                      : '$_periodDays ngày',
                ),
                const SizedBox(height: 14),
                _MuscleDistributionCard(values: muscles),
                const SizedBox(height: 14),
                _PersonalRecordsCard(
                  completions: allCompletions,
                  longestWorkoutStreak: state.longestWorkoutStreak,
                ),
                const SizedBox(height: 20),
                SectionHeader(
                  title: 'Lịch sử gần đây',
                  subtitle: 'Kết quả từ Active Workout',
                  action: TextButton(
                    onPressed: () => _openHistory(context),
                    child: const Text('Xem tất cả'),
                  ),
                ),
                const SizedBox(height: 8),
                if (completions.isEmpty)
                  EmptyState(
                    icon: Icons.query_stats_outlined,
                    title: allCompletions.isEmpty
                        ? 'Chưa có dữ liệu tiến độ'
                        : 'Không có dữ liệu trong khoảng này',
                    message: allCompletions.isEmpty
                        ? 'Hoàn thành một buổi tập để FitTrack tạo báo cáo tự động.'
                        : 'Hãy chọn khoảng thời gian khác để xem kết quả đã ghi nhận.',
                  )
                else
                  for (final completion in completions.take(3))
                    _RecentCompletionTile(
                      completion: completion,
                      onTap: () => _openHistory(context),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openHistory(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => Scaffold(body: HistoryScreen(state: widget.state)),
    ),
  );

  DateTime? _periodStart(DateTime today, int days) =>
      days == 0 ? null : today.subtract(Duration(days: days - 1));

  String _periodDescription(DateTime today, DateTime? start) {
    if (start == null) return 'Toàn bộ dữ liệu tập luyện đã ghi nhận';
    final formatter = DateFormat('dd/MM/yyyy');
    return '${formatter.format(start)} – ${formatter.format(today)}';
  }

  List<WorkoutCompletion> _completionsBetween(
    List<WorkoutCompletion> values, {
    required DateTime? start,
    required DateTime endExclusive,
  }) {
    final unique = <String, WorkoutCompletion>{};
    for (final item in values) {
      final completedDate = _dateOnly(item.completedAt);
      if (start != null && completedDate.isBefore(start)) continue;
      if (!completedDate.isBefore(endExclusive)) continue;
      unique.putIfAbsent(item.idempotencyKey, () => item);
    }
    return unique.values.toList(growable: false);
  }

  double? _attendance(
    AppState state, {
    required DateTime? start,
    required DateTime endExclusive,
  }) {
    final due = state.occurrences
        .where((item) {
          if (item.status == WorkoutOccurrenceStatus.cancelled) return false;
          final scheduledDate = _dateOnly(item.scheduledDate);
          if (start != null && scheduledDate.isBefore(start)) return false;
          return scheduledDate.isBefore(endExclusive);
        })
        .toList(growable: false);
    if (due.isEmpty) return null;
    final completedIds = state.completedTargetWorkouts
        .map((item) => item.occurrenceId)
        .toSet();
    final attended = due.where((item) => completedIds.contains(item.id)).length;
    return (attended / due.length).clamp(0, 1).toDouble();
  }

  int _completedSets(List<WorkoutCompletion> values) =>
      values.fold(0, (total, item) => total + item.completedSetCount);

  int _durationSeconds(List<WorkoutCompletion> values) =>
      values.fold(0, (total, item) => total + item.actualDurationSeconds);

  List<_DailyActivity> _dailyActivity(
    List<WorkoutCompletion> values, {
    required DateTime start,
    required int days,
  }) {
    final setsByDay = <DateTime, int>{};
    for (final completion in values) {
      final day = _dateOnly(completion.completedAt);
      setsByDay.update(
        day,
        (value) => value + completion.completedSetCount,
        ifAbsent: () => completion.completedSetCount,
      );
    }
    return [
      for (var offset = 0; offset < days; offset++)
        _DailyActivity(
          date: start.add(Duration(days: offset)),
          completedSets: setsByDay[start.add(Duration(days: offset))] ?? 0,
        ),
    ];
  }

  List<_MuscleMetric> _muscleDistribution(List<WorkoutCompletion> completions) {
    final counts = <String, int>{};
    for (final completion in completions) {
      final groups = {
        for (final exercise in completion.snapshot.exercises)
          exercise.exerciseId: exercise.muscleGroup.trim().isEmpty
              ? 'Toàn thân'
              : exercise.muscleGroup,
      };
      for (final event in completion.setEvents) {
        if (event.status != SetEventStatus.completed) continue;
        final group = groups[event.exerciseId] ?? 'Toàn thân';
        counts.update(group, (value) => value + 1, ifAbsent: () => 1);
      }
    }
    final total = counts.values.fold(0, (sum, value) => sum + value);
    final result =
        counts.entries
            .map(
              (entry) => _MuscleMetric(
                label: entry.key,
                setCount: entry.value,
                ratio: total == 0 ? 0 : entry.value / total,
              ),
            )
            .toList()
          ..sort((left, right) => right.setCount.compareTo(left.setCount));
    return result.take(4).toList(growable: false);
  }

  _MetricTrend? _trend(num? current, num? previous, {required bool enabled}) {
    if (!enabled || current == null || previous == null) return null;
    if (previous == 0) {
      return _MetricTrend(label: current == 0 ? '0%' : 'Mới', positive: true);
    }
    final percentage = ((current - previous) / previous * 100).round();
    return _MetricTrend(
      label: '${percentage > 0 ? '+' : ''}$percentage%',
      positive: percentage >= 0,
    );
  }

  String _formatDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    if (duration.inHours > 0) {
      return '${duration.inHours}g ${duration.inMinutes.remainder(60)}p';
    }
    return '${duration.inMinutes} phút';
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}

class _ProgressMetricCard extends StatelessWidget {
  const _ProgressMetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.trend,
  });

  final String label;
  final String value;
  final IconData icon;
  final _MetricTrend? trend;

  @override
  Widget build(BuildContext context) => Card(
    child: SizedBox(
      height: 132,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.paleBlue.withValues(alpha: .6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 19, color: AppColors.primary),
                ),
                const Spacer(),
                if (trend != null) _TrendBadge(trend: trend!),
              ],
            ),
            const Spacer(),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.navy,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    ),
  );
}

class _TrendBadge extends StatelessWidget {
  const _TrendBadge({required this.trend});

  final _MetricTrend trend;

  @override
  Widget build(BuildContext context) {
    final color = trend.positive ? AppColors.success : AppColors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        trend.label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ActivityTrendCard extends StatelessWidget {
  const _ActivityTrendCard({required this.points, required this.periodLabel});

  final List<_DailyActivity> points;
  final String periodLabel;

  @override
  Widget build(BuildContext context) {
    final maximum = points.fold<int>(
      0,
      (value, item) => math.max(value, item.completedSets),
    );
    final formatter = DateFormat('dd/MM');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Xu hướng số hiệp',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Text(
                  periodLabel,
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: AppColors.primary),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Số hiệp hoàn tất theo ngày',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 170,
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: math.max(1, points.length - 1).toDouble(),
                  minY: 0,
                  maxY: math.max(1, maximum).toDouble() * 1.2,
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(drawVerticalLine: false),
                  titlesData: const FlTitlesData(
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: points.indexed
                          .map(
                            (item) => FlSpot(
                              item.$1.toDouble(),
                              item.$2.completedSets.toDouble(),
                            ),
                          )
                          .toList(growable: false),
                      color: AppColors.primary,
                      barWidth: 3,
                      isCurved: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppColors.paleBlue.withValues(alpha: .45),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (points.isNotEmpty)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(formatter.format(points.first.date)),
                  Text(formatter.format(points[points.length ~/ 2].date)),
                  Text(formatter.format(points.last.date)),
                ],
              ),
            if (maximum == 0) ...[
              const SizedBox(height: 8),
              const Text('Chưa có hiệp hoàn tất trong khoảng thời gian này.'),
            ],
          ],
        ),
      ),
    );
  }
}

class _MuscleDistributionCard extends StatelessWidget {
  const _MuscleDistributionCard({required this.values});

  final List<_MuscleMetric> values;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nhóm cơ nhiều nhất',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'Tính từ các hiệp đã hoàn tất',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          if (values.isEmpty)
            const Text('Chưa đủ dữ liệu để phân tích nhóm cơ.')
          else
            for (final item in values) ...[
              Row(
                children: [
                  Expanded(child: Text(item.label)),
                  Text('${(item.ratio * 100).round()}%'),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(value: item.ratio, minHeight: 8),
              ),
              const SizedBox(height: 12),
            ],
        ],
      ),
    ),
  );
}

class _PersonalRecordsCard extends StatelessWidget {
  const _PersonalRecordsCard({
    required this.completions,
    required this.longestWorkoutStreak,
  });

  final List<WorkoutCompletion> completions;
  final int longestWorkoutStreak;

  @override
  Widget build(BuildContext context) {
    final longestSeconds = completions.fold<int>(
      0,
      (value, item) => math.max(value, item.actualDurationSeconds),
    );
    final mostSets = completions.fold<int>(
      0,
      (value, item) => math.max(value, item.completedSetCount),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.emoji_events_outlined,
                  color: AppColors.warning,
                ),
                const SizedBox(width: 8),
                Text(
                  'Kỷ lục cá nhân',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _RecordRow(
              icon: Icons.timer_outlined,
              label: 'Buổi dài nhất',
              value: longestSeconds == 0
                  ? 'Chưa có'
                  : '${(longestSeconds / 60).ceil()} phút',
            ),
            const Divider(height: 20),
            _RecordRow(
              icon: Icons.repeat_rounded,
              label: 'Nhiều hiệp nhất',
              value: mostSets == 0 ? 'Chưa có' : '$mostSets hiệp',
            ),
            const Divider(height: 20),
            _RecordRow(
              icon: Icons.local_fire_department_outlined,
              label: 'Chuỗi tập dài nhất',
              value: '$longestWorkoutStreak ngày',
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordRow extends StatelessWidget {
  const _RecordRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: AppColors.primary),
      const SizedBox(width: 10),
      Expanded(child: Text(label)),
      Text(
        value,
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
    ],
  );
}

class _RecentCompletionTile extends StatelessWidget {
  const _RecentCompletionTile({required this.completion, required this.onTap});

  final WorkoutCompletion completion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      onTap: onTap,
      leading: const CircleAvatar(
        backgroundColor: AppColors.paleBlue,
        foregroundColor: AppColors.primary,
        child: Icon(Icons.fitness_center),
      ),
      title: Text(completion.snapshot.title),
      subtitle: Text(
        '${DateFormat('dd/MM/yyyy • HH:mm').format(completion.completedAt)}\n'
        '${(completion.actualDurationSeconds / 60).ceil()} phút • '
        '${completion.completedSetCount} hiệp',
      ),
      isThreeLine: true,
      trailing: const Icon(Icons.chevron_right),
    ),
  );
}

class _MetricTrend {
  const _MetricTrend({required this.label, required this.positive});

  final String label;
  final bool positive;
}

class _DailyActivity {
  const _DailyActivity({required this.date, required this.completedSets});

  final DateTime date;
  final int completedSets;
}

class _MuscleMetric {
  const _MuscleMetric({
    required this.label,
    required this.setCount,
    required this.ratio,
  });

  final String label;
  final int setCount;
  final double ratio;
}
