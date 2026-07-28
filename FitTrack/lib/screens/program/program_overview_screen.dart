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
              IconButton(
                tooltip: 'Danh mục lộ trình',
                onPressed: () => _showCatalog(context),
                icon: const Icon(Icons.explore_outlined),
              ),
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
                              '${state.activeSessionsPerWeek} buổi/tuần',
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
                        if (!version.cadence.supports(
                          state.trainingPreferences.sessionsPerWeek,
                        )) ...[
                          const SizedBox(height: 12),
                          Text(
                            'Bạn chọn ${state.trainingPreferences.sessionsPerWeek} buổi/tuần; '
                            'phiên bản đã phát hành phù hợp gần nhất có '
                            '${state.activeSessionsPerWeek} buổi/tuần. '
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
                      onReschedule:
                          occurrencesBySession[session.id]?.isOpen == true &&
                              occurrencesBySession[session.id]?.status !=
                                  WorkoutOccurrenceStatus.inProgress
                          ? () => _reschedule(
                              context,
                              occurrencesBySession[session.id]!,
                            )
                          : null,
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

  Future<void> _showCatalog(BuildContext context) async {
    final versions = state.catalogProgramVersions;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: .86,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Danh mục lộ trình',
                        style: Theme.of(sheetContext).textTheme.headlineSmall,
                      ),
                    ),
                    Chip(label: Text('${versions.length} lựa chọn')),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: versions.isEmpty
                    ? const EmptyState(
                        icon: Icons.route_outlined,
                        title: 'Chưa có lộ trình khả dụng',
                        message:
                            'Danh mục chưa có phiên bản đã phát hành phù hợp.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: versions.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (_, index) {
                          final version = versions[index];
                          final program = state.programs
                              .where((item) => item.id == version.programId)
                              .firstOrNull;
                          final issue = state.programCompatibilityIssue(
                            version,
                          );
                          final active =
                              state.enrollment?.programVersionId ==
                                  version.id &&
                              state.enrollment?.status ==
                                  ProgramEnrollmentStatus.active;
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
                                          program?.title ?? version.id,
                                          style: Theme.of(
                                            sheetContext,
                                          ).textTheme.titleLarge,
                                        ),
                                      ),
                                      if (active)
                                        const Chip(
                                          avatar: Icon(Icons.check, size: 18),
                                          label: Text('Đang theo'),
                                        ),
                                    ],
                                  ),
                                  if (program?.description.isNotEmpty ==
                                      true) ...[
                                    const SizedBox(height: 6),
                                    Text(program!.description),
                                  ],
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      Chip(
                                        label: Text(
                                          '${version.weeks.length} tuần',
                                        ),
                                      ),
                                      Chip(
                                        label: Text(
                                          '${version.cadence.supportedFrequencies.join('/')} buổi/tuần',
                                        ),
                                      ),
                                      Chip(
                                        label: Text(
                                          version.equipmentKeys.contains('gym')
                                              ? 'Phòng gym'
                                              : 'Tại nhà',
                                        ),
                                      ),
                                      for (final goal in version.goalKeys.take(
                                        2,
                                      ))
                                        Chip(
                                          label: Text(
                                            TrainingGoalKey.labelFor(goal),
                                          ),
                                        ),
                                    ],
                                  ),
                                  if (issue != null) ...[
                                    const SizedBox(height: 10),
                                    Text(
                                      issue,
                                      style: const TextStyle(
                                        color: AppColors.warning,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: FilledButton.icon(
                                      onPressed: active || issue != null
                                          ? null
                                          : () {
                                              Navigator.pop(sheetContext);
                                              _selectCatalogVersion(
                                                context,
                                                version,
                                              );
                                            },
                                      icon: Icon(
                                        active
                                            ? Icons.check
                                            : Icons.route_outlined,
                                      ),
                                      label: Text(
                                        active
                                            ? 'Đang sử dụng'
                                            : 'Chọn lộ trình này',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectCatalogVersion(
    BuildContext context,
    ProgramVersion version,
  ) async {
    await Future<void>.delayed(Duration.zero);
    if (!context.mounted) return;
    if (state.enrollment?.status == ProgramEnrollmentStatus.active) {
      final accepted = await confirmAction(
        context,
        title: 'Đổi lộ trình?',
        message:
            'Các buổi chưa tập của lộ trình hiện tại sẽ được hủy. Kết quả đã tập vẫn được giữ trong lịch sử.',
        confirmLabel: 'Đổi lộ trình',
      );
      if (!accepted || !context.mounted) return;
    }
    try {
      await state.enrollInProgramVersion(version.id);
    } on Object catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _reschedule(
    BuildContext context,
    WorkoutOccurrence occurrence,
  ) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final initialDate = occurrence.scheduledDate.isBefore(today)
        ? today
        : occurrence.scheduledDate;
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: occurrence.scheduledHour ?? state.programReminderHour,
        minute: occurrence.scheduledMinute ?? state.programReminderMinute,
      ),
    );
    if (time == null || !context.mounted) return;
    final mode = await showModalBottomSheet<OccurrenceRescheduleMode>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.event),
              title: const Text('Chỉ dời buổi này'),
              subtitle: const Text('Giữ nguyên lịch các buổi còn lại.'),
              onTap: () =>
                  Navigator.pop(sheetContext, OccurrenceRescheduleMode.single),
            ),
            ListTile(
              leading: const Icon(Icons.event_repeat),
              title: const Text('Dời cả phần lịch còn lại'),
              subtitle: const Text(
                'Dịch buổi này và mọi buổi sau cùng số ngày.',
              ),
              onTap: () =>
                  Navigator.pop(sheetContext, OccurrenceRescheduleMode.cascade),
            ),
          ],
        ),
      ),
    );
    if (mode == null || !context.mounted) return;
    try {
      await state.rescheduleOccurrence(
        occurrence,
        scheduledDate: date,
        hour: time.hour,
        minute: time.minute,
        mode: mode,
      );
    } on Object catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({
    required this.session,
    required this.occurrence,
    required this.onReschedule,
  });

  final ProgramSession session;
  final WorkoutOccurrence? occurrence;
  final VoidCallback? onReschedule;

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
          if (onReschedule != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: onReschedule,
                  icon: const Icon(Icons.event_repeat),
                  label: const Text('Dời lịch buổi này'),
                ),
              ),
            ),
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
    WorkoutOccurrenceStatus.abandoned ||
    WorkoutOccurrenceStatus.missed ||
    WorkoutOccurrenceStatus.skipped ||
    WorkoutOccurrenceStatus.cancelled => AppColors.textMuted,
    _ => AppColors.primary,
  };

  IconData _statusIcon(WorkoutOccurrenceStatus? value) => switch (value) {
    WorkoutOccurrenceStatus.completed => Icons.check,
    WorkoutOccurrenceStatus.abandoned => Icons.block_outlined,
    WorkoutOccurrenceStatus.missed => Icons.event_busy_outlined,
    WorkoutOccurrenceStatus.inProgress => Icons.play_arrow,
    WorkoutOccurrenceStatus.skipped => Icons.skip_next,
    WorkoutOccurrenceStatus.postponed => Icons.event_repeat,
    _ => Icons.calendar_today_outlined,
  };

  String _statusLabel(WorkoutOccurrenceStatus? value) => switch (value) {
    WorkoutOccurrenceStatus.completed => 'Xong',
    WorkoutOccurrenceStatus.abandoned => 'Bỏ dở (0 hiệp)',
    WorkoutOccurrenceStatus.missed => 'Đã lỡ',
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
