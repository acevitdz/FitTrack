import 'package:flutter/material.dart';

import '../../data/exercise_repository.dart';
import '../../domain/muscle_balance_calculator.dart';
import '../../models/exercise.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common_widgets.dart';
import 'exercise_detail_screen.dart';

/// Not in the Figma export (docs/TV2_TASKS.md §4 lists it as "còn thiếu") —
/// built to match the existing theme/widget vocabulary. Reached by tapping a
/// muscle card on Muscle Balance: session-by-session chart, legend, and the
/// catalog exercises that target this muscle.
class MuscleDetailScreen extends StatelessWidget {
  const MuscleDetailScreen({
    super.key,
    required this.summary,
    required this.exercises,
    required this.favoriteRepository,
    required this.uid,
  });

  final MuscleVolumeSummary summary;
  final List<Exercise> exercises;
  final FavoriteExerciseRepository favoriteRepository;
  final String uid;

  @override
  Widget build(BuildContext context) {
    final related = exercises
        .where((e) => e.allMuscles.contains(summary.muscle))
        .toList();
    final maxVolume = summary.sessions.isEmpty
        ? 1.0
        : summary.sessions.map((s) => s.volumeKg).reduce((a, b) => a > b ? a : b);

    return Scaffold(
      appBar: AppBar(title: Text(summary.muscle.label)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Row(
            children: [
              Expanded(
                child: MetricCard(
                  label: 'Tổng khối lượng (có trọng số)',
                  value: '${summary.weightedVolumeKg.toStringAsFixed(0)} kg',
                  icon: Icons.stacked_bar_chart,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: MetricCard(
                  label: 'Số buổi đã tập',
                  value: '${summary.sessions.length} buổi',
                  icon: Icons.event_available_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          MetricCard(
            label: summary.baselineVolumeKg <= 0
                ? 'Chưa đủ dữ liệu để so với mức bình thường'
                : 'So với mức bình thường của chính nhóm cơ này',
            value: summary.baselineVolumeKg <= 0
                ? '—'
                : '${summary.changeFromBaseline >= 0 ? '+' : ''}'
                      '${(summary.changeFromBaseline * 100).round()}%',
            icon: Icons.trending_up,
            color: switch (summary.level) {
              MuscleVolumeLevel.high => AppColors.warning,
              MuscleVolumeLevel.low => AppColors.accent,
              _ => AppColors.success,
            },
          ),
          const SizedBox(height: 22),
          Text('Theo buổi tập', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Row(
            children: const [
              _LegendDot(color: AppColors.primary, label: 'Nhóm cơ chính'),
              SizedBox(width: 16),
              _LegendDot(color: AppColors.paleBlue, label: 'Nhóm cơ phụ (x0.5)'),
            ],
          ),
          const SizedBox(height: 12),
          if (summary.sessions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Chưa có buổi tập nào tác động đến nhóm cơ này trong giai đoạn đã chọn.',
                style: TextStyle(color: AppColors.textMuted),
              ),
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
                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: session.volumeKg / maxVolume,
                          minHeight: 16,
                          backgroundColor: AppColors.input,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('${session.volumeKg.toStringAsFixed(0)} kg'),
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
              'Chưa có bài tập nào trong thư viện dùng nhóm cơ này.',
              style: TextStyle(color: AppColors.textMuted),
            )
          else
            StreamBuilder<Set<String>>(
              stream: favoriteRepository.watchFavoriteIds(uid),
              builder: (context, snapshot) {
                final favoriteIds = snapshot.data ?? const {};
                return Column(
                  children: [
                    for (final exercise in related)
                      Card(
                        child: ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image(
                              image: fitTrackImageProvider(exercise.imageUrl)!,
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover,
                            ),
                          ),
                          title: Text(exercise.name),
                          subtitle: Text(
                            exercise.primaryMuscle == summary.muscle
                                ? 'Nhóm cơ chính'
                                : 'Nhóm cơ phụ',
                          ),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ExerciseDetailScreen(
                                exercise: exercise,
                                favorite: favoriteIds.contains(exercise.id),
                                onToggleFavorite: () => favoriteRepository
                                    .setFavorite(
                                      uid,
                                      exercise.id,
                                      !favoriteIds.contains(exercise.id),
                                    ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) => '${date.day}/${date.month}';
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
      ],
    );
  }
}
