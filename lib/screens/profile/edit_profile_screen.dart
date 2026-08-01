import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../models/program.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/design_system.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, required this.state});

  final AppState state;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _birthDateController;
  late final TextEditingController _targetWeightController;

  DateTime? _dateOfBirth;
  late ProgramAudiencePreference _audience;
  late String _goal;
  late int _sessionsPerWeek;
  var _saving = false;
  var _discarding = false;

  @override
  void initState() {
    super.initState();
    final profile = widget.state.profile;
    final preferences = widget.state.trainingPreferences;
    _nameController = TextEditingController(text: profile.name);
    _dateOfBirth = profile.dateOfBirth;
    _birthDateController = TextEditingController(
      text: _formatBirthDate(profile.dateOfBirth),
    );
    _targetWeightController = TextEditingController(
      text: (profile.targetWeightKg ?? profile.currentWeightKg).toStringAsFixed(
        1,
      ),
    );
    _audience = preferences.programAudiencePreference;
    _goal = preferences.goalKey;
    _sessionsPerWeek = preferences.sessionsPerWeek;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _birthDateController.dispose();
    _targetWeightController.dispose();
    super.dispose();
  }

  String _formatBirthDate(DateTime? value) =>
      value == null ? '' : DateFormat('MM/dd/yyyy').format(value);

  double _parseNumber(String value) =>
      double.tryParse(value.trim().replaceAll(',', '.')) ?? 0;

  String? _validateTargetWeight(String? value) {
    final weightKg = _parseNumber(value ?? '');
    return weightKg <= 0 || weightKg > 500
        ? 'Cân nặng mục tiêu phải trên 0 và không quá 500 kg'
        : null;
  }

  bool get _hasUnsavedChanges {
    final profile = widget.state.profile;
    final preferences = widget.state.trainingPreferences;
    final initialTarget = profile.targetWeightKg ?? profile.currentWeightKg;
    final targetWeight = _parseNumber(_targetWeightController.text);
    return _nameController.text.trim() != profile.name.trim() ||
        _dateOfBirth != profile.dateOfBirth ||
        (targetWeight - initialTarget).abs() > .01 ||
        _audience != preferences.programAudiencePreference ||
        _goal != preferences.goalKey ||
        _sessionsPerWeek != preferences.sessionsPerWeek;
  }

  Future<void> _handlePopInvoked(bool didPop) async {
    if (didPop || _saving || _discarding || !_hasUnsavedChanges) return;
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Bỏ thay đổi?'),
        content: const Text('Các thay đổi chưa lưu sẽ bị mất.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Tiếp tục chỉnh sửa'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Bỏ thay đổi'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) {
      setState(() => _discarding = true);
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (_saving || !_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final profile = widget.state.profile.copyWith(
        name: _nameController.text.trim(),
        goal: TrainingGoalKey.labelFor(_goal),
        weeklyWorkoutGoal: _sessionsPerWeek,
        gender: _audience.name,
        dateOfBirth: _dateOfBirth,
        targetWeightKg: _parseNumber(_targetWeightController.text),
      );
      final currentPreferences = widget.state.trainingPreferences;

      await widget.state.updateProfile(profile);
      await widget.state.updateTrainingPreferences(
        UserTrainingPreferences(
          populationKey: currentPreferences.populationKey,
          programAudiencePreference: _audience,
          goalKey: _goal,
          experienceKey: currentPreferences.experienceKey,
          equipmentKeys: currentPreferences.equipmentKeys,
          sessionsPerWeek: _sessionsPerWeek,
        ),
        rematch: false,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã cập nhật hồ sơ.')));
      Navigator.pop(context, true);
    } on Object catch (error) {
      if (!mounted) return;
      final message = error
          .toString()
          .replaceFirst('Invalid argument(s): ', '')
          .replaceFirst('Bad state: ', '');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không thể lưu: $message')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _selectBirthDate() async {
    if (_saving) return;
    final today = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(today.year - 25),
      firstDate: DateTime(today.year - 120, today.month, today.day),
      lastDate: today,
      helpText: 'Chọn ngày sinh',
    );
    if (selected == null || !mounted) return;
    setState(() {
      _dateOfBirth = selected;
      _birthDateController.text = _formatBirthDate(selected);
    });
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

  @override
  Widget build(BuildContext context) {
    final profile = widget.state.profile;
    final initial = profile.name.trim().isEmpty
        ? 'F'
        : profile.name.trim().characters.first.toUpperCase();

    return Scaffold(
      backgroundColor: AppColors.background,
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
            tooltip: 'Thông báo',
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Bạn không có thông báo mới.')),
            ),
            icon: const Icon(Icons.notifications_none_outlined),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: AppPrimaryButton(
            label: 'Lưu thay đổi',
            loading: _saving,
            onPressed: _save,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        canPop: _saving || _discarding || !_hasUnsavedChanges,
        onPopInvokedWithResult: (didPop, result) => _handlePopInvoked(didPop),
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Chỉnh sửa hồ sơ',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.text,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Cập nhật thông tin để tối ưu hóa lộ trình của bạn.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.center,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _saving ? null : _updateAvatar,
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
              ),
              const SizedBox(height: 22),
              AppFormLabel(
                label: 'Họ và tên',
                child: TextFormField(
                  key: const Key('edit_profile_name'),
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(hintText: 'Nhập họ và tên'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Họ tên không được để trống'
                      : null,
                ),
              ),
              const SizedBox(height: 14),
              AppFormLabel(
                label: 'Ngày sinh',
                child: TextFormField(
                  key: const Key('edit_profile_birth_date'),
                  controller: _birthDateController,
                  readOnly: true,
                  onTap: _selectBirthDate,
                  decoration: const InputDecoration(
                    hintText: 'Chọn ngày sinh',
                    suffixIcon: Icon(Icons.calendar_today_outlined, size: 19),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text('Giới tính', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
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
                  ButtonSegment(
                    value: ProgramAudiencePreference.unisex,
                    label: Text('Khác'),
                  ),
                ],
                selected: {_audience},
                onSelectionChanged: _saving
                    ? null
                    : (value) => setState(() => _audience = value.first),
              ),
              const SizedBox(height: 14),
              AppFormLabel(
                label: 'Mục tiêu chính',
                child: DropdownButtonFormField<String>(
                  key: const Key('edit_profile_goal'),
                  initialValue: _goal,
                  decoration: const InputDecoration(),
                  items: [
                    for (final entry in TrainingGoalKey.labels.entries)
                      DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                  ],
                  onChanged: _saving
                      ? null
                      : (value) {
                          if (value != null) setState(() => _goal = value);
                        },
                ),
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: AppFormLabel(
                      label: 'Cân nặng mục tiêu',
                      child: TextFormField(
                        key: const Key('edit_profile_target_weight'),
                        controller: _targetWeightController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textInputAction: TextInputAction.done,
                        onChanged: (_) => setState(() {}),
                        validator: _validateTargetWeight,
                        decoration: const InputDecoration(suffixText: 'kg'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Buổi tập/tuần',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: AppColors.outline),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                tooltip: 'Giảm số buổi',
                                onPressed: _saving || _sessionsPerWeek <= 1
                                    ? null
                                    : () => setState(() => _sessionsPerWeek--),
                                icon: const Icon(Icons.remove, size: 18),
                              ),
                              Expanded(
                                child: Text(
                                  '$_sessionsPerWeek',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Tăng số buổi',
                                onPressed: _saving || _sessionsPerWeek >= 7
                                    ? null
                                    : () => setState(() => _sessionsPerWeek++),
                                icon: const Icon(Icons.add, size: 18),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
