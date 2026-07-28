import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/measurement_units.dart';
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
  late final TextEditingController _heightController;
  late final TextEditingController _weightController;
  late final MeasurementUnitSystem _unit;

  late ProgramAudiencePreference _audience;
  late String _goal;
  late int _sessionsPerWeek;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    final profile = widget.state.profile;
    final preferences = widget.state.trainingPreferences;
    _unit = MeasurementUnitSystem.fromStored(widget.state.unit);
    _nameController = TextEditingController(text: profile.name);
    _heightController = TextEditingController(
      text: _unit
          .heightFromCentimeters(profile.heightCm)
          .toStringAsFixed(_unit == MeasurementUnitSystem.metric ? 0 : 1),
    );
    _weightController = TextEditingController(
      text: _unit
          .weightFromKilograms(profile.currentWeightKg)
          .toStringAsFixed(1),
    );
    _audience = preferences.programAudiencePreference;
    _goal = preferences.goalKey;
    _sessionsPerWeek = preferences.sessionsPerWeek;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  double _parseNumber(String value) =>
      double.tryParse(value.trim().replaceAll(',', '.')) ?? 0;

  String? _requiredNumber(String? value) {
    return _parseNumber(value ?? '') > 0 ? null : 'Giá trị không hợp lệ';
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (_saving || !_formKey.currentState!.validate()) return;

    final heightCm = _unit.heightToCentimeters(
      _parseNumber(_heightController.text),
    );
    final weightKg = _unit.weightToKilograms(
      _parseNumber(_weightController.text),
    );

    setState(() => _saving = true);
    try {
      final profile = widget.state.profile.copyWith(
        name: _nameController.text.trim(),
        heightCm: heightCm,
        currentWeightKg: weightKg,
        goal: TrainingGoalKey.labelFor(_goal),
        weeklyWorkoutGoal: _sessionsPerWeek,
        gender: _audience.name,
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
      await widget.state.updateBodyMetrics(
        heightCm: heightCm,
        weightKg: weightKg,
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
      appBar: AppBar(
        title: const Text('FitTrack'),
        centerTitle: true,
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
      body: FitTrackPage(
        maxWidth: 390,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        child: Form(
          key: _formKey,
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
              const SizedBox(height: 4),
              Text(
                'Cập nhật thông tin để tối ưu hóa lộ trình của bạn.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.center,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _saving ? null : _updateAvatar,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        radius: 42,
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
                          radius: 14,
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          child: Icon(Icons.edit_outlined, size: 15),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              AppFormLabel(
                label: 'Họ và tên',
                child: TextFormField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(hintText: 'Nhập họ và tên'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Họ tên không được để trống'
                      : null,
                ),
              ),
              const SizedBox(height: 16),
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
              const SizedBox(height: 16),
              AppFormLabel(
                label: 'Mục tiêu chính',
                child: DropdownButtonFormField<String>(
                  value: _goal,
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
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: AppFormLabel(
                      label: 'Chiều cao (${_unit.heightSymbol})',
                      child: TextFormField(
                        controller: _heightController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textInputAction: TextInputAction.next,
                        validator: _requiredNumber,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppFormLabel(
                      label: 'Cân nặng (${_unit.weightSymbol})',
                      child: TextFormField(
                        controller: _weightController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textInputAction: TextInputAction.done,
                        validator: _requiredNumber,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'Buổi tập mỗi tuần',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
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
                      icon: const Icon(Icons.remove),
                    ),
                    Expanded(
                      child: Text(
                        '$_sessionsPerWeek',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Tăng số buổi',
                      onPressed: _saving || _sessionsPerWeek >= 7
                          ? null
                          : () => setState(() => _sessionsPerWeek++),
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              AppPrimaryButton(
                label: 'Lưu thay đổi',
                loading: _saving,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
