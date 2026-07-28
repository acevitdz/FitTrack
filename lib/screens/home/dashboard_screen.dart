import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/program.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../widgets/design_system.dart';
import '../health/weight_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.state,
    required this.onOpenProgram,
    required this.onOpenProfile,
    required this.onOpenHistory,
  });

  final AppState state;
  final VoidCallback onOpenProgram;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenHistory;

  @override
  Widget build(BuildContext context) {
    final occurrence = state.todayOccurrence;
    final session = occurrence == null
        ? null
        : state.sessionForOccurrence(occurrence);
    final stats = _DashboardStats.fromState(state);

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: state.ensureProgramEnrollment,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            _Header(
              name: state.profile.name,
              onOpenProfile: onOpenProfile,
              onOpenNotifications: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Bạn chưa có thông báo mới.')),
                );
              },
            ),
            const SizedBox(height: 16),
            OfflineBanner(visible: !state.firebaseAvailable),
            if (!state.firebaseAvailable) const SizedBox(height: 12),
            _TodayPlanCard(
              session: session,
              hasActiveDraft: state.activeWorkoutDraft != null,
              onPressed: state.activeWorkoutDraft != null
                  ? onOpenHistory
                  : onOpenProgram,
            ),
            const SizedBox(height: 20),
            const _SectionTitle(title: 'Mục tiêu tuần'),
            const SizedBox(height: 10),
            _WeeklyGoalCard(
              completed: stats.completedWorkouts,
              target: stats.weeklyTarget,
              workoutDays: state.workoutDays,
            ),
            const SizedBox(height: 20),
            _SectionTitle(
              title: 'Chỉ số tuần này',
              actionLabel: 'Xem tiến độ',
              onAction: onOpenHistory,
            ),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.45,
              children: [
                _MetricTile(
                  label: 'Thời gian',
                  value: '${stats.durationMinutes} phút',
                  icon: Icons.timer_outlined,
                  color: AppColors.action,
                ),
                _MetricTile(
                  label: 'Tổng số hiệp',
                  value: '${stats.completedSets} sets',
                  icon: Icons.format_list_numbered_rounded,
                  color: AppColors.success,
                ),
                _MetricTile(
                  label: 'Volume',
                  value: stats.volumeKg <= 0
                      ? '--'
                      : _compactWeight(stats.volumeKg),
                  icon: Icons.fitness_center_rounded,
                  color: AppColors.warning,
                ),
                _MetricTile(
                  label: 'BMI gần nhất',
                  value: state.profile.bmi <= 0
                      ? '--'
                      : state.profile.bmi.toStringAsFixed(1),
                  icon: Icons.favorite_outline_rounded,
                  color: AppColors.error,
                ),
              ],
            ),
            const SizedBox(height: 20),
            const _SectionTitle(title: 'Tiến độ của bạn'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _ActionCard(
                    icon: Icons.local_fire_department_rounded,
                    value: '${state.currentWorkoutStreak} ngày',
                    label: 'Workout streak',
                    color: AppColors.warning,
                    onTap: onOpenHistory,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionCard(
                    icon: Icons.monitor_weight_outlined,
                    value: state.profile.currentWeightKg <= 0
                        ? '--'
                        : '${state.profile.currentWeightKg.toStringAsFixed(1)} kg',
                    label: 'Cân nặng',
                    color: AppColors.success,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => WeightScreen(state: state),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const _SectionTitle(title: 'Thành tích gần nhất'),
            const SizedBox(height: 10),
            _PersonalRecordCard(record: stats.personalRecord),
          ],
        ),
      ),
    );
  }

  static String _compactWeight(double value) {
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}k kg';
    return '${value.toStringAsFixed(0)} kg';
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.name,
    required this.onOpenProfile,
    required this.onOpenNotifications,
  });

  final String name;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenNotifications;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        InkWell(
          onTap: onOpenProfile,
          customBorder: const CircleBorder(),
          child: CircleAvatar(
            radius: 23,
            backgroundColor: AppColors.paleBlue,
            foregroundColor: AppColors.navy,
            child: Text(
              name.trim().isEmpty ? 'F' : name.trim().characters.first,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _greeting(),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
              ),
              Text(
                name.trim().isEmpty ? 'Người dùng FitTrack' : name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Thông báo',
          onPressed: onOpenNotifications,
          icon: const Icon(Icons.notifications_none_rounded),
        ),
      ],
    );
  }

  static String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'Chào buổi sáng';
    if (hour < 18) return 'Chào buổi chiều';
    return 'Chào buổi tối';
  }
}

class _TodayPlanCard extends StatelessWidget {
  const _TodayPlanCard({
    required this.session,
    required this.hasActiveDraft,
    required this.onPressed,
  });

