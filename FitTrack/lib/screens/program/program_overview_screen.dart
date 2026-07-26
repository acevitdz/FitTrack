import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/program.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common_widgets.dart';

class ProgramOverviewScreen extends StatelessWidget {
  const ProgramOverviewScreen({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final program = state.activeProgram;
    final version = state.activeProgramVersion;
    if (program == null || version == null) {
      return SafeArea(
        child: EmptyState(
          icon: Icons.route_outlined,
          title: 'Chưa có chương trình phù hợp',
          message:
              'FitTrack chưa tìm thấy chương trình đã phát hành đáp ứng lựa chọn hiện tại.',
          action: FilledButton(
            onPressed: () => state.ensureProgramEnrollment(),
            child: const Text('Thử chọn lại'),
          ),
        ),
      );
    }

    final occurrencesBySession = <String, WorkoutOccurrence>{
      for (final occurrence in state.occurrences)
        occurrence.sessionId: occurrence,
    };
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            pinned: true,
            title: const Text('Chương trình'),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Chip(label: Text('v${version.version}')),
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            sliver: SliverList.list(
              children: [
                Card(
                  color: AppColors.navy,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          program.title,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(color: Colors.white),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          program.description,
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _DarkChip('${version.weeks.length} tuần'),
                            _DarkChip(
                              '${version.cadence.sessionsPerWeek} buổi/tuần',
                            ),
                            _DarkChip('${version.allSessions.length} buổi'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tiêu chí đã ghép',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Chip(
                              avatar: const Icon(Icons.flag_outlined, size: 18),
                              label: Text(
                                TrainingGoalKey.labelFor(
                                  state.trainingPreferences.goalKey,
                                ),
                              ),
                            ),
                            Chip(
                              avatar: const Icon(
                                Icons.calendar_view_week_outlined,
                                size: 18,
                              ),
                              label: Text(
                                '${state.trainingPreferences.sessionsPerWeek} buổi mong muốn',
                              ),
                            ),
                            Chip(
                              avatar: const Icon(
                                Icons.fitness_center,
                                size: 18,
                              ),
                              label: Text(
                                state.trainingPreferences.equipmentKeys
                                        .contains('gym')
                                    ? 'Có phòng gym'
                                    : 'Không dụng cụ',
                              ),
                            ),
                            Chip(
                              avatar: const Icon(Icons.trending_up, size: 18),
                              label: Text(
                                state.trainingPreferences.experienceKey ==
                                        'intermediate'
                                    ? 'Đã tập'
                                    : 'Mới bắt đầu',
                              ),
                            ),
                          ],
                        ),
                        if (state.trainingPreferences.sessionsPerWeek !=
                            version.cadence.sessionsPerWeek) ...[
                          const SizedBox(height: 12),
                          Text(
                            'Bạn chọn ${state.trainingPreferences.sessionsPerWeek} buổi/tuần; '
                            'phiên bản đã phát hành phù hợp gần nhất có '
                            '${version.cadence.sessionsPerWeek} buổi/tuần. '
                            'FitTrack giữ nguyên nội dung chương trình đã phát hành và không tự sinh thêm buổi.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                for (final week in [
                  ...version.weeks,
                ]..sort((a, b) => a.weekNumber.compareTo(b.weekNumber))) ...[
                  Text(
                    'Tuần ${week.weekNumber}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  for (final session in [
                    ...week.sessions,
                  ]..sort((a, b) => a.order.compareTo(b.order)))
                    _SessionTile(
                      session: session,
                      occurrence: occurrencesBySession[session.id],
                    ),
                  const SizedBox(height: 14),
                ],
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('An toàn và phạm vi'),
                  leading: const Icon(Icons.health_and_safety_outlined),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(version.safetyCopy),
                    ),
                  ],
                ),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('Nguồn tham khảo'),
                  leading: const Icon(Icons.menu_book_outlined),
                  children: [
                    for (final source in version.sourceRefs)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(source.title),
                        subtitle: Text(
                          '${source.publisher}${source.publicationYear == null ? '' : ' • ${source.publicationYear}'}',
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Nội dung chương trình được ghim theo phiên bản. Người dùng không tự thêm bài, số hiệp hoặc lịch tập.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session, required this.occurrence});

  final ProgramSession session;
  final WorkoutOccurrence? occurrence;

  @override
  Widget build(BuildContext context) {
    final status = occurrence?.status;
    return Card(
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: _statusColor(status).withValues(alpha: .14),
          foregroundColor: _statusColor(status),
          child: Icon(_statusIcon(status)),
        ),
        title: Text(session.title),
        subtitle: Text(
          '${session.estimatedDurationMinutes} phút • ${session.totalSets} hiệp'
          '${occurrence == null ? '' : ' • ${DateFormat('dd/MM').format(occurrence!.scheduledDate)}'}',
        ),
        trailing: Chip(label: Text(_statusLabel(status))),
        children: [
          for (final block in [
            ...session.blocks,
          ]..sort((a, b) => a.order.compareTo(b.order)))
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _blockLabel(block.type),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  const SizedBox(height: 6),
                  for (final item in [
                    ...block.prescriptions,
                  ]..sort((a, b) => a.order.compareTo(b.order)))
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.fitness_center, size: 19),
                      title: Text(item.exerciseId),
                      subtitle: Text('${item.sets} hiệp • ${item.targetLabel}'),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Color _statusColor(WorkoutOccurrenceStatus? value) => switch (value) {
    WorkoutOccurrenceStatus.completed => AppColors.success,
    WorkoutOccurrenceStatus.inProgress => AppColors.warning,
    WorkoutOccurrenceStatus.skipped ||
    WorkoutOccurrenceStatus.cancelled => AppColors.textMuted,
    _ => AppColors.primary,
  };

  IconData _statusIcon(WorkoutOccurrenceStatus? value) => switch (value) {
    WorkoutOccurrenceStatus.completed => Icons.check,
    WorkoutOccurrenceStatus.inProgress => Icons.play_arrow,
    WorkoutOccurrenceStatus.skipped => Icons.skip_next,
    WorkoutOccurrenceStatus.postponed => Icons.event_repeat,
    _ => Icons.calendar_today_outlined,
  };

  String _statusLabel(WorkoutOccurrenceStatus? value) => switch (value) {
    WorkoutOccurrenceStatus.completed => 'Xong',
    WorkoutOccurrenceStatus.inProgress => 'Đang tập',
    WorkoutOccurrenceStatus.skipped => 'Bỏ qua',
    WorkoutOccurrenceStatus.postponed => 'Đã dời',
    WorkoutOccurrenceStatus.cancelled => 'Đã hủy',
    _ => 'Sắp tới',
  };

  String _blockLabel(ProgramBlockType value) => switch (value) {
    ProgramBlockType.warmUp => 'Khởi động',
    ProgramBlockType.main => 'Phần chính',
    ProgramBlockType.accessory => 'Bổ trợ',
    ProgramBlockType.conditioning => 'Thể lực',
    ProgramBlockType.coolDown => 'Thả lỏng',
  };
}

class _DarkChip extends StatelessWidget {
  const _DarkChip(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(label, style: const TextStyle(color: Colors.white)),
  );
}
