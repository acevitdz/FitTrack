import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/measurement_units.dart';
import '../../models/program.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/design_system.dart';
import '../exercises/exercise_library_screen.dart';
import '../health/weight_screen.dart';
import '../history/legacy_data_screen.dart';
import '../history/progress_screen.dart';
import 'achievements_screen.dart';
import 'edit_profile_screen.dart';
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
    final initial = profile.name.trim().isEmpty
        ? 'F'
        : profile.name.trim().characters.first.toUpperCase();

    return Material(
      color: AppColors.background,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            SizedBox(
              height: 48,
              child: Row(
                children: [
                  const SizedBox(width: 48),
                  Expanded(
                    child: Text(
                      'FitTrack',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  PopupMenuButton<_ProfileMenuAction>(
                    tooltip: 'Thông báo và cài đặt',
                    icon: const Icon(Icons.notifications_none_outlined),
                    onSelected: _handleProfileMenu,
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: _ProfileMenuAction.notifications,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.notifications_none_outlined),
                          title: Text('Thông báo'),
                        ),
                      ),
                      PopupMenuItem(
                        value: _ProfileMenuAction.settings,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.settings_outlined),
                          title: Text('Cài đặt và tiện ích'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Column(
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
                            radius: 40,
                            backgroundColor: AppColors.paleBlue,
                            backgroundImage: fitTrackImageProvider(
                              profile.photoUrl,
                            ),
                            child: profile.photoUrl == null
                                ? Text(
                                    initial,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium
                                        ?.copyWith(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w800,
                                        ),
                                  )
                                : null,
                          ),
                          const Positioned(
                            right: -2,
                            bottom: -2,
                            child: CircleAvatar(
                              radius: 13,
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              child: Icon(Icons.edit_outlined, size: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 13),
                  _ProfileNameButton(
                    name: profile.name,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.text,
                      fontWeight: FontWeight.w800,
                    ),
                    onTap: _renameProfile,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    profile.email,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF9297A3),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.local_fire_department_outlined,
                          color: Colors.white,
                          size: 15,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          TrainingGoalKey.labels[state
                                  .trainingPreferences
                                  .goalKey] ??
                              'Mục tiêu luyện tập',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            _FigmaProfileTile(
              icon: Icons.person_outline,
              title: 'Chỉnh sửa hồ sơ',
              onTap: () => _open(EditProfileScreen(state: state)),
            ),
            const SizedBox(height: 10),
            _FigmaProfileTile(
              icon: Icons.monitor_weight_outlined,
              title: 'Chỉ số cơ thể',
              onTap: () => _open(WeightScreen(state: state)),
            ),
            const SizedBox(height: 10),
            _FigmaProfileTile(
              icon: Icons.query_stats_outlined,
              title: 'Báo cáo tổng kết',
              onTap: () => _open(ProgressScreen(state: state)),
            ),
            const SizedBox(height: 10),
            _FigmaProfileTile(
              icon: Icons.alarm_outlined,
              title: 'Nhắc nhở luyện tập',
              onTap: () => _open(RemindersScreen(state: state)),
            ),
            const SizedBox(height: 16),
            _FigmaProfileTile(
              icon: Icons.logout,
              title: 'Đăng xuất',
              destructive: true,
              onTap: _signOut,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleProfileMenu(_ProfileMenuAction action) async {
    switch (action) {
      case _ProfileMenuAction.notifications:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bạn không có thông báo mới.')),
        );
        break;
      case _ProfileMenuAction.settings:
        await Navigator.push<void>(
          context,
          MaterialPageRoute(
            builder: (_) => Scaffold(
              appBar: AppBar(title: const Text('Cài đặt và tiện ích')),
              body: Builder(builder: _buildLegacyProfile),
            ),
          ),
        );
        if (mounted) setState(() {});
        break;
    }
  }

  Widget _buildLegacyProfile(BuildContext context) {
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
          Row(
            children: [
              const SizedBox(width: 48),
              Expanded(
                child: Text(
                  'FitTrack',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Thông báo',
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Bạn không có thông báo mới.')),
                ),
                icon: const Icon(Icons.notifications_none_outlined),
              ),
            ],
          ),
          const SizedBox(height: 26),
          Center(
            child: Column(
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
                          radius: 48,
                          backgroundColor: AppColors.paleBlue,
                          backgroundImage: fitTrackImageProvider(
                            profile.photoUrl,
                          ),
                          child: profile.photoUrl == null
                              ? Text(
                                  initial,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w800,
                                      ),
                                )
                              : null,
                        ),
                        const Positioned(
                          right: -2,
                          bottom: -2,
                          child: CircleAvatar(
                            radius: 15,
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            child: Icon(Icons.edit_outlined, size: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _ProfileNameButton(
                  name: profile.name,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.text,
                    fontWeight: FontWeight.w800,
                  ),
                  onTap: _renameProfile,
                ),
                const SizedBox(height: 3),
                Text(
                  profile.email,
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.local_fire_department_outlined,
                        color: Colors.white,
                        size: 17,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        TrainingGoalKey.labels[state
                                .trainingPreferences
                                .goalKey] ??
                            'Mục tiêu luyện tập',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _Section(
            title: 'Luyện tập',
            children: [
              _MenuTile(
                icon: Icons.person_outline,
                title: 'Chỉnh sửa hồ sơ',
                subtitle: 'Cập nhật tên hiển thị và ảnh đại diện',
                onTap: () => _open(EditProfileScreen(state: state)),
              ),
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
                title: const Text('Voice Coach'),
                subtitle: const Text('Đọc cue và chuyển pha trên thiết bị'),
                value: state.voiceCoachEnabled,
                onChanged: state.setVoiceCoachEnabled,
              ),
              SwitchListTile(
                secondary: const Icon(Icons.vibration),
                title: const Text('Phản hồi rung'),
                value: state.hapticsEnabled,
                onChanged: state.setHapticsEnabled,
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
                trailing: DropdownButton<ThemeMode>(
                  value: state.themeMode,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(
                      value: ThemeMode.system,
                      child: Text('Hệ thống'),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.light,
                      child: Text('Sáng'),
                    ),
                    DropdownMenuItem(value: ThemeMode.dark, child: Text('Tối')),
                  ],
                  onChanged: (value) {
                    if (value != null) state.setThemeMode(value);
                  },
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
              _MenuTile(
                icon: Icons.download_outlined,
                title: 'Yêu cầu xuất dữ liệu',
                subtitle: 'Tạo yêu cầu nhận bản sao dữ liệu tài khoản',
                onTap: _requestDataExport,
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
            child: const Text('Yêu cầu xóa tài khoản và dữ liệu'),
          ),
        ],
      ),
    );
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

  Future<void> _requestDataExport() async {
    try {
      await widget.state.requestDataExport();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.state.firebaseAvailable
                ? 'Đã gửi yêu cầu xuất dữ liệu.'
                : 'Bản demo chỉ lưu dữ liệu trên thiết bị; chưa có máy chủ để xử lý yêu cầu.',
          ),
        ),
      );
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không thể gửi yêu cầu: $error')));
    }
  }

  Future<void> _showSafetyAndPrivacy() => showDialog<void>(
    context: context,
    builder: (context) => const _PrivacyDialog(),
  );

  Future<void> _renameProfile() async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) =>
          _RenameProfileDialog(initialName: widget.state.profile.name),
    );
    if (name == null || !mounted) return;
    try {
      await widget.state.updateProfileName(name);
      if (!mounted) return;
      setState(() {});
    } on Object catch (error) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Không thể cập nhật tên'),
          content: Text('$error'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Đóng'),
            ),
          ],
        ),
      );
    }
  }

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
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => const _AccountConfirmationDialog(
        icon: Icons.logout,
        title: 'Đăng xuất?',
        message: 'Buổi tập đang dở sẽ được xóa khỏi thiết bị khi đăng xuất.',
        confirmLabel: 'Đăng xuất',
      ),
    );
    if (accepted == true) await widget.state.signOut();
  }

  Future<void> _deleteAccount() async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => const _AccountConfirmationDialog(
        icon: Icons.warning_amber_rounded,
        title: 'Gửi yêu cầu xóa tài khoản?',
        message:
            'FitTrack sẽ ghi nhận yêu cầu, đăng xuất và xóa bản dữ liệu cục bộ của tài khoản này.',
        confirmLabel: 'Gửi yêu cầu',
        destructive: true,
      ),
    );
    if (accepted != true) return;
    try {
      await widget.state.requestAccountDeletion();
    } on Object {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Chưa thể gửi yêu cầu'),
          content: Text(
            'FitTrack chưa thể ghi nhận yêu cầu xóa tài khoản. '
            'Vui lòng thử lại.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Đóng'),
            ),
          ],
        ),
      );
    }
  }
}

