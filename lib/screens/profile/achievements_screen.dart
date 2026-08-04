import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/seed_data.dart';
import '../../models/health_models.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';

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
    final achievements = widget.state.achievements
        .where((achievement) {
          return switch (_filter) {
            _AchievementFilter.all => true,
            _AchievementFilter.unlocked => achievement.unlocked,
            _AchievementFilter.locked => !achievement.unlocked,
          };
        })
        .toList(growable: false);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FC),
      appBar: AppBar(
        title: const Text('Thành tích'),
        centerTitle: true,
        actions: [
          PopupMenuButton<_AchievementFilter>(
            tooltip: 'Lọc thành tích',
            initialValue: _filter,
            icon: const Icon(Icons.more_vert),
            onSelected: (value) => setState(() => _filter = value),
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _AchievementFilter.all,
                child: Text('Tất cả'),
              ),
              PopupMenuItem(
                value: _AchievementFilter.unlocked,
                child: Text('Đã mở khóa'),
              ),
              PopupMenuItem(
                value: _AchievementFilter.locked,
                child: Text('Chưa mở khóa'),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: achievements.isEmpty
            ? const _EmptyAchievements()
            : GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: .76,
                ),
                itemCount: achievements.length,
                itemBuilder: (context, index) {
                  final achievement = achievements[index];
                  return _AchievementCard(
                    achievement: achievement,
                    onTap: () => _showDetails(achievement),
                  );
                },
              ),
      ),
    );
  }

  _AchievementProgress _progressFor(Achievement achievement) {
    final isStreak = achievement.id.startsWith('streak_');
    final bestStreak =
        widget.state.longestStreak > widget.state.longestWorkoutStreak
        ? widget.state.longestStreak
        : widget.state.longestWorkoutStreak;
    return _AchievementProgress(
      current: isStreak
          ? bestStreak
          : widget.state.completedTargetWorkouts.length,
      target: _targetFor(achievement.id),
      unit: isStreak ? 'ngày' : 'buổi',
    );
  }

  int _targetFor(String id) => switch (id) {
    'first_workout' => 1,
    'streak_3' => 3,
    'streak_7' => 7,
    'workout_50' => 50,
    _ => 1,
  };

  Future<void> _showDetails(Achievement achievement) {
    final progress = _progressFor(achievement);
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _AchievementIcon(achievement: achievement, size: 76),
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
                  minHeight: 9,
                  backgroundColor: AppColors.input,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                achievement.unlocked
                    ? 'Đạt ${DateFormat('dd/MM/yyyy').format(achievement.unlockedAt!)}'
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

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({required this.achievement, required this.onTap});

  final Achievement achievement;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unlocked = achievement.unlocked;
    return Material(
      color: unlocked ? const Color(0xFFE9F7E2) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 14),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE7E9EE)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              _AchievementIcon(achievement: achievement, size: 66),
              const SizedBox(height: 14),
              Text(
                achievement.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.text,
                  fontWeight: FontWeight.w800,
                  height: 1.12,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                achievement.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF858A96),
                  height: 1.3,
                ),
              ),
              const Spacer(),
              Text(
                unlocked
                    ? 'Đạt ${DateFormat('dd/MM/yyyy').format(achievement.unlockedAt!)}'
                    : 'Chưa mở khóa',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF737985),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AchievementIcon extends StatelessWidget {
  const _AchievementIcon({required this.achievement, required this.size});

  final Achievement achievement;
  final double size;

  @override
  Widget build(BuildContext context) {
    final unlocked = achievement.unlocked;
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFFE8EEFF),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(
        unlocked
            ? SeedData.achievementIcon(achievement.id)
            : Icons.lock_outline,
        size: size * .4,
        color: unlocked ? AppColors.primary : const Color(0xFF8B919D),
      ),
    );
  }
}

class _EmptyAchievements extends StatelessWidget {
  const _EmptyAchievements();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.emoji_events_outlined,
            size: 46,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 12),
          Text(
            'Không có thành tích phù hợp',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    ),
  );
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
