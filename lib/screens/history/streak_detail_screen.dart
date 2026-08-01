import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../theme/app_colors.dart';

enum StreakKind { workout, weight }

class StreakDetailScreen extends StatelessWidget {
  const StreakDetailScreen({
    super.key,
    required this.state,
    required this.kind,
  });

  final AppState state;
  final StreakKind kind;

  @override
  Widget build(BuildContext context) {
    final isWorkout = kind == StreakKind.workout;
    final current = isWorkout
        ? state.currentWorkoutStreak
        : state.currentStreak;
    final longest = isWorkout
        ? state.longestWorkoutStreak
        : state.longestStreak;
    final activeDays = isWorkout ? state.workoutDays : state.activeDays;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'FitTrack',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Thông báo',
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Bạn không có thông báo mới.')),
            ),
            icon: const Icon(Icons.notifications_none),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 32, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StreakHero(
                current: current,
                label: isWorkout
                    ? 'Chuỗi tập luyện hiện tại'
                    : 'Chuỗi nhập cân hiện tại',
                icon: isWorkout
                    ? Icons.local_fire_department_rounded
                    : Icons.monitor_weight_outlined,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _StreakStatCard(
                      icon: Icons.emoji_events_outlined,
                      iconColor: const Color(0xFF4E5E84),
                      value: '$longest Ngày',
                      label: 'Kỷ lục dài nhất',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StreakStatCard(
                      icon: Icons.check_circle_outline,
                      iconColor: AppColors.success,
                      value: '${activeDays.length} Ngày',
                      label: 'Tổng ngày hoạt động',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _ActivityHeatmapCard(activeDays: activeDays),
              const SizedBox(height: 24),
              _StreakRulesCard(isWorkout: isWorkout),
            ],
          ),
        ),
      ),
    );
  }
}

class _StreakHero extends StatelessWidget {
  const _StreakHero({
    required this.current,
    required this.label,
    required this.icon,
  });

  final int current;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        width: 96,
        height: 96,
        decoration: const BoxDecoration(
          color: AppColors.action,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Color(0x0D000000),
              blurRadius: 2,
              offset: Offset(0, 1),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 40, color: const Color(0xFFD8E2FF)),
      ),
      const SizedBox(height: 16),
      Text(
        '$current Ngày',
        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
          color: AppColors.primary,
          fontSize: 32,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        label,
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.bodyLarge?.copyWith(color: AppColors.textMuted),
      ),
    ],
  );
}

class _StreakStatCard extends StatelessWidget {
  const _StreakStatCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Card(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: AppColors.outline),
    ),
    child: Padding(
      padding: const EdgeInsets.all(17),
      child: Column(
        children: [
          Icon(icon, size: 22, color: iconColor),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.text,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    ),
  );
}

class _ActivityHeatmapCard extends StatelessWidget {
  const _ActivityHeatmapCard({required this.activeDays});

  final Set<String> activeDays;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = [
      for (var offset = 27; offset >= 0; offset--)
        today.subtract(Duration(days: offset)),
    ];

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Lịch sử hoạt động (28 ngày)',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '${activeDays.length} ngày',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
              ),
              itemCount: days.length,
              itemBuilder: (context, index) {
                final day = days[index];
                final active = activeDays.contains(_dateKey(day));
                return Tooltip(
                  message: '${day.day}/${day.month}/${day.year}',
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: active
                          ? AppColors.primary
                          : const Color(0xFFEBEEF2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            const Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('Ít', style: TextStyle(fontSize: 10)),
                SizedBox(width: 8),
                _LegendSquare(color: Color(0xFFEBEEF2)),
                SizedBox(width: 4),
                _LegendSquare(color: Color(0xFFC1D1FE)),
                SizedBox(width: 4),
                _LegendSquare(color: Color(0xFF6A91CB)),
                SizedBox(width: 4),
                _LegendSquare(color: AppColors.primary),
                SizedBox(width: 8),
                Text('Nhiều', style: TextStyle(fontSize: 10)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _dateKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

class _LegendSquare extends StatelessWidget {
  const _LegendSquare({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 14,
    height: 14,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(2),
    ),
  );
}

class _StreakRulesCard extends StatelessWidget {
  const _StreakRulesCard({required this.isWorkout});

  final bool isWorkout;

  @override
  Widget build(BuildContext context) {
    final rules = isWorkout
        ? const [
            'Hoàn thành ít nhất một buổi tập để ghi nhận ngày hoạt động.',
            'Bỏ lỡ một ngày trọn vẹn sẽ bắt đầu lại chuỗi hiện tại.',
            'Thử lại cùng một completion không làm tăng streak hai lần.',
          ]
        : const [
            'Cập nhật cân nặng ít nhất một lần để ghi nhận ngày hoạt động.',
            'Bỏ lỡ một ngày trọn vẹn sẽ bắt đầu lại chuỗi hiện tại.',
            'Nhiều lần cập nhật cùng ngày vẫn chỉ được tính một ngày.',
          ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.paleBlue,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info, size: 20, color: AppColors.navy),
              const SizedBox(width: 4),
              Text(
                'Cách duy trì Streak',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final rule in rules)
            Padding(
              padding: const EdgeInsets.only(left: 24, bottom: 4),
              child: Text(
                rule,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF36466B),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
