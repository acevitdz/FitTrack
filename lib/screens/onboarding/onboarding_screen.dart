import 'package:flutter/material.dart';

import '../../models/measurement_units.dart';
import '../../models/program.dart';
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
  final _nameKey = GlobalKey<FormState>();
  final _metricKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _height;
  late final TextEditingController _weight;
  var _step = 0;
  var _saving = false;
  var _population = 'healthy_adult_18_64';
  var _audience = ProgramAudiencePreference.unisex;
  var _goal = TrainingGoalKey.generalFitness;
  var _experience = 'beginner';
  var _equipment = 'bodyweight';
  var _sessionsPerWeek = 3;
  var _unit = MeasurementUnitSystem.metric;

  @override
  void initState() {
    super.initState();
    final profile = widget.state.profile;
    _unit = MeasurementUnitSystem.fromStored(widget.state.unit);
    _name = TextEditingController(text: profile.name);
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
    final preferences = widget.state.trainingPreferences;
    _population = preferences.populationKey;
    _audience = preferences.programAudiencePreference;
    _goal = preferences.goalKey;
    _experience = preferences.experienceKey;
    _sessionsPerWeek = preferences.sessionsPerWeek;
    _equipment = preferences.equipmentKeys.contains('gym')
        ? 'gym'
        : 'bodyweight';
  }

  @override
  void dispose() {
    _name.dispose();
    _height.dispose();
    _weight.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    FocusScope.of(context).unfocus();
    if (_step == 0 && !_nameKey.currentState!.validate()) return;
    if (_step == 1 && !_metricKey.currentState!.validate()) return;
    if (_step < 2) {
      setState(() => _step++);
      return;
    }
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final heightCm = _unit.heightToCentimeters(_parse(_height.text));
      final weightKg = _unit.weightToKilograms(_parse(_weight.text));
      final profile = widget.state.profile.copyWith(
        name: _name.text.trim(),
        heightCm: heightCm,
        currentWeightKg: weightKg,
        goal: TrainingGoalKey.labelFor(_goal),
        weeklyWorkoutGoal: _sessionsPerWeek,
        gender: _audience.name,
        onboardingCompleted: false,
      );
      await widget.state.updateProfile(profile);
      await widget.state.updateTrainingPreferences(
        UserTrainingPreferences(
          populationKey: _population,
          programAudiencePreference: _audience,
          goalKey: _goal,
          experienceKey: _experience,
          equipmentKeys: _equipmentKeys,
          sessionsPerWeek: _sessionsPerWeek,
        ),
        rematch: false,
      );
      await widget.state.updateBodyMetrics(
        heightCm: profile.heightCm,
        weightKg: profile.currentWeightKg,
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
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: OnboardingProgress(step: _step + 1),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: switch (_step) {
                      0 => _safetyStep(),
                      1 => _metricStep(),
                      _ => _preferenceStep(),
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
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Row(
            children: [
              if (_step > 0) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : () => setState(() => _step--),
                    child: const Text('Quay lại'),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                flex: 2,
                child: AppPrimaryButton(
                  label: _step == 2 ? 'Chọn chương trình' : 'Tiếp tục',
                  icon: _step == 2 ? Icons.auto_awesome : Icons.arrow_forward,
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

  Widget _safetyStep() => ListView(
    key: const ValueKey(0),
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
    children: [
      Text('Bắt đầu an toàn', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8),
      const Text(
        'FitTrack cung cấp chương trình cho người trưởng thành khỏe mạnh. Ứng dụng không chẩn đoán và không thay thế chuyên gia y tế.',
      ),
      const SizedBox(height: 22),
      Form(
        key: _nameKey,
        child: AppFormLabel(
          label: 'Tên hiển thị',
          child: TextFormField(
            controller: _name,
            textInputAction: TextInputAction.done,
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Hãy nhập tên hiển thị'
                : null,
          ),
        ),
      ),
      const SizedBox(height: 22),
      ChoiceCard(
        title: 'Người trưởng thành khỏe mạnh (18–64)',
        subtitle:
            'Không có chống chỉ định hoặc tình trạng cần giám sát chuyên môn',
        icon: Icons.health_and_safety_outlined,
        selected: _population == 'healthy_adult_18_64',
        onTap: () => setState(() => _population = 'healthy_adult_18_64'),
      ),
      const SizedBox(height: 10),
      ChoiceCard(
        title: 'Ngoài phạm vi hỗ trợ',
        subtitle:
            'Mang thai, dưới 18, trên 64 hoặc có tình trạng cần tư vấn chuyên môn',
        icon: Icons.medical_information_outlined,
        selected: _population == 'outside_supported_population',
        onTap: () =>
            setState(() => _population = 'outside_supported_population'),
      ),
      if (_population == 'outside_supported_population')
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'FitTrack sẽ không tự kê chương trình cho lựa chọn này. Hãy trao đổi với chuyên gia phù hợp trước khi tập.',
            ),
          ),
        ),
    ],
  );

  Widget _metricStep() => ListView(
    key: const ValueKey(1),
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
    children: [
      Text('Chỉ số cơ thể', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8),
      const Text(
        'Chiều cao và cân nặng là hai ô số duy nhất. BMI được tính tự động; FitTrack không yêu cầu cân nặng mục tiêu.',
      ),
      const SizedBox(height: 16),
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
      const SizedBox(height: 24),
      Form(
        key: _metricKey,
        child: Column(
          children: [
            AppFormLabel(
              label: 'Chiều cao (${_unit.heightSymbol})',
              child: TextFormField(
                controller: _height,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(suffixText: _unit.heightSymbol),
                validator: (value) {
                  final number = _tryParse(value);
                  final centimeters = number == null
                      ? null
                      : _unit.heightToCentimeters(number);
                  return centimeters == null ||
                          centimeters < 100 ||
                          centimeters > 250
                      ? 'Nhập chiều cao tương đương 100–250 cm'
                      : null;
                },
              ),
            ),
            const SizedBox(height: 18),
            AppFormLabel(
              label: 'Cân nặng (${_unit.weightSymbol})',
              child: TextFormField(
                controller: _weight,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(suffixText: _unit.weightSymbol),
                validator: (value) {
                  final number = _tryParse(value);
                  final kilograms = number == null
                      ? null
                      : _unit.weightToKilograms(number);
                  return kilograms == null ||
                          kilograms <= 0 ||
                          kilograms > 500
                      ? 'Nhập cân nặng tương đương trên 0 và không quá 500 kg'
                      : null;
                },
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _preferenceStep() => ListView(
    key: const ValueKey(2),
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
    children: [
      Text(
        'Chọn bằng một chạm',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 8),
      const Text(
        'FitTrack dùng các lựa chọn này để ghép một phiên bản chương trình đã phát hành.',
      ),
      const SizedBox(height: 20),
      _label('Mục tiêu'),
      _chips(
        values: TrainingGoalKey.labels,
        selected: _goal,
        onSelected: (value) => setState(() => _goal = value),
      ),
      _label('Số buổi tập mỗi tuần'),
      _sessionChips(),
      _label('Kinh nghiệm'),
      _chips(
        values: const {'beginner': 'Mới bắt đầu', 'intermediate': 'Đã tập'},
        selected: _experience,
        onSelected: (value) => setState(() => _experience = value),
      ),
      _label('Dụng cụ sẵn có'),
      _chips(
        values: const {'bodyweight': 'Không dụng cụ', 'gym': 'Phòng gym'},
        selected: _equipment,
        onSelected: (value) => setState(() => _equipment = value),
      ),
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
        onSelectionChanged: (value) => setState(() => _audience = value.first),
      ),
    ],
  );

  Widget _label(String value) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 8),
    child: Text(value, style: Theme.of(context).textTheme.titleMedium),
  );

  Widget _chips({
    required Map<String, String> values,
    required String selected,
    required ValueChanged<String> onSelected,
  }) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final entry in values.entries)
        ChoiceChip(
          label: Text(entry.value),
          selected: selected == entry.key,
          onSelected: (_) => onSelected(entry.key),
        ),
    ],
  );

  Widget _sessionChips() => Wrap(
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
  );

  List<String> get _equipmentKeys =>
      _equipment == 'gym' ? const ['bodyweight', 'gym'] : const ['bodyweight'];

  void _changeUnit(MeasurementUnitSystem next) {
    if (next == _unit) return;
    final height = _tryParse(_height.text);
    final weight = _tryParse(_weight.text);
    final heightCm = height == null ? null : _unit.heightToCentimeters(height);
    final weightKg = weight == null ? null : _unit.weightToKilograms(weight);
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
    });
  }

  double _parse(String value) => double.parse(value.replaceAll(',', '.'));
  double? _tryParse(String? value) =>
      double.tryParse((value ?? '').replaceAll(',', '.'));
}
