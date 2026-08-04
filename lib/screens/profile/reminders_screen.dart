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
    if (_busy) return;
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

  Future<void> _selectMinutesBefore(int minutes) async {
    if (_busy || widget.state.programReminderMinutesBefore == minutes) return;
    setState(() => _busy = true);
    try {
      await widget.state.setProgramReminderTime(
        hour: widget.state.programReminderHour,
        minute: widget.state.programReminderMinute,
        minutesBefore: minutes,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
        .toList(growable: false);
    final time = TimeOfDay(
      hour: state.programReminderHour,
      minute: state.programReminderMinute,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        centerTitle: true,
        title: const Text(
          'FitTrack',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Tùy chọn thông báo',
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              showDragHandle: true,
              builder: (context) => SafeArea(
                child: ListTile(
                  leading: const Icon(Icons.settings_outlined),
                  title: const Text('Mở cài đặt thông báo'),
                  onTap: () {
                    Navigator.pop(context);
                    state.openNotificationSettings();
                  },
                ),
              ),
            ),
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text(
            'Thông báo và nhắc lịch',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.text,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          if (!state.notificationPermissionGranted) ...[
            _PermissionWarning(onOpenSettings: state.openNotificationSettings),
            const SizedBox(height: 14),
          ],
          _ReminderToggleCard(
            value:
                state.notificationsEnabled &&
                state.notificationPermissionGranted,
            busy: _busy,
            onChanged: _toggle,
          ),
          const SizedBox(height: 22),
          const _SectionTitle('Thời điểm nhắc'),
          const SizedBox(height: 10),
          _TimeCard(
            label: time.format(context),
            enabled: !_busy,
            onTap: _pickTime,
          ),
          const SizedBox(height: 12),
          _ReminderLeadTimeSelector(
            selectedMinutes: state.programReminderMinutesBefore,
            enabled: !_busy,
            onSelected: _selectMinutesBefore,
          ),
          const SizedBox(height: 26),
          const _SectionTitle('Lịch sắp tới'),
          const SizedBox(height: 10),
          if (upcoming.isEmpty)
            const _EmptyScheduleCard()
          else
            for (var index = 0; index < upcoming.length; index++) ...[
              _UpcomingWorkoutCard(
                title:
                    state.sessionForOccurrence(upcoming[index])?.title ??
                    'Buổi tập FitTrack',
                scheduledDate: upcoming[index].scheduledDate,
                time: time,
              ),
              if (index != upcoming.length - 1) const SizedBox(height: 10),
            ],
          const SizedBox(height: 18),
          const Text(
            'Lưu ý: Thời gian nhận thông báo có thể trễ vài phút tùy chế độ tiết kiệm pin của thiết bị.',
            style: TextStyle(
              color: Color(0xFF858A96),
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionWarning extends StatelessWidget {
  const _PermissionWarning({required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFFFD8D5),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFFB3261E),
            size: 24,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Quyền thông báo đang tắt',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: const Color(0xFF8C1D18),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                'Ứng dụng không thể gửi thông báo nhắc nhở tập luyện cho bạn.',
                style: TextStyle(
                  color: Color(0xFF5F3030),
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 3),
              TextButton(
                onPressed: onOpenSettings,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: AppColors.primary,
                ),
                child: const Text(
                  'Mở cài đặt',
                  style: TextStyle(
                    decoration: TextDecoration.underline,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ReminderToggleCard extends StatelessWidget {
  const _ReminderToggleCard({
    required this.value,
    required this.busy,
    required this.onChanged,
  });

  final bool value;
  final bool busy;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => _SurfaceCard(
    child: Row(
      children: [
        const _LeadingIcon(
          icon: Icons.notifications_active_outlined,
          color: AppColors.primary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nhắc buổi tập',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              const Text(
                'Nhận thông báo khi đến giờ tập',
                style: TextStyle(color: Color(0xFF7E8490), fontSize: 12),
              ),
            ],
          ),
        ),
        if (busy)
          const SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          )
        else
          Switch(value: value, onChanged: onChanged),
      ],
    ),
  );
}

class _TimeCard extends StatelessWidget {
  const _TimeCard({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _SurfaceCard(
    onTap: enabled ? onTap : null,
    child: Row(
      children: [
        const Icon(Icons.schedule, color: Color(0xFF7E8490), size: 24),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        const Icon(Icons.chevron_right, color: Color(0xFF9297A3)),
      ],
    ),
  );
}

class _ReminderLeadTimeSelector extends StatelessWidget {
  const _ReminderLeadTimeSelector({
    required this.selectedMinutes,
    required this.enabled,
    required this.onSelected,
  });

  final int selectedMinutes;
  final bool enabled;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final minutes in const [0, 15, 30, 60])
        ChoiceChip(
          label: Text(minutes == 0 ? 'Đúng giờ' : 'Trước $minutes phút'),
          selected: selectedMinutes == minutes,
          showCheckmark: false,
          onSelected: enabled ? (_) => onSelected(minutes) : null,
          side: BorderSide.none,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          selectedColor: AppColors.action,
          backgroundColor: const Color(0xFFEEF1F6),
          labelStyle: TextStyle(
            color: selectedMinutes == minutes
                ? Colors.white
                : AppColors.textMuted,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
    ],
  );
}

class _UpcomingWorkoutCard extends StatelessWidget {
  const _UpcomingWorkoutCard({
    required this.title,
    required this.scheduledDate,
    required this.time,
  });

  final String title;
  final DateTime scheduledDate;
  final TimeOfDay time;

  @override
  Widget build(BuildContext context) => _SurfaceCard(
    child: Row(
      children: [
        const _LeadingIcon(
          icon: Icons.event_outlined,
          color: AppColors.primary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 3),
              Text(
                '${_twoDigits(scheduledDate.day)}/${_twoDigits(scheduledDate.month)}/${scheduledDate.year} • ${time.format(context)}',
                style: const TextStyle(color: Color(0xFF7E8490), fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  static String _twoDigits(int value) => value.toString().padLeft(2, '0');
}

class _EmptyScheduleCard extends StatelessWidget {
  const _EmptyScheduleCard();

  @override
  Widget build(BuildContext context) => const _SurfaceCard(
    child: Row(
      children: [
        _LeadingIcon(
          icon: Icons.event_available_outlined,
          color: AppColors.primary,
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Không có buổi sắp tới',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 3),
              Text(
                'Lịch sẽ xuất hiện khi có chương trình phù hợp.',
                style: TextStyle(color: Color(0xFF7E8490), fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE8EAF0)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: child,
      ),
    ),
  );
}

class _LeadingIcon extends StatelessWidget {
  const _LeadingIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 40,
    height: 40,
    decoration: const BoxDecoration(
      color: Color(0xFFE8EEFF),
      shape: BoxShape.circle,
    ),
    alignment: Alignment.center,
    child: Icon(icon, color: color, size: 21),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: Theme.of(context).textTheme.titleMedium?.copyWith(
      color: AppColors.text,
      fontWeight: FontWeight.w800,
    ),
  );
}