class _ProfileNameButton extends StatelessWidget {
  const _ProfileNameButton({
    required this.name,
    required this.style,
    required this.onTap,
  });

  final String name;
  final TextStyle? style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: 'Sửa tên hiển thị',
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Text(name, textAlign: TextAlign.center, style: style),
        ),
      ),
    ),
  );
}

class _RenameProfileDialog extends StatefulWidget {
  const _RenameProfileDialog({required this.initialName});

  final String initialName;

  @override
  State<_RenameProfileDialog> createState() => _RenameProfileDialogState();
}

class _RenameProfileDialogState extends State<_RenameProfileDialog> {
  final _formKey = GlobalKey<FormState>();
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

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, _controller.text.trim());
  }

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.symmetric(horizontal: 28),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Tên hiển thị',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('rename_profile_name'),
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _save(),
              decoration: const InputDecoration(hintText: 'Nhập tên hiển thị'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Tên hiển thị không được để trống'
                  : null,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Hủy'),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _save, child: const Text('Lưu')),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _PrivacyDialog extends StatelessWidget {
  const _PrivacyDialog();

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.symmetric(horizontal: 24),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircleAvatar(
            radius: 24,
            backgroundColor: Color(0xFFE8EEFF),
            foregroundColor: AppColors.primary,
            child: Icon(Icons.shield_outlined, size: 24),
          ),
          const SizedBox(height: 14),
          Text(
            'Quyền riêng tư và an toàn',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 18),
          const _PrivacyRow(
            icon: Icons.phone_android_outlined,
            label: 'Xử lý trên thiết bị, không lưu video.',
          ),
          const SizedBox(height: 12),
          const _PrivacyRow(
            icon: Icons.lock_outline,
            label: 'Dữ liệu sức khỏe được bảo vệ.',
          ),
          const SizedBox(height: 12),
          const _PrivacyRow(
            icon: Icons.verified_user_outlined,
            label: 'Camera Coach có Guided Confirmation.',
          ),
          const SizedBox(height: 12),
          const _PrivacyRow(
            icon: Icons.info_outline,
            label: 'BMI chỉ mang tính tham khảo.',
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Đã hiểu'),
            ),
          ),
        ],
      ),
    ),
  );
}

