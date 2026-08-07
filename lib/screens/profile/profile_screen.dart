import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/account.dart';
import '../../models/measurement_units.dart';
import '../../models/program.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/design_system.dart';
import '../exercises/exercise_library_screen.dart';
import '../health/weight_screen.dart';
import '../history/legacy_data_screen.dart';
import 'achievements_screen.dart';
import 'reminders_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.state});
  final AppState state;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<void> _open(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final profile = state.profile;
    final measurementUnit = MeasurementUnitSystem.fromStored(state.unit);
    final initial = profile.name.trim().isEmpty
        ? 'F'
        : profile.name.trim().characters.first.toUpperCase();
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
        children: [
          Text('Hồ sơ', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Tooltip(
                    message: 'Đổi ảnh đại diện',
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _updateAvatar,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          CircleAvatar(
                            radius: 32,
                            backgroundColor: AppColors.paleBlue,
                            backgroundImage: fitTrackImageProvider(
                              profile.photoUrl,
                            ),
                            child: profile.photoUrl == null
                                ? Text(initial)
                                : null,
                          ),
                          const Positioned(
                            right: -3,
                            bottom: -3,
                            child: CircleAvatar(
                              radius: 12,
                              child: Icon(Icons.camera_alt_outlined, size: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.name,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          profile.email,
                          style: const TextStyle(color: AppColors.textMuted),
                        ),
                        const SizedBox(height: 4),
                        Text(_accountStatusLabel(state.accountAccess.status)),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Sửa tên hiển thị',
                    onPressed: _editName,
                    icon: const Icon(Icons.edit_outlined),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _Section(
            title: 'Luyện tập',
            children: [
              _MenuTile(
                icon: Icons.tune,
                title: 'Lựa chọn chương trình',
                subtitle:
                    'Mục tiêu, số buổi/tuần, kinh nghiệm, dụng cụ và ưu tiên',
                onTap: _editPreferences,
              ),
              _MenuTile(
                icon: Icons.menu_book_outlined,
                title: 'Thư viện bài tập',
                subtitle: 'Nội dung có sẵn, chỉ đọc',
                onTap: () => _open(ExerciseLibraryScreen(state: state)),
              ),
              _MenuTile(
                icon: Icons.monitor_weight_outlined,
                title: 'Chỉ số cơ thể',
                subtitle:
                    '${measurementUnit.formatHeight(profile.heightCm)} • '
                    '${measurementUnit.formatWeight(profile.currentWeightKg)}',
                onTap: () => _open(WeightScreen(state: state)),
              ),
              _MenuTile(
                icon: Icons.emoji_events_outlined,
                title: 'Thành tích',
                subtitle: 'Mốc buổi tập và chuỗi hoạt động',
                onTap: () => _open(AchievementsScreen(state: state)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Section(
            title: 'Trợ lý và nhắc lịch',
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.record_voice_over_outlined),
                title: const Text('Huấn luyện bằng giọng nói'),
                subtitle: const Text(
                  'Đọc nhịp và hướng dẫn ngay trên thiết bị',
                ),
                value: state.voiceCoachEnabled,
                onChanged: state.setVoiceCoachEnabled,
              ),
              SwitchListTile(
                secondary: const Icon(Icons.notifications_active_outlined),
                title: const Text('Âm thanh đếm ngược'),
                subtitle: const Text(
                  'Phát âm báo ở 3–2–1 giây cuối khi nghỉ và tập theo thời gian',
                ),
                value: state.countdownSoundsEnabled,
                onChanged: state.setCountdownSoundsEnabled,
              ),
              _MenuTile(
                icon: Icons.alarm_outlined,
                title: 'Thông báo và nhắc lịch',
                subtitle: 'Quyền thông báo và lịch nhắc do hệ thống tạo',
                onTap: () => _open(RemindersScreen(state: state)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Section(
            title: 'Ứng dụng',
            children: [
              ListTile(
                leading: const Icon(Icons.brightness_6_outlined),
                title: const Text('Giao diện'),
                trailing: SizedBox(
                  width: 116,
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<ThemeMode>(
                      value: state.themeMode,
                      isExpanded: true,
                      alignment: Alignment.center,
                      items: const [
                        DropdownMenuItem(
                          value: ThemeMode.light,
                          alignment: Alignment.center,
                          child: Text('Sáng', textAlign: TextAlign.center),
                        ),
                        DropdownMenuItem(
                          value: ThemeMode.dark,
                          alignment: Alignment.center,
                          child: Text('Tối', textAlign: TextAlign.center),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) state.setThemeMode(value);
                      },
                    ),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.straighten_outlined),
                title: const Text('Đơn vị'),
                trailing: DropdownButton<MeasurementUnitSystem>(
                  value: measurementUnit,
                  underline: const SizedBox.shrink(),
                  items: [
                    for (final value in MeasurementUnitSystem.values)
                      DropdownMenuItem(
                        value: value,
                        child: Text(
                          value == MeasurementUnitSystem.metric
                              ? 'cm / kg'
                              : 'in / lb',
                        ),
                      ),
                  ],
                  onChanged: (value) async {
                    if (value == null) return;
                    await state.setUnit(value.storageKey);
                    if (mounted) setState(() {});
                  },
                ),
              ),
              _MenuTile(
                icon: Icons.privacy_tip_outlined,
                title: 'Quyền riêng tư, an toàn và nguồn',
                subtitle: 'Giới hạn AI, dữ liệu camera và lưu trữ sức khỏe',
                onTap: _showSafetyAndPrivacy,
              ),
              if (state.plans.isNotEmpty || state.completions.isNotEmpty)
                _MenuTile(
                  icon: Icons.archive_outlined,
                  title: 'Dữ liệu cũ',
                  subtitle: 'Được giữ chỉ đọc để tham khảo',
                  onTap: () => _open(LegacyDataScreen(state: state)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _signOut,
            icon: const Icon(Icons.logout),
            label: const Text('Đăng xuất'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _deleteAccount,
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Xóa tài khoản'),
          ),
        ],
      ),
    );
  }

  Future<void> _editName() async {
    final value = await _showSettledDialog<String>(
      (_) => _EditDisplayNameDialog(initialName: widget.state.profile.name),
    );
    if (!mounted || value == null || value.isEmpty) return;
    try {
      await widget.state.updateProfile(
        widget.state.profile.copyWith(name: value),
      );
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã cập nhật tên hiển thị.')),
        );
      }
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Không thể cập nhật tên: ${error.toString().replaceFirst('Invalid argument(s): ', '')}',
          ),
        ),
      );
    }
  }

  Future<void> _updateAvatar() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 85,
    );
    if (image == null) return;
    final extension = image.name.split('.').last.toLowerCase();
    try {
      await widget.state.updateAvatar(
        await image.readAsBytes(),
        extension == 'png' ? 'png' : 'jpg',
      );
      if (mounted) setState(() {});
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không thể cập nhật ảnh: $error')));
    }
  }

  Future<void> _showSafetyAndPrivacy() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Quyền riêng tư và an toàn'),
      content: const SingleChildScrollView(
        child: Text(
          '• Hướng dẫn bằng camera xử lý khung hình trên thiết bị và mặc định không lưu hoặc tải video lên.\n\n'
          '• Chiều cao, cân nặng và lịch sử tập là dữ liệu riêng, được bảo vệ theo tài khoản của bạn.\n\n'
          '• Camera AI chỉ hỗ trợ kỹ thuật cho bài có quy tắc nhận diện đã phát hành, có thể không chính xác và luôn có chế độ tự xác nhận.\n\n'
          '• BMI và gợi ý tập chỉ mang tính tham khảo, không thay thế tư vấn hoặc chẩn đoán y khoa.\n\n'
          '• Nguồn của từng chương trình được hiển thị trong màn Chương trình và lịch sử phiên bản.',
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Đã hiểu'),
        ),
      ],
    ),
  );

  Future<void> _editPreferences() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProgramPreferencesScreen(state: widget.state),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _signOut() async {
    final accepted = await confirmAction(
      context,
      title: 'Đăng xuất?',
      message: 'Buổi tập đang dở sẽ được xóa khỏi thiết bị khi đăng xuất.',
      confirmLabel: 'Đăng xuất',
    );
    if (accepted) await widget.state.signOut();
  }

  Future<void> _deleteAccount() async {
    final accepted = await _showSettledDialog<bool>(
      (_) => const _DeleteAccountDialog(),
    );
    if (!mounted) return;
    if (accepted == true) {
      try {
        await widget.state.deleteAccountData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã xóa tài khoản và dữ liệu thành công.'),
            ),
          );
        }
      } on Object catch (error) {
        if (!mounted) return;
        final msg = error.toString().replaceFirst('Bad state: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể xóa tài khoản: $msg')),
        );
      }
    }
  }

  Future<T?> _showSettledDialog<T>(WidgetBuilder builder) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    final route = DialogRoute<T>(context: context, builder: builder);
    final result = await navigator.push<T>(route);
    await route.completed;
    return result;
  }

  String _accountStatusLabel(AccountStatus status) => switch (status) {
    AccountStatus.active => 'Tài khoản đang hoạt động',
    AccountStatus.suspended => 'Tài khoản đang tạm khóa',
    AccountStatus.deletionPending => 'Tài khoản đang được xóa',
    AccountStatus.deleted => 'Tài khoản đã xóa',
  };
}