  final ProgramSession? session;
  final bool hasActiveDraft;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final title = hasActiveDraft
        ? 'Buổi tập đang dở'
        : session?.title ?? 'Chưa có kế hoạch hôm nay';
    final detail = hasActiveDraft
        ? 'Tiếp tục từ phần tiến độ để không mất kết quả.'
        : session == null
        ? 'Tạo kế hoạch đầu tiên để bắt đầu luyện tập.'
        : '${session!.estimatedDurationMinutes} phút · '
              '${session!.totalSets} hiệp · ${session!.blocks.length} phần';

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.navy, AppColors.navySurface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: .18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.today_outlined, color: Colors.white70),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'KẾ HOẠCH HÔM NAY',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .7,
                  ),
                ),
              ),
              Text(
                DateFormat('dd/MM').format(DateTime.now()),
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          Text(detail, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.navy,
            ),
            icon: Icon(
              hasActiveDraft
                  ? Icons.restore_rounded
                  : session == null
                  ? Icons.add_rounded
                  : Icons.arrow_forward_rounded,
            ),
            label: Text(
              hasActiveDraft
                  ? 'Tiếp tục'
                  : session == null
                  ? 'Tạo kế hoạch'
                  : 'Xem buổi tập',
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyGoalCard extends StatelessWidget {
  const _WeeklyGoalCard({
    required this.completed,
    required this.target,
    required this.workoutDays,
  });

  final int completed;
  final int target;
  final Set<String> workoutDays;

  @override
  Widget build(BuildContext context) {
    final safeTarget = target <= 0 ? 1 : target;
    final progress = (completed / safeTarget).clamp(0, 1).toDouble();
    final percent = (progress * 100).round();
    final now = DateTime.now();
    final monday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$completed/$safeTarget buổi đã hoàn thành',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '$percent%',
                  style: const TextStyle(
                    color: AppColors.action,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              borderRadius: BorderRadius.circular(10),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (index) {
                final date = monday.add(Duration(days: index));
                final key =
                    '${date.year.toString().padLeft(4, '0')}-'
                    '${date.month.toString().padLeft(2, '0')}-'
                    '${date.day.toString().padLeft(2, '0')}';
                final done = workoutDays.contains(key);
                return Column(
                  children: [
                    Text(
                      const ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'][index],
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: done ? AppColors.success : AppColors.input,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        done ? Icons.check_rounded : Icons.remove_rounded,
                        size: 16,
                        color: done ? Colors.white : AppColors.textMuted,
                      ),
                    ),
                  ],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color, size: 27),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 30),
              const SizedBox(height: 12),
              Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _PersonalRecordCard extends StatelessWidget {
  const _PersonalRecordCard({required this.record});

  final _PersonalRecord? record;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        leading: const CircleAvatar(
          backgroundColor: AppColors.paleBlue,
          foregroundColor: AppColors.action,
          child: Icon(Icons.emoji_events_outlined),
        ),
        title: Text(
          record?.exerciseName ?? 'Chưa có kỷ lục cá nhân',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          record == null
              ? 'Hoàn thành buổi tập để ghi nhận thành tích.'
              : 'Mức tạ tốt nhất đã ghi nhận',
        ),
        trailing: record == null
            ? null
            : Text(
                '${record!.weightKg.toStringAsFixed(1)} kg',
                style: const TextStyle(
                  color: AppColors.action,
                  fontWeight: FontWeight.w800,
                ),
              ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        if (actionLabel != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

class _DashboardStats {
  const _DashboardStats({
    required this.completedWorkouts,
    required this.weeklyTarget,
    required this.durationMinutes,
    required this.completedSets,
    required this.volumeKg,
    required this.personalRecord,
  });

  final int completedWorkouts;
  final int weeklyTarget;
  final int durationMinutes;
  final int completedSets;
  final double volumeKg;
  final _PersonalRecord? personalRecord;

  factory _DashboardStats.fromState(AppState state) {
    final now = DateTime.now();
    final monday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));

    final targetCompletions = state.workoutCompletions
        .where((item) => !item.completedAt.isBefore(monday))
        .toList();
    final legacyCompletions = state.completedCompletions
        .where((item) => !item.completedAt.isBefore(monday))
        .toList();
    final useTarget = targetCompletions.isNotEmpty;

    final completed = useTarget
        ? targetCompletions.length
        : legacyCompletions.length;
    final durationSeconds = useTarget
        ? targetCompletions.fold<int>(
            0,
            (sum, item) => sum + item.actualDurationSeconds,
          )
        : legacyCompletions.fold<int>(
            0,
            (sum, item) => sum + item.actualDuration.inSeconds,
          );
    final sets = useTarget
        ? targetCompletions.fold<int>(
            0,
            (sum, item) => sum + item.completedSetCount,
          )
        : legacyCompletions.fold<int>(
            0,
            (sum, item) => sum + item.completedSetCount,
          );
    final volume = legacyCompletions.fold<double>(
      0,
      (sum, item) => sum + item.totalVolume,
    );

    _PersonalRecord? record;
    for (final completion in state.completedCompletions) {
      for (final exercise in completion.exerciseResults) {
        for (final set in exercise.sets.where((item) => item.isCompleted)) {
          if (record == null || set.actualWeightKg > record.weightKg) {
            record = _PersonalRecord(
              exerciseName: exercise.exerciseName,
              weightKg: set.actualWeightKg,
            );
          }
        }
      }
    }

    final target =
        state.activeProgramVersion?.cadence.sessionsPerWeek ??
        state.profile.weeklyWorkoutGoal;
    return _DashboardStats(
      completedWorkouts: completed,
      weeklyTarget: target,
      durationMinutes: (durationSeconds / 60).round(),
      completedSets: sets,
      volumeKg: volume,
      personalRecord: record,
    );
  }
}

class _PersonalRecord {
  const _PersonalRecord({required this.exerciseName, required this.weightKg});

  final String exerciseName;
  final double weightKg;
}
