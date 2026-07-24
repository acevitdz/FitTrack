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

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final upcoming = state.occurrences
        .where(
          (item) =>
              item.status == WorkoutOccurrenceStatus.scheduled ||
              item.status == WorkoutOccurrenceStatus.postponed,
        )
        .take(5)
        .toList();
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
                  leading: const Icon(Icons.event_outlined),
                  title: Text(
                    state.sessionForOccurrence(occurrence)?.title ??
                        'Buổi tập FitTrack',
                  ),
                  subtitle: Text(
                    '${occurrence.scheduledDate.day.toString().padLeft(2, '0')}/'
                    '${occurrence.scheduledDate.month.toString().padLeft(2, '0')}/'
                    '${occurrence.scheduledDate.year} • ${time.format(context)}',
                  ),
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