class _EditDisplayNameDialog extends StatefulWidget {
  const _EditDisplayNameDialog({required this.initialName});

  final String initialName;

  @override
  State<_EditDisplayNameDialog> createState() => _EditDisplayNameDialogState();
}

class _EditDisplayNameDialogState extends State<_EditDisplayNameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Tên hiển thị'),
    content: TextField(
      controller: _controller,
      autofocus: true,
      maxLength: 50,
      textCapitalization: TextCapitalization.words,
      decoration: const InputDecoration(
        labelText: 'Tên bạn muốn hiển thị',
        helperText: 'Từ 2 đến 50 ký tự',
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _controller.text.trim()),
        child: const Text('Lưu'),
      ),
    ],
  );
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _controller = TextEditingController();

  bool get _isConfirmed {
    final confirmation = _controller.text.trim().toUpperCase();
    return confirmation == 'XÓA' || confirmation == 'XOA';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Xóa tài khoản và dữ liệu?'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Hồ sơ, lịch tập, lịch sử, ảnh và tài khoản đăng nhập sẽ được xóa khỏi hệ thống. Thao tác này không thể hoàn tác.',
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _controller,
          autofocus: true,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(labelText: 'Nhập XÓA để xác nhận'),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Hủy'),
      ),
      FilledButton(
        style: FilledButton.styleFrom(backgroundColor: AppColors.error),
        onPressed: _isConfirmed ? () => Navigator.pop(context, true) : null,
        child: const Text('Xóa tài khoản'),
      ),
    ],
  );
}

