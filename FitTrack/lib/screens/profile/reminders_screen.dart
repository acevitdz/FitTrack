import 'package:flutter/material.dart';

import '../../models/program.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key, required this.state});
  final AppState state;

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  bool _busy = false;

  Future<void> _toggle(bool value) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (value && !widget.state.notificationPermissionGranted) {
        final granted = await widget.state.requestNotificationPermission();
        if (!granted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Chưa có quyền thông báo. Bạn vẫn có thể tập bình thường.',
                ),
              ),
            );
          }
          return;
        }
      }
      await widget.state.setNotificationsEnabled(value);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: widget.state.programReminderHour,
        minute: widget.state.programReminderMinute,
      ),
    );
    if (selected == null) return;
    await widget.state.setProgramReminderTime(
      hour: selected.hour,
      minute: selected.minute,
    );
    if (mounted) setState(() {});
  }

  Future<void> _editOccurrenceReminder(WorkoutOccurrence occurrence) async {
    var enabled = occurrence.reminderEnabled;
    var minutesBefore =
        occurrence.reminderMinutesBefore ??
        widget.state.programReminderMinutesBefore;
    var time = TimeOfDay(
      hour: occurrence.scheduledHour ?? widget.state.programReminderHour,
      minute: occurrence.scheduledMinute ?? widget.state.programReminderMinute,
    );
    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Nhắc riêng cho buổi này'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Bật nhắc nhở'),
                value: enabled,
                onChanged: (value) => setDialogState(() => enabled = value),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule),
                title: Text(time.format(context)),
                subtitle: const Text('Giờ bắt đầu buổi tập'),
                onTap: () async {
                  final selected = await showTimePicker(
                    context: dialogContext,
                    initialTime: time,
                  );
                  if (selected != null) {
                    setDialogState(() => time = selected);
                  }
                },
              ),
              DropdownButtonFormField<int>(
                initialValue: minutesBefore,
                decoration: const InputDecoration(labelText: 'Thông báo'),
                items: const [0, 15, 30, 60, 120]
                    .map(
                      (minutes) => DropdownMenuItem(
                        value: minutes,
                        child: Text(
                          minutes == 0 ? 'Đúng giờ' : 'Trước $minutes phút',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => minutesBefore = value);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
    if (shouldSave != true || !mounted) return;
    try {
      await widget.state.setOccurrenceReminder(
        occurrence,
        enabled: enabled,
        hour: time.hour,
        minute: time.minute,
        minutesBefore: minutesBefore,
      );
      if (mounted) setState(() {});
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final upcoming =
        state.occurrences
            .where(
              (item) =>
                  item.status == WorkoutOccurrenceStatus.scheduled ||
                  item.status == WorkoutOccurrenceStatus.postponed,
            )
            .toList()
          ..sort((left, right) {
            final date = left.scheduledDate.compareTo(right.scheduledDate);
            if (date != 0) return date;
            return (left.scheduledHour ?? state.programReminderHour).compareTo(
              right.scheduledHour ?? state.programReminderHour,
            );
          });
    final time = TimeOfDay(
      hour: state.programReminderHour,
      minute: state.programReminderMinute,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Thông báo và nhắc lịch')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.notifications_active_outlined),
              title: const Text('Nhắc buổi tập'),
              subtitle: const Text(
                'Thông báo được sinh từ lịch chương trình, không tạo lịch tập mới.',
              ),
              value:
                  state.notificationsEnabled &&
                  state.notificationPermissionGranted,
              onChanged: _busy ? null : _toggle,
            ),
          ),
          if (state.notificationPermissionRequested &&
              !state.notificationPermissionGranted) ...[
            const SizedBox(height: 10),
            Card(
              color: AppColors.warning.withValues(alpha: .12),
              child: ListTile(
                leading: const Icon(Icons.notifications_off_outlined),
                title: const Text('Quyền thông báo đang tắt'),
                subtitle: const Text(
                  'Bạn có thể bật lại trong cài đặt Android.',
                ),
                trailing: TextButton(
                  onPressed: state.openNotificationSettings,
                  child: const Text('Mở cài đặt'),
                ),
              ),
            ),
          ],
          const SizedBox(height: 18),
          Text('Thời điểm nhắc', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.schedule),
              title: Text(time.format(context)),
              subtitle: const Text('Giờ mặc định của buổi tập trong ngày'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickTime,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              for (final minutes in const [0, 15, 30, 60])
                ChoiceChip(
                  label: Text(
                    minutes == 0 ? 'Đúng giờ' : 'Trước $minutes phút',
                  ),
                  selected: state.programReminderMinutesBefore == minutes,
                  onSelected: (_) async {
                    await state.setProgramReminderTime(
                      hour: state.programReminderHour,
                      minute: state.programReminderMinute,
                      minutesBefore: minutes,
                    );
                    if (mounted) setState(() {});
                  },
                ),
            ],
          ),
          const SizedBox(height: 22),
          Text('Lịch sắp tới', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (upcoming.isEmpty)
            const Card(
              child: ListTile(
                leading: Icon(Icons.event_available),
                title: Text('Không có buổi sắp tới'),
                subtitle: Text(
                  'Lịch sẽ xuất hiện khi có chương trình phù hợp.',
                ),
              ),
            )
          else
            for (final occurrence in upcoming)
              Card(
                child: ListTile(
                  leading: Icon(
                    occurrence.reminderEnabled
                        ? Icons.notifications_active_outlined
                        : Icons.notifications_off_outlined,
                  ),
                  title: Text(
                    state.sessionForOccurrence(occurrence)?.title ??
                        'Buổi tập FitTrack',
                  ),
                  subtitle: Text(
                    '${occurrence.scheduledDate.day.toString().padLeft(2, '0')}/'
                    '${occurrence.scheduledDate.month.toString().padLeft(2, '0')}/'
                    '${occurrence.scheduledDate.year} • '
                    '${TimeOfDay(hour: occurrence.scheduledHour ?? state.programReminderHour, minute: occurrence.scheduledMinute ?? state.programReminderMinute).format(context)}'
                    '${occurrence.reminderEnabled ? ' • trước ${occurrence.reminderMinutesBefore ?? state.programReminderMinutesBefore} phút' : ' • đã tắt nhắc'}',
                  ),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () => _editOccurrenceReminder(occurrence),
                ),
              ),
          const SizedBox(height: 16),
          const Text(
            'Thông báo có thể đến trễ tùy cơ chế tiết kiệm pin của Android. Active Workout vẫn hoạt động khi bạn không cấp quyền thông báo.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
