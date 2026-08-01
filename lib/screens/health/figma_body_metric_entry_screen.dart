import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/measurement_units.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../widgets/design_system.dart';

class FigmaBodyMetricEntryScreen extends StatefulWidget {
  const FigmaBodyMetricEntryScreen({super.key, required this.state});

  final AppState state;

  @override
  State<FigmaBodyMetricEntryScreen> createState() =>
      _FigmaBodyMetricEntryScreenState();
}

class _FigmaBodyMetricEntryScreenState
    extends State<FigmaBodyMetricEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _height;
  late final TextEditingController _weight;
  late MeasurementUnitSystem _unit;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _unit = MeasurementUnitSystem.fromStored(widget.state.unit);
    _height = TextEditingController(
      text: _unit
          .heightFromCentimeters(widget.state.profile.heightCm)
          .toStringAsFixed(_unit == MeasurementUnitSystem.metric ? 0 : 1),
    );
    _weight = TextEditingController(
      text: _unit
          .weightFromKilograms(widget.state.profile.currentWeightKg)
          .toStringAsFixed(1),
    );
  }

  @override
  void dispose() {
    _height.dispose();
    _weight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final heightCm = _unit.heightToCentimeters(_number(_height.text));
    final weightKg = _unit.weightToKilograms(_number(_weight.text));
    final heightM = heightCm / 100;
    final bmi = heightM > 0 && weightKg > 0
        ? weightKg / (heightM * heightM)
        : null;
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Đóng',
          onPressed: _saving ? null : () => Navigator.pop(context),
          icon: const Icon(Icons.close),
        ),
        centerTitle: true,
        title: const Text(
          'Nhập cân nặng',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('Lưu'),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 17, 16, 16),
          decoration: const BoxDecoration(
            color: Color(0xF2F7FAFE),
            border: Border(top: BorderSide(color: AppColors.outline)),
          ),
          child: AppPrimaryButton(
            label: 'Lưu cân nặng',
            icon: Icons.save_outlined,
            loading: _saving,
            onPressed: _save,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
          child: Column(
            children: [
              _WeightCard(
                controller: _weight,
                unit: _unit,
                bmi: bmi,
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Expanded(
                    child: _InfoCard(
                      label: 'Ngày đo',
                      value: 'Hôm nay',
                      icon: Icons.calendar_today_outlined,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _InfoCard(
                      label: 'Giờ đo',
                      value: DateFormat('HH:mm').format(now),
                      icon: Icons.access_time,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Thông tin chỉ số',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
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
                        onSelectionChanged: (values) =>
                            _changeUnit(values.first),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _height,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Chiều cao hiện tại',
                          suffixText: _unit.heightSymbol,
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: (value) {
                          final centimeters = _unit.heightToCentimeters(
                            _number(value ?? ''),
                          );
                          return centimeters < 100 || centimeters > 250
                              ? 'Chiều cao phải tương đương 100–250 cm'
                              : null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 128,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        'assets/images/body_metric_scale.png',
                        fit: BoxFit.cover,
                      ),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xA600408A), Color(0x0000408A)],
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: SizedBox(
                            width: 210,
                            child: Text(
                              'Theo dõi cân nặng đều đặn để thấy sự thay đổi rõ rệt.',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.state.updateBodyMetrics(
        heightCm: _unit.heightToCentimeters(_parse(_height.text)),
        weightKg: _unit.weightToKilograms(_parse(_weight.text)),
      );
      await widget.state.setUnit(_unit.storageKey);
      if (mounted) Navigator.pop(context);
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Không thể cập nhật: $error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _changeUnit(MeasurementUnitSystem next) {
    if (next == _unit) return;
    final height = _number(_height.text);
    final weight = _number(_weight.text);
    final heightCm = _unit.heightToCentimeters(height);
    final weightKg = _unit.weightToKilograms(weight);
    setState(() {
      _unit = next;
      if (height > 0) {
        _height.text = next
            .heightFromCentimeters(heightCm)
            .toStringAsFixed(next == MeasurementUnitSystem.metric ? 0 : 1);
      }
      if (weight > 0) {
        _weight.text = next.weightFromKilograms(weightKg).toStringAsFixed(1);
      }
    });
  }

  double _parse(String value) => double.parse(value.replaceAll(',', '.'));
  double _number(String value) =>
      double.tryParse(value.replaceAll(',', '.')) ?? 0;
}

class _WeightCard extends StatelessWidget {
  const _WeightCard({
    required this.controller,
    required this.unit,
    required this.bmi,
    required this.onChanged,
  });

  final TextEditingController controller;
  final MeasurementUnitSystem unit;
  final double? bmi;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(
            'Cân nặng hiện tại (${unit.weightSymbol})',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SizedBox(
                width: 150,
                child: TextFormField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 48,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                  decoration: const InputDecoration(
                    filled: false,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                  onChanged: (_) => onChanged(),
                  validator: (value) {
                    final kilograms = unit.weightToKilograms(
                      double.tryParse((value ?? '').replaceAll(',', '.')) ?? 0,
                    );
                    return kilograms <= 0 || kilograms > 500
                        ? 'Cân nặng phải từ trên 0 đến 500 kg'
                        : null;
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  unit.weightSymbol,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: const Color(0xFF737783),
                  ),
                ),
              ),
            ],
          ),
          if (bmi != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '▣  BMI: ${bmi!.toStringAsFixed(1)}',
                style: const TextStyle(
                  color: AppColors.success,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Thể trạng: ${_bmiLabel(bmi!)}',
              style: const TextStyle(fontSize: 11, color: Color(0xFFC2C6D4)),
            ),
          ],
        ],
      ),
    ),
  );

  String _bmiLabel(double value) {
    if (value < 18.5) return 'Thiếu cân';
    if (value < 25) return 'Bình thường';
    if (value < 30) return 'Thừa cân';
    return 'Béo phì';
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF737783)),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(icon, size: 18, color: AppColors.primary),
            ],
          ),
        ],
      ),
    ),
  );
}
