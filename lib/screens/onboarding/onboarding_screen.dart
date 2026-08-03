import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/program_seed_data.dart';
import '../../models/measurement_units.dart';
import '../../models/program.dart';
import '../../services/program_matcher.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../widgets/design_system.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.state});

  final AppState state;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _totalSteps = 4;
  static const _goalLabels = <String, String>{
    TrainingGoalKey.fatLoss: 'Giảm mỡ',
    TrainingGoalKey.generalFitness: 'Duy trì sức khỏe',
    TrainingGoalKey.strength: 'Tăng cơ',
    TrainingGoalKey.flexibility: 'Linh hoạt',
  };

  final _personalKey = GlobalKey<FormState>();
  final _metricKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _birthDate;
  late final TextEditingController _height;
  late final TextEditingController _weight;
  late final TextEditingController _targetWeight;

  var _step = 0;
  var _saving = false;
  DateTime? _dateOfBirth;
  var _population = 'healthy_adult_18_64';
  var _audience = ProgramAudiencePreference.unisex;
  var _goal = TrainingGoalKey.generalFitness;
  var _experience = 'beginner';
  var _equipment = 'bodyweight';
  var _sessionsPerWeek = 3;
  var _unit = MeasurementUnitSystem.metric;

  UserTrainingPreferences get _draftPreferences => UserTrainingPreferences(
    populationKey: _population,
    programAudiencePreference: _audience,
    goalKey: _goal,
    experienceKey: _experience,
    equipmentKeys: _equipmentKeys,
    sessionsPerWeek: _sessionsPerWeek,
  );

  ProgramMatchResult get _programPreview => const ProgramMatcher().match(
    preferences: _draftPreferences,
    catalog: widget.state.programVersions,
    fallbackProgramVersionId: ProgramSeedData.defaultFallbackProgramVersionId,
  );

  Program? get _previewProgram {
    final programId = _programPreview.version?.programId;
    if (programId == null) return null;
    for (final program in widget.state.programs) {
      if (program.id == programId) return program;
    }
    return null;
  }

  double? get _draftBmi {
    final height = _tryParse(_height.text);
    final weight = _tryParse(_weight.text);
    if (height == null || weight == null) return null;
    final heightCm = _unit.heightToCentimeters(height);
    final weightKg = _unit.weightToKilograms(weight);
    if (heightCm < 100 || heightCm > 250 || weightKg <= 0 || weightKg > 500) {
      return null;
    }
    final heightMeters = heightCm / 100;
    return weightKg / (heightMeters * heightMeters);
  }

  @override
  void initState() {
    super.initState();
    final profile = widget.state.profile;
    final preferences = widget.state.trainingPreferences;
    _unit = MeasurementUnitSystem.fromStored(widget.state.unit);
    _name = TextEditingController(text: profile.name);
    _dateOfBirth = profile.dateOfBirth;
    _birthDate = TextEditingController(text: _formatDate(_dateOfBirth));
    _height = TextEditingController(
      text: profile.heightCm > 0
          ? _unit
                .heightFromCentimeters(profile.heightCm)
                .toStringAsFixed(_unit == MeasurementUnitSystem.metric ? 0 : 1)
          : '',
    );
    _weight = TextEditingController(
      text: profile.currentWeightKg > 0
          ? _unit
                .weightFromKilograms(profile.currentWeightKg)
                .toStringAsFixed(1)
          : '',
    );
    _targetWeight = TextEditingController(
      text: (profile.targetWeightKg ?? profile.currentWeightKg) > 0
          ? _unit
                .weightFromKilograms(
                  profile.targetWeightKg ?? profile.currentWeightKg,
                )
                .toStringAsFixed(1)
          : '',
    );
    _population = preferences.populationKey;
    _audience = preferences.programAudiencePreference;
    _goal = preferences.goalKey;
    _experience = preferences.experienceKey;
    _sessionsPerWeek = preferences.sessionsPerWeek;
    _equipment = preferences.equipmentKeys.contains('gym')
        ? 'gym'
        : 'bodyweight';
    _updatePopulationFromBirthDate();
  }

  @override
  void dispose() {
    _name.dispose();
    _birthDate.dispose();
    _height.dispose();
    _weight.dispose();
    _targetWeight.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    FocusScope.of(context).unfocus();
    if (_step == 0 && !_personalKey.currentState!.validate()) return;
    if (_step == 1 && !_metricKey.currentState!.validate()) return;
    if (_step < _totalSteps - 1) {
      setState(() => _step++);
      return;
    }
    await _completeOnboarding();
  }

  Future<void> _completeOnboarding() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final heightCm = _unit.heightToCentimeters(_parse(_height.text));
      final weightKg = _unit.weightToKilograms(_parse(_weight.text));
      final targetWeightKg = _unit.weightToKilograms(
        _parse(_targetWeight.text),
      );
      final profile = widget.state.profile.copyWith(
        name: _name.text.trim(),
        heightCm: heightCm,
        currentWeightKg: weightKg,
        targetWeightKg: targetWeightKg,
        dateOfBirth: _dateOfBirth,
        goal: _goalLabels[_goal] ?? TrainingGoalKey.labelFor(_goal),
        weeklyWorkoutGoal: _sessionsPerWeek,
        gender: _audience.name,
        onboardingCompleted: false,
      );
      await widget.state.updateProfile(profile);
      await widget.state.updateTrainingPreferences(
        _draftPreferences,
        rematch: false,
      );
      await widget.state.updateBodyMetrics(
        heightCm: heightCm,
        weightKg: weightKg,
      );
      await widget.state.setUnit(_unit.storageKey);
      await widget.state.completeOnboarding(profile);
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể hoàn tất thiết lập: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
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
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                  child: OnboardingProgress(
                    step: _step + 1,
                    totalSteps: _totalSteps,
                  ),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: switch (_step) {
                      0 => _personalStep(),
                      1 => _metricStep(),
                      2 => _goalStep(),
                      _ => _completionStep(),
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Row(
            children: [
              if (_step > 0) ...[
                SizedBox(
                  width: 104,
                  child: OutlinedButton(
                    onPressed: _saving ? null : () => setState(() => _step--),
                    child: const Text('Quay lại'),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: AppPrimaryButton(
                  label: _step == _totalSteps - 1
                      ? 'Bắt đầu hành trình'
                      : 'Tiếp tục',
                  icon: _step == _totalSteps - 1
                      ? Icons.arrow_forward_rounded
                      : null,
                  loading: _saving,
                  onPressed: _next,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _personalStep() => ListView(
    key: const ValueKey('ui-05-personal'),
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
    children: [
      const _StepHeading(
        title: 'Thông tin cá nhân',
        subtitle: 'Giúp FitTrack xây dựng lộ trình phù hợp với bạn.',
      ),
      const SizedBox(height: 22),
      _OnboardingCard(
        child: Form(
          key: _personalKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppFormLabel(
                label: 'Họ và tên',
                child: TextFormField(
                  key: const Key('onboarding_name'),
                  controller: _name,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    hintText: 'Nhập họ và tên',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Hãy nhập họ và tên'
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              AppFormLabel(
                label: 'Ngày sinh',
                child: TextFormField(
                  key: const Key('onboarding_birth_date'),
                  controller: _birthDate,
                  readOnly: true,
                  onTap: _selectBirthDate,
                  decoration: const InputDecoration(
                    hintText: 'Chọn ngày sinh',
                    prefixIcon: Icon(Icons.calendar_today_outlined),
                  ),
                  validator: (_) =>
                      _dateOfBirth == null ? 'Hãy chọn ngày sinh' : null,
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
                onSelectionChanged: (value) =>
                    setState(() => _audience = value.first),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 14),
      _SafetyNotice(supported: _population == 'healthy_adult_18_64'),
    ],
  );

  Widget _metricStep() => ListView(
    key: const ValueKey('ui-06-metrics'),
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
    children: [
      const _StepHeading(
        title: 'Chỉ số cơ thể',
        subtitle: 'Các chỉ số giúp theo dõi tiến độ chính xác hơn.',
      ),
      const SizedBox(height: 18),
      SegmentedButton<MeasurementUnitSystem>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(
            value: MeasurementUnitSystem.metric,
            label: Text('cm / kg'),
          ),
          ButtonSegment(
            value: MeasurementUnitSystem.imperial,
            label: Text('in / lb'),
          ),
        ],
        selected: {_unit},
        onSelectionChanged: (values) => _changeUnit(values.first),
      ),
      const SizedBox(height: 16),
      _OnboardingCard(
        child: Form(
          key: _metricKey,
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: AppFormLabel(
                      label: 'Chiều cao',
                      child: TextFormField(
                        key: const Key('onboarding_height'),
                        controller: _height,
                        onChanged: (_) => setState(() {}),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          suffixText: _unit.heightSymbol,
                        ),
                        validator: _validateHeight,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppFormLabel(
                      label: 'Cân nặng hiện tại',
                      child: TextFormField(
                        key: const Key('onboarding_weight'),
                        controller: _weight,
                        onChanged: (_) => setState(() {}),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          suffixText: _unit.weightSymbol,
                        ),
                        validator: _validateWeight,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AppFormLabel(
                label: 'Cân nặng mục tiêu',
                child: TextFormField(
                  key: const Key('onboarding_target_weight'),
                  controller: _targetWeight,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(suffixText: _unit.weightSymbol),
                  validator: _validateWeight,
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      _BmiPreview(bmi: _draftBmi),
    ],
  );

  Widget _goalStep() => ListView(
    key: const ValueKey('ui-07-goals'),
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
    children: [
      const _StepHeading(
        title: 'Mục tiêu luyện tập',
        subtitle: 'Chọn mục tiêu chính để FitTrack đề xuất chương trình.',
      ),
      const SizedBox(height: 18),
      for (final entry in _goalLabels.entries) ...[
        _GoalCard(
          icon: _goalIcon(entry.key),
          title: entry.value,
          selected: _goal == entry.key,
          onTap: () => setState(() => _goal = entry.key),
        ),
        const SizedBox(height: 10),
      ],
      const SizedBox(height: 8),
      _OnboardingCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Số buổi tập mỗi tuần',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                IconButton.outlined(
                  tooltip: 'Giảm số buổi',
                  onPressed: _sessionsPerWeek <= 2
                      ? null
                      : () => setState(() => _sessionsPerWeek--),
                  icon: const Icon(Icons.remove),
                ),
                Expanded(
                  child: Text(
                    '$_sessionsPerWeek buổi',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton.outlined(
                  tooltip: 'Tăng số buổi',
                  onPressed: _sessionsPerWeek >= 5
                      ? null
                      : () => setState(() => _sessionsPerWeek++),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text('Kinh nghiệm', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Mới bắt đầu'),
                  selected: _experience == 'beginner',
                  onSelected: (_) => setState(() => _experience = 'beginner'),
                ),
                ChoiceChip(
                  label: const Text('Đã tập'),
                  selected: _experience == 'intermediate',
                  onSelected: (_) =>
                      setState(() => _experience = 'intermediate'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text('Dụng cụ', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Không dụng cụ'),
                  selected: _equipment == 'bodyweight',
                  onSelected: (_) => setState(() => _equipment = 'bodyweight'),
                ),
                ChoiceChip(
                  label: const Text('Phòng gym'),
                  selected: _equipment == 'gym',
                  onSelected: (_) => setState(() => _equipment = 'gym'),
                ),
              ],
            ),
          ],
        ),
      ),
    ],
  );

  Widget _completionStep() {
    final match = _programPreview;
    final version = match.version;
    final program = _previewProgram;
    final bmi = _draftBmi;
    return ListView(
      key: const ValueKey('ui-08-complete'),
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 28),
      children: [
        const Center(
          child: CircleAvatar(
            radius: 34,
            backgroundColor: Color(0xFFE7F8F0),
            foregroundColor: AppColors.success,
            child: Icon(Icons.check_rounded, size: 38),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Thiết lập hoàn tất!',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: AppColors.text,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Chào mừng ${_name.text.trim()} đến với FitTrack.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textMuted),
        ),
        const SizedBox(height: 24),
        _OnboardingCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.auto_awesome, color: AppColors.primary),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Chương trình dành cho bạn',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                version == null
                    ? 'Chưa thể tự ghép chương trình'
                    : (program?.title ?? 'Chương trình FitTrack'),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                version == null
                    ? 'Hồ sơ vẫn được lưu. Hãy trao đổi với chuyên gia trước khi bắt đầu tập.'
                    : '$_sessionsPerWeek buổi/tuần • ${version.weeks.length} tuần',
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                label: 'Mục tiêu',
                value: _goalLabels[_goal] ?? TrainingGoalKey.labelFor(_goal),
                icon: _goalIcon(_goal),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryCard(
                label: 'BMI tham khảo',
                value: bmi?.toStringAsFixed(1) ?? '--',
                icon: Icons.monitor_weight_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const Text(
          'Bạn có thể thay đổi các thông tin này bất cứ lúc nào trong Hồ sơ.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
      ],
    );
  }

  Future<void> _selectBirthDate() async {
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
      _birthDate.text = _formatDate(selected);
      _updatePopulationFromBirthDate();
    });
  }

  void _updatePopulationFromBirthDate() {
    final birthDate = _dateOfBirth;
    if (birthDate == null) return;
    final today = DateTime.now();
    var age = today.year - birthDate.year;
    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    _population = age >= 18 && age <= 64
        ? 'healthy_adult_18_64'
        : 'outside_supported_population';
  }

  String? _validateHeight(String? value) {
    final number = _tryParse(value);
    final centimeters = number == null
        ? null
        : _unit.heightToCentimeters(number);
    return centimeters == null || centimeters < 100 || centimeters > 250
        ? 'Chiều cao phải tương đương 100–250 cm'
        : null;
  }

  String? _validateWeight(String? value) {
    final number = _tryParse(value);
    final kilograms = number == null ? null : _unit.weightToKilograms(number);
    return kilograms == null || kilograms <= 0 || kilograms > 500
        ? 'Cân nặng phải trên 0 và không quá 500 kg'
        : null;
  }

  void _changeUnit(MeasurementUnitSystem next) {
    if (next == _unit) return;
    final height = _tryParse(_height.text);
    final weight = _tryParse(_weight.text);
    final target = _tryParse(_targetWeight.text);
    final heightCm = height == null ? null : _unit.heightToCentimeters(height);
    final weightKg = weight == null ? null : _unit.weightToKilograms(weight);
    final targetKg = target == null ? null : _unit.weightToKilograms(target);
    setState(() {
      _unit = next;
      if (heightCm != null) {
        _height.text = next
            .heightFromCentimeters(heightCm)
            .toStringAsFixed(next == MeasurementUnitSystem.metric ? 0 : 1);
      }
      if (weightKg != null) {
        _weight.text = next.weightFromKilograms(weightKg).toStringAsFixed(1);
      }
      if (targetKg != null) {
        _targetWeight.text = next
            .weightFromKilograms(targetKg)
            .toStringAsFixed(1);
      }
    });
  }

  IconData _goalIcon(String key) => switch (key) {
    TrainingGoalKey.fatLoss => Icons.local_fire_department_outlined,
    TrainingGoalKey.strength => Icons.fitness_center_outlined,
    TrainingGoalKey.flexibility => Icons.self_improvement_outlined,
    _ => Icons.favorite_border,
  };

  String _formatDate(DateTime? value) =>
      value == null ? '' : DateFormat('MM/dd/yyyy').format(value);
  List<String> get _equipmentKeys =>
      _equipment == 'gym' ? const ['bodyweight', 'gym'] : const ['bodyweight'];
  double _parse(String value) => double.parse(value.replaceAll(',', '.'));
  double? _tryParse(String? value) =>
      double.tryParse((value ?? '').replaceAll(',', '.'));
}

class _StepHeading extends StatelessWidget {
  const _StepHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
          color: AppColors.text,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 5),
      Text(subtitle, style: const TextStyle(color: AppColors.textMuted)),
    ],
  );
}

class _OnboardingCard extends StatelessWidget {
  const _OnboardingCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: AppColors.outline),
      borderRadius: BorderRadius.circular(16),
    ),
    child: child,
  );
}

class _SafetyNotice extends StatelessWidget {
  const _SafetyNotice({required this.supported});

  final bool supported;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: (supported ? AppColors.success : AppColors.warning).withValues(
        alpha: .1,
      ),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          supported
              ? Icons.verified_user_outlined
              : Icons.health_and_safety_outlined,
          color: supported ? AppColors.success : AppColors.warning,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            supported
                ? 'FitTrack hỗ trợ chương trình cho người trưởng thành khỏe mạnh từ 18–64 tuổi.'
                : 'FitTrack sẽ lưu hồ sơ nhưng không tự đề xuất chương trình. Hãy tham khảo chuyên gia phù hợp trước khi tập.',
            style: const TextStyle(fontSize: 12, height: 1.4),
          ),
        ),
      ],
    ),
  );
}

class _BmiPreview extends StatelessWidget {
  const _BmiPreview({required this.bmi});

  final double? bmi;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('onboarding-bmi-preview'),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.paleBlue.withValues(alpha: .48),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.primary.withValues(alpha: .16)),
    ),
    child: Row(
      children: [
        const CircleAvatar(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.primary,
          child: Icon(Icons.monitor_weight_outlined),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('BMI hiện tại', style: TextStyle(fontSize: 12)),
              Text(
                bmi?.toStringAsFixed(1) ?? '--',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Text(
                'Chỉ mang tính tham khảo, không thay thế tư vấn y tế.',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? AppColors.paleBlue.withValues(alpha: .42) : Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(
        color: selected ? AppColors.primary : AppColors.outline,
        width: selected ? 1.5 : 1,
      ),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: selected ? AppColors.primary : AppColors.input,
              foregroundColor: selected ? Colors.white : AppColors.primary,
              child: Icon(icon, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? AppColors.primary : AppColors.textMuted,
            ),
          ],
        ),
      ),
    ),
  );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => _OnboardingCard(
    child: Column(
      children: [
        Icon(icon, color: AppColors.primary),
        const SizedBox(height: 8),
        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
      ],
    ),
  );
}
