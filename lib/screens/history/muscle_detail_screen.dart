import 'package:flutter/material.dart';

import '../../services/workout_insights.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common_widgets.dart';
import '../exercises/exercise_detail_screen.dart';

class MuscleDetailScreen extends StatelessWidget {
  const MuscleDetailScreen({
    super.key,
    required this.state,
    required this.summary,
  });

  final AppState state;
  final MuscleActivitySummary summary;

  @override
  Widget build(BuildContext context) {
    final related = state.templateExercises
        .where(
          (exercise) =>
              muscleRegionForLabel(exercise.muscleGroup) == summary.region ||
              exercise.secondaryMuscles
                  .map(muscleRegionForLabel)
                  .contains(summary.region),
        )
        .toList();
    final maxSets = summary.sessions.isEmpty
        ? 1.0
        : summary.sessions
              .map((session) => session.weightedSets)
              .reduce((left, right) => left > right ? left : right);

    return Scaffold(
      appBar: AppBar(title: Text(summary.region.label)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Row(
            children: [
              Expanded(
                child: MetricCard(
                  label: 'Hiệp có trọng số',
                  value: '${_formatSets(summary.weightedSets)} hiệp',
                  icon: Icons.fitness_center,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: MetricCard(
                  label: 'Số buổi tác động',
                  value: '${summary.sessions.length} buổi',
                  icon: Icons.event_available_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          MetricCard(
            label: summary.baselineSets <= 0
                ? 'Chưa đủ lịch sử để so sánh'
                : 'So với mức hiệp gần đây của nhóm cơ này',
            value: summary.baselineSets <= 0
                ? '—'
                : '${summary.changeFromBaseline >= 0 ? '+' : ''}${(summary.changeFromBaseline * 100).round()}%',
            icon: Icons.compare_arrows,
            color: switch (summary.level) {
              MuscleActivityLevel.high => AppColors.warning,
              MuscleActivityLevel.low => AppColors.accent,
              _ => AppColors.success,
            },
          ),
          const SizedBox(height: 22),
          Text('Theo buổi tập', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (summary.sessions.isEmpty)
            const Text(
              'Chưa có buổi tập nào tác động đến nhóm cơ này trong giai đoạn đã chọn.',
              style: TextStyle(color: AppColors.textMuted),
            )
          else
            for (final session in summary.sessions.reversed)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    SizedBox(
                      width: 72,
                      child: Text(
                        _formatDate(session.date),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: session.weightedSets / maxSets,
                          minHeight: 16,
                          backgroundColor: AppColors.input,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('${_formatSets(session.weightedSets)} hiệp'),
                  ],
                ),
              ),
          const SizedBox(height: 22),
          Text(
            'Bài tập liên quan (${related.length})',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          if (related.isEmpty)
            const Text(
              'Chưa có bài tập trong catalog khớp nhóm cơ này.',
              style: TextStyle(color: AppColors.textMuted),
            )
          else
            for (final exercise in related)
              Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.paleBlue,
                    child: Icon(Icons.fitness_center),
                  ),
                  title: Text(exercise.name),
                  subtitle: Text(
                    muscleRegionForLabel(exercise.muscleGroup) == summary.region
                        ? 'Nhóm cơ chính'
                        : 'Nhóm cơ phụ',
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ExerciseDetailScreen(
                        state: state,
                        exercise: exercise,
                      ),
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  String _formatDate(DateTime value) => '${value.day}/${value.month}';

  String _formatSets(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(1);
}