class _PrivacyRow extends StatelessWidget {
  const _PrivacyRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 28,
        height: 28,
        decoration: const BoxDecoration(
          color: Color(0xFFE8EEFF),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: AppColors.primary, size: 15),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textMuted,
            height: 1.35,
          ),
        ),
      ),
    ],
  );
}

class _AccountConfirmationDialog extends StatelessWidget {
  const _AccountConfirmationDialog({
    required this.icon,
    required this.title,
    required this.message,
    required this.confirmLabel,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final String confirmLabel;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final actionColor = destructive ? AppColors.error : AppColors.action;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.error.withValues(alpha: .12),
                  foregroundColor: AppColors.error,
                  child: Icon(icon, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 7),
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textMuted,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Hủy'),
                ),
                const SizedBox(width: 8),
                if (destructive)
                  FilledButton.icon(
                    onPressed: () => Navigator.pop(context, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: actionColor,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: Text(confirmLabel),
                  )
                else
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: FilledButton.styleFrom(backgroundColor: actionColor),
                    child: Text(confirmLabel),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum _ProfileMenuAction { notifications, settings }

class _FigmaProfileTile extends StatelessWidget {
  const _FigmaProfileTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final foreground = destructive ? AppColors.error : AppColors.text;
    final iconColor = destructive ? AppColors.error : AppColors.primary;
    final iconBackground = destructive
        ? AppColors.error.withValues(alpha: .1)
        : AppColors.primary.withValues(alpha: .08);

    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.outline),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 19, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, size: 20, color: foreground),
            ],
          ),
        ),
      ),
    );
  }
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
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final current = widget.state.trainingPreferences;
    _goal = current.goalKey;
    _experience = current.experienceKey;
    _sessionsPerWeek = current.sessionsPerWeek;
    _equipment = current.equipmentKeys.contains('gym') ? 'gym' : 'bodyweight';
    _audience = current.programAudiencePreference;
  }

  Future<void> _save() async {
    if (_saving) return;
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
              for (final value in const [2, 3, 4, 5])
                ChoiceChip(
                  label: Text('$value buổi'),
                  selected: _sessionsPerWeek == value,
                  onSelected: (_) => setState(() => _sessionsPerWeek = value),
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
          _label('Ưu tiên nội dung'),
          SegmentedButton<ProgramAudiencePreference>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: ProgramAudiencePreference.unisex,
                label: Text('Chung'),
              ),
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