class ProgramPreferencesScreen extends StatefulWidget {
  const ProgramPreferencesScreen({super.key, required this.state});
  final AppState state;

  @override
  State<ProgramPreferencesScreen> createState() =>
      _ProgramPreferencesScreenState();
}

class _ProgramPreferencesScreenState extends State<ProgramPreferencesScreen> {
  late String _goal;
  late String _experience;
  late String _equipment;
  late int _sessionsPerWeek;
  late ProgramAudiencePreference _audience;
  late Set<int> _weekdays;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final current = widget.state.trainingPreferences;
    _goal = current.goalKey;
    _experience = current.experienceKey;
    _sessionsPerWeek = current.sessionsPerWeek;
    _weekdays = current.preferredWeekdays.length == _sessionsPerWeek
        ? current.preferredWeekdays.toSet()
        : _recommendedWeekdays(_sessionsPerWeek);
    _equipment = current.equipmentKeys.contains('gym') ? 'gym' : 'bodyweight';
    _audience =
        current.programAudiencePreference == ProgramAudiencePreference.unisex
        ? ProgramAudiencePreference.male
        : current.programAudiencePreference;
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_weekdays.length != _sessionsPerWeek) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hãy chọn đúng $_sessionsPerWeek ngày tập trong tuần.'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final current = widget.state.trainingPreferences;
      await widget.state.updateTrainingPreferences(
        UserTrainingPreferences(
          populationKey: current.populationKey,
          programAudiencePreference: _audience,
          goalKey: _goal,
          experienceKey: _experience,
          equipmentKeys: _equipment == 'gym'
              ? const ['bodyweight', 'gym']
              : const ['bodyweight'],
          sessionsPerWeek: _sessionsPerWeek,
          preferredWeekdays: _weekdays.toList()..sort(),
        ),
      );
      if (mounted) Navigator.pop(context);
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error
                  .toString()
                  .replaceFirst('Bad state: ', '')
                  .replaceFirst('Invalid argument(s): ', ''),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Lựa chọn chương trình')),
    body: FitTrackPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Thay đổi lựa chọn sẽ ghép lại một phiên bản đã phát hành và tạo lịch tự động mới.',
          ),
          _label('Mục tiêu'),
          for (final entry in TrainingGoalKey.labels.entries)
            _choice(entry.key, entry.value, _goal, (value) => _goal = value),
          _label('Số buổi tập mỗi tuần'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final value in const [2, 3, 4])
                ChoiceChip(
                  label: Text('$value buổi'),
                  selected: _sessionsPerWeek == value,
                  onSelected: (_) => setState(() {
                    _sessionsPerWeek = value;
                    _weekdays = _recommendedWeekdays(value);
                  }),
                ),
            ],
          ),
          _label('Ngày tập mong muốn'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var day = DateTime.monday; day <= DateTime.sunday; day++)
                FilterChip(
                  label: Text(_weekdayLabel(day)),
                  selected: _weekdays.contains(day),
                  onSelected: (selected) => setState(() {
                    if (selected && _weekdays.length < _sessionsPerWeek) {
                      _weekdays.add(day);
                    } else if (!selected) {
                      _weekdays.remove(day);
                    }
                  }),
                ),
            ],
          ),
          _label('Kinh nghiệm'),
          _choice(
            'beginner',
            'Mới bắt đầu',
            _experience,
            (v) => _experience = v,
          ),
          _choice(
            'intermediate',
            'Đã tập',
            _experience,
            (v) => _experience = v,
          ),
          _label('Dụng cụ'),
          _choice(
            'bodyweight',
            'Không dụng cụ',
            _equipment,
            (v) => _equipment = v,
          ),
          _choice('gym', 'Phòng gym', _equipment, (v) => _equipment = v),
          _label('Giới tính hồ sơ'),
          SegmentedButton<ProgramAudiencePreference>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: ProgramAudiencePreference.male,
                label: Text('Nam'),
              ),
              ButtonSegment(
                value: ProgramAudiencePreference.female,
                label: Text('Nữ'),
              ),
            ],
            selected: {_audience},
            onSelectionChanged: (value) =>
                setState(() => _audience = value.first),
          ),
          const SizedBox(height: 28),
          AppPrimaryButton(
            label: 'Lưu và chọn lại',
            loading: _saving,
            onPressed: _save,
          ),
        ],
      ),
    ),
  );

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 8),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );

  Widget _choice(
    String value,
    String label,
    String selected,
    ValueChanged<String> update,
  ) => ListTile(
    title: Text(label),
    leading: Icon(
      value == selected ? Icons.radio_button_checked : Icons.radio_button_off,
    ),
    selected: value == selected,
    onTap: () => setState(() => update(value)),
  );

  Set<int> _recommendedWeekdays(int frequency) => switch (frequency) {
    2 => {DateTime.monday, DateTime.thursday},
    3 => {DateTime.monday, DateTime.wednesday, DateTime.friday},
    4 => {
      DateTime.monday,
      DateTime.tuesday,
      DateTime.thursday,
      DateTime.saturday,
    },
    _ => {
      DateTime.monday,
      DateTime.tuesday,
      DateTime.wednesday,
      DateTime.friday,
      DateTime.saturday,
    },
  };

  String _weekdayLabel(int day) => switch (day) {
    DateTime.monday => 'T2',
    DateTime.tuesday => 'T3',
    DateTime.wednesday => 'T4',
    DateTime.thursday => 'T5',
    DateTime.friday => 'T6',
    DateTime.saturday => 'T7',
    _ => 'CN',
  };
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 6),
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      ),
      Card(child: Column(children: children)),
    ],
  );
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon),
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: const Icon(Icons.chevron_right),
    onTap: onTap,
  );
}
