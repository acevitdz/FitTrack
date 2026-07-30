import 'package:flutter/material.dart';

import '../../domain/pr_calculator.dart';
import '../../models/exercise.dart';
import '../../models/exercise_set_log.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common_widgets.dart';

enum _Window { sevenDays, thirtyDays, threeMonths }

extension on _Window {
  String get label => switch (this) {
    _Window.sevenDays => '7 Ngày',
    _Window.thirtyDays => '30 Ngày',
    _Window.threeMonths => '3 Tháng',
  };

  int get days => switch (this) {
    _Window.sevenDays => 7,
    _Window.thirtyDays => 30,
    _Window.threeMonths => 90,
  };
}

/// UI.pdf "PHÂN TÍCH BÀI TẬP" (Exercise Progress / PR) — SRS §4.5.
/// [logs] stands in for TV3's WorkoutCompletion feed — see
/// lib/models/exercise_set_log.dart.
class ExerciseProgressScreen extends StatefulWidget {
  const ExerciseProgressScreen({
    super.key,
    required this.exercise,
    required this.logs,
  });

  final Exercise exercise;
  final List<ExerciseSetLog> logs;

  @override
  State<ExerciseProgressScreen> createState() => _ExerciseProgressScreenState();
}

class _ExerciseProgressScreenState extends State<ExerciseProgressScreen> {
  var _window = _Window.threeMonths;

  @override
  Widget build(BuildContext context) {
    final cutoff = DateTime.now().subtract(Duration(days: _window.days));
    final windowedLogs = widget.logs
        .where((log) => !log.date.isBefore(cutoff))
        .toList();
    // PR (weight/reps/volume) always comes from the full history — see
    // pr_calculator.dart doc comment. Only session count/average volume/the
    // recent-sessions list are restricted to the selected window.
    final stats = computeExerciseProgress(
      exerciseId: widget.exercise.id,
      allLogs: widget.logs,
      windowedLogs: windowedLogs,
    );
    final hasAnyHistory = stats.prWeightDate != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Phân tích bài tập')),
      body: !hasAnyHistory
          ? EmptyState(
              icon: Icons.show_chart,
              title: 'Chưa có dữ liệu',
              message:
                  'Hoàn thành ít nhất 1 buổi tập với "${widget.exercise.name}" '
                  'để xem PR và tiến độ.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                Text(
                  widget.exercise.name,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    widget.exercise.primaryMuscle.label,
                    ...widget.exercise.secondaryMuscles.map((m) => m.label),
                  ].join(', '),
                  style: const TextStyle(color: AppColors.textMuted),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final window in _Window.values)
                      ChoiceChip(
                        label: Text(window.label),
                        selected: _window == window,
                        onSelected: (_) => setState(() => _window = window),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                Text('Kỷ lục cá nhân (PR)', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                const Text(
                  'Luôn tính trên toàn bộ lịch sử, không đổi theo bộ lọc thời gian ở trên.',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: MetricCard(
                        label: stats.prWeightDate == null
                            ? 'Tạ nặng nhất'
                            : 'Tạ nặng nhất · ${_formatDate(stats.prWeightDate!)}',
                        value: '${stats.prWeightKg.toStringAsFixed(1)} kg',
                        icon: Icons.emoji_events_outlined,
                        color: AppColors.warning,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: MetricCard(
                        label: stats.prRepsDate == null
                            ? 'Nhiều reps nhất (1 hiệp)'
                            : 'Nhiều reps nhất · ${_formatDate(stats.prRepsDate!)}',
                        value: '${stats.prReps} reps',
                        icon: Icons.repeat,
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                MetricCard(
                  label: stats.prVolumeDate == null
                      ? 'Volume cao nhất (1 buổi)'
                      : 'Volume cao nhất · ${_formatDate(stats.prVolumeDate!)}',
                  value: '${stats.prVolumeKg.toStringAsFixed(0)} kg',
                  icon: Icons.stacked_bar_chart,
                  color: AppColors.success,
                ),
                const SizedBox(height: 22),
                Text(
                  'Trong ${_window.label.toLowerCase()} qua',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: MetricCard(
                        label: 'Tổng số lần tập',
                        value: '${stats.totalSessions} lần',
                        icon: Icons.event_repeat_outlined,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: MetricCard(
                        label: 'Volume trung bình/buổi',
                        value: '${stats.averageVolumeKg.toStringAsFixed(0)} kg',
                        icon: Icons.bar_chart,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Text('Lịch sử gần đây', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                if (stats.recentSessions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Không có buổi tập nào trong khung thời gian đang chọn.',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  )
                else
                  for (final session in stats.recentSessions)
                    Card(
                      child: ListTile(
                        title: Text(_formatDate(session.date)),
                        subtitle: Text(
                          '${session.setCount} hiệp · ${session.totalReps} reps · '
                          '${session.volumeKg.toStringAsFixed(0)} kg volume',
                        ),
                        trailing: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${session.maxWeightKg.toStringAsFixed(1)} kg',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            for (final type in session.achievedPrTypes)
                              Text(
                                _prBadgeLabel(type),
                                style: const TextStyle(
                                  color: AppColors.warning,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
              ],
            ),
    );
  }

  String _prBadgeLabel(PrType type) => switch (type) {
    PrType.weight => 'PR Tạ',
    PrType.reps => 'PR Reps',
    PrType.volume => 'PR Volume',
  };

  String _formatDate(DateTime date) {
    const months = [
      'Th1', 'Th2', 'Th3', 'Th4', 'Th5', 'Th6',
      'Th7', 'Th8', 'Th9', 'Th10', 'Th11', 'Th12',
    ];
    return '${date.day} ${months[date.month - 1]}, ${date.year}';
  }
}
