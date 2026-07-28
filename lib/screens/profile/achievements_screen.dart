import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/seed_data.dart';
import '../../models/health_models.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common_widgets.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key, required this.state});

  final AppState state;

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  var _filter = _AchievementFilter.all;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final achievements = state.achievements;
    final unlockedCount = achievements.where((item) => item.unlocked).length;
    final workoutAchievements = _visibleAchievements(
      achievements.where((item) => !item.id.startsWith('streak_')),
    );
    final streakAchievements = _visibleAchievements(
      achievements.where((item) => item.id.startsWith('streak_')),
    );
    final bestStreak = state.longestStreak > state.longestWorkoutStreak
        ? state.longestStreak
        : state.longestWorkoutStreak;

    return Scaffold(
      appBar: AppBar(title: const Text('Thành tích'), centerTitle: true),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _AchievementSummaryCard(
              unlockedCount: unlockedCount,
              totalCount: achievements.length,
              completedWorkouts: state.completedTargetWorkouts.length,
              bestStreak: bestStreak,
            ),
            const SizedBox(height: 16),
            SegmentedButton<_AchievementFilter>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: _AchievementFilter.all,
                  label: Text('Tất cả'),
                ),
                ButtonSegment(
                  value: _AchievementFilter.unlocked,
                  label: Text('Đã mở'),
                ),
                ButtonSegment(
                  value: _AchievementFilter.locked,
                  label: Text('Chưa mở'),
                ),
              ],
              selected: {_filter},
              onSelectionChanged: (values) =>
                  setState(() => _filter = values.first),
            ),
            const SizedBox(height: 22),
            if (workoutAchievements.isNotEmpty) ...[
              const SectionHeader(
                title: 'Mốc buổi tập',
                subtitle: 'Hoàn thành Active Workout để mở khóa',
              ),
              const SizedBox(height: 10),
              for (final achievement in workoutAchievements)
                _AchievementCard(
                  achievement: achievement,
                  progress: _progressFor(achievement, state),
                  onTap: () => _showDetails(achievement, state),
                ),
            ],
            if (streakAchievements.isNotEmpty) ...[
              const SizedBox(height: 12),
              const SectionHeader(
                title: 'Chuỗi hoạt động',
                subtitle: 'Streak tập luyện và nhập cân được tính riêng',
              ),
              const SizedBox(height: 10),
              for (final achievement in streakAchievements)
                _AchievementCard(
                  achievement: achievement,
                  progress: _progressFor(achievement, state),
                  onTap: () => _showDetails(achievement, state),
                ),
            ],
            if (workoutAchievements.isEmpty && streakAchievements.isEmpty)
              const EmptyState(
                icon: Icons.emoji_events_outlined,
                title: 'Không có thành tích phù hợp',
                message: 'Hãy chọn bộ lọc khác để xem các mốc thành tích.',
              ),
          ],
        ),
      ),
    );
  }

  List<Achievement> _visibleAchievements(Iterable<Achievement> values) => values
      .where((item) {
        return switch (_filter) {
          _AchievementFilter.all => true,
          _AchievementFilter.unlocked => item.unlocked,
          _AchievementFilter.locked => !item.unlocked,
        };
      })
      .toList(growable: false);

  _AchievementProgress _progressFor(Achievement achievement, AppState state) {
    final target = _targetFor(achievement.id);
    final isStreak = achievement.id.startsWith('streak_');
    final bestStreak = state.longestStreak > state.longestWorkoutStreak
        ? state.longestStreak
        : state.longestWorkoutStreak;
    final current = isStreak
        ? bestStreak
        : state.completedTargetWorkouts.length;
    return _AchievementProgress(
      current: current,
      target: target,
      unit: isStreak ? 'ngày' : 'buổi',
    );
  }

  int _targetFor(String id) => switch (id) {
    'first_workout' => 1,
    'workout_5' => 5,
    'workout_10' => 10,
    'streak_3' => 3,
    'streak_7' => 7,
    'streak_30' => 30,
    _ => 1,
  };

  Future<void> _showDetails(Achievement achievement, AppState state) {
    final progress = _progressFor(achievement, state);
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 38,
                backgroundColor: achievement.unlocked
                    ? AppColors.warning.withValues(alpha: .16)
                    : AppColors.input,
                foregroundColor: achievement.unlocked
                    ? AppColors.warning
                    : AppColors.textMuted,
                child: Icon(
                  achievement.unlocked
                      ? SeedData.achievementIcon(achievement.id)
                      : Icons.lock_outline,
                  size: 38,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                achievement.title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                achievement.description,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: achievement.unlocked ? 1 : progress.ratio,
                  minHeight: 10,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                achievement.unlocked
                    ? 'Đã mở khóa ngày ${DateFormat('dd/MM/yyyy').format(achievement.unlockedAt!)}'
                    : '${progress.cappedCurrent}/${progress.target} ${progress.unit}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              if (!achievement.unlocked) ...[
                const SizedBox(height: 4),
                Text(
                  'Còn ${progress.remaining} ${progress.unit} để mở khóa',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AchievementSummaryCard extends StatelessWidget {
  const _AchievementSummaryCard({
    required this.unlockedCount,
    required this.totalCount,
    required this.completedWorkouts,
    required this.bestStreak,
  });

  final int unlockedCount;
  final int totalCount;
  final int completedWorkouts;
  final int bestStreak;

  @override
  Widget build(BuildContext context) {
    final ratio = totalCount == 0 ? 0.0 : unlockedCount / totalCount;
    return Card(
      color: AppColors.navy,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 26,
                  backgroundColor: Color(0x26FFFFFF),
                  foregroundColor: Colors.white,
                  child: Icon(Icons.emoji_events_outlined, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$unlockedCount / $totalCount huy hiệu',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Text(
                        'Tiếp tục luyện tập để mở khóa tất cả',
                        style: TextStyle(color: Color(0xCCFFFFFF)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 9,
                backgroundColor: const Color(0x33FFFFFF),
                color: AppColors.warning,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _SummaryValue(
                    value: '$completedWorkouts',
                    label: 'Buổi hoàn thành',
                  ),
                ),
                Container(width: 1, height: 42, color: const Color(0x33FFFFFF)),
                Expanded(
                  child: _SummaryValue(
                    value: '$bestStreak ngày',
                    label: 'Chuỗi dài nhất',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        value,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 12),
      ),
    ],
  );
}

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({
    required this.achievement,
    required this.progress,
    required this.onTap,
  });

  final Achievement achievement;
  final _AchievementProgress progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unlocked = achievement.unlocked;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: unlocked
          ? AppColors.warning.withValues(alpha: .08)
          : Theme.of(context).cardColor,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: unlocked
                        ? AppColors.warning.withValues(alpha: .16)
                        : AppColors.input,
                    foregroundColor: unlocked
                        ? AppColors.warning
                        : AppColors.textMuted,
                    child: Icon(
                      unlocked
                          ? SeedData.achievementIcon(achievement.id)
                          : Icons.lock_outline,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                achievement.title,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ),
                            if (unlocked)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withValues(
                                    alpha: .1,
                                  ),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  'Đã mở',
                                  style: TextStyle(
                                    color: AppColors.success,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          achievement.description,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: unlocked ? 1 : progress.ratio,
                        minHeight: 8,
                        color: unlocked ? AppColors.warning : AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    unlocked
                        ? DateFormat(
                            'dd/MM/yyyy',
                          ).format(achievement.unlockedAt!)
                        : '${progress.cappedCurrent}/${progress.target} ${progress.unit}',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AchievementProgress {
  const _AchievementProgress({
    required this.current,
    required this.target,
    required this.unit,
  });

  final int current;
  final int target;
  final String unit;

  int get cappedCurrent => current.clamp(0, target);
  int get remaining => (target - current).clamp(0, target);
  double get ratio => target == 0 ? 0 : (current / target).clamp(0, 1);
}

enum _AchievementFilter { all, unlocked, locked }
